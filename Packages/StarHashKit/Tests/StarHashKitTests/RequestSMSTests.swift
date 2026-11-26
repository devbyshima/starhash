import Foundation
import Testing
@testable import StarHashKit

/// Requests and the carriers' SMS, end to end: a payment made through
/// `Paying`, its message through `AutoVerify.receive` (as the Process
/// Carrier SMS action hands it over), and the request settling from the
/// transactions as the app settles it whenever they change.
@MainActor
@Suite("Requests and SMS", .timeLimit(.minutes(1)))
struct RequestSMSTests {
    /// Payments are recorded at the real time, so the messages carry it too.
    nonisolated static let now = Date.now
    static let jean = Recipient(name: "Jean Bosco", destination: "0788123456", kind: .phone)
    static let ariane = Recipient(name: "Ariane Uwase", destination: "0788000101", kind: .phone)
    static let aline = Recipient(name: "Aline Keza", destination: "0732561240", kind: .phone)

    /// A message's time as MTN writes it, in Kigali.
    static func stamp(_ date: Date = now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Africa/Kigali")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// Auto-verify set up and proven a day ago, Paying with a dialler that
    /// dials nothing, and the requests in memory.
    @MainActor
    final class Rig {
        let store = StarHashStore(fileURL: nil)
        let defaults = TestDefaults("RequestSMSTests")
        let autoVerify: AutoVerify
        let paying: Paying
        let requests = MoneyRequests(fileURL: nil)

        init(splitLargePayments: Bool = false) {
            defaults.set(splitLargePayments, forKey: Preferences.splitLargePayments.key)
            autoVerify = AutoVerify(store: store, defaults: defaults, now: RequestSMSTests.now)
            let day = RequestSMSTests.now.addingTimeInterval(-86_400)
            autoVerify.receive(AutoVerificationSample.message, sender: nil, at: day)
            autoVerify.finishSetUp(at: day)
            autoVerify.receive("Equity Bank: You have received RWF 50,000 from JOHN DOE on 02-10-2026. Ref: FT2627512345.", sender: "EquityBank", at: day.addingTimeInterval(3600))
            paying = Paying(
                store: store, owner: Owner(defaults: defaults), defaults: defaults, dialDelay: .zero,
                dial: { _ in }, locate: { _ in nil }, isContact: { _ in false }
            )
        }

        /// A message arrives, as the automation hands it over, and the
        /// requests settle as the app settles them.
        @discardableResult
        func receive(_ message: String, from sender: String) -> AutoVerify.Outcome {
            let outcome = autoVerify.receive(message, sender: sender, at: RequestSMSTests.now)
            requests.settle(with: store.transactions, at: RequestSMSTests.now)
            return outcome
        }

        func asked(by person: Recipient, amount: Int) throws -> MoneyRequest {
            let ask = MoneyRequest.Message.Ask(
                id: UUID(), name: person.name ?? "", number: person.destination, photoID: nil, amount: amount, note: nil
            )
            return try #require(requests.receive(ask, at: RequestSMSTests.now.addingTimeInterval(-60)))
        }

        func status(_ request: MoneyRequest) -> MoneyRequest.Status? {
            requests.request(id: request.id)?.status
        }
    }

    // MARK: A request the owner was sent, which they pay

    @Test func payingARequestPaysItAndItsSMSConfirmsThePayment() throws {
        let rig = Rig()
        let request = try rig.asked(by: Self.jean, amount: 5_000)
        #expect(rig.paying.pay(request.amount, to: request.person) == .dialled)
        rig.requests.settle(with: rig.store.transactions)
        #expect(rig.status(request) == .paid)

        let sent = "*165*S*5000 RWF transferred to Jean BOSCO (250788123456) from 1234567 at \(Self.stamp()) . Fee was: 100 RWF. New balance: 12000 RWF."
        guard case .confirmed(let payment, _) = rig.receive(sent, from: "M-Money") else {
            Issue.record("the payment was not confirmed")
            return
        }
        #expect(payment.status == .confirmed && payment.fee == 100)
        #expect(rig.status(request) == .paid)
        #expect(rig.requests.request(id: request.id)?.transactionIDs == [payment.id])
    }

    @Test func aFailureSMSPutsTheRequestBackToWaiting() throws {
        let rig = Rig()
        let request = try rig.asked(by: Self.jean, amount: 5_000)
        rig.paying.pay(request.amount, to: request.person)
        rig.requests.settle(with: rig.store.transactions)
        #expect(rig.status(request) == .paid)

        let failed = "Your transfer of 5000 RWF to Jean BOSCO (250788123456) has failed at \(Self.stamp()). Message: . Financial Transaction Id: 30557484199.}."
        guard case .failed = rig.receive(failed, from: "M-Money") else {
            Issue.record("the payment did not fail")
            return
        }
        #expect(rig.status(request) == .waiting)
        #expect(rig.requests.waitingForOwner.map(\.id) == [request.id])
    }

    /// Split Large Payments: the request is paid once every part has gone,
    /// and waits again when any part fails.
    @Test func aRequestPaidInPartsIsPaidByAllOfThem() throws {
        let rig = Rig(splitLargePayments: true)
        let request = try rig.asked(by: Self.jean, amount: 300_000)
        #expect(rig.paying.pay(request.amount, to: request.person) == .split)
        rig.paying.sendNextPart()
        rig.requests.settle(with: rig.store.transactions)
        #expect(rig.status(request) == .waiting)
        rig.paying.sendNextPart()
        rig.requests.settle(with: rig.store.transactions)
        #expect(rig.status(request) == .paid)
        #expect(rig.requests.request(id: request.id)?.transactionIDs?.count == 2)

        let failed = "Your transfer of 150000 RWF to Jean BOSCO (250788123456) has failed at \(Self.stamp()). Message: . Financial Transaction Id: 30557484200.}."
        rig.receive(failed, from: "M-Money")
        #expect(rig.status(request) == .waiting)
    }

    // MARK: A request the owner sent, which money received pays

    @Test func moneyReceivedOnMTNPaysARequestSent() {
        let rig = Rig()
        let request = rig.requests.ask(Self.ariane, photoID: nil, amount: 2_500, note: "Taxi", at: Self.now.addingTimeInterval(-60))
        let received = "You have received 2500 RWF from Ariane UWASE (*********101) on your mobile money account at \(Self.stamp()). Message from sender: Taxi. Your new balance:47000 RWF. Financial Transaction Id: 1203940099."
        guard case .added(let money) = rig.receive(received, from: "M-Money") else {
            Issue.record("the money received was not added")
            return
        }
        #expect(money.direction == .incoming)
        #expect(rig.requests.request(id: request.id)?.status == .paid)
        #expect(rig.requests.request(id: request.id)?.transactionIDs == [money.id])
    }

    @Test func moneyReceivedOnAirtelPaysARequestSentByNumberOrByName() {
        let rig = Rig()
        let byNumber = rig.requests.ask(Self.aline, photoID: nil, amount: 2_500, note: nil, at: Self.now.addingTimeInterval(-60))
        rig.receive("RECEIVED. TID 143487144327. RWF 2,500 from 732561240, ALINE KEZA. Bal RWF 40,000. View txns on MyAirtel App", from: "AirtelMoney")
        #expect(rig.requests.request(id: byNumber.id)?.status == .paid)

        let byName = rig.requests.ask(Self.aline, photoID: nil, amount: 300, note: nil, at: Self.now.addingTimeInterval(-60))
        rig.receive("You have received RWF 300 from ALINE KEZA. Txn. ID: CI260726.1522.A37499. Reason: Mobile Money Transfer.", from: "AirtelMoney")
        #expect(rig.requests.request(id: byName.id)?.status == .paid)
    }

    @Test func moneyReceivedInPartsPaysItOnceItAddsUp() {
        let rig = Rig()
        let request = rig.requests.ask(Self.ariane, photoID: nil, amount: 2_500, note: nil, at: Self.now.addingTimeInterval(-60))
        rig.receive("You have received 1500 RWF from Ariane UWASE (*********101) on your mobile money account at \(Self.stamp()). Message from sender: . Your new balance:45000 RWF. Financial Transaction Id: 1203940100.", from: "M-Money")
        #expect(rig.requests.request(id: request.id)?.status == .waiting)
        rig.receive("You have received 1000 RWF from Ariane UWASE (*********101) on your mobile money account at \(Self.stamp()). Message from sender: . Your new balance:46000 RWF. Financial Transaction Id: 1203940101.", from: "M-Money")
        #expect(rig.requests.request(id: request.id)?.status == .paid)
        #expect(rig.requests.request(id: request.id)?.transactionIDs?.count == 2)
    }

    @Test func moneyFromSomeoneElseOrForAnotherAmountLeavesItWaiting() {
        let rig = Rig()
        let request = rig.requests.ask(Self.ariane, photoID: nil, amount: 2_500, note: nil, at: Self.now.addingTimeInterval(-60))
        // Another person's last digits.
        rig.receive("You have received 2500 RWF from Jean BOSCO (*********456) on your mobile money account at \(Self.stamp()). Message from sender: . Your new balance:47000 RWF. Financial Transaction Id: 1203940102.", from: "M-Money")
        // Ariane, but more than asked.
        rig.receive("You have received 3000 RWF from Ariane UWASE (*********101) on your mobile money account at \(Self.stamp()). Message from sender: . Your new balance:50000 RWF. Financial Transaction Id: 1203940103.", from: "M-Money")
        #expect(rig.requests.request(id: request.id)?.status == .waiting)
    }

    /// A look-alike of the wallet's message is held back as a scam: it
    /// never reaches the transactions, so it pays nothing.
    @Test func aScamLookAlikePaysNothing() {
        let rig = Rig()
        let request = rig.requests.ask(Self.ariane, photoID: nil, amount: 2_500, note: nil, at: Self.now.addingTimeInterval(-60))
        let outcome = rig.receive("You have received 2500 RWF from Ariane UWASE (*********101) on your mobile money account at \(Self.stamp()). Message from sender: . Your new balance:47000 RWF. Financial Transaction Id: 1203940104.", from: "+250 788 555 123")
        guard case .scam = outcome else {
            Issue.record("the look-alike was not held back: \(outcome)")
            return
        }
        #expect(rig.requests.request(id: request.id)?.status == .waiting)
    }
}
