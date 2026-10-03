import Foundation
import Observation

/// Every transaction, kept as one JSON file on the device. The app, its
/// App Intents and its views all share one instance (`AppEnvironment.store`).
@MainActor
@Observable
public final class StarHashStore {
    /// Newest first.
    public private(set) var transactions: [Transaction] = []

    @ObservationIgnored private let fileURL: URL?

    /// False while the file exists but could not be read: a Shortcuts
    /// automation can wake the app while the phone is still locked after a
    /// restart, when the file is sealed. Writing then would replace a
    /// history the store never saw, so changes stay in memory until the
    /// file reads again and they are merged into it.
    @ObservationIgnored private var hasReadFile = true

    /// `fileURL` nil keeps everything in memory (tests, previews).
    public init(fileURL: URL?) {
        self.fileURL = fileURL
        reloadFromDisk()
    }

    public static var defaultFileURL: URL {
        let folder = URL.applicationSupportDirectory.appending(path: "StarHash", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "transactions.json")
    }

    // MARK: Reading

    public func transaction(id: UUID) -> Transaction? {
        transactions.first { $0.id == id }
    }

    /// People and merchants paid, most recent first, one entry each. Only
    /// ones StarHash can dial again: a merchant read from an SMS without
    /// its code is left out.
    public func recentRecipients(limit: Int = 10) -> [Recipient] {
        var seen = Set<String>()
        var result: [Recipient] = []
        for t in transactions where t.direction == .outgoing && t.counterparty.isPayable {
            let key = t.counterparty.kind.rawValue + t.counterparty.destination
            if seen.insert(key).inserted { result.append(t.counterparty) }
            if result.count == limit { break }
        }
        return result
    }

    /// Outgoing totals to one destination this calendar year.
    public func yearToDate(for recipient: Recipient, now: Date = .now, calendar: Calendar = .current) -> (amount: Int, count: Int) {
        let year = calendar.component(.year, from: now)
        let matching = transactions.filter {
            $0.direction == .outgoing && $0.status != .failed
                && $0.counterparty.kind == recipient.kind
                && $0.counterparty.destination == recipient.destination
                && calendar.component(.year, from: $0.date) == year
        }
        return (matching.reduce(0) { $0 + $1.amount }, matching.count)
    }

    // MARK: Writing

    public func add(_ transaction: Transaction) {
        transactions.append(transaction)
        sortAndSave()
    }

