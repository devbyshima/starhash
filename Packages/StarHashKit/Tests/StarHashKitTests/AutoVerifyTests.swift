import Foundation
import Testing
@testable import StarHashKit

@Suite("Auto-verify failures")
@MainActor
struct AutoVerifyTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)
    static let aline = Recipient(name: "Aline", destination: "0788123456", kind: .phone)

    static func payment(_ amount: Int = 5_000, minutesAgo: Double, to recipient: Recipient = aline, wallet: Recipient.Network? = .mtn) -> Transaction {
        Transaction(
            direction: .outgoing, counterparty: recipient, amount: amount,
            date: now.addingTimeInterval(-minutesAgo * 60), status: .pending, source: .app, wallet: wallet
        )
    }

    static func store(_ transactions: Transaction...) -> StarHashStore {
        let store = StarHashStore(fileURL: nil)
        for t in transactions { store.add(t) }
        return store
    }

    // MARK: Failure messages

    @Test func readsAnMTNTransferThatFailed() throws {
        let sms = try #require(CarrierSMS.parseFailure("*165*S*Your transfer of 5000 RWF to John Doe (250788123456) failed. Insufficient balance."))
        #expect(sms.wallet == .mtn)
        #expect(sms.amount == 5_000)
        #expect(sms.counterparty.destination == "0788123456")
    }

    @Test func readsAnAirtelTransferThatFailed() throws {
        let sms = try #require(CarrierSMS.parseFailure("Transaction failed. TID 145041307720. RWF 1,000 to JEAN BOSCO 0732561240. Insufficient funds."))
        #expect(sms.wallet == .airtel)
        #expect(sms.amount == 1_000)
        #expect(sms.counterparty.destination == "0732561240")
    }

    @Test func aFailureThatNamesNoPayeeIsLeftAlone() {
        #expect(CarrierSMS.parseFailure("*164*S*Transaction of 9000 RWF was cancelled at 2024-10-20 16:13:05.") == nil)
        #expect(CarrierSMS.parseFailure("Transaction of 9000 RWF was cancelled at 2024-10-20 16:13:05.") == nil)
    }

    @Test func aSuccessIsNotAFailure() {
        #expect(CarrierSMS.parseFailure("*165*S*5000 RWF transferred to John Doe (250788123456) from 1234567 at 2024-10-20 16:13:05. Fee was: 100 RWF. New balance: 12000 RWF.") == nil)
    }

    @Test func aFailureMessageFailsTheMatchingPayment() throws {
        let pending = Self.payment(minutesAgo: 2)
        let store = Self.store(pending)
        let sms = try #require(CarrierSMS.parseFailure("*165*S*Your transfer of 5000 RWF to Aline (250788123456) failed. Insufficient balance."))
        let failed = try #require(store.applyFailure(sms, receivedAt: Self.now))
        #expect(failed.id == pending.id)
        #expect(store.transaction(id: pending.id)?.status == .failed)
        #expect(store.transaction(id: pending.id)?.failureReason == .message)
    }

    @Test func aFailureMessageMatchingNothingAddsNothing() throws {
        let store = Self.store(Self.payment(2_000, minutesAgo: 2))
        let sms = try #require(CarrierSMS.parseFailure("*165*S*Your transfer of 5000 RWF to Aline (250788123456) failed. Insufficient balance."))
        #expect(store.applyFailure(sms, receivedAt: Self.now) == nil)
        #expect(store.transactions.count == 1)
        #expect(store.transactions[0].status == .pending)
    }

    // MARK: The hour

    @Test func aPaymentPendingPastTheHourFails() {
        let old = Self.payment(minutesAgo: 61)
        let recent = Self.payment(2_000, minutesAgo: 30)
        let store = Self.store(old, recent)
        let expired = store.expireUnconfirmed(dialledSince: .distantPast, now: Self.now)
        #expect(expired.map(\.id) == [old.id])
        #expect(store.transaction(id: old.id)?.failureReason == .noMessage)
        #expect(store.transaction(id: recent.id)?.status == .pending)
    }

    @Test func paymentsFromBeforeAutoVerifyAreLeftPending() {
        let old = Self.payment(minutesAgo: 600)
        let store = Self.store(old)
        store.expireUnconfirmed(dialledSince: Self.now.addingTimeInterval(-60 * 60 * 2), now: Self.now)
        #expect(store.transaction(id: old.id)?.status == .pending)
    }

    @Test func aLateMessageStillConfirmsAnExpiredPayment() throws {
        let old = Self.payment(minutesAgo: 90)
        let store = Self.store(old)
        store.expireUnconfirmed(dialledSince: .distantPast, now: Self.now)
        let sms = try #require(CarrierSMS.parse("*165*S*5000 RWF transferred to Aline (250788123456) from 1234567. Fee was: 100 RWF. New balance: 12000 RWF."))
        let applied = store.apply(sms, receivedAt: Self.now)
        #expect(applied.id == old.id)
        #expect(store.transactions.count == 1)
        #expect(store.transactions[0].status == .confirmed)
        #expect(store.transactions[0].failureReason == nil)
    }

    @Test func aPaymentFailedByHandIsNotRevived() throws {
        let old = Self.payment(minutesAgo: 90).markedFailed()
        let store = Self.store(old)
        let sms = try #require(CarrierSMS.parse("*165*S*5000 RWF transferred to Aline (250788123456) from 1234567. Fee was: 100 RWF."))
        store.apply(sms, receivedAt: Self.now)
        #expect(store.transaction(id: old.id)?.status == .failed)
        #expect(store.transactions.count == 2)
    }

    // MARK: A broken shortcut

    @Test func threeUnconfirmedAndAQuietWeekLooksBroken() {
        let payments = (1...3).map { Self.payment(minutesAgo: Double($0) * 120) }
        let quiet = Self.now.addingTimeInterval(-8 * 24 * 3600)
        #expect(AutoVerify.looksBroken(payments, lastMessageAt: quiet, now: Self.now))
        // A message this week says the shortcut runs.
        #expect(!AutoVerify.looksBroken(payments, lastMessageAt: Self.now.addingTimeInterval(-3600), now: Self.now))
    }

    @Test func oneConfirmedPaymentMeansItWorks() {
        var payments = (1...3).map { Self.payment(minutesAgo: Double($0) * 120) }
        payments[1].status = .confirmed
        #expect(!AutoVerify.looksBroken(payments, lastMessageAt: nil, now: Self.now))
    }

    // MARK: The notification

    @Test func theReminderSaysItFailedAtTheHour() throws {
        let pending = Self.payment(minutesAgo: 5)
        let item = try #require(NotificationPlan.reminder(for: pending, settings: .init(failsUnconfirmed: true)))
        #expect(item.kind == .paymentExpired)
        #expect(item.date == pending.date.addingTimeInterval(AutoVerify.confirmationWindow))
        #expect(item.body == "No M\u{2011}Money message confirmed 5,000 RWF to Aline within an hour, so StarHash marked it failed.")
    }
}
