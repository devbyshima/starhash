import Foundation
import Observation

/// A request for money between two StarHash users: one the owner sent
/// (asking someone to pay them) or one they received (someone asking them
/// to pay). They travel to people nearby (`PeopleNearby`), or to anyone on
/// StarHash through its server, sealed (`RequestsAnywhere`). One asked
/// nearby goes through the server too when it can (`RequestsAnywhere.carry`),
/// in case the other walks away before answering. Both phones keep the
/// request under the same id, so it is one request whichever way it came
/// first, and an answer finds it.
///
/// A request never dials anything. The person asked pays through Pay as
/// they would anyone, and the request settles from the transactions
/// themselves (`MoneyRequests.settle`), never from what a phone says.
public struct MoneyRequest: Codable, Hashable, Identifiable, Sendable {
    public enum Direction: String, Codable, Sendable {
        /// The owner asked someone to pay them.
        case sent
        /// Someone asked the owner to pay them.
        case received
    }

    public enum Status: String, Codable, Sendable {
        case waiting, paid, declined, cancelled, expired
    }

    /// How long a request waits before it expires.
    public static let lifetime: TimeInterval = 7 * 86_400

    /// The longest note a request carries.
    public static let maximumNoteLength = 60

    public var id: UUID
    public var direction: Direction
    /// The other person: who the owner asked, or who asks them. A phone
    /// number, under their name.
    public var person: Recipient
    /// Their photo on StarHash's server, when they have one.
    public var photoID: UUID?
    /// Whole RWF.
    public var amount: Int
    public var note: String?
    public var createdAt: Date
    public var status: Status
    /// When it was paid, declined or cancelled.
    public var settledAt: Date?
    /// The transactions that paid it: one, or each part of one paid in
    /// parts. Nil when marked paid by hand, or not paid.
    public var transactionIDs: [UUID]?
    /// The other person's public key, when it travelled through StarHash's
    /// server (on its own, or beside People Nearby's connection): an answer
    /// is sealed to it. Nil for one only between people nearby.
    public var key: String?
    /// Whether the server has been told how it ended: a decline sent, or
    /// one the owner sent closed there (cancelled, paid, declined or
    /// expired), which frees the two of them to ask again.
    public internal(set) var reported: Bool?

    public init(
        id: UUID = UUID(), direction: Direction, person: Recipient, photoID: UUID? = nil, amount: Int,
        note: String? = nil, createdAt: Date, status: Status = .waiting, key: String? = nil
    ) {
        self.id = id
        self.direction = direction
        self.person = person
        self.photoID = photoID
        self.amount = amount
        self.note = Self.clean(note)
        self.createdAt = createdAt
        self.status = status
        self.key = key
    }

    public var expiresAt: Date { createdAt.addingTimeInterval(Self.lifetime) }

    /// Whether it travelled through StarHash's server, so its answer or its
    /// end can too: one asked of anyone, or one asked nearby that the
    /// server carried as well.
    public var isAnywhere: Bool { key != nil }

    /// Whether the server still has to hear how it ended: a decline the
    /// owner made, or the end of one they sent.
    var needsReport: Bool {
        guard isAnywhere, reported != true else { return false }
        return switch direction {
        case .sent: status != .waiting
        case .received: status == .declined
        }
    }

