import Foundation
import Testing
@testable import StarHashKit

/// Paying, through its interface only: an in-memory store, a dialler that
/// writes down what it was asked to dial, a fixed place, and no wait.
@MainActor
@Suite struct PayingTests {
    private let mtnNumber = Recipient(name: "John Doe", destination: "0788123456", kind: .phone)
    private let merchant = Recipient(name: "Pili-Pili", destination: "020205", kind: .merchant)
    private let kigaliHeights = Transaction.Coordinate(latitude: -1.9536, longitude: 30.0927, accuracy: 8)

    /// The codes the dialler was asked to dial.
    @MainActor
    private final class DialLog {
        var codes: [String] = []
    }

    /// Everything a test needs, and what the dialler was asked.
    @MainActor
    private final class Rig {
        let store = StarHashStore(fileURL: nil)
        let defaults: UserDefaults
        let paying: Paying
        private let log = DialLog()
        var dialled: [String] { log.codes }

        init(
            splitLargePayments: Bool = false, saveTransactions: Bool = true, nearby: Bool = false,
            fix: Transaction.Coordinate? = nil, isContact: Bool? = false
        ) {
            let name = "PayingTests-\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: name)!
            defaults.removePersistentDomain(forName: name)
            defaults.set(splitLargePayments, forKey: Preferences.splitLargePayments.key)
            defaults.set(saveTransactions, forKey: Preferences.saveTransactions.key)
            defaults.set(nearby, forKey: Preferences.nearbyLocation.key)
            paying = Paying(
                store: store, owner: Owner(defaults: defaults), defaults: defaults, dialDelay: .zero,
                dial: { [log] code in log.codes.append(code) },
                locate: { usable in
                    if let fix { usable(fix) }
                    return fix
                },
                isContact: { _ in isContact }
            )
        }
    }

    // MARK: Whole payments

    @Test func aWholePaymentIsRecordedThenDialled() throws {
        let rig = Rig()
        #expect(rig.paying.pay(5_000, to: mtnNumber) == .dialled)
        let payment = try #require(rig.store.transactions.first)
        #expect(payment.amount == 5_000 && payment.status == .pending && payment.wallet == .mtn && payment.split == nil)
        #expect(rig.dialled == ["*182*1*1*0788123456*5000#"])
    }

    @Test func nothingTypedIsRefused() {
        let rig = Rig()
        #expect(rig.paying.pay(0, to: mtnNumber) == .refused)
        #expect(rig.store.transactions.isEmpty && rig.dialled.isEmpty)
    }

    @Test func aRecipientThatCannotBePaidIsRefused() {
        let rig = Rig()
        // A masked SMS sender: no number to dial.
        let masked = Recipient(name: "M-Money", destination: "", kind: .phone)
        #expect(rig.paying.pay(5_000, to: masked) == .refused)
        #expect(rig.store.transactions.isEmpty && rig.dialled.isEmpty)
    }

    @Test func withTransactionsNotKeptItDialsAndRecordsNothing() {
        let rig = Rig(saveTransactions: false)
        #expect(rig.paying.pay(5_000, to: mtnNumber) == .dialled)
        #expect(rig.store.transactions.isEmpty)
        #expect(rig.dialled.count == 1)
    }

    @Test func aLargePaymentGoesWholeWithSplittingOff() {
        let rig = Rig()
        #expect(rig.paying.pay(300_000, to: mtnNumber) == .dialled)
        #expect(rig.paying.split == nil)
        #expect(rig.dialled == ["*182*1*1*0788123456*300000#"])
    }

    // MARK: Split payments

    @Test func aPaymentCheaperInPartsWaitsForTheFirst() throws {
        let rig = Rig(splitLargePayments: true)
        #expect(rig.paying.pay(400_000, to: mtnNumber) == .split)
        let split = try #require(rig.paying.split)
        #expect(split.plan.parts == [150_000, 150_000, 100_000])
        #expect(rig.store.transactions.isEmpty && rig.dialled.isEmpty)
        #expect(rig.paying.status(ofPart: 0) == .next)
        #expect(rig.paying.status(ofPart: 1) == .notSent)
    }

    @Test func aPaymentThatSavesNothingInPartsGoesWhole() {
        let rig = Rig(splitLargePayments: true)
        #expect(rig.paying.pay(100_000, to: mtnNumber) == .dialled)
        #expect(rig.paying.pay(400_000, to: merchant) == .dialled)
        #expect(rig.paying.split == nil)
    }

    @Test func partsAreDialledInOrderEachItsOwnPayment() throws {
        let rig = Rig(splitLargePayments: true)
        rig.paying.pay(400_000, to: mtnNumber)
        rig.paying.sendNextPart()
        rig.paying.sendNextPart()
        #expect(rig.dialled == ["*182*1*1*0788123456*150000#", "*182*1*1*0788123456*150000#"])
        #expect(rig.paying.status(ofPart: 0) == .pending)
        #expect(rig.paying.status(ofPart: 1) == .pending)
        #expect(rig.paying.status(ofPart: 2) == .next)
        rig.paying.sendNextPart()
        let split = try #require(rig.paying.split)
        #expect(split.allDialled)
        #expect(rig.dialled.last == "*182*1*1*0788123456*100000#")
        let parts = rig.store.parts(ofSplit: split.id)
        #expect(parts.map(\.amount) == [150_000, 150_000, 100_000])
        #expect(parts.map(\.split?.part) == [1, 2, 3])
        // Nothing past the last part.
        rig.paying.sendNextPart()
        #expect(rig.dialled.count == 3)
    }

