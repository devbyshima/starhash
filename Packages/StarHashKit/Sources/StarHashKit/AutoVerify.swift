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

    /// What one message did (`receive`).
    public enum Outcome: Equatable, Sendable {
        /// The setup's own sample: it proves the shortcut and saves nothing.
        case sample
        /// Nothing to do: auto-verify is off, transactions are not kept, or
        /// it is no wallet message (a bank's text, say).
        case ignored
        /// A look-alike of the wallet's message, never logged: the owner
        /// is to be warned before they send anything back.
        case scam(ScamWarning)
        /// A payment StarHash dialled went through. `wasFailed` when
        /// auto-verify had already failed it for want of a message.
        case confirmed(Transaction, wasFailed: Bool)
        /// A movement StarHash did not dial, now logged: money received,
        /// or a payment made outside StarHash.
        case added(Transaction)
        /// A message applied before: nothing changed.
        case alreadyApplied(Transaction)
        /// The wallet says a payment StarHash dialled did not go through.
        case failed(Transaction)
        /// MoMoAdvance paid for a payment: its access fee joined it.
        case overdraft(Transaction)
        /// A wallet's failure or MoMoAdvance message about no payment
        /// StarHash knows: StarHash keeps no record of attempts it did not
        /// dial.
        case unmatched

        /// Whether it reached the transactions, so what is scheduled from
        /// them is worked out again. Expiry runs with every one that did.
        public var reachedTransactions: Bool {
            switch self {
            case .sample, .ignored, .scam: false
            default: true
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let store: StarHashStore

    private var isSetUp = false
    /// When the shortcut last reached StarHash, the setup's sample run
    /// included; nil until it has.
    private(set) var shortcutRanAt: Date?

    /// The setup's own check, as the guide shows it (`beginCheck`).
    public private(set) var check: Check = .idle
    /// When the shortcut had last run as the check began.
    @ObservationIgnored private var checkStartedAfter: Date?
    /// When a real wallet message last came through the automation.
    private var lastMessageAt: Date?
    /// The setup's check: Verify Shortcut runs the shortcut by hand with
    /// the sample, which proves the shortcut, not the automation (Proven,
    /// in GLOSSARY.md).
    public enum Check: Equatable, Sendable {
        /// Not run.
        case idle
        /// Shortcuts was opened with the sample; waiting for the shortcut
        /// to reach StarHash.
        case running
        /// The shortcut ran and the setup finished, but no real message has
        /// come through the automation since: Waiting.
        case awaitingMessage
        /// The shortcut ran, and a real message has come through the
        /// automation: Proven.
        case proven
        /// The shortcut did not run: missing, failed or cancelled.
        case failed
    }

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

    // MARK: Receiving

    /// A message handed over by the owner's Shortcuts automation (the
    /// Process Carrier SMS action), with who sent it when the shortcut
    /// passes that on. Everything a message does happens here, in this
    /// order: any run proves the shortcut; the setup's sample stops there;
    /// any other message proves the automation; nothing more while
    /// auto-verify is off or transactions are not kept; a look-alike is
    /// held back; a wallet's message confirms, logs, fails or adds its
    /// access fee; and then any payment past its hour fails.
    @discardableResult
    public func receive(_ message: String, sender: String?, at now: Date = .now) -> Outcome {
        shortcutRan(at: now)
        guard !AutoVerificationSample.isSample(message) else { return .sample }
        // A real message, so the automation hands them over: what the
        // setup's own check cannot prove, and what auto-verify waits for
        // before failing any payment on its own. Bank texts count too: the
        // automation runs for every message with RWF in it.
        messageArrived(at: now)
        guard status(at: now) != .off, Preferences.saveTransactions.value(in: defaults) else { return .ignored }
        if Preferences.scamWarnings.value(in: defaults), let warning = ScamCheck.check(message, sender: sender) {
            return .scam(warning)
        }
        let outcome: Outcome
        switch CarrierSMS.read(message) {
        case .transaction(let sms):
            outcome = switch store.apply(sms, receivedAt: now) {
            case .confirmed(let t, let previous): .confirmed(t, wasFailed: previous.status == .failed)
            case .added(let t): .added(t)
            case .alreadyApplied(let t): .alreadyApplied(t)
            }
        case .failure(let failure):
            outcome = store.applyFailure(failure, receivedAt: now).map(Outcome.failed) ?? .unmatched
        case .overdraft(let use):
            outcome = store.applyOverdraft(use, receivedAt: now).map(Outcome.overdraft) ?? .unmatched
        case nil:
            return .ignored
        }
        // Awake anyway: any payment past its hour fails now too.
        expireUnconfirmed(now: now)
        return outcome
    }

    // MARK: The setup's check

    /// Verify Shortcut was tapped: the check runs until the shortcut
    /// reaches StarHash, which finishes the setup (`receive`), or Shortcuts
    /// comes back without it (`checkReturned`).
    public func beginCheck() {
        checkStartedAfter = shortcutRanAt ?? .distantPast
        check = .running
    }

    /// Back from Shortcuts: with its answer, or with none when the owner
    /// came back by hand. The Process Carrier SMS action may have run in
    /// another process, so what it wrote is read first. Still not run, the
    /// check failed, unless Shortcuts says it succeeded and the run is yet
    /// to land.
    public func checkReturned(_ result: StarHashLink.ShortcutResult?) {
        guard check == .running else { return }
        if let ran = date(Key.shortcutRanAt), ran != shortcutRanAt { shortcutRan(at: ran) }
        if check == .running, result != .success { check = .failed }
    }

    /// The guide moved to another step, or was left.
    public func resetCheck() {
        check = .idle
        checkStartedAfter = nil
    }

    // MARK: Changing

    /// The shortcut reached StarHash: any run of the Process Carrier SMS
    /// action, the setup's sample included. A check waiting for it passes,
    /// and the setup finishes.
    func shortcutRan(at now: Date = .now) {
        shortcutRanAt = now
        write(now, Key.shortcutRanAt)
        if check == .running, let start = checkStartedAfter, now > start {
            checkStartedAfter = nil
            finishSetUp(at: now)
            check = isProven ? .proven : .awaitingMessage
        }
    }

    /// A real wallet message came through the automation. Kept even while
    /// auto-verify is off: the setup date keeps it from proving a later
    /// setup. A check waiting for one is now proven.
    func messageArrived(at now: Date = .now) {
        lastMessageAt = now
        write(now, Key.lastMessageAt)
        if check == .awaitingMessage, isProven { check = .proven }
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
        // A message the action logged in another process proves a check
        // that was waiting for one.
        if check == .awaitingMessage, isProven { check = .proven }
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

/// The sample message the setup guide sends through the shortcut to check
/// it works. It parses like a real merchant payment, so the whole path is
/// exercised, but `AutoVerify.receive` recognises it and saves nothing.
public enum AutoVerificationSample {
    /// What the guide tells the owner to name the shortcut, and runs by name.
    public static let shortcutName = "StarHash SMS"

    private static let marker = "STARHASH TEST"

    public static let message = "TxId: 0000000000. Your payment of 1,000 RWF to \(marker) 000000 has been completed at 2024-01-01 12:00:00. Your new balance: 0 RWF. Fee was 0 RWF."

    public static func isSample(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains(marker)
    }
}
