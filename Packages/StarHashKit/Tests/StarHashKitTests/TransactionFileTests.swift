import Foundation
import Testing
@testable import StarHashKit

/// The store against its file, played by `MemoryTransactionFile`: sealed
/// as the phone keeps it until first unlocked after a restart, or damaged.
@Suite("The transaction file")
@MainActor
struct TransactionFileTests {
    static let john = Recipient(name: "John Doe", destination: "0788123456", kind: .phone)
    static let noon = Date(timeIntervalSince1970: 1_727_000_000)

    static func pending(_ amount: Int = 5_000, at date: Date = noon) -> Transaction {
        Transaction(direction: .outgoing, counterparty: john, amount: amount, date: date, status: .pending, source: .app, wallet: .mtn)
    }

    static func sent(_ amount: Int = 5_000, at date: Date = noon.addingTimeInterval(30), reference: String = "1203948571") -> ParsedSMS {
        ParsedSMS(
            wallet: .mtn, direction: .outgoing, counterparty: john,
            amount: amount, fee: 100, date: date, reference: reference, balanceAfter: 12_000, category: nil
        )
    }

    /// The bug the seam was for: a payment's message came while the file
    /// was sealed, the store could not see the payment and added the
    /// message beside it, and both counted once the file read.
    @Test func aMessageWhileSealedConfirmsThePaymentItCouldNotSee() throws {
        let payment = Self.pending()
        let file = MemoryTransactionFile(saved: [payment])
        file.isSealed = true
        let store = StarHashStore(file: file)
        #expect(store.transactions.isEmpty)

        guard case .added = store.apply(Self.sent()) else { Issue.record("not added while sealed"); return }
        #expect(file.saved == [payment])

        file.isSealed = false
        store.reloadFromDisk()
        #expect(store.transactions.count == 1)
        let confirmed = try #require(store.transactions.first)
        #expect(confirmed.id == payment.id)
        #expect(confirmed.status == .confirmed)
        #expect(confirmed.fee == 100)
        #expect(file.saved?.count == 1)
    }

    @Test func moneyReceivedWhileSealedIsKeptOnce() {
        let earlier = Self.pending(700, at: Self.noon.addingTimeInterval(-86_400))
        let file = MemoryTransactionFile(saved: [earlier])
        file.isSealed = true
        let store = StarHashStore(file: file)
        store.apply(ParsedSMS(
            wallet: .mtn, direction: .incoming, counterparty: Recipient(name: "Ariane", destination: "998", kind: .phone),
            amount: 35_000, fee: nil, date: Self.noon, reference: "1203940012", balanceAfter: 47_000, category: nil
        ))
        file.isSealed = false
        store.reloadFromDisk()
        #expect(store.transactions.map(\.amount).sorted() == [700, 35_000])
    }

    /// A failure's message had nothing to fail while sealed: it fails the
    /// payment once the file reads.
    @Test func aFailureWhileSealedFailsThePaymentOnceTheFileReads() throws {
        let payment = Self.pending(10_000)
        let file = MemoryTransactionFile(saved: [payment])
        file.isSealed = true
        let store = StarHashStore(file: file)
        let failure = ParsedSMS(
            wallet: .mtn, direction: .outgoing, counterparty: Self.john,
            amount: 10_000, fee: nil, date: Self.noon.addingTimeInterval(60), reference: nil, balanceAfter: nil, category: nil
        )
        #expect(store.applyFailure(failure) == nil)
        file.isSealed = false
        store.reloadFromDisk()
        #expect(store.transaction(id: payment.id)?.status == .failed)
        #expect(store.transaction(id: payment.id)?.failureReason == .message)
    }

    @Test func nothingIsWrittenWhileSealed() {
        let file = MemoryTransactionFile(saved: [Self.pending()])
        file.isSealed = true
        let store = StarHashStore(file: file)
        store.recordPayment(to: Self.john, amount: 700, date: Self.noon.addingTimeInterval(3600))
        #expect(file.saved?.count == 1)
    }

    /// A file that cannot be decoded is moved aside, never overwritten.
    @Test func aDamagedFileIsSetAside() {
        let old = [Self.pending()]
        let file = MemoryTransactionFile(saved: old)
        file.isDamaged = true
        let store = StarHashStore(file: file)
        #expect(store.transactions.isEmpty)
        #expect(file.setAsideCopies == [old])
        store.recordPayment(to: Self.john, amount: 700, date: Self.noon)
        #expect(file.saved?.count == 1)
        #expect(file.saved?.first?.amount == 700)
    }

    @Test func eraseAllEmptiesTheFile() {
        let file = MemoryTransactionFile(saved: [Self.pending()])
        let store = StarHashStore(file: file)
        store.eraseAll()
        #expect(store.transactions.isEmpty)
        #expect(file.saved == nil)
    }
}
