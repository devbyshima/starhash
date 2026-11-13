import Foundation
import Testing
@testable import StarHashKit

/// What a message does, driven only through `AutoVerify.receive`: the
/// Process Carrier SMS action calls nothing else.
@Suite("Receiving a message")
@MainActor
struct AutoVerifyReceiveTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)
    static let aline = Recipient(name: "Aline", destination: "0788123456", kind: .phone)

    static let sent = "*165*S*5000 RWF transferred to Aline (250788123456) from 1234567. Fee was: 100 RWF. New balance: 12000 RWF."
    static let received = "You have received 35000 RWF from Ariane ISHIMWE (*********998) on your mobile money account at 2024-10-20 10:04:11. Message from sender: . Your new balance:47000 RWF. Financial Transaction Id: 1203940012."
    static let failed = "Your transfer of 10000 RWF to Serein SHIMA BYIRINGIRO (250788335935) has failed at 2026-09-14 11:27:16. Message: . Financial Transaction Id: 30557484114.}."
    static let bankText = "Equity Bank: You have received RWF 50,000 from JOHN DOE on 02-10-2026. Ref: FT2627512345. Bal: RWF 210,500."

    static func defaults() -> UserDefaults {
        let name = "AutoVerifyReceiveTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static func payment(minutesAgo: Double, amount: Int = 5_000, to recipient: Recipient = aline, at now: Date = now) -> Transaction {
        Transaction(
            direction: .outgoing, counterparty: recipient, amount: amount,
            date: now.addingTimeInterval(-minutesAgo * 60), status: .pending, source: .app, wallet: .mtn
        )
    }

    /// Auto-verify set up as the guide does (the sample, then the setup)
    /// a day ago, and proven by a message an hour after that when `proven`.
    static func autoVerify(
        _ transactions: [Transaction] = [], setUp: Bool = true, proven: Bool = true, defaults: UserDefaults = defaults()
    ) -> (AutoVerify, StarHashStore) {
        let store = StarHashStore(fileURL: nil)
        for t in transactions { store.add(t) }
        let autoVerify = AutoVerify(store: store, defaults: defaults, now: now)
        if setUp {
            let day = now.addingTimeInterval(-24 * 3600)
            autoVerify.receive(AutoVerificationSample.message, sender: nil, at: day)
            autoVerify.finishSetUp(at: day)
            if proven { autoVerify.receive(bankText, sender: "EquityBank", at: day.addingTimeInterval(3600)) }
        }
        return (autoVerify, store)
    }

    @Test func theSampleProvesTheShortcutAndSavesNothing() {
        let (autoVerify, store) = Self.autoVerify(setUp: false)
        #expect(autoVerify.receive(AutoVerificationSample.message, sender: nil, at: Self.now) == .sample)
        #expect(autoVerify.shortcutRanAt == Self.now)
        #expect(store.transactions.isEmpty)
        #expect(autoVerify.status(at: Self.now) == .off)
    }

    @Test func offIgnoresEveryMessage() {
        let (autoVerify, store) = Self.autoVerify([Self.payment(minutesAgo: 2)], setUp: false)
        #expect(autoVerify.receive(Self.sent, sender: "M-Money", at: Self.now) == .ignored)
        #expect(store.transactions[0].status == .pending)
    }

    @Test func aMessageConfirmsThePaymentItIsFor() throws {
        let payment = Self.payment(minutesAgo: 2)
        let (autoVerify, store) = Self.autoVerify([payment])
        guard case .confirmed(let confirmed, let wasFailed) = autoVerify.receive(Self.sent, sender: "M-Money", at: Self.now) else {
            Issue.record("not confirmed"); return
        }
        #expect(confirmed.id == payment.id)
        #expect(!wasFailed)
        #expect(store.transaction(id: payment.id)?.fee == 100)
    }

    @Test func aLateMessageConfirmsAPaymentAutoVerifyFailed() throws {
        let payment = Self.payment(minutesAgo: 90)
        let (autoVerify, store) = Self.autoVerify([payment])
        autoVerify.expireUnconfirmed(now: Self.now)
        #expect(store.transaction(id: payment.id)?.status == .failed)
        guard case .confirmed(_, let wasFailed) = autoVerify.receive(Self.sent, sender: "M-Money", at: Self.now) else {
            Issue.record("not confirmed"); return
        }
        #expect(wasFailed)
        #expect(store.transaction(id: payment.id)?.status == .confirmed)
    }

    @Test func moneyReceivedIsAddedOnceAndOnlyOnce() {
        let (autoVerify, store) = Self.autoVerify()
        guard case .added(let added) = autoVerify.receive(Self.received, sender: "M-Money", at: Self.now) else {
            Issue.record("not added"); return
        }
        #expect(added.direction == .incoming)
        #expect(autoVerify.receive(Self.received, sender: "M-Money", at: Self.now) == .alreadyApplied(added))
        #expect(store.transactions.count == 1)
    }

    @Test func aLookAlikeIsHeldBackUnlessWarningsAreOff() {
        let defaults = Self.defaults()
        let (autoVerify, store) = Self.autoVerify(defaults: defaults)
        guard case .scam(let warning) = autoVerify.receive(Self.received, sender: "+250 788 555 123", at: Self.now) else {
            Issue.record("not held back"); return
        }
        #expect(warning.reason == .unofficialSender)
        #expect(store.transactions.isEmpty)

        defaults.set(false, forKey: "scamWarnings")
        guard case .added = autoVerify.receive(Self.received, sender: "+250 788 555 123", at: Self.now) else {
            Issue.record("not logged with warnings off"); return
        }
    }

    @Test func withTransactionsNotKeptEveryMessageIsIgnored() {
        let defaults = Self.defaults()
        let (autoVerify, store) = Self.autoVerify(defaults: defaults)
        defaults.set(false, forKey: "saveTransactions")
        #expect(autoVerify.receive(Self.received, sender: "M-Money", at: Self.now) == .ignored)
        #expect(store.transactions.isEmpty)
    }

    /// The automation runs for any text with RWF in it: a bank's proves it
    /// hands messages over, but logs nothing.
    @Test func aBankTextProvesTheAutomationAndLogsNothing() {
        let (autoVerify, store) = Self.autoVerify(proven: false)
        #expect(autoVerify.status(at: Self.now) == .waiting)
        #expect(autoVerify.receive(Self.bankText, sender: "EquityBank", at: Self.now) == .ignored)
        #expect(autoVerify.status(at: Self.now) == .active)
        #expect(store.transactions.isEmpty)
    }

    @Test func aFailureMessageFailsItsPaymentAndIgnoresOthers() throws {
        let sms = try #require(CarrierSMS.parseFailure(Self.failed))
        let date = try #require(sms.date)
        let serein = Recipient(name: "Serein", destination: "0788335935", kind: .phone)
        let payment = Self.payment(minutesAgo: 1, amount: 10_000, to: serein, at: date)
        let (autoVerify, store) = Self.autoVerify([payment])
        guard case .failed(let failed) = autoVerify.receive(Self.failed, sender: "M-Money", at: date) else {
            Issue.record("not failed"); return
        }
        #expect(failed.failureReason == .message)
        #expect(store.transaction(id: payment.id)?.status == .failed)

        let (other, _) = Self.autoVerify()
        #expect(other.receive(Self.failed, sender: "M-Money", at: date) == .unmatched)
    }

    @Test func anyMessagePastAPaymentsHourFailsIt() {
        let old = Self.payment(minutesAgo: 120)
        let (autoVerify, store) = Self.autoVerify([old])
        autoVerify.receive(Self.received, sender: "M-Money", at: Self.now)
        #expect(store.transaction(id: old.id)?.status == .failed)
        #expect(store.transaction(id: old.id)?.failureReason == .noMessage)
    }

    @Test func onlyMessagesThatReachTheTransactionsReschedule() {
        #expect(!AutoVerify.Outcome.sample.reachedTransactions)
        #expect(!AutoVerify.Outcome.ignored.reachedTransactions)
        #expect(AutoVerify.Outcome.unmatched.reachedTransactions)
    }
}