    /// A note trimmed and cut to its length, or nil when nothing is left.
    static func clean(_ note: String?) -> String? {
        guard let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumNoteLength))
    }

    // MARK: What paid it

    /// How long before the request a payment may be dated and still pay
    /// it: the carrier's clock is not the phone's, and Airtel dates to the
    /// minute.
    static let clockGrace: TimeInterval = 5 * 60

    /// The transactions among `transactions` (newest first, as the store
    /// keeps them) that pay this request, leaving out those in `taken`
    /// (other requests' payments); nil when none does.
    ///
    /// A request the owner sent is paid by money received from the person
    /// asked; one they received by money they sent to that number. Either
    /// way, after it was made (give or take the carrier's clock) and before
    /// it expired, and not failed. One payment of the amount pays it, the
    /// oldest first. So does a payment in parts: every part of one the
    /// owner split (Split Large Payments), or payments received from that
    /// person that add up to the amount exactly, oldest first.
    public func payment(in transactions: [Transaction], excluding taken: Set<UUID> = []) -> [UUID]? {
        let candidates = transactions.reversed().filter { !taken.contains($0.id) && counts($0) }
        if let one = candidates.first(where: { $0.amount == amount }) { return [one.id] }
        switch direction {
        case .received:
            let parts = Dictionary(grouping: candidates.filter { $0.split?.total == amount }) { $0.split!.id }
            for (_, group) in parts.sorted(by: { $0.value[0].date < $1.value[0].date }) where group.count == group[0].split?.count {
                return group.map(\.id)
            }
        case .sent:
            var sum = 0
            var ids: [UUID] = []
            for transaction in candidates {
                sum += transaction.amount
                ids.append(transaction.id)
                if sum == amount { return ids }
                if sum > amount { break }
            }
        }
        return nil
    }

    /// The request the owner sent that `transactionID` finished paying,
    /// among `requests` once settled, or nil: the money received that it
    /// was, said as the request.
    public static func sent(paidBy transactionID: UUID, in requests: [MoneyRequest]) -> MoneyRequest? {
        requests.first { $0.direction == .sent && $0.status == .paid && $0.transactionIDs?.last == transactionID }
    }

    /// Whether `transaction` pays this request on its own.
    public func isPaid(by transaction: Transaction) -> Bool {
        payment(in: [transaction]) != nil
    }

    /// Whether `transaction` could pay this request, in whole or in part:
    /// who, which way, when, and not failed.
    private func counts(_ transaction: Transaction) -> Bool {
        guard transaction.status != .failed,
              transaction.date >= createdAt.addingTimeInterval(-Self.clockGrace), transaction.date <= expiresAt else { return false }
        switch direction {
        case .sent:
            guard transaction.direction == .incoming, transaction.counterparty.kind == .phone else { return false }
            return Self.sender(transaction.counterparty, is: person)
        case .received:
            return transaction.direction == .outgoing && transaction.counterparty.destination == person.destination
        }
    }

    /// Whether a sender read from an SMS is `person`: the whole number when
    /// it shows one, its last digits when masked, or a word of the name
    /// when it shows no number at all (Airtel's "from Jean Bosco").
    static func sender(_ sender: Recipient, is person: Recipient) -> Bool {
        let digits = sender.destination.filter(\.isASCIIDigit)
        if digits.count >= 10 { return digits == person.destination }
        if digits.count >= 3 { return person.destination.hasSuffix(digits) }
        guard let shown = sender.name, let name = person.name else { return false }
        return !words(shown).isDisjoint(with: words(name))
    }

    private static func words(_ name: String) -> Set<String> {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return Set(folded.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count >= 3 })
    }

    // MARK: Between phones

    /// What one phone says to another about a request.
    public enum Message: Hashable, Sendable {
        /// Pay me: who asks, how much and what for.
        case ask(Ask)
        /// The person asked declined.
        case declined(id: UUID)
        /// The person asked tapped Pay on a request that came by a tap
        /// (`TapToRequest`): who is paying, which the asker's phone did not
        /// know, so its request settles from their SMS.
        case paying(Payer)

        public struct Payer: Hashable, Sendable {
            /// The request being paid.
            public var id: UUID
            public var name: String?
            /// The payer's own number: where the money comes from.
            public var number: String

            public init(id: UUID, name: String?, number: String) {
                self.id = id
                self.name = name.flatMap(PeopleNearby.Announcement.clean)
                self.number = number
            }

            /// Who pays, as the asker's request keeps them.
            public var person: Recipient {
                Recipient(name: name, destination: number, kind: .phone)
            }
        }

        public struct Ask: Hashable, Sendable {
            public var id: UUID
            public var name: String
            /// The asker's own number: where the money goes.
            public var number: String
            public var photoID: UUID?
            public var amount: Int
            public var note: String?

            public init(id: UUID, name: String, number: String, photoID: UUID?, amount: Int, note: String?) {
                self.id = id
                self.name = name
                self.number = number
                self.photoID = photoID
                self.amount = amount
                self.note = MoneyRequest.clean(note)
            }
        }

        public var data: Data {
            let body: Body = switch self {
            case .ask(let ask):
                Body(v: 1, kind: "ask", id: ask.id, name: ask.name, number: ask.number, photo: ask.photoID, amount: ask.amount, note: ask.note)
            case .declined(let id):
                Body(v: 1, kind: "declined", id: id)
            case .paying(let payer):
                Body(v: 1, kind: "paying", id: payer.id, name: payer.name, number: payer.number)
            }
            return (try? JSONEncoder().encode(body)) ?? Data()
        }

        /// One received, or nil for anything StarHash would not act on: a
        /// number that is no Rwandan mobile number, an amount it could not
        /// pay, another version.
        public init?(data: Data) {
            guard let body = try? JSONDecoder().decode(Body.self, from: data), body.v == 1 else { return nil }
            switch body.kind {
            case "ask":
                guard let number = body.number.flatMap({ Recipient(input: $0) }), number.isRwandanMobile,
                      let amount = body.amount, amount > 0, amount <= Money.maximumAmount,
                      let name = body.name.flatMap(PeopleNearby.Announcement.clean) else { return nil }
                self = .ask(Ask(id: body.id, name: name, number: number.destination, photoID: body.photo, amount: amount, note: body.note))
            case "declined":
                self = .declined(id: body.id)
            case "paying":
                guard let number = body.number.flatMap({ Recipient(input: $0) }), number.isRwandanMobile else { return nil }
                self = .paying(Payer(id: body.id, name: body.name, number: number.destination))
            default:
                return nil
            }
        }

        private struct Body: Codable {
            var v: Int
            var kind: String
            var id: UUID
            var name: String?
            var number: String?
            var photo: UUID?
            var amount: Int?
            var note: String?
        }
    }
}

