import Foundation
import Testing
@testable import StarHashKit

/// Auto-verify's state, driven only through its interface: the four verbs
/// in, `status(at:)` and `expireUnconfirmed` out, on a throwaway
/// UserDefaults and an in-memory store.
@Suite("Auto-verify's state")
@MainActor
struct AutoVerifyStatusTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)
    static let aline = Recipient(name: "Aline", destination: "0788123456", kind: .phone)

    static func defaults() -> UserDefaults {
        let name = "AutoVerifyStatusTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static func payment(minutesAgo: Double, at now: Date = now) -> Transaction {
        Transaction(
            direction: .outgoing, counterparty: aline, amount: 5_000,
            date: now.addingTimeInterval(-minutesAgo * 60), status: .pending, source: .app, wallet: .mtn
        )
    }

    static func autoVerify(_ transactions: [Transaction] = [], defaults: UserDefaults = defaults()) -> (AutoVerify, StarHashStore) {
        let store = StarHashStore(fileURL: nil)
        for t in transactions { store.add(t) }
        return (AutoVerify(store: store, defaults: defaults, now: now), store)
    }

    /// Set up as the guide does: the sample runs the shortcut, then the
    /// setup finishes.
    static func setUp(_ autoVerify: AutoVerify, at date: Date) {
        autoVerify.shortcutRan(at: date)
        autoVerify.finishSetUp(at: date)
    }

    @Test func aFreshInstallIsOff() {
        let (autoVerify, _) = Self.autoVerify()
        #expect(autoVerify.status(at: Self.now) == .off)
        #expect(autoVerify.shortcutRanAt == nil)
    }

    @Test func finishingTheSetupWaitsForAMessage() {
        let (autoVerify, _) = Self.autoVerify()
        Self.setUp(autoVerify, at: Self.now)
        #expect(autoVerify.status(at: Self.now) == .waiting)
        #expect(autoVerify.shortcutRanAt == Self.now)
    }

    /// A message from before the setup proves nothing; one after it proves
    /// the automation hands them over.
    @Test func aMessageAfterTheSetupMakesItActive() {
        let (autoVerify, _) = Self.autoVerify()
        autoVerify.messageArrived(at: Self.now.addingTimeInterval(-60))
        Self.setUp(autoVerify, at: Self.now)
        #expect(autoVerify.status(at: Self.now) == .waiting)
        autoVerify.messageArrived(at: Self.now.addingTimeInterval(60))
        #expect(autoVerify.status(at: Self.now.addingTimeInterval(60)) == .active)
    }

    @Test func aQuietWeekWithThreeUnconfirmedLooksBrokenUntilTheNextMessage() {
        let later = Self.now.addingTimeInterval(8 * 24 * 3600)
        let payments = (1...3).map { Self.payment(minutesAgo: Double($0) * 120, at: later) }
        let (autoVerify, _) = Self.autoVerify(payments)
        Self.setUp(autoVerify, at: Self.now)
        autoVerify.messageArrived(at: Self.now.addingTimeInterval(60))
        #expect(autoVerify.status(at: later) == .looksBroken)
        // One message this week says the automation runs again.
        autoVerify.messageArrived(at: later)
        #expect(autoVerify.status(at: later) == .active)
    }

    @Test func oneConfirmedPaymentMeansItWorks() {
        let later = Self.now.addingTimeInterval(8 * 24 * 3600)
        var payments = (1...3).map { Self.payment(minutesAgo: Double($0) * 120, at: later) }
        payments[1].status = .confirmed
        let (autoVerify, _) = Self.autoVerify(payments)
        Self.setUp(autoVerify, at: Self.now)
        autoVerify.messageArrived(at: Self.now.addingTimeInterval(60))
        #expect(autoVerify.status(at: later) == .active)
    }

    @Test func turningOffClearsEverything() {
        let defaults = Self.defaults()
        let (autoVerify, store) = Self.autoVerify(defaults: defaults)
        Self.setUp(autoVerify, at: Self.now)
        autoVerify.messageArrived(at: Self.now.addingTimeInterval(60))
        autoVerify.turnOff()
        #expect(autoVerify.status(at: Self.now) == .off)
        #expect(autoVerify.shortcutRanAt == nil)
        // And it stays off once read again, as after a relaunch.
        let reread = AutoVerify(store: store, defaults: defaults, now: Self.now)
        #expect(reread.status(at: Self.now) == .off)
    }

    /// An install set up before the setup date was kept counts from the
    /// moment it is first read, so nothing it dialled earlier fails.
    @Test func anOldInstallIsSettledOnceAtLoad() {
        let defaults = Self.defaults()
        defaults.set(true, forKey: "autoVerifySetUp")
        defaults.set(Self.now.addingTimeInterval(-86_400).timeIntervalSince1970, forKey: "lastVerifiedAt")
        let (autoVerify, _) = Self.autoVerify(defaults: defaults)
        #expect(defaults.double(forKey: "autoVerifySince") == Self.now.timeIntervalSince1970)
        #expect(autoVerify.status(at: Self.now) == .waiting)
    }

    /// Only while active, and only payments dialled since the setup.
    @Test func expiryFailsOnlyActivePaymentsDialledSinceTheSetup() {
        let later = Self.now.addingTimeInterval(3 * 3600)
        let before = Self.payment(minutesAgo: 60 * 4, at: later)
        let after = Self.payment(minutesAgo: 90, at: later)
        let (autoVerify, store) = Self.autoVerify([before, after])
        Self.setUp(autoVerify, at: Self.now)
        // Waiting: nothing fails yet.
        #expect(autoVerify.expireUnconfirmed(now: later).isEmpty)
        autoVerify.messageArrived(at: later.addingTimeInterval(-60))
        let expired = autoVerify.expireUnconfirmed(now: later)
        #expect(expired.map(\.id) == [after.id])
        #expect(store.transaction(id: after.id)?.failureReason == .noMessage)
        #expect(store.transaction(id: before.id)?.status == .pending)
    }
}
