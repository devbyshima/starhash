import Foundation
import Observation

/// Every transaction, kept as one JSON file on the device. The app, its
/// App Intents and its views all share one instance (`AppEnvironment.store`).
@MainActor
@Observable
public final class StarHashStore {
    /// Newest first.
    public private(set) var transactions: [Transaction] = []

    /// Bumped whenever the locations are wiped (Nearby turned off, Delete
    /// All Data). A payment notes it when it starts locating, so a fix that
    /// arrives after a wipe is dropped rather than written back.
    public private(set) var locationsGeneration = 0

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
        locationsGeneration += 1
        guard transactions.contains(where: { $0.location != nil }) else { return }
        for i in transactions.indices { transactions[i].location = nil }
        save()
    }

    /// Everything this store keeps, gone: its transactions, its file, and
    /// any damaged copies set aside beside it. For "Delete All Data".
    public func eraseAll() {
        locationsGeneration += 1
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
    /// until the SMS confirming it gives one. `wallet` is the wallet it was
    /// dialled with.
    @discardableResult
    public func recordPayment(
        to recipient: Recipient,
        amount: Int,
        date: Date = .now,
        location: Transaction.Coordinate? = nil,
        wallet: Recipient.Network? = nil,
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
            if let wallet { retry.wallet = wallet }
            transactions[index] = retry
            sortAndSave()
            return retry
        }
        let transaction = Transaction(
            direction: .outgoing, counterparty: recipient, amount: amount,
            date: date, status: .pending, source: .app, location: location, wallet: wallet
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
            return confirm(at: index, with: sms)
        }
        let transaction = Transaction(
            direction: sms.direction, counterparty: sms.counterparty, amount: sms.amount,
            fee: sms.fee, date: date, status: .confirmed, source: .sms,
            reference: sms.reference, balanceAfter: sms.balanceAfter, wallet: sms.wallet, messageDate: sms.date
        )
        add(transaction)
        return transaction
    }

    /// Confirms the payment at `index` with the message that says it went
    /// through, and returns it.
    private func confirm(at index: Int, with sms: ParsedSMS) -> Transaction {
        var match = transactions[index]
        match.status = .confirmed
        // A failed payment had a message after all.
        match.failureReason = nil
        // The fee only ever comes from the SMS, with MoMoAdvance's on
        // top when its message came first.
        match.fee = match.fee(adding: sms.fee)
        match.reference = sms.reference
        match.balanceAfter = sms.balanceAfter
        match.messageDate = sms.date
        match.wallet = sms.wallet
        // A merchant takes the name its code is registered under, from
        // a message that names the code: it can differ from the shop's
        // sign, and it is what the code shows as from now on (Activity,
        // Recent, Nearby). A message without the code may be another
        // payment's of the same amount, so it only fills a missing
        // name. A person keeps the name they were paid under.
        if match.counterparty.kind == .merchant, !sms.counterparty.destination.isEmpty,
           let name = sms.counterparty.name {
            match.counterparty.name = name
        } else if match.counterparty.name == nil {
            match.counterparty.name = sms.counterparty.name
        }
        transactions[index] = match
        sortAndSave()
        return match
    }

    /// Applies a message saying a payment did not go through: the payment
    /// it matches, as `apply` matches one, is marked failed (with the reason
    /// `.message`). One that matches nothing is ignored: StarHash keeps no
    /// record of attempts it did not dial. Returns the payment it failed.
    @discardableResult
    public func applyFailure(_ sms: ParsedSMS, receivedAt now: Date = .now) -> Transaction? {
        guard sms.direction == .outgoing, !sms.counterparty.destination.isEmpty,
              let index = pendingMatch(for: sms, at: sms.date ?? now) else { return nil }
        var failed = transactions[index].markedFailed()
        failed.failureReason = .message
        transactions[index] = failed
        save()
        return failed
    }

    /// Applies a MoMoAdvance message: the overdraft's access fee joins the
    /// fee of the payment it paid for. That is the outgoing payment whose
    /// own message, already applied, gives the same moment to the second,
    /// or else the closest one from StarHash still waiting for its message
    /// (it takes the access fee now and its own fee when that arrives). A
    /// message applied twice changes nothing; one that matches no payment
    /// is ignored. Returns the payment it added the fee to.
    @discardableResult
    public func applyOverdraft(_ use: OverdraftUse, receivedAt now: Date = .now) -> Transaction? {
        guard use.accessFee > 0, let index = overdraftMatch(for: use, at: use.date ?? now) else { return nil }
        return addAccessFee(of: use, at: index)
    }

    /// The access fee joins the payment at `index`: in its fee at once when
    /// it is confirmed, or when its own message confirms it.
    private func addAccessFee(of use: OverdraftUse, at index: Int) -> Transaction {
        var paid = transactions[index]
        guard paid.accessFee != use.accessFee else { return paid }
        if paid.status == .confirmed {
            paid.fee = (paid.walletFee ?? 0) + use.accessFee
        }
        paid.accessFee = use.accessFee
        transactions[index] = paid
        save()
        return paid
    }

    // MARK: Verify

    /// Checks a payment against a wallet message its owner pasted (iOS lets
    /// no app read Messages, so Verify reads the one they copy) and
    /// applies it, only when it is this payment's: the same amount, the
    /// same number or code (or the same kind of payment when the message
    /// leaves it out), the same wallet, and within six hours of when it
    /// was dialled. A message the automation logged on its own, unable to
    /// match it, joins the payment instead of standing beside it. Nil when
    /// the payment is gone.
    @discardableResult
    public func verify(_ id: UUID, withMessage text: String) -> Verification? {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return nil }
        let payment = transactions[index]
        if let sms = CarrierSMS.parse(text) {
            guard settles(payment, with: sms, at: sms.date) else {
                return .anotherPayment(amount: sms.amount, counterparty: sms.counterparty)
            }
            if let other = alreadyApplied(sms), other.id != id {
                guard other.source == .sms else { return .confirmedAnother(other) }
                transactions.removeAll { $0.id == other.id }
            }
            guard let index = transactions.firstIndex(where: { $0.id == id }) else { return nil }
            return .confirmed(confirm(at: index, with: sms))
        }
        if let failure = CarrierSMS.parseFailure(text) {
            guard settles(payment, with: failure, at: failure.date) else {
                return .anotherPayment(amount: failure.amount, counterparty: failure.counterparty)
            }
            var failed = payment.markedFailed()
            failed.failureReason = .message
            transactions[index] = failed
            save()
            return .failed(failed)
        }
        if let use = CarrierSMS.parseOverdraft(text) {
            guard use.accessFee > 0, overdraftCovers(payment, use, at: use.date ?? payment.date) else {
                return .anotherPayment(amount: use.amount, counterparty: nil)
            }
            return .overdraft(addAccessFee(of: use, at: index))
        }
        return .notAMessage
    }

    /// Marks failed every payment dialled from StarHash since `since` that
    /// is still pending `window` after it was dialled (`AutoVerify`): with
    /// auto-verify on, its message would have come by then. Only the app
    /// calls this, and only while auto-verify is on and working; payments
    /// from before it was set up are left as they are. Returns those it
    /// failed.
    @discardableResult
    public func expireUnconfirmed(
        dialledSince since: Date,
        now: Date = .now,
        window: TimeInterval = AutoVerify.confirmationWindow
    ) -> [Transaction] {
        var expired: [Transaction] = []
        for index in transactions.indices {
            let t = transactions[index]
            guard t.status == .pending, t.source == .app, t.direction == .outgoing,
                  t.date >= since, now.timeIntervalSince(t.date) >= window else { continue }
            var failed = t.markedFailed()
            failed.failureReason = .noMessage
            transactions[index] = failed
            expired.append(failed)
        }
        if !expired.isEmpty { save() }
        return expired
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

    /// The pending payment a sent-money message confirms, or fails. A
    /// message that leaves the number or code out (a merchant's name alone,
    /// a transfer to the other network) settles for the same kind of
    /// payment. A payment dialled with the other wallet is never the one.
    /// One failed for want of a message counts as pending here, so a late
    /// message still settles it.
    private func pendingMatch(for sms: ParsedSMS, at date: Date) -> Int? {
        transactions.indices
            .filter {
                let t = transactions[$0]
                let open = t.status == .pending || (t.status == .failed && t.failureReason == .noMessage)
                return open && settles(t, with: sms, at: date)
            }
            .min { abs(transactions[$0].date.timeIntervalSince(date)) < abs(transactions[$1].date.timeIntervalSince(date)) }
    }

    /// How far apart a payment and its message can be.
    private static let matchWindow: TimeInterval = 6 * 3600

    /// Whether a sent-money message is about `payment`: the same amount,
    /// wallet and number or code, within `matchWindow` of `date` (when the
    /// message gives one).
    private func settles(_ payment: Transaction, with sms: ParsedSMS, at date: Date?) -> Bool {
        let destination = sms.counterparty.destination
        let sameDestination = destination.isEmpty
            ? payment.counterparty.kind == sms.counterparty.kind
            : payment.counterparty.destination == destination
        return sms.direction == .outgoing && payment.direction == .outgoing && payment.amount == sms.amount
            && (payment.wallet == nil || payment.wallet == sms.wallet)
            && sameDestination && abs(payment.date.timeIntervalSince(date ?? payment.date)) < Self.matchWindow
    }

    /// The payment an overdraft paid for. It covered at most the payment
    /// and its fee (less when the balance paid the rest), which rules out
    /// a smaller payment made about the same time. Only MTN lends.
    private func overdraftMatch(for use: OverdraftUse, at date: Date) -> Int? {
        let mtn = { (t: Transaction) in t.direction == .outgoing && (t.wallet == nil || t.wallet == .mtn) }
        if let messageDate = use.date, let index = transactions.firstIndex(where: {
            mtn($0) && $0.status == .confirmed && $0.messageDate == messageDate
                && use.amount <= $0.amount + ($0.walletFee ?? 0)
        }) {
            return index
        }
        return transactions.indices
            .filter {
                let t = transactions[$0]
                let open = t.status == .pending || (t.status == .failed && t.failureReason == .noMessage)
                return open && t.source == .app && t.messageDate == nil && overdraftCovers(t, use, at: date)
            }
            .min { abs(transactions[$0].date.timeIntervalSince(date)) < abs(transactions[$1].date.timeIntervalSince(date)) }
    }

    /// Whether MoMoAdvance could have paid for `payment`: an MTN payment
    /// within `matchWindow` of `date`, costing at least what it lent.
    private func overdraftCovers(_ payment: Transaction, _ use: OverdraftUse, at date: Date) -> Bool {
        let fee = payment.walletFee ?? Tariff.fee(sending: payment.amount, to: payment.counterparty, from: .mtn) ?? 0
        return payment.direction == .outgoing && (payment.wallet == nil || payment.wallet == .mtn)
            && use.amount <= payment.amount + fee
            && abs(payment.date.timeIntervalSince(date)) < Self.matchWindow
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