    public func update(_ transaction: Transaction) {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return }
        transactions[index] = transaction
        sortAndSave()
    }

    public func delete(id: UUID) {
        transactions.removeAll { $0.id == id }
        save()
    }

    public func deleteAll() {
        transactions.removeAll()
        save()
    }

    /// Every transaction's location removed, for turning Nearby off.
    public func clearLocations() {
        guard transactions.contains(where: { $0.location != nil }) else { return }
        for i in transactions.indices { transactions[i].location = nil }
        save()
    }

    /// Everything this store keeps, gone: its transactions, its file, and
    /// any damaged copies set aside beside it. For "Delete All Data".
    public func eraseAll() {
        transactions.removeAll()
        guard let fileURL else { return }
        let folder = fileURL.deletingLastPathComponent()
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(stem) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// A payment just dialled from StarHash, pending until its SMS arrives.
    ///
    /// The amount stays on Pay's keypad after dialling, so a call cancelled
    /// at the system prompt can be dialled again. With `retryWindow`, a
    /// pending payment from StarHash to the same recipient for the same
    /// amount, dialled less than that long ago, is taken to be that retry:
    /// it moves to `date` instead of a second one being added. It has no fee
    /// until the SMS confirming it gives one.
    @discardableResult
    public func recordPayment(
        to recipient: Recipient,
        amount: Int,
        date: Date = .now,
        location: Transaction.Coordinate? = nil,
        retryWindow: TimeInterval = 0
    ) -> Transaction {
        if retryWindow > 0, let index = transactions.firstIndex(where: {
            $0.status == .pending && $0.source == .app && $0.direction == .outgoing
                && $0.amount == amount && $0.counterparty.kind == recipient.kind
                && $0.counterparty.destination == recipient.destination
                && date.timeIntervalSince($0.date) >= 0 && date.timeIntervalSince($0.date) < retryWindow
        }) {
            var retry = transactions[index]
            retry.date = date
            if retry.counterparty.name == nil { retry.counterparty.name = recipient.name }
            if let location { retry.location = location }
            transactions[index] = retry
            sortAndSave()
            return retry
        }
        let transaction = Transaction(
            direction: .outgoing, counterparty: recipient, amount: amount,
            date: date, status: .pending, source: .app, location: location
        )
        add(transaction)
        return transaction
    }

    /// Applies a carrier SMS: confirms the matching pending payment (same
    /// amount and destination, dialled within 6 hours of the message; the
    /// closest one when there are several) or adds a new transaction. A
    /// message already applied changes nothing. Returns the transaction it
    /// confirmed or added.
    @discardableResult
    public func apply(_ sms: ParsedSMS, receivedAt now: Date = .now) -> Transaction {
        if let existing = alreadyApplied(sms) { return existing }
        let date = sms.date ?? now
        if sms.direction == .outgoing, let index = pendingMatch(for: sms, at: date) {
            var match = transactions[index]
            match.status = .confirmed
            // The fee only ever comes from the SMS.
            match.fee = sms.fee
            match.reference = sms.reference
            match.balanceAfter = sms.balanceAfter
            match.messageDate = sms.date
            if match.counterparty.name == nil { match.counterparty.name = sms.counterparty.name }
            transactions[index] = match
            sortAndSave()
            return match
        }
        let transaction = Transaction(
            direction: sms.direction, counterparty: sms.counterparty, amount: sms.amount,
            fee: sms.fee, date: date, status: .confirmed, source: .sms,
            reference: sms.reference, balanceAfter: sms.balanceAfter, messageDate: sms.date
        )
        add(transaction)
        return transaction
    }

    /// The transaction a message was already applied to: the same carrier
    /// reference, or, for a message without one, the same movement at the
    /// same moment. The automation can run twice for one SMS, and the
    /// Process Carrier SMS action can be run by hand.
    private func alreadyApplied(_ sms: ParsedSMS) -> Transaction? {
        if let reference = sms.reference {
            return transactions.first { $0.reference == reference }
        }
        guard let date = sms.date else { return nil }
        return transactions.first {
            $0.messageDate == date && $0.direction == sms.direction && $0.amount == sms.amount
                && $0.counterparty.destination == sms.counterparty.destination
        }
    }

    /// The pending payment a sent-money message confirms.
    private func pendingMatch(for sms: ParsedSMS, at date: Date) -> Int? {
        let window: TimeInterval = 6 * 3600
        return transactions.indices
            .filter {
                let t = transactions[$0]
                return t.status == .pending && t.direction == .outgoing && t.amount == sms.amount
                    && t.counterparty.destination == sms.counterparty.destination
                    && abs(t.date.timeIntervalSince(date)) < window
            }
            .min { abs(transactions[$0].date.timeIntervalSince(date)) < abs(transactions[$1].date.timeIntervalSince(date)) }
    }

    // MARK: Disk

    /// Reads the file again (the app calls this on returning to the
    /// foreground). A file that cannot be decoded is moved aside rather than
    /// overwritten, so it can still be recovered.
    public func reloadFromDisk() {
        guard let fileURL else { return }
        switch Self.read(fileURL) {
        case .missing:
            hasReadFile = true
        case .unreadable:
            hasReadFile = false
        case .damaged:
            Self.setAside(fileURL)
            hasReadFile = true
        case .read(let saved):
            if hasReadFile {
                transactions = saved.sorted { $0.date > $1.date }
            } else {
                // What changed while the file was sealed is newer than the
                // file, so it wins; everything else comes from the file.
                let inMemory = Set(transactions.map(\.id))
                transactions = (transactions + saved.filter { !inMemory.contains($0.id) })
                    .sorted { $0.date > $1.date }
                hasReadFile = true
                write(to: fileURL)
            }
        }
    }

    private func sortAndSave() {
        transactions.sort { $0.date > $1.date }
        save()
    }

    private func save() {
        guard let fileURL else { return }
        if !hasReadFile {
            // Merges and writes once the file reads; until then, memory only.
            reloadFromDisk()
            return
        }
        write(to: fileURL)
    }

    /// Readable once the phone has been unlocked after a restart, so the
    /// Process Carrier SMS action can log a payment while it is locked.
    private func write(to fileURL: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(transactions) {
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    private enum FileState {
        case missing
        case unreadable
        case damaged
        case read([Transaction])
    }

    private static func read(_ url: URL) -> FileState {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url) else { return .unreadable }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([Transaction].self, from: data) else { return .damaged }
        return .read(decoded)
    }

    /// "transactions.json" becomes "transactions.damaged-<time>.json".
    private static func setAside(_ url: URL) {
        let stamp = Int(Date.now.timeIntervalSince1970)
        let backup = url.deletingPathExtension().appendingPathExtension("damaged-\(stamp).json")
        try? FileManager.default.moveItem(at: url, to: backup)
    }
}
