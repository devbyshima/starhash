import Foundation

/// What auto-verify promises about a payment's outcome. A wallet's message
/// arrives within a minute or two of a payment, so with auto-verify on, a
/// payment no message has confirmed an hour on almost surely never went
/// through: cancelled at the wallet's prompt, a wrong PIN, a dropped call.
/// StarHash marks it failed then, and a message that turns up later (inside
/// the store's six hours) still confirms it.
public enum AutoVerify {
    /// How long a payment waits for its message before it fails.
    public static let confirmationWindow: TimeInterval = 3600

    /// How many payments in a row going unconfirmed, with no message at
    /// all for `quietPeriod`, look like a broken shortcut.
    public static let unconfirmedInARow = 3
    public static let quietPeriod: TimeInterval = 7 * 24 * 3600

    /// Whether auto-verify looks broken rather than the payments failed:
    /// the last three payments dialled from StarHash all went an hour
    /// without a message, and no message of any kind has reached StarHash
    /// for a week. A Shortcuts automation iOS turned off looks like this,
    /// and failing every payment then would be wrong, so StarHash stops
    /// and points to the setup instead. `lastMessageAt` is when the
    /// shortcut last ran.
    public static func looksBroken(_ transactions: [Transaction], lastMessageAt: Date?, now: Date) -> Bool {
        let quiet = lastMessageAt.map { now.timeIntervalSince($0) >= quietPeriod } ?? true
        guard quiet else { return false }
        let recent = transactions
            .filter { $0.source == .app && $0.direction == .outgoing }
            .sorted { $0.date > $1.date }
            .prefix(unconfirmedInARow)
        guard recent.count == unconfirmedInARow else { return false }
        return recent.allSatisfy { isUnconfirmed($0, now: now) }
    }

    /// Failed for want of a message, or still pending past the hour.
    static func isUnconfirmed(_ transaction: Transaction, now: Date) -> Bool {
        switch transaction.status {
        case .failed: transaction.failureReason == .noMessage
        case .pending: now.timeIntervalSince(transaction.date) >= confirmationWindow
        case .confirmed: false
        }
    }
}
