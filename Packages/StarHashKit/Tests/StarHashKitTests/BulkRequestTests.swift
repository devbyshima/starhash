import Foundation
import Testing
@testable import StarHashKit

@Suite("Request in Bulk")
@MainActor
struct BulkRequestTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    static let ariane = Recipient(name: "Ariane Uwase", destination: "0788123456", kind: .phone)
    static let jean = Recipient(name: "Jean Bosco", destination: "0722000102", kind: .phone)
    static let grace = Recipient(name: "Grace Mutoni", destination: "0789000103", kind: .phone)
    static let eric = PeopleNearby.Person(id: "peer-1", announcement: .init(name: "Eric Nshuti"))

    // MARK: Choosing

    @Test func everyoneStartsAtTheAmountTypedAndCanBeAskedTheirOwn() {
        var bulk = BulkRequest(amount: 5_000)
        bulk.toggle(.number(Self.ariane))
        bulk.toggle(.nearby(Self.eric))
        #expect(bulk.picks.map(\.amount) == [5_000, 5_000])
        bulk.setAmount(12_000, for: BulkRequest.Person.nearby(Self.eric).id)
        #expect(bulk.picks.map(\.amount) == [5_000, 12_000])
        #expect(bulk.total == 17_000)
        #expect(bulk.canSend)
    }

    @Test func choosingSomeoneAgainTakesThemOut() {
        var bulk = BulkRequest(amount: 2_000)
        bulk.toggle(.number(Self.ariane))
        // The same number, from a contact whose name differs.
        bulk.toggle(.number(Recipient(name: "Ariane", destination: "0788123456", kind: .phone)))
        #expect(bulk.picks.isEmpty)
        #expect(!bulk.canSend)
    }

    @Test func noOneIsChosenPastTheLimit() {
        var bulk = BulkRequest(amount: 1_000)
        for index in 0..<(BulkRequest.maximumPeople + 2) {
            bulk.toggle(.number(Recipient(name: nil, destination: String(format: "07881000%02d", index), kind: .phone)))
        }
        #expect(bulk.picks.count == BulkRequest.maximumPeople)
        #expect(bulk.isFull)
    }

    @Test func anAmountStarHashCannotAskForStopsItGoing() {
        var bulk = BulkRequest(amount: 1_000)
        bulk.toggle(.number(Self.ariane))
        bulk.toggle(.number(Self.jean))
        let jean = BulkRequest.Person.number(Self.jean).id
        bulk.setAmount(0, for: jean)
        #expect(!bulk.canSend)
        bulk.setAmount(Money.maximumAmount + 1, for: jean)
        #expect(!bulk.canSend)
        bulk.setAmount(-50, for: jean)
        #expect(bulk.picks[1].amount == 0)
        bulk.setAmount(3_000, for: jean)
        #expect(bulk.canSend)
    }

    // MARK: On the Requests page

    @Test func aBulkRequestIsOneGroupWhereItWasAsked() {
        let requests = MoneyRequests(fileURL: nil)
        let single = requests.ask(Self.grace, photoID: nil, amount: 9_000, note: nil, at: Self.start)
        let group = UUID()
        let first = requests.ask(Self.ariane, photoID: nil, amount: 5_000, note: "Lunch", at: Self.start.addingTimeInterval(60))
        let second = requests.ask(Self.jean, photoID: nil, amount: 7_000, note: "Lunch", at: Self.start.addingTimeInterval(61))
        requests.group(first.id, in: group)
        requests.group(second.id, in: group)
        let later = requests.ask(Self.grace, photoID: nil, amount: 1_000, note: nil, at: Self.start.addingTimeInterval(120))

        let sent = requests.sent
        #expect(sent.map(\.id) == [later.id, group, single.id])
        guard case .group(let shown) = sent[1] else {
            Issue.record("Expected the bulk request as a group")
            return
        }
        // In the order they were asked.
        #expect(shown.requests.map(\.id) == [first.id, second.id])
        #expect(shown.asked == 12_000)
        #expect(shown.note == "Lunch")
    }

    @Test func aGroupCountsWhatCameIn() {
        let requests = MoneyRequests(fileURL: nil)
        let group = UUID()
        let ariane = requests.ask(Self.ariane, photoID: nil, amount: 5_000, note: nil, at: Self.start)
        let jean = requests.ask(Self.jean, photoID: nil, amount: 7_000, note: nil, at: Self.start)
        let grace = requests.ask(Self.grace, photoID: nil, amount: 3_000, note: nil, at: Self.start)
        for request in [ariane, jean, grace] { requests.group(request.id, in: group) }

        let paid = Transaction(
            direction: .incoming, counterparty: Self.ariane, amount: 5_000, date: Self.start.addingTimeInterval(600),
            status: .confirmed, source: .sms
        )
        requests.settle(with: [paid], at: Self.start.addingTimeInterval(700))
        requests.theyDeclined(grace.id)

        guard case .group(let shown) = requests.sent.first else {
            Issue.record("Expected the bulk request as a group")
            return
        }
        #expect(shown.collected == 5_000)
        #expect(shown.asked == 15_000)
        #expect(shown.paidCount == 1)
        #expect(shown.waitingCount == 1)
    }

    @Test func onlyARequestTheOwnerSentJoinsAGroupAndOnlyOne() {
        let requests = MoneyRequests(fileURL: nil)
        let asked = MoneyRequest.Message.Ask(id: UUID(), name: "Jean Bosco", number: "0722000102", photoID: nil, amount: 5_000, note: nil)
        let received = requests.receive(asked, at: Self.start)!
        requests.group(received.id, in: UUID())
        #expect(requests.request(id: received.id)?.groupID == nil)

        let sent = requests.ask(Self.ariane, photoID: nil, amount: 5_000, note: nil, at: Self.start)
        let first = UUID()
        requests.group(sent.id, in: first)
        requests.group(sent.id, in: UUID())
        #expect(requests.request(id: sent.id)?.groupID == first)
    }

    @Test func aGroupStaysAGroupInTheFile() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "requests-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let requests = MoneyRequests(fileURL: url)
        let group = UUID()
        let sent = requests.ask(Self.ariane, photoID: nil, amount: 5_000, note: nil, at: Self.start)
        requests.group(sent.id, in: group)
        #expect(MoneyRequests(fileURL: url).request(id: sent.id)?.groupID == group)
    }

    @Test func requestsKeptBeforeBulkRequestsStillRead() throws {
        let id = UUID()
        let json = #"[{"id":"\#(id.uuidString)","direction":"sent","person":{"name":"Ariane","destination":"0788123456","kind":"phone"},"amount":5000,"createdAt":0,"status":"waiting"}]"#
        let read = try JSONDecoder().decode([MoneyRequest].self, from: Data(json.utf8))
        #expect(read.first?.id == id)
        #expect(read.first?.groupID == nil)
    }
}
