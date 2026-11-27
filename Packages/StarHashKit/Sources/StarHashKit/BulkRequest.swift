import Foundation

/// Request in Bulk: several people asked at once, each for an amount of
/// their own. It sends one `MoneyRequest` to each, under one group id
/// (`MoneyRequest.groupID`), and the Requests page shows them together
/// (`RequestGroup`). The person asked gets a request like any other: the
/// group is only on the asker's iPhone.
///
/// This is what the owner chooses before it goes: who, and how much each.
/// Everyone starts at the amount typed on Pay.
public struct BulkRequest: Hashable, Sendable {
    /// Someone to ask: a StarHash user nearby, or a number (a contact's or
    /// one typed) asked through StarHash's server.
    public enum Person: Hashable, Sendable {
        case nearby(PeopleNearby.Person)
        case number(Recipient)

        /// The same each time one person is chosen.
        public var id: String {
            switch self {
            case .nearby(let person): "nearby:\(person.id)"
            case .number(let recipient): "number:\(recipient.destination)"
            }
        }
    }

    /// One person chosen, and what they are asked for.
    public struct Pick: Hashable, Identifiable, Sendable {
        public var person: Person
        /// Whole RWF, 0 while nothing is typed.
        public var amount: Int

        public var id: String { person.id }

        /// An amount StarHash can ask for.
        public var isAskable: Bool { amount > 0 && amount <= Money.maximumAmount }
    }

    /// At most this many people at once: each is one of the 20 requests a
    /// day StarHash's server takes from one person.
    public static let maximumPeople = 10

    /// What each person starts at: the amount typed on Pay.
    public let amount: Int
    /// Who is asked, in the order they were chosen.
    public private(set) var picks: [Pick] = []

    public init(amount: Int) {
        self.amount = amount
    }

    public func isPicked(_ person: Person) -> Bool {
        picks.contains { $0.id == person.id }
    }

    /// Whether no one else can be chosen.
    public var isFull: Bool { picks.count >= Self.maximumPeople }

    /// Chooses `person` at the amount typed on Pay, or takes them out
    /// again. No one past `maximumPeople`.
    public mutating func toggle(_ person: Person) {
        if let index = picks.firstIndex(where: { $0.id == person.id }) {
            picks.remove(at: index)
        } else if !isFull {
            picks.append(Pick(person: person, amount: amount))
        }
    }

    /// What the person picked under `id` is asked for.
    public mutating func setAmount(_ amount: Int, for id: String) {
        guard let index = picks.firstIndex(where: { $0.id == id }) else { return }
        picks[index].amount = max(0, amount)
    }

    /// Every amount together.
    public var total: Int { picks.reduce(0) { $0 + $1.amount } }

    /// Whether it can go: someone chosen, each for an amount StarHash can
    /// ask for.
    public var canSend: Bool { !picks.isEmpty && picks.allSatisfy(\.isAskable) }
}

/// A bulk request as the Requests page shows it: everyone asked at once,
/// in the order they were asked, and how much has come in.
public struct RequestGroup: Hashable, Identifiable, Sendable {
    public let id: UUID
    /// Oldest first, the order they were asked in.
    public let requests: [MoneyRequest]

    public init(id: UUID, requests: [MoneyRequest]) {
        self.id = id
        self.requests = requests.sorted { $0.createdAt < $1.createdAt }
    }

    /// Every amount asked for.
    public var asked: Int { requests.reduce(0) { $0 + $1.amount } }

    /// What the requests paid so far brought.
    public var collected: Int { requests.filter { $0.status == .paid }.reduce(0) { $0 + $1.amount } }

    public var paidCount: Int { requests.count { $0.status == .paid } }

    public var waitingCount: Int { requests.count { $0.status == .waiting } }

    /// When it was asked: its first request's time.
    public var createdAt: Date? { requests.first?.createdAt }

    /// The note everyone was asked with.
    public var note: String? { requests.first?.note }
}

/// One line of the requests the owner sent: a request asked on its own,
/// or a bulk request's group.
public enum SentRequest: Hashable, Identifiable, Sendable {
    case single(MoneyRequest)
    case group(RequestGroup)

    public var id: UUID {
        switch self {
        case .single(let request): request.id
        case .group(let group): group.id
        }
    }
}