    @Test func aPartDialledAgainIsTheSamePayment() throws {
        let rig = Rig(splitLargePayments: true)
        rig.paying.pay(300_000, to: mtnNumber)
        rig.paying.sendNextPart()
        #expect(rig.paying.canDialPartAgain)
        rig.paying.dialPartAgain()
        #expect(rig.dialled.count == 2)
        #expect(rig.store.transactions.count == 1)
    }

    @Test func aConfirmedPartIsNotDialledAgain() throws {
        let rig = Rig(splitLargePayments: true)
        rig.paying.pay(300_000, to: mtnNumber)
        rig.paying.sendNextPart()
        let id = try #require(rig.paying.split?.payments[0])
        rig.store.confirmByHand(id, fallback: .mtn)
        #expect(rig.paying.status(ofPart: 0) == .confirmed)
        #expect(!rig.paying.canDialPartAgain)
        rig.paying.dialPartAgain()
        #expect(rig.dialled.count == 1)
    }

    @Test func withTransactionsNotKeptAPartReadsAsDialled() {
        let rig = Rig(splitLargePayments: true, saveTransactions: false)
        rig.paying.pay(300_000, to: mtnNumber)
        rig.paying.sendNextPart()
        #expect(rig.store.transactions.isEmpty)
        #expect(rig.paying.status(ofPart: 0) == .dialled)
        #expect(rig.paying.canDialPartAgain)
    }

    @Test func theWholeAmountCanStillGoAsOne() {
        let rig = Rig(splitLargePayments: true)
        rig.paying.pay(300_000, to: mtnNumber)
        rig.paying.sendWhole()
        #expect(rig.paying.split == nil)
        #expect(rig.dialled == ["*182*1*1*0788123456*300000#"])
        #expect(rig.store.transactions.map(\.split) == [nil])
    }

    @Test func notOnceAPartHasGone() {
        let rig = Rig(splitLargePayments: true)
        rig.paying.pay(300_000, to: mtnNumber)
        rig.paying.sendNextPart()
        rig.paying.sendWhole()
        #expect(rig.paying.split != nil)
        #expect(rig.dialled.count == 1)
    }

    @Test func stoppingDropsThePartsNotSent() {
        let rig = Rig(splitLargePayments: true)
        rig.paying.pay(300_000, to: mtnNumber)
        rig.paying.sendNextPart()
        rig.paying.stop()
        #expect(rig.paying.split == nil)
        #expect(rig.store.transactions.count == 1)
    }

    // MARK: The place, for Nearby

    @Test func theFixReachesTheRecipientScreen() async {
        let rig = Rig(nearby: true, fix: kigaliHeights)
        rig.paying.prepare()
        _ = await rig.paying.locating?.value
        #expect(rig.paying.nearbyFix == kigaliHeights)
        rig.paying.forgetPlace()
        #expect(rig.paying.nearbyFix == nil)
    }

    @Test func aMerchantPaymentTakesThePlace() async throws {
        let rig = Rig(nearby: true, fix: kigaliHeights)
        rig.paying.prepare()
        rig.paying.pay(5_000, to: merchant)
        await rig.paying.placing?.value
        #expect(rig.store.transactions.first?.location == kigaliHeights)
    }

    @Test func aSavedContactsPlaceIsNotKept() async {
        let rig = Rig(nearby: true, fix: kigaliHeights, isContact: true)
        rig.paying.prepare()
        rig.paying.pay(5_000, to: mtnNumber)
        await rig.paying.placing?.value
        #expect(rig.store.transactions.first?.location == nil)
    }

    @Test func withNearbyOffNoPlaceIsFound() async {
        let rig = Rig(nearby: false, fix: kigaliHeights)
        rig.paying.prepare()
        rig.paying.pay(5_000, to: merchant)
        #expect(rig.paying.placing == nil)
        #expect(rig.store.transactions.first?.location == nil)
    }

    @Test func everyPartTakesThePlace() async throws {
        let rig = Rig(splitLargePayments: true, nearby: true, fix: kigaliHeights, isContact: false)
        rig.paying.prepare()
        rig.paying.pay(300_000, to: mtnNumber)
        rig.paying.sendNextPart()
        await rig.paying.placing?.value
        rig.paying.sendNextPart()
        await rig.paying.placing?.value
        #expect(rig.store.transactions.count == 2)
        #expect(rig.store.transactions.allSatisfy { $0.location == kigaliHeights })
    }

    // MARK: Nearby's misses

    @Test func payingBringsBackASuggestionPassedOver() {
        let rig = Rig()
        var misses = NearbyMisses()
        for _ in 0..<NearbyMisses.limit { misses.record(shown: [merchant], chosen: mtnNumber) }
        misses.save(in: rig.defaults)
        #expect(NearbyMisses.stored(in: rig.defaults).filter([merchant]).isEmpty)
        rig.paying.pay(5_000, to: merchant)
        #expect(NearbyMisses.stored(in: rig.defaults).filter([merchant]) == [merchant])
    }
}