/// Every request the owner sent or received, newest first, in one JSON file
/// beside the transactions (or in memory, for tests and previews).
@MainActor
@Observable
public final class MoneyRequests {
    public private(set) var requests: [MoneyRequest] = []

    @ObservationIgnored private let fileURL: URL?

    public init(fileURL: URL?) {
        self.fileURL = fileURL
        reload()
    }

    /// Requests in StarHash's Application Support folder.
    public static var standardURL: URL {
        let folder = URL.applicationSupportDirectory.appending(path: "StarHash", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "requests.json")
    }

    // MARK: Reading

    /// Requests the owner was sent and has yet to answer, newest first.
    public var waitingForOwner: [MoneyRequest] {
        requests.filter { $0.direction == .received && $0.status == .waiting }
    }

    public func request(id: UUID) -> MoneyRequest? {
        requests.first { $0.id == id }
    }

    // MARK: Changing

    /// The owner asked `person` for `amount`. `key` is theirs when it went
    /// through the server. Asked again under an id already kept (a request
    /// sent nearby that then went through the server too), it stays one
    /// request, which takes the key.
    @discardableResult
    public func ask(
        _ person: Recipient, id: UUID = UUID(), photoID: UUID?, amount: Int, note: String?, at now: Date = .now, key: String? = nil
    ) -> MoneyRequest {
        if let kept = request(id: id) {
            if let key, kept.direction == .sent { carried(id, key: key) }
            return request(id: id) ?? kept
        }
        let request = MoneyRequest(
            id: id, direction: .sent, person: person, photoID: photoID, amount: amount, note: note, createdAt: now, key: key
        )
        insert(request)
        return request
    }

    /// Someone asked the owner: through the server when `key`, the asker's,
    /// is given. Nil when that request is already here.
    @discardableResult
    public func receive(_ ask: MoneyRequest.Message.Ask, at now: Date = .now, key: String? = nil) -> MoneyRequest? {
        guard request(id: ask.id) == nil else { return nil }
        let person = Recipient(name: ask.name, destination: ask.number, kind: .phone)
        let request = MoneyRequest(
            id: ask.id, direction: .received, person: person, photoID: ask.photoID, amount: ask.amount, note: ask.note,
            createdAt: now, key: key
        )
        insert(request)
        return request
    }

