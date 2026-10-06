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

    /// Why a payment failed when StarHash marked it so, rather than its
    /// owner: nil for one marked by hand.
    public enum FailureReason: String, Codable, Sendable {
        /// The wallet's own message said it did not go through.
        case message
        /// Auto-verify was on and no message confirmed it within the hour
        /// (`AutoVerify.confirmationWindow`). A late message still can.
        case noMessage
    }

    public struct Coordinate: Codable, Hashable, Sendable {
        public var latitude: Double
        public var longitude: Double
        /// The fix's horizontal accuracy, in metres; nil for places saved
        /// before it was kept.
        public var accuracy: Double?
        public init(latitude: Double, longitude: Double, accuracy: Double? = nil) {
            self.latitude = latitude
            self.longitude = longitude
            self.accuracy = accuracy
        }
    }

    public var id: UUID
    public var direction: Direction
    public var counterparty: Recipient
    /// Whole RWF, always positive.
    public var amount: Int
    /// Everything the payment cost on top of its amount: the wallet's fee,
    /// and MoMoAdvance's `accessFee` when the overdraft paid for it.
    public var fee: Int?
    public var date: Date
    public var status: Status
    public var source: Source
    /// The carrier's transaction id.
    public var reference: String?
    public var balanceAfter: Int?
    /// A free label such as "restaurant".
    public var category: String?
    public var location: Coordinate?
    /// The wallet a payment was dialled with, or whose message it came
    /// from: for its fee when it is confirmed by hand, and so a message
    /// only confirms a payment made with its own wallet. Nil for
    /// transactions saved before it was kept.
    public var wallet: Recipient.Network?
    /// When the carrier SMS applied to it says the movement happened. Kept
    /// so the same message applied twice is recognised even when it carries
    /// no reference (transfers sent have none). Nil until a message applies.
    public var messageDate: Date?
    /// Set only while it is failed, and only when StarHash failed it.
    public var failureReason: FailureReason?
    /// What MoMoAdvance, MTN's overdraft, charged when it paid for some or
    /// all of this payment. Counted in `fee` once the payment is confirmed,
    /// and kept apart so the payment's own message, whichever of the two
    /// arrives first, adds to it rather than replacing it.
    public var accessFee: Int?

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
        location: Coordinate? = nil,
        wallet: Recipient.Network? = nil,
        messageDate: Date? = nil,
        failureReason: FailureReason? = nil,
        accessFee: Int? = nil
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
        self.location = location
        self.wallet = wallet
        self.messageDate = messageDate
        self.failureReason = failureReason
        self.accessFee = accessFee
    }

    /// The amount with its sign: negative when money left.
    public var signedAmount: Int { direction == .outgoing ? -amount : amount }

    /// The wallet's own fee, without MoMoAdvance's.
    public var walletFee: Int? { fee.map { $0 - (accessFee ?? 0) } }

    /// `fee` for a payment the wallet charged `walletFee` for, with
    /// MoMoAdvance's access fee on top when the overdraft paid for it.
    func fee(adding walletFee: Int?) -> Int? {
        guard let accessFee else { return walletFee }
        return (walletFee ?? 0) + accessFee
    }

    /// Marked as confirmed by hand (Activity, its details page, or a
    /// reminder's action). No SMS to read the fee from, so it comes from
    /// the carriers' prices, for the wallet it was dialled with (`wallet`
    /// for payments saved before that was kept); money received costs
    /// nothing here.
    public func confirmedByHand(wallet fallback: Recipient.Network) -> Transaction {
        var confirmed = self
        confirmed.status = .confirmed
        confirmed.failureReason = nil
        confirmed.fee = direction == .outgoing
            ? fee(adding: Tariff.fee(sending: amount, to: counterparty, from: wallet ?? fallback))
            : nil
        return confirmed
    }

    /// Marked as failed: it did not go through, so it stays, struck
    /// through, and counts towards nothing.
    public func markedFailed() -> Transaction {
        var failed = self
        failed.status = .failed
        failed.fee = nil
        failed.failureReason = nil
        return failed
    }
}
