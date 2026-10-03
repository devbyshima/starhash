import Foundation

/// What the sender is charged for a payment, worked out from the carriers'
/// published prices, for a payment confirmed by hand: the carrier's SMS
/// gives the real fee, and without one the totals would leave it out.
///
/// Sources, checked 3 October 2026:
/// - MTN MoMo to MoMo: MTN Rwanda's tariff page (mtn.co.rw/momo-tarrif),
///   the on-net column.
/// - To the other network: since 14 July 2026 every transfer between
///   providers runs over eKash (BNR Directive No. 45/2026), capped at 20
///   for the sender. The cap is a ceiling; a carrier may charge less.
/// - Airtel Money to Airtel Money: free, as Airtel Rwanda announced in
///   June 2021 (up to 2,000,000, three a day); no later tariff was found.
/// - A merchant code: free for the payer; the merchant pays.
public enum Tariff {
    /// The fee for sending `amount` to `recipient` from `wallet`, or nil
    /// when nothing published covers it (MTN above its last band).
    public static func fee(sending amount: Int, to recipient: Recipient, from wallet: Recipient.Network) -> Int? {
        guard amount > 0 else { return 0 }
        guard let network = recipient.network else { return 0 }
        if network != wallet { return 20 }
        switch wallet {
        case .airtel: return 0
        case .mtn: return mtnOnNet.first { $0.range.contains(amount) }?.fee
        }
    }

    /// MTN MoMo to MoMo, by amount.
    private static let mtnOnNet: [(range: ClosedRange<Int>, fee: Int)] = [
        (1...1_000, 20),
        (1_001...10_000, 100),
        (10_001...150_000, 250),
        (150_001...2_000_000, 1_500),
        (2_000_001...5_000_000, 3_000),
        (5_000_001...10_000_000, 5_000),
    ]
}