    /// The asker took back a request the owner was sent (or was paid some
    /// way StarHash did not see): it no longer waits.
    public func theyCancelled(_ id: UUID, at now: Date = .now) {
        settle(id, as: .cancelled, direction: .received, at: now)
    }

    /// A request that came between people nearby went through the server
    /// too: `key` is the other person's, so an answer or its end can follow
    /// it there once they have walked away. A key it has already stays.
    func carried(_ id: UUID, key: String) {
        guard let index = requests.firstIndex(where: { $0.id == id }), requests[index].key == nil else { return }
        requests[index].key = key
        save()
    }

    /// Requests whose end the server has yet to hear, oldest first.
    var unreported: [MoneyRequest] {
        requests.reversed().filter(\.needsReport)
    }

    /// The server heard how it ended.
    func markReported(_ id: UUID) {
        guard let index = requests.firstIndex(where: { $0.id == id }), requests[index].reported != true else { return }
        requests[index].reported = true
        save()
    }

    /// The owner declined a request they were sent.
    public func decline(_ id: UUID, at now: Date = .now) {
        settle(id, as: .declined, direction: .received, at: now)
    }

    /// The owner took back a request they sent.
    public func cancel(_ id: UUID, at now: Date = .now) {
        settle(id, as: .cancelled, direction: .sent, at: now)
    }

    /// The person asked declined a request the owner sent.
    public func theyDeclined(_ id: UUID, at now: Date = .now) {
        settle(id, as: .declined, direction: .sent, at: now)
    }

    /// Paid, by the owner's word: the money came some way StarHash did not
    /// see (no auto-verify, cash).
    public func markPaid(_ id: UUID, at now: Date = .now) {
        guard let index = requests.firstIndex(where: { $0.id == id }), requests[index].status == .waiting else { return }
        requests[index].status = .paid
        requests[index].settledAt = now
        save()
    }

    /// Requests settle from the transactions: one still waiting is paid by
    /// the first payment that pays it and no other request took, oldest
    /// request first; one whose payment has since failed or gone (any part
    /// of it) waits again; and one past its week expires.
    public func settle(with transactions: [Transaction], at now: Date = .now) {
        var changed = false
        let byID = Dictionary(transactions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for index in requests.indices where requests[index].status == .paid {
            guard let ids = requests[index].transactionIDs else { continue }
            if ids.contains(where: { byID[$0].map { $0.status == .failed } ?? true }) {
                requests[index].status = .waiting
                requests[index].transactionIDs = nil
                requests[index].settledAt = nil
                changed = true
            }
        }
        var taken = Set(requests.flatMap { $0.transactionIDs ?? [] })
        // Oldest first, so the first request asked is the first paid.
        for index in requests.indices.reversed() where requests[index].status == .waiting {
            if let paying = requests[index].payment(in: transactions, excluding: taken) {
                requests[index].status = .paid
                requests[index].transactionIDs = paying
                requests[index].settledAt = paying.compactMap { byID[$0]?.date }.max()
                taken.formUnion(paying)
                changed = true
            } else if now > requests[index].expiresAt {
                requests[index].status = .expired
                requests[index].settledAt = requests[index].expiresAt
                changed = true
            }
        }
        if changed { save() }
    }

    /// Everything, gone: Delete All Data.
    public func removeAll() {
        requests.removeAll()
        save()
    }

    // MARK: The file

    public func reload() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let read = try? JSONDecoder().decode([MoneyRequest].self, from: data) else { return }
        requests = read.sorted { $0.createdAt > $1.createdAt }
    }

    private func insert(_ request: MoneyRequest) {
        requests.insert(request, at: 0)
        save()
    }

    private func settle(_ id: UUID, as status: MoneyRequest.Status, direction: MoneyRequest.Direction, at now: Date) {
        guard let index = requests.firstIndex(where: { $0.id == id }),
              requests[index].direction == direction, requests[index].status == .waiting else { return }
        requests[index].status = status
        requests[index].settledAt = now
        save()
    }

    private func save() {
        guard let fileURL, let data = try? JSONEncoder().encode(requests) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
