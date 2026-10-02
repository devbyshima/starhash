import Foundation

/// One MoMo movement: a payment made from StarHash, or anything read from a
/// carrier SMS (sent, received, merchant payment).
public struct Transaction: Codable, Identifiable, Hashable, Sendable {
    public enum Direction: String, Codable, Sendable {
        case outgoing
        case incoming
    }

    public enum Status: String, Codable, Sendable {
        /// Dialled from StarHash, no carrier SMS matched yet.
        case pending
        /// Confirmed by a carrier SMS, or by hand.
        case confirmed
        case failed
    }

    public enum Source: String, Codable, Sendable {
        case app
        case sms
    }

    public struct Coordinate: Codable, Hashable, Sendable {
        public var latitude: Double
        public var longitude: Double
        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    public var id: UUID
    public var direction: Direction
    public var counterparty: Recipient
    /// Whole RWF, always positive.
    public var amount: Int
    public var fee: Int?
    public var date: Date
    public var status: Status
    public var source: Source
    /// The carrier's transaction id.
    public var reference: String?
    public var balanceAfter: Int?
    /// A free label such as "restaurant".
    public var category: String?
    public var note: String?
    public var location: Coordinate?
    /// When the carrier SMS applied to it says the movement happened. Kept
    /// so the same message applied twice is recognised even when it carries
    /// no reference (transfers sent have none). Nil until a message applies.
    public var messageDate: Date?

    public init(
        id: UUID = UUID(),
        direction: Direction,
        counterparty: Recipient,
        amount: Int,
        fee: Int? = nil,
        date: Date,
        status: Status,
        source: Source,
        reference: String? = nil,
        balanceAfter: Int? = nil,
        category: String? = nil,
        note: String? = nil,
        location: Coordinate? = nil,
        messageDate: Date? = nil
    ) {
        self.id = id
        self.direction = direction
        self.counterparty = counterparty
        self.amount = amount
        self.fee = fee
        self.date = date
        self.status = status
        self.source = source
        self.reference = reference
        self.balanceAfter = balanceAfter
        self.category = category
        self.note = note
        self.location = location
        self.messageDate = messageDate
    }

    /// The amount with its sign: negative when money left.
    public var signedAmount: Int { direction == .outgoing ? -amount : amount }
}
