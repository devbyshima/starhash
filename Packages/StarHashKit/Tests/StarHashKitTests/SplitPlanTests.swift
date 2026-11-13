import Foundation
import Testing
@testable import StarHashKit

@MainActor
struct SplitPlanTests {
    private let mtnNumber = Recipient(name: nil, destination: "0788123456", kind: .phone)
    private let airtelNumber = Recipient(name: nil, destination: "0728123456", kind: .phone)
    private let merchant = Recipient(name: "Shop", destination: "020205", kind: .merchant)
    private let noon = Date(timeIntervalSince1970: 1_727_000_000)

    // MARK: The plan

    @Test(arguments: [
        (150_001, [150_000, 1], 270),
        (300_000, [150_000, 150_000], 500),
        (300_001, [150_000, 150_000, 1], 520),
        (400_000, [150_000, 150_000, 100_000], 750),
        (450_000, [150_000, 150_000, 150_000], 750),
        (600_000, [150_000, 150_000, 150_000, 150_000], 1_000),
        (750_000, [150_000, 150_000, 150_000, 150_000, 150_000], 1_250),
        (2_000_001, [2_000_000, 1], 1_520),
        (2_300_000, [2_000_000, 150_000, 150_000], 2_000),
        (2_600_000, [2_000_000, 150_000, 150_000, 150_000, 150_000], 2_500),
        (5_500_000, [5_000_000, 150_000, 150_000, 150_000, 50_000], 4_000),
        (7_000_000, [5_000_000, 2_000_000], 4_500),
        (7_160_000, [5_000_000, 2_000_000, 150_000, 10_000], 4_850),
    ])
    func mtnToMTNSplitsWhereItSaves(amount: Int, parts: [Int], fee: Int) throws {
        let plan = try #require(SplitPlan.cheapest(sending: amount, to: mtnNumber, from: .mtn))
        #expect(plan.parts == parts)
        #expect(plan.amount == amount)
        #expect(plan.fee == fee)
        #expect(plan.saving == plan.feeAsOne - fee)
        #expect(plan.saving > 0)
    }

    @Test(arguments: [1, 10_000, 150_000, 750_001, 900_000, 2_000_000, 2_600_001, 4_000_000, 5_000_000, 7_160_001, 10_000_000, 10_000_001])
    func mtnToMTNStaysWholeWhereSplittingSavesNothing(amount: Int) {
        #expect(SplitPlan.cheapest(sending: amount, to: mtnNumber, from: .mtn) == nil)
    }

    @Test func onlyMTNToMTNIsSplit() {
        // The other network's fee is the same for any amount, and Airtel
        // to Airtel and merchant codes are free.
        #expect(SplitPlan.cheapest(sending: 300_000, to: airtelNumber, from: .mtn) == nil)
        #expect(SplitPlan.cheapest(sending: 300_000, to: mtnNumber, from: .airtel) == nil)
        #expect(SplitPlan.cheapest(sending: 300_000, to: airtelNumber, from: .airtel) == nil)
        #expect(SplitPlan.cheapest(sending: 300_000, to: merchant, from: .mtn) == nil)
    }

    @Test func noPartButTheLastIsSmallerThanTheCheapBandsTop() {
        // 152,000 as 150,000 and 2,000, never 150,000, 1,000 and 1,000 for
        // 60 less and another PIN.
        let plan = SplitPlan.cheapest(sending: 152_000, to: mtnNumber, from: .mtn)
        #expect(plan?.parts == [150_000, 2_000])
    }

    @Test func nothingTypedIsNoPlan() {
        #expect(SplitPlan.cheapest(sending: 0, to: mtnNumber, from: .mtn) == nil)
    }

    @Test func noPlanHasMorePartsThanTheCap() {
        for amount in stride(from: 150_001, through: 10_000_000, by: 7_919) {
            let plan = SplitPlan.cheapest(sending: amount, to: mtnNumber, from: .mtn)
            #expect((plan?.parts.count ?? 0) <= SplitPlan.maximumParts)
            #expect(plan.map { $0.amount == amount } ?? true)
        }
    }

    // MARK: The parts in the store

    private func split(_ id: UUID, part: Int) -> Transaction.Split {
        Transaction.Split(id: id, part: part, count: 2, total: 300_000)
    }

    @Test func eachPartIsItsOwnPayment() {
        let store = StarHashStore(fileURL: nil)
        let id = UUID()
        let first = store.recordPayment(to: mtnNumber, amount: 150_000, date: noon, wallet: .mtn, split: split(id, part: 1))
        let second = store.recordPayment(to: mtnNumber, amount: 150_000, date: noon.addingTimeInterval(60), wallet: .mtn, split: split(id, part: 2))
        #expect(first.id != second.id)
        #expect(store.transactions.count == 2)
        #expect(store.parts(ofSplit: id).map(\.split?.part) == [1, 2])
    }

    @Test func aPartDialledAgainIsTheSamePayment() {
        let store = StarHashStore(fileURL: nil)
        let id = UUID()
        let first = store.recordPayment(to: mtnNumber, amount: 150_000, date: noon, split: split(id, part: 1))
        // Long after the plain retry window: the sheet still knows it is
        // part 1 dialled again.
        let again = store.recordPayment(to: mtnNumber, amount: 150_000, date: noon.addingTimeInterval(3_600), split: split(id, part: 1))
        #expect(again.id == first.id)
        #expect(store.transactions.count == 1)
    }

    @Test func aPaymentSentWholeIsNeverTakenForAPart() {
        let store = StarHashStore(fileURL: nil)
        let part = store.recordPayment(to: mtnNumber, amount: 150_000, date: noon, split: split(UUID(), part: 1))
        let whole = store.recordPayment(to: mtnNumber, amount: 150_000, date: noon.addingTimeInterval(60))
        #expect(whole.id != part.id)
        #expect(whole.split == nil)
    }

    @Test func eachPartsMessageConfirmsAPart() {
        let store = StarHashStore(fileURL: nil)
        let id = UUID()
        store.recordPayment(to: mtnNumber, amount: 150_000, date: noon, wallet: .mtn, split: split(id, part: 1))
        store.recordPayment(to: mtnNumber, amount: 150_000, date: noon.addingTimeInterval(60), wallet: .mtn, split: split(id, part: 2))
        for minute in [1.0, 2.0] {
            store.apply(ParsedSMS(
                direction: .outgoing, counterparty: mtnNumber, amount: 150_000, fee: 250,
                date: noon.addingTimeInterval(minute * 60), reference: nil, balanceAfter: nil
            ))
        }
        let parts = store.parts(ofSplit: id)
        #expect(parts.count == 2)
        #expect(parts.allSatisfy { $0.status == .confirmed && $0.fee == 250 })
    }

    @Test func thePartSurvivesTheFile() throws {
        let part = Transaction(
            direction: .outgoing, counterparty: mtnNumber, amount: 150_000, date: noon,
            status: .pending, source: .app, split: split(UUID(), part: 2)
        )
        let decoded = try JSONDecoder().decode(Transaction.self, from: JSONEncoder().encode(part))
        #expect(decoded.split == part.split)
    }

    @Test func aFileFromBeforeSplitsReadsAsWhole() throws {
        let whole = Transaction(direction: .outgoing, counterparty: mtnNumber, amount: 5_000, date: noon, status: .pending, source: .app)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(whole)) as? [String: Any])
        object["split"] = nil
        let decoded = try JSONDecoder().decode(Transaction.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.split == nil)
    }
}
