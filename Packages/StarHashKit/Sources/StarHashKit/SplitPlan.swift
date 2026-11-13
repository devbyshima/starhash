import Foundation

/// A payment sent as several smaller ones because together they cost less
/// in fees. MTN charges 250 to send up to 150,000 and 1,500 from 150,001,
/// so 300,000 sent as two payments of 150,000 costs 500 rather than 1,500.
/// Offered only with Split Large Payments on in Settings
/// (`Preferences.splitLargePayments`), and only when it saves something.
public struct SplitPlan: Hashable, Sendable {
    /// Each payment's amount, in the order they are sent: the tops of
    /// MTN's bands, largest first, then what is left.
    public let parts: [Int]
    /// Every part's fee together.
    public let fee: Int
    /// The fee for sending the whole amount as one payment.
    public let feeAsOne: Int

    /// The whole amount.
    public var amount: Int { parts.reduce(0, +) }
    /// How much less the parts cost than one payment. Always more than 0.
    public var saving: Int { feeAsOne - fee }

    /// Each part is another PIN to type, so a plan never has more than
    /// this. Today's prices save nothing past five parts of 150,000 anyway
    /// (six cost what one payment does); the cap keeps a change in them
    /// from ever asking for a dozen.
    public static let maximumParts = 5

    /// The smallest part a plan is built from, besides what is left over:
    /// MTN's top of 250. Its cheaper bands (20 up to 1,000, 100 up to
    /// 10,000) would only save tens of francs for another PIN.
    public static let smallestPart = 150_000

    /// The cheapest way to send `amount` to `recipient` from `wallet` in
    /// at most `maximumParts` parts, or nil when one payment costs as
    /// little: a merchant code, Airtel Money, the other network, and MTN
    /// up to 150,000, from 750,001 to 2,000,000, from 2,600,001 to
    /// 5,000,000 and above 7,160,000. Nil too when the prices do not cover
    /// the amount. At the same fee, fewer parts.
    ///
    /// Every part but the last is the top of a band (150,000, 2,000,000 or
    /// 5,000,000), the most it can carry for its fee, and the last is what
    /// is left: a cheapest plan can always be made so, since moving money
    /// from one part to another until one is full never raises a fee. So
    /// trying every mix of tops, largest first, finds it.
    public static func cheapest(sending amount: Int, to recipient: Recipient, from wallet: Recipient.Network) -> SplitPlan? {
        guard amount > 0, let feeAsOne = Tariff.fee(sending: amount, to: recipient, from: wallet), feeAsOne > 0 else { return nil }
        let tops = Tariff.bandTops.filter { $0 >= smallestPart && $0 < amount }.sorted(by: >)
        var best: SplitPlan?

        func consider(_ parts: [Int]) {
            guard parts.count > 1, parts.count <= maximumParts else { return }
            var fee = 0
            for part in parts {
                guard let partFee = Tariff.fee(sending: part, to: recipient, from: wallet) else { return }
                fee += partFee
            }
            guard fee < feeAsOne else { return }
            if let current = best, current.fee < fee || (current.fee == fee && current.parts.count <= parts.count) { return }
            best = SplitPlan(parts: parts, fee: fee, feeAsOne: feeAsOne)
        }

        /// `chosen` tops so far, then each top from `index` on added to them.
        func extend(_ chosen: [Int], total: Int, from index: Int) {
            let rest = amount - total
            consider(rest > 0 ? chosen + [rest] : chosen)
            guard chosen.count < maximumParts else { return }
            for next in index..<tops.count where total + tops[next] <= amount {
                extend(chosen + [tops[next]], total: total + tops[next], from: next)
            }
        }

        extend([], total: 0, from: 0)
        return best
    }
}

extension Transaction {
    /// One of the payments a `SplitPlan` sent, so the parts are known for
    /// one payment: on the transaction's page, and when a part is dialled
    /// again after a cancelled call.
    public struct Split: Codable, Hashable, Sendable {
        /// The same for every part of one payment.
        public var id: UUID
        /// Which part, from 1.
        public var part: Int
        /// How many parts there are.
        public var count: Int
        /// The whole amount, every part together.
        public var total: Int

        public init(id: UUID, part: Int, count: Int, total: Int) {
            self.id = id
            self.part = part
            self.count = count
            self.total = total
        }
    }
}
