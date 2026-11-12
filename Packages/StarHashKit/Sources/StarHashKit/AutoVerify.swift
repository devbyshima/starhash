import Foundation
import Observation

/// Auto-verify: the wallet's SMS, handed over by the owner's Shortcuts
/// automation, confirms each payment, and a payment no message confirms
/// within the hour fails on its own. Everything StarHash knows about it,
/// and the one place that knows how the pieces combine: every reader asks
/// `status(at:)` and every change goes through one of four verbs.
///
/// A wallet's message arrives within a minute or two of a payment, so with
/// auto-verify working, a payment no message has confirmed an hour on almost
/// surely never went through: cancelled at the wallet's prompt, a wrong PIN,
/// a dropped call. A message that turns up later (inside the store's six
/// hours) still confirms it.
///
/// Four facts are kept in UserDefaults under the keys StarHash has always
/// used, so installs keep their state: whether the setup finished, when
/// the shortcut last ran, when a real message last came through it, and
/// when the setup finished.
@MainActor
@Observable
public final class AutoVerify {
    /// Where auto-verify stands.
    public enum Status: Equatable, Sendable {
        /// Never set up, or turned off in Settings: every message is
        /// ignored, and payments stay pending until settled by hand.
        case off
        /// Set up with a shortcut that runs, but no real message has come
        /// through the automation since: nothing proves the automation
        /// exists, so nothing fails on its own yet.
        case waiting
        /// Messages confirm payments, and one with none within the hour
        /// fails.
        case active
        /// No message for a week and the last payments all unconfirmed: the
        /// automation has likely stopped (iOS can turn it off), so nothing
        /// more fails until a message comes again.
        case looksBroken
    }

    /// How long a payment waits for its message before it fails.
    public nonisolated static let confirmationWindow: TimeInterval = 3600
    /// How many payments in a row going unconfirmed, with no message at all
    /// for `quietPeriod`, look like a broken automation.
    nonisolated static let unconfirmedInARow = 3
    nonisolated static let quietPeriod: TimeInterval = 7 * 24 * 3600

    /// The keys, as StarHash has always kept them.
    enum Key {
        static let setUp = "autoVerifySetUp"
        static let shortcutRanAt = "lastVerifiedAt"
        static let lastMessageAt = "lastMessageAt"
        static let since = "autoVerifySince"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let store: StarHashStore

    private var isSetUp = false
    /// When the shortcut last reached StarHash, the setup's sample run
    /// included; nil until it has. The setup guide compares it with the
    /// moment it ran the sample.
    public private(set) var shortcutRanAt: Date?
    /// When a real wallet message last came through the automation.
    private var lastMessageAt: Date?
    /// When the setup last finished: payments dialled before it never fail
    /// for want of a message, and messages before it prove nothing.
    private var since: Date?

    public init(store: StarHashStore, defaults: UserDefaults = .standard, now: Date = .now) {
        self.store = store
        self.defaults = defaults
        reload(now: now)
    }

    // MARK: Reading

    /// Where auto-verify stands at `now`.
    public func status(at now: Date = .now) -> Status {
        guard isSetUp, shortcutRanAt != nil else { return .off }
        guard isProven else { return .waiting }
        return looksBroken(at: now) ? .looksBroken : .active
    }

    /// A real message has come through the automation since the setup.
    private var isProven: Bool {
        guard let lastMessageAt else { return false }
        return lastMessageAt >= (since ?? .distantPast)
    }

    /// The last three payments dialled from StarHash all went an hour
    /// without a message, and nothing has come for a week.
    private func looksBroken(at now: Date) -> Bool {
        let quiet = lastMessageAt.map { now.timeIntervalSince($0) >= Self.quietPeriod } ?? true
        guard quiet else { return false }
        let recent = store.transactions
            .filter { $0.source == .app && $0.direction == .outgoing }
            .sorted { $0.date > $1.date }
            .prefix(Self.unconfirmedInARow)
        guard recent.count == Self.unconfirmedInARow else { return false }
        return recent.allSatisfy { isUnconfirmed($0, at: now) }
    }

    /// Failed for want of a message, or still pending past the hour.
    private func isUnconfirmed(_ transaction: Transaction, at now: Date) -> Bool {
        switch transaction.status {
        case .failed: transaction.failureReason == .noMessage
        case .pending: now.timeIntervalSince(transaction.date) >= Self.confirmationWindow
        case .confirmed: false
        }
    }

    // MARK: Changing

    /// The shortcut reached StarHash: any run of the Process Carrier SMS
    /// action, the setup's sample included.
    public func shortcutRan(at now: Date = .now) {
        shortcutRanAt = now
        write(now, Key.shortcutRanAt)
    }

    /// A real wallet message came through the automation. Kept even while
    /// auto-verify is off: the setup date keeps it from proving a later
    /// setup.
    public func messageArrived(at now: Date = .now) {
        lastMessageAt = now
        write(now, Key.lastMessageAt)
    }

    /// The setup's check passed: auto-verify is on, counting from now.
    public func finishSetUp(at now: Date = .now) {
        isSetUp = true
        defaults.set(true, forKey: Key.setUp)
        since = now
        write(now, Key.since)
    }

    /// Turned off in Settings: setting it up again checks the shortcut
    /// anew, and waits for a message through the automation anew.
    public func turnOff() {
        isSetUp = false
        shortcutRanAt = nil
        lastMessageAt = nil
        since = nil
        defaults.set(false, forKey: Key.setUp)
        for key in [Key.shortcutRanAt, Key.lastMessageAt, Key.since] {
            defaults.removeObject(forKey: key)
        }
    }

    /// Reads the four facts again: the Process Carrier SMS action may have
    /// written while StarHash was away, and Delete All Data clears them. An
    /// install set up before the setup date was kept starts counting from
    /// now, once.
    public func reload(now: Date = .now) {
        isSetUp = defaults.bool(forKey: Key.setUp)
        shortcutRanAt = date(Key.shortcutRanAt)
        lastMessageAt = date(Key.lastMessageAt)
        since = date(Key.since)
        if isSetUp, shortcutRanAt != nil, since == nil {
            since = now
            write(now, Key.since)
        }
    }

    // MARK: Expiry

    /// Fails the payments auto-verify should have confirmed by now: only
    /// while it is active, and only those dialled since the setup. Returns
    /// what it failed.
    @discardableResult
    public func expireUnconfirmed(now: Date = .now) -> [Transaction] {
        guard status(at: now) == .active, let since else { return [] }
        return store.expireUnconfirmed(dialledSince: since, now: now)
    }

    // MARK: Storage

    /// Seconds since 1970, as the keys have always held them; 0 for never.
    private func date(_ key: String) -> Date? {
        let seconds = defaults.double(forKey: key)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    private func write(_ date: Date, _ key: String) {
        defaults.set(date.timeIntervalSince1970, forKey: key)
    }
}
