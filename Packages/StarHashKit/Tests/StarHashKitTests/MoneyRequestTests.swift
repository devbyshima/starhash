import Foundation
import Testing
@testable import StarHashKit

@Suite("Requests")
@MainActor
struct MoneyRequestTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static let ariane = Recipient(name: "Ariane Uwase", destination: "0788123456", kind: .phone)

    static func received(from sender: Recipient, amount: Int = 5_000, after seconds: TimeInterval = 600, status: Transaction.Status = .confirmed) -> Transaction {
        Transaction(direction: .incoming, counterparty: sender, amount: amount, date: start.addingTimeInterval(seconds), status: status, source: .sms)
    }

    static func sent(to recipient: Recipient, amount: Int = 5_000, after seconds: TimeInterval = 600, status: Transaction.Status = .pending) -> Transaction {
        Transaction(direction: .outgoing, counterparty: recipient, amount: amount, date: start.addingTimeInterval(seconds), status: status, source: .app)
    }

    static func ask(_ id: UUID = UUID(), amount: Int = 5_000) -> MoneyRequest.Message.Ask {
        .init(id: id, name: "Ariane Uwase", number: "0788123456", photoID: nil, amount: amount, note: "Lunch")
    }

    // MARK: Between phones

    @Test func anAskReadsBackAsItWasSent() throws {
        let ask = Self.ask()
        #expect(MoneyRequest.Message(data: MoneyRequest.Message.ask(ask).data) == .ask(ask))
        let id = UUID()
        #expect(MoneyRequest.Message(data: MoneyRequest.Message.declined(id: id).data) == .declined(id: id))
    }

    @Test func anAskStarHashCouldNotActOnIsDropped() {
        func data(_ json: String) -> Data { Data(json.utf8) }
        let id = UUID().uuidString
        #expect(MoneyRequest.Message(data: data(#"{"v":1,"kind":"ask","id":"\#(id)","name":"A","number":"020205","amount":500}"#)) == nil)
        #expect(MoneyRequest.Message(data: data(#"{"v":1,"kind":"ask","id":"\#(id)","name":"A","number":"0788123456","amount":0}"#)) == nil)
        #expect(MoneyRequest.Message(data: data(#"{"v":1,"kind":"ask","id":"\#(id)","name":" ","number":"0788123456","amount":500}"#)) == nil)
        #expect(MoneyRequest.Message(data: data(#"{"v":2,"kind":"declined","id":"\#(id)"}"#)) == nil)
        #expect(MoneyRequest.Message(data: data(#"{"v":1,"kind":"paid","id":"\#(id)"}"#)) == nil)
    }

    /// The payer's number reaches the asker only as they tap Pay on a
    /// request that came by a tap.
    @Test func whoIsPayingReadsBackAsItWasSent() {
        let payer = MoneyRequest.Message.Payer(id: UUID(), name: "  Grace Mutoni ", number: "0789000103")
        #expect(payer.name == "Grace Mutoni")
        #expect(MoneyRequest.Message(data: MoneyRequest.Message.paying(payer).data) == .paying(payer))
        #expect(payer.person == Recipient(name: "Grace Mutoni", destination: "0789000103", kind: .phone))
        // With no name, the number alone.
        let unnamed = MoneyRequest.Message.Payer(id: UUID(), name: " ", number: "0789000103")
        #expect(unnamed.name == nil)
        #expect(MoneyRequest.Message(data: MoneyRequest.Message.paying(unnamed).data) == .paying(unnamed))
    }

    /// The SMS that pays a request the owner sent is said as the request:
    /// Request paid, not Money received. In parts, only the last part
    /// finishes paying it.
    @Test func moneyThatPaysARequestIsSaidAsTheRequest() throws {
        let requests = MoneyRequests(fileURL: nil)
        let asked = requests.ask(Self.ariane, photoID: nil, amount: 5_000, note: nil, at: Self.start)
        let first = Self.received(from: Self.ariane, amount: 3_000, after: 60)
        let second = Self.received(from: Self.ariane, amount: 2_000, after: 120)
        requests.settle(with: [first], at: Self.start.addingTimeInterval(90))
        #expect(MoneyRequest.sent(paidBy: first.id, in: requests.requests) == nil)
        requests.settle(with: [second, first], at: Self.start.addingTimeInterval(150))
        let paid = try #require(MoneyRequest.sent(paidBy: second.id, in: requests.requests))
        #expect(paid.id == asked.id)
        #expect(MoneyRequest.sent(paidBy: first.id, in: requests.requests) == nil)

        let item = try #require(NotificationPlan.requestPaid(paid, name: "Ariane Uwase", settings: .init()))
        #expect(item.kind == .requestPaid && item.requestID == asked.id && item.transactionID == nil)
        #expect(item.body.contains("Ariane Uwase") && item.body.contains("5,000"))
        let hidden = try #require(NotificationPlan.requestPaid(paid, name: "Ariane", settings: .init(showsAmounts: false)))
        #expect(!hidden.body.contains("5,000"))
        #expect(NotificationPlan.requestPaid(paid, name: "Ariane", settings: .init(requests: false)) == nil)
        // Only one the owner sent, and only once paid.
        #expect(NotificationPlan.requestPaid(asked, name: "Ariane", settings: .init()) == nil)
    }

    @Test func whoIsPayingIsOnlyARwandanMobileNumber() throws {
        func data(_ json: String) -> Data { Data(json.utf8) }
        let id = UUID()
        #expect(MoneyRequest.Message(data: data(#"{"v":1,"kind":"paying","id":"\#(id)","number":"020205"}"#)) == nil)
        #expect(MoneyRequest.Message(data: data(#"{"v":1,"kind":"paying","id":"\#(id)"}"#)) == nil)
        let international = try #require(MoneyRequest.Message(data: data(#"{"v":1,"kind":"paying","id":"\#(id)","number":"+250788123456"}"#)))
        #expect(international == .paying(.init(id: id, name: nil, number: "0788123456")))
    }

    @Test func aNoteIsTrimmedAndCut() {
        let long = MoneyRequest.Message.Ask(id: UUID(), name: "A", number: "0788123456", photoID: nil, amount: 1, note: " \(String(repeating: "x", count: 90)) ")
        #expect(long.note?.count == MoneyRequest.maximumNoteLength)
        #expect(MoneyRequest.Message.Ask(id: UUID(), name: "A", number: "0788123456", photoID: nil, amount: 1, note: "  ").note == nil)
    }

    // MARK: What pays a request the owner sent

    @Test func moneyReceivedFromThemPaysIt() {
        let requests = MoneyRequests(fileURL: nil)
        let request = requests.ask(Self.ariane, photoID: nil, amount: 5_000, note: nil, at: Self.start)
        // MTN shows the sender's last three digits.
        let paying = Self.received(from: Recipient(name: "Ariane UWASE", destination: "456", kind: .phone))
        requests.settle(with: [paying], at: Self.start.addingTimeInterval(700))
        #expect(requests.request(id: request.id)?.status == .paid)
        #expect(requests.request(id: request.id)?.transactionIDs == [paying.id])
    }

    @Test func onlyTheRightPersonAmountAndTimePayIt() {
        let request = MoneyRequest(direction: .sent, person: Self.ariane, amount: 5_000, createdAt: Self.start)
        // Another person's digits, another amount, before the request, after it expired.
        #expect(!request.isPaid(by: Self.received(from: Recipient(name: "Jean", destination: "999", kind: .phone))))
        #expect(!request.isPaid(by: Self.received(from: Recipient(name: "Ariane", destination: "456", kind: .phone), amount: 4_000)))
        #expect(!request.isPaid(by: Self.received(from: Recipient(name: "Ariane", destination: "456", kind: .phone), after: -3_600)))
        #expect(!request.isPaid(by: Self.received(from: Recipient(name: "Ariane", destination: "456", kind: .phone), after: 8 * 86_400)))
        // A failed one, or money the owner sent.
        #expect(!request.isPaid(by: Self.received(from: Recipient(name: "Ariane", destination: "456", kind: .phone), status: .failed)))
        #expect(!request.isPaid(by: Self.sent(to: Self.ariane)))
        // The whole number, or only a word of the name (Airtel shows no number).
        #expect(request.isPaid(by: Self.received(from: Recipient(name: "X", destination: "0788123456", kind: .phone))))
        #expect(request.isPaid(by: Self.received(from: Recipient(name: "UWASE ARIANE", destination: "", kind: .phone))))
        #expect(!request.isPaid(by: Self.received(from: Recipient(name: "Jean Bosco", destination: "", kind: .phone))))
    }

    /// Two waiting requests for the same amount from the same person: one
    /// payment pays the older, and the next pays the other.
    @Test func onePaymentPaysOneRequestOldestFirst() {
        let requests = MoneyRequests(fileURL: nil)
        let first = requests.ask(Self.ariane, photoID: nil, amount: 5_000, note: nil, at: Self.start)
        let second = requests.ask(Self.ariane, photoID: nil, amount: 5_000, note: nil, at: Self.start.addingTimeInterval(60))
        let sender = Recipient(name: "Ariane", destination: "456", kind: .phone)
        let one = Self.received(from: sender, after: 600)
        requests.settle(with: [one])
        #expect(requests.request(id: first.id)?.status == .paid)
        #expect(requests.request(id: second.id)?.status == .waiting)
        let two = Self.received(from: sender, after: 1_200)
        requests.settle(with: [two, one])
        #expect(requests.request(id: second.id)?.transactionIDs == [two.id])
    }

    // MARK: What pays a request the owner received

    @Test func payingThemPaysItAndAFailedPaymentUndoesThat() throws {
        let requests = MoneyRequests(fileURL: nil)
        let request = try #require(requests.receive(Self.ask(), at: Self.start))
        var payment = Self.sent(to: Self.ariane)
        requests.settle(with: [payment])
        #expect(requests.request(id: request.id)?.status == .paid)
        payment.status = .failed
        requests.settle(with: [payment])
        #expect(requests.request(id: request.id)?.status == .waiting)
        // A payment deleted from Transactions too.
        requests.settle(with: [Self.sent(to: Self.ariane)])
        requests.settle(with: [])
        #expect(requests.request(id: request.id)?.status == .waiting)
    }

    // MARK: Answers and expiry

    @Test func answersSettleOnlyWhatTheyAreFor() throws {
        let requests = MoneyRequests(fileURL: nil)
        let sent = requests.ask(Self.ariane, photoID: nil, amount: 500, note: nil, at: Self.start)
        let received = try #require(requests.receive(Self.ask(), at: Self.start))
        // The same ask twice is one request.
        #expect(requests.receive(Self.ask(received.id), at: Self.start) == nil)
        // Declining is for what the owner received; cancelling for what they sent.
        requests.decline(sent.id)
        requests.cancel(received.id)
        #expect(requests.requests.allSatisfy { $0.status == .waiting })
        requests.theyDeclined(sent.id)
        requests.decline(received.id)
        #expect(requests.request(id: sent.id)?.status == .declined)
        #expect(requests.request(id: received.id)?.status == .declined)
        #expect(requests.waitingForOwner.isEmpty)
    }

    @Test func aRequestNobodyPaidExpiresAfterAWeek() {
        let requests = MoneyRequests(fileURL: nil)
        let request = requests.ask(Self.ariane, photoID: nil, amount: 500, note: nil, at: Self.start)
        requests.settle(with: [], at: Self.start.addingTimeInterval(6 * 86_400))
        #expect(requests.request(id: request.id)?.status == .waiting)
        requests.settle(with: [], at: Self.start.addingTimeInterval(8 * 86_400))
        #expect(requests.request(id: request.id)?.status == .expired)
    }

    @Test func requestsAreKeptInTheirFile() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "requests-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let written = MoneyRequests(fileURL: url)
        let request = written.ask(Self.ariane, photoID: nil, amount: 2_500, note: "Taxi", at: Self.start)
        written.markPaid(request.id)
        let read = MoneyRequests(fileURL: url)
        #expect(read.requests.count == 1)
        #expect(read.request(id: request.id)?.status == .paid)
        #expect(read.request(id: request.id)?.note == "Taxi")
    }
}
