import Foundation
import Testing
@testable import StarHashKit

/// Requests through the server, between iPhones that share one server in
/// memory, which keeps the Worker's rules (`server/src/index.ts`, tested
/// on its own by `npm test`): only listed numbers with a key, the asker's
/// own number checked, one waiting per pair, twenty a day, and what each
/// side may close or answer.
@Suite("Requests anywhere")
@MainActor
struct RequestsAnywhereTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// StarHash's server, as the Worker keeps it.
    @MainActor
    final class World {
        struct Entry {
            var secret: String
            var name: String
            var key: String?
        }

        struct Row {
            var to: String
            /// The key the number asked was listed under: only it reads,
            /// answers or drops the request.
            var toSecret: String
            var fromSecret: String
            var fromKey: String
            var sealed: String?
            var answer: String?
            var state: String
            var createdAt: Date
            var remindedAt: Date?
        }

        var directory: [String: Entry] = [:]
        var rows: [UUID: Row] = [:]
        var reachable = true
        var now = RequestsAnywhereTests.start
    }

    @MainActor
    final class FakeServer: RequestsAnywhere.Server {
        let world: World
        private(set) var drops = 0

        init(world: World) { self.world = world }

        func lookUp(_ number: String) async -> RequestsAnywhere.LookUp {
            guard world.reachable else { return .failed }
            guard let entry = world.directory[number] else { return .notListed }
            return .listed(.init(name: entry.name, photoID: nil, key: entry.key))
        }

        func send(id: UUID, to number: String, from own: String, sealed: String, key: String) async -> RequestsAnywhere.SendAnswer {
            guard world.reachable else { return .failed }
            guard let asker = world.directory[own], asker.secret == key, let fromKey = asker.key else { return .notListed }
            guard let asked = world.directory[number], asked.key != nil, asked.secret != key else { return .notOnStarHash }
            let today = world.rows.values.filter { $0.fromSecret == key && $0.createdAt > world.now.addingTimeInterval(-86_400) }
            guard today.count < 20 else { return .tooMany }
            let waiting = world.rows.values.contains {
                $0.fromSecret == key && $0.to == number && ["waiting", "dropped"].contains($0.state) && !expired($0)
            }
            guard !waiting, world.rows[id] == nil else { return .alreadyAsked }
            world.rows[id] = World.Row(
                to: number, toSecret: asked.secret, fromSecret: key, fromKey: fromKey, sealed: sealed, state: "waiting", createdAt: world.now
            )
            return .sent
        }

        func inbox(key: String) async -> RequestsAnywhere.Inbox? {
            guard world.reachable else { return nil }
            let asked = world.rows.filter { $0.value.toSecret == key && ["waiting", "closed"].contains($0.value.state) && !expired($0.value) }
                .sorted { $0.value.createdAt < $1.value.createdAt }
                .map {
                    RequestsAnywhere.Inbox.Asked(
                        id: $0.key, sealed: $0.value.sealed, key: $0.value.fromKey, createdAt: $0.value.createdAt,
                        remindedAt: $0.value.remindedAt
                    )
                }
            let answers = world.rows.filter { $0.value.fromSecret == key && $0.value.state == "answered" && !expired($0.value) }
                .map { RequestsAnywhere.Inbox.Answer(id: $0.key, sealed: $0.value.answer!) }
            return .init(asked: asked, answers: answers)
        }

        func answer(id: UUID, sealed: String, key: String) async -> Bool {
            guard world.reachable else { return false }
            guard let row = world.rows[id], row.toSecret == key else { return true }
            guard row.state == "waiting" else { return true }
            world.rows[id]?.state = "answered"
            world.rows[id]?.answer = sealed
            world.rows[id]?.sealed = nil
            return true
        }

        func close(id: UUID, key: String) async -> Bool {
            guard world.reachable else { return false }
            guard let row = world.rows[id] else { return true }
            if row.fromSecret == key {
                world.rows[id]?.state = "closed"
                world.rows[id]?.sealed = nil
                world.rows[id]?.answer = nil
            } else if row.toSecret == key, row.state == "waiting" {
                world.rows[id]?.state = "dropped"
                world.rows[id]?.sealed = nil
                drops += 1
            }
            return true
        }

        private(set) var erased: [String] = []

        func erase(key: String) async -> Bool {
            guard world.reachable else { return false }
            erased.append(key)
            for (id, row) in world.rows where row.fromSecret == key {
                world.rows[id]?.state = "closed"
                world.rows[id]?.sealed = nil
            }
            return true
        }

        /// As the Worker: the asker only, a request waiting (or dropped,
        /// silently), a day since it was asked or last reminded of.
        func remind(id: UUID, key: String) async -> RequestsAnywhere.RemindAnswer {
            guard world.reachable else { return .failed }
            guard let row = world.rows[id], row.fromSecret == key else { return .notWaiting }
            guard ["waiting", "dropped"].contains(row.state), !expired(row) else { return .notWaiting }
            guard world.now >= (row.remindedAt ?? row.createdAt).addingTimeInterval(86_400) else { return .tooSoon }
            world.rows[id]?.remindedAt = world.now
            return .reminded(world.now)
        }

        private func expired(_ row: World.Row) -> Bool {
            world.now >= row.createdAt.addingTimeInterval(MoneyRequest.lifetime)
        }
    }

    /// One iPhone: its requests, its keys, its listing and its Contacts
    /// (nil when StarHash may not read them).
    @MainActor
    final class Phone {
        let name: String
        let number: String
        let secret = UUID().uuidString
        let key = RequestSeal.makeKey()
        let requests = MoneyRequests(fileURL: nil)
        let server: FakeServer
        let defaults: TestDefaults
        var contacts: Set<String>? = []
        private(set) var anywhere: RequestsAnywhere!

        init(_ name: String, _ number: String, in world: World, takesRequests: Bool = true) {
            self.name = name
            self.number = number
            server = FakeServer(world: world)
            defaults = TestDefaults("RequestsAnywhereTests.\(number)")
            world.directory[number] = .init(secret: secret, name: name, key: takesRequests ? RequestSeal.publicKey(of: key) : nil)
            let secret = secret, key = key
            anywhere = RequestsAnywhere(
                requests: requests, server: server, key: { secret }, privateKey: { key },
                mayAsk: { [unowned self] asker in contacts.map { $0.contains(asker.destination) } },
                defaults: defaults
            )
        }

        func knows(_ other: Phone) { contacts?.insert(other.number) }

        /// Asks `other`, as the Request sheet does: looked up first.
        @discardableResult
        func ask(_ other: Phone, amount: Int = 5_000, note: String? = "Lunch") async -> Result<MoneyRequest, RequestsAnywhere.AskFailure> {
            guard case .listed(let listed) = await anywhere.lookUp(other.number) else { return .failure(.notOnStarHash) }
            let ask = MoneyRequest.Message.Ask(id: UUID(), name: name, number: number, photoID: nil, amount: amount, note: note)
            return await anywhere.ask(ask, to: Recipient(destination: other.number, kind: .phone), listed: listed, at: server.world.now)
        }

        /// Asks `other` nearby, as `NearbyRequests` does once their phone
        /// handed over its number: kept here, on its way to them over
        /// People Nearby's connection (`hear`), and not yet through the
        /// server (`carry`).
        func askNearby(_ other: Phone, amount: Int = 5_000, note: String? = "Lunch") -> MoneyRequest.Message.Ask {
            let ask = MoneyRequest.Message.Ask(id: UUID(), name: name, number: number, photoID: nil, amount: amount, note: note)
            let them = Recipient(name: other.name, destination: other.number, kind: .phone)
            requests.ask(them, id: ask.id, photoID: nil, amount: amount, note: note, at: server.world.now)
            return ask
        }

        /// The server copy of a request asked nearby.
        @discardableResult
        func carry(_ ask: MoneyRequest.Message.Ask, to other: Phone) async -> Result<MoneyRequest, RequestsAnywhere.AskFailure> {
            await anywhere.carry(ask, to: Recipient(name: other.name, destination: other.number, kind: .phone), at: server.world.now)
        }

        /// A request nearby arrives over People Nearby's connection.
        @discardableResult
        func hear(_ ask: MoneyRequest.Message.Ask) -> MoneyRequest? {
            requests.receive(ask, at: server.world.now)
        }
    }

    let world = World()

    // MARK: Sealing

    @Test func aSealOpensOnlyForItsKeyItsSenderItsIdAndItsPurpose() throws {
        let asker = RequestSeal.makeKey(), asked = RequestSeal.makeKey(), stranger = RequestSeal.makeKey()
        let id = UUID()
        let data = Data("Pay me".utf8)
        let sealed = try #require(RequestSeal.seal(data, id: id, purpose: .ask, to: RequestSeal.publicKey(of: asked), from: asker))
        let askerKey = RequestSeal.publicKey(of: asker)
        #expect(RequestSeal.open(sealed, id: id, purpose: .ask, with: asked, from: askerKey) == data)
        #expect(RequestSeal.open(sealed, id: id, purpose: .ask, with: stranger, from: askerKey) == nil)
        #expect(RequestSeal.open(sealed, id: id, purpose: .ask, with: asked, from: RequestSeal.publicKey(of: stranger)) == nil)
        #expect(RequestSeal.open(sealed, id: UUID(), purpose: .ask, with: asked, from: askerKey) == nil)
        #expect(RequestSeal.open(sealed, id: id, purpose: .answer, with: asked, from: askerKey) == nil)
        var bytes = try #require(Data(base64Encoded: sealed))
        bytes[bytes.count - 1] ^= 1
        #expect(RequestSeal.open(bytes.base64EncodedString(), id: id, purpose: .ask, with: asked, from: askerKey) == nil)
        #expect(RequestSeal.seal(data, id: id, purpose: .ask, to: "not a key", from: asker) == nil)
    }

    @Test func aPrivateKeyKeptAsItsBytesIsTheSameKey() throws {
        let key = RequestSeal.makeKey()
        let kept = try #require(RequestSeal.privateKey(raw: key.rawRepresentation))
        #expect(RequestSeal.publicKey(of: kept) == RequestSeal.publicKey(of: key))
        #expect(RequestSeal.isPublicKey(RequestSeal.publicKey(of: key)))
        #expect(!RequestSeal.isPublicKey("AAAA"))
    }

    // MARK: Asking, answering, cancelling

    @Test func aRequestReachesSomeoneAnywhereWhoKnowsTheAsker() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let sent = try await jean.ask(shima).get()
        #expect(sent.direction == .sent && sent.isAnywhere && sent.person.name == "Shima Serein")
        #expect(jean.requests.request(id: sent.id)?.status == .waiting)

        world.now = Self.start.addingTimeInterval(3_600)
        let news = await shima.anywhere.sync(at: world.now)
        let received = try #require(news.received.first)
        #expect(received.id == sent.id && received.person.destination == "0788000102" && received.person.name == "Jean Bosco")
        #expect(received.amount == 5_000 && received.note == "Lunch")
        // Its week runs from when it was asked, not when it was read.
        #expect(received.createdAt == Self.start)
        #expect(shima.requests.waitingForOwner.map(\.id) == [sent.id])
        // Taken in once.
        #expect(await shima.anywhere.sync(at: world.now).isEmpty)
    }

    // MARK: Reminding

    @Test func aReminderGoesOnceADayAndIsSaidOnceOnTheOtherIPhone() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let sent = try await jean.ask(shima).get()
        await shima.anywhere.sync(at: world.now)

        // Not the day it was asked.
        #expect(jean.requests.request(id: sent.id)?.canRemind(at: world.now) == false)
        #expect(await jean.anywhere.remind(sent.id, at: world.now) == .failure(.tooSoon))

        world.now = Self.start.addingTimeInterval(86_400)
        let reminded = try await jean.anywhere.remind(sent.id, at: world.now).get()
        #expect(reminded.remindedAt == world.now)
        #expect(reminded.nextReminderAt == world.now.addingTimeInterval(86_400))
        #expect(!reminded.canRemind(at: world.now.addingTimeInterval(3_600)))

        let news = await shima.anywhere.sync(at: world.now)
        #expect(news.reminded.map(\.id) == [sent.id] && news.received.isEmpty)
        #expect(shima.requests.request(id: sent.id)?.remindedAt == world.now)
        // Said once.
        #expect(await shima.anywhere.sync(at: world.now).isEmpty)

        // A day on, once more.
        world.now = Self.start.addingTimeInterval(2 * 86_400)
        #expect(await jean.anywhere.remind(sent.id, at: world.now) == .success(jean.requests.request(id: sent.id)!))
        #expect(await shima.anywhere.sync(at: world.now).reminded.map(\.id) == [sent.id])
    }

    @Test func onlyAWaitingRequestThatWentThroughTheServerIsReminded() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let sent = try await jean.ask(shima).get()
        // Asked nearby only: no way to remind them.
        let nearby = jean.askNearby(shima, amount: 2_000)
        world.now = Self.start.addingTimeInterval(86_400)
        #expect(jean.requests.request(id: nearby.id)?.isRemindable == false)
        #expect(await jean.anywhere.remind(nearby.id, at: world.now) == .failure(.notWaiting))

        // Declined since: nothing left to remind of.
        await shima.anywhere.sync(at: world.now)
        shima.requests.decline(sent.id)
        await shima.anywhere.report()
        await jean.anywhere.sync(at: world.now)
        #expect(await jean.anywhere.remind(sent.id, at: world.now) == .failure(.notWaiting))
        #expect(world.rows[sent.id]?.remindedAt == nil)
    }

    @Test func aReminderTheServerFindsTooSoonWaitsItsDay() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        let sent = try await jean.ask(shima).get()
        // Reminded from elsewhere: the server has one from an hour ago.
        world.now = Self.start.addingTimeInterval(90_000)
        world.rows[sent.id]?.remindedAt = world.now.addingTimeInterval(-3_600)
        #expect(await jean.anywhere.remind(sent.id, at: world.now) == .failure(.tooSoon))
        #expect(jean.requests.request(id: sent.id)?.canRemind(at: world.now) == false)
    }

    @Test func twoSyncsAtOnceShareWhatTheyBring() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let sent = try await jean.ask(shima).get()
        async let first = shima.anywhere.sync()
        async let second = shima.anywhere.sync()
        let (one, two) = await (first, second)
        #expect(one.received.map(\.id) == [sent.id] && one == two)
        #expect(shima.requests.requests.count == 1)
    }

    @Test func aDeclineTravelsBackAndFreesThePair() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let sent = try await jean.ask(shima).get()
        await shima.anywhere.sync()
        shima.requests.decline(sent.id)
        await shima.anywhere.report()
        #expect(world.rows[sent.id]?.state == "answered")

        let news = await jean.anywhere.sync()
        #expect(news.declined.map(\.id) == [sent.id])
        #expect(jean.requests.request(id: sent.id)?.status == .declined)
        // Closed on the server once heard, its answer wiped.
        #expect(world.rows[sent.id]?.state == "closed" && world.rows[sent.id]?.answer == nil)
        #expect(try await jean.ask(shima).get().status == .waiting)
    }

    @Test func aCancelTravelsToThePersonAsked() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let sent = try await jean.ask(shima).get()
        await shima.anywhere.sync()
        jean.requests.cancel(sent.id)
        await jean.anywhere.report()
        #expect(world.rows[sent.id]?.state == "closed")
        await shima.anywhere.sync()
        #expect(shima.requests.request(id: sent.id)?.status == .cancelled)
        #expect(shima.requests.waitingForOwner.isEmpty)
    }

    @Test func oneThatWasPaidIsClosedSoThePairMayAskAgain() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        let sent = try await jean.ask(shima).get()
        #expect(await jean.ask(shima) == .failure(.alreadyAsked))
        let paying = Transaction(
            direction: .incoming, counterparty: Recipient(name: "Shima", destination: "456", kind: .phone), amount: 5_000,
            date: Self.start.addingTimeInterval(600), status: .confirmed, source: .sms
        )
        jean.requests.settle(with: [paying], at: Self.start.addingTimeInterval(700))
        #expect(jean.requests.request(id: sent.id)?.status == .paid)
        await jean.anywhere.sync()
        #expect(world.rows[sent.id]?.state == "closed")
        #expect(try await jean.ask(shima).get().status == .waiting)
    }

    // MARK: Asked nearby, carried by the server too

    @Test func nearbyFirstThenTheServerIsOneRequestWhoseDeclineStillTravels() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let ask = jean.askNearby(shima)
        let heard = try #require(shima.hear(ask))
        #expect(!heard.isAnywhere)
        let carried = try await jean.carry(ask, to: shima).get()
        // One request on the asker's iPhone, under the id it went nearby
        // with, now holding the other's key.
        #expect(jean.requests.requests.count == 1)
        #expect(carried.id == ask.id && carried.person.name == "Shima Serein" && carried.status == .waiting)
        #expect(carried.key == world.directory[shima.number]?.key)
        #expect(world.rows[ask.id]?.state == "waiting")

        // Jean walks away; Shima declines, and the connection is gone, so
        // only the server can carry it.
        shima.requests.decline(ask.id)
        await shima.anywhere.report()
        #expect(world.rows[ask.id]?.state == "waiting")
        // The sync shows nothing new: the server's copy is the one already
        // shown, whose key it keeps, and the decline goes with it.
        #expect(await shima.anywhere.sync().isEmpty)
        #expect(shima.requests.requests.count == 1)
        let kept = try #require(shima.requests.request(id: ask.id))
        #expect(kept.status == .declined && kept.key == world.directory[jean.number]?.key && kept.reported == true)
        #expect(world.rows[ask.id]?.state == "answered")

        let news = await jean.anywhere.sync()
        #expect(news.declined.map(\.id) == [ask.id] && news.received.isEmpty)
        #expect(jean.requests.request(id: ask.id)?.status == .declined)
        #expect(world.rows[ask.id]?.state == "closed")
        #expect(jean.requests.requests.count == 1 && shima.requests.requests.count == 1)
    }

    @Test func theServerFirstThenNearbyIsStillOneRequest() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let ask = jean.askNearby(shima)
        _ = try await jean.carry(ask, to: shima).get()
        // People Nearby's message was missed, or is late: the server's copy
        // comes first, as any request from anywhere.
        let news = await shima.anywhere.sync()
        #expect(news.received.map(\.id) == [ask.id])
        let received = try #require(shima.requests.request(id: ask.id))
        #expect(received.isAnywhere && received.amount == 5_000 && received.person.destination == jean.number)
        // The nearby message then arriving is not a second request, and
        // takes nothing from the first.
        #expect(shima.hear(ask) == nil)
        #expect(shima.requests.requests.count == 1 && shima.requests.waitingForOwner.map(\.id) == [ask.id])
        #expect(shima.requests.request(id: ask.id)?.key == received.key)
        #expect(await shima.anywhere.sync().isEmpty)

        // On the asker's iPhone too, the server's answer and the nearby one
        // under one id are one request, whichever is kept first.
        let other = MoneyRequests(fileURL: nil)
        let them = Recipient(name: "Shima Serein", destination: shima.number, kind: .phone)
        let id = UUID()
        other.ask(them, id: id, photoID: nil, amount: 2_000, note: nil, at: world.now, key: "theirs")
        let again = other.ask(them, id: id, photoID: nil, amount: 2_000, note: nil, at: world.now)
        #expect(other.requests.count == 1 && again.key == "theirs")
    }

    @Test func paidOnceSettlesOnceOnBothIPhones() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let ask = jean.askNearby(shima)
        shima.hear(ask)
        _ = try await jean.carry(ask, to: shima).get()
        await shima.anywhere.sync()
        let paid = Transaction(
            direction: .outgoing, counterparty: Recipient(name: "Jean Bosco", destination: jean.number, kind: .phone), amount: 5_000,
            date: Self.start.addingTimeInterval(60), status: .confirmed, source: .sms
        )
        let received = Transaction(
            direction: .incoming, counterparty: Recipient(name: "Shima", destination: "456", kind: .phone), amount: 5_000,
            date: Self.start.addingTimeInterval(60), status: .confirmed, source: .sms
        )
        shima.requests.settle(with: [paid], at: Self.start.addingTimeInterval(120))
        jean.requests.settle(with: [received], at: Self.start.addingTimeInterval(120))
        #expect(shima.requests.requests.map(\.status) == [.paid] && jean.requests.requests.map(\.status) == [.paid])
        // The asker's end closes the server's copy, so the pair may ask again.
        await jean.anywhere.sync()
        #expect(world.rows[ask.id]?.state == "closed")
        await shima.anywhere.sync()
        #expect(shima.requests.requests.map(\.status) == [.paid])
    }

    @Test func aCancelReachesThemAfterTheyWalkedAway() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let ask = jean.askNearby(shima)
        shima.hear(ask)
        _ = try await jean.carry(ask, to: shima).get()
        jean.requests.cancel(ask.id)
        await jean.anywhere.report()
        #expect(world.rows[ask.id]?.state == "closed")
        #expect(await shima.anywhere.sync().isEmpty)
        #expect(shima.requests.request(id: ask.id)?.status == .cancelled && shima.requests.waitingForOwner.isEmpty)
    }

    @Test func oneThatEndedNearbyBeforeTheServerTookItIsClosedThereAtOnce() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let ask = jean.askNearby(shima)
        shima.hear(ask)
        // Declined nearby while the server copy was on its way.
        shima.requests.decline(ask.id)
        jean.requests.theyDeclined(ask.id)
        let carried = try await jean.carry(ask, to: shima).get()
        #expect(carried.status == .declined && carried.isAnywhere)
        #expect(world.rows[ask.id]?.state == "closed")
        #expect(await shima.anywhere.sync().isEmpty)
        #expect(shima.requests.requests.map(\.status) == [.declined])
        #expect(try await jean.ask(shima).get().status == .waiting)
    }

    @Test func aServerCopyThatSaysOtherwiseIsDroppedAndTheNearbyOneStays() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let ask = jean.askNearby(shima)
        shima.hear(ask)
        var more = ask
        more.amount = 50_000
        _ = try await jean.carry(more, to: shima).get()
        #expect(await shima.anywhere.sync().isEmpty)
        let kept = try #require(shima.requests.request(id: ask.id))
        #expect(kept.amount == 5_000 && !kept.isAnywhere && kept.status == .waiting)
        #expect(world.rows[ask.id]?.state == "dropped")
    }

    @Test func theServerCopyKeepsTheContactsRule() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let ask = jean.askNearby(shima)
        shima.hear(ask)
        _ = try await jean.carry(ask, to: shima).get()
        // While Contacts cannot be read, its key waits with it.
        shima.contacts = nil
        #expect(await shima.anywhere.sync().isEmpty)
        #expect(shima.requests.request(id: ask.id)?.isAnywhere == false && world.rows[ask.id]?.state == "waiting")
        // Jean is no longer a contact: the server's copy is dropped.
        shima.contacts = []
        #expect(await shima.anywhere.sync().isEmpty)
        #expect(shima.requests.request(id: ask.id)?.isAnywhere == false && world.rows[ask.id]?.state == "dropped")
    }

    @Test func aRequestTheServerCannotCarryStaysBetweenPeopleNearby() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        let old = Phone("Old StarHash", "0788555555", in: world, takesRequests: false)
        let unlisted = Recipient(name: "Eric", destination: "0788000104", kind: .phone)
        let toEric = MoneyRequest.Message.Ask(id: UUID(), name: jean.name, number: jean.number, photoID: nil, amount: 1_000, note: nil)
        jean.requests.ask(unlisted, id: toEric.id, photoID: nil, amount: 1_000, note: nil, at: world.now)
        #expect(await jean.anywhere.carry(toEric, to: unlisted) == .failure(.notOnStarHash))
        #expect(await jean.carry(jean.askNearby(old), to: old) == .failure(.takesNoRequests))
        // One to Shima already waits on the server: the second stays nearby.
        _ = try await jean.carry(jean.askNearby(shima), to: shima).get()
        let second = jean.askNearby(shima, amount: 2_000)
        #expect(await jean.carry(second, to: shima) == .failure(.alreadyAsked))
        world.reachable = false
        #expect(await jean.carry(jean.askNearby(shima, amount: 3_000), to: shima) == .failure(.failed))
        #expect(jean.requests.requests.count == 5)
        #expect(jean.requests.requests.filter(\.isAnywhere).count == 1)
        #expect(jean.requests.requests.allSatisfy { $0.status == .waiting })
    }

    // MARK: Who may ask

    @Test func aRequestFromSomeoneNotInContactsIsDroppedWithoutAWord() async throws {
        let stranger = Phone("MTN Rwanda", "0788999999", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        let sent = try await stranger.ask(shima).get()
        #expect(await shima.anywhere.sync().isEmpty)
        #expect(shima.requests.requests.isEmpty)
        #expect(world.rows[sent.id]?.state == "dropped" && world.rows[sent.id]?.sealed == nil)
        // The asker hears nothing, and cannot ask again while it "waits".
        #expect(await stranger.anywhere.sync().isEmpty)
        #expect(stranger.requests.request(id: sent.id)?.status == .waiting)
        #expect(await stranger.ask(shima) == .failure(.alreadyAsked))
    }

    @Test func whileContactsCannotBeReadRequestsWaitUnread() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.contacts = nil
        let sent = try await jean.ask(shima).get()
        #expect(await shima.anywhere.sync().isEmpty)
        #expect(world.rows[sent.id]?.state == "waiting")
        shima.contacts = [jean.number]
        #expect(await shima.anywhere.sync().received.map(\.id) == [sent.id])
    }

    @Test func nobodyAsksInAnothersName() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let thief = Phone("Thief", "0788666666", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        // The thief seals Jean's name and number, and sends it from their
        // own, which the server lets through.
        let id = UUID()
        let forged = MoneyRequest.Message.ask(.init(id: id, name: "Jean Bosco", number: jean.number, photoID: nil, amount: 50_000, note: nil))
        let shimasKey = try #require(world.directory[shima.number]?.key)
        let sealed = try #require(RequestSeal.seal(forged.data, id: id, purpose: .ask, to: shimasKey, from: thief.key))
        #expect(await thief.server.send(id: id, to: shima.number, from: thief.number, sealed: sealed, key: thief.secret) == .sent)
        // Jean's number is listed under Jean's key, not the one that
        // sealed it: dropped.
        #expect(await shima.anywhere.sync().isEmpty)
        #expect(world.rows[id]?.state == "dropped")
        // Nor from a number they do not list.
        #expect(await thief.server.send(id: UUID(), to: shima.number, from: jean.number, sealed: sealed, key: thief.secret) == .notListed)
    }

    @Test func aRequestTheServerCannotVouchForWaitsUntilItCan() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let sent = try await jean.ask(shima).get()

        /// A server that hands over its inbox but cannot look anyone up.
        @MainActor
        final class Flaky: RequestsAnywhere.Server {
            let inner: FakeServer
            init(_ inner: FakeServer) { self.inner = inner }
            func lookUp(_ number: String) async -> RequestsAnywhere.LookUp { .failed }
            func send(id: UUID, to number: String, from own: String, sealed: String, key: String) async -> RequestsAnywhere.SendAnswer { .failed }
            func inbox(key: String) async -> RequestsAnywhere.Inbox? { await inner.inbox(key: key) }
            func answer(id: UUID, sealed: String, key: String) async -> Bool { false }
            func close(id: UUID, key: String) async -> Bool { await inner.close(id: id, key: key) }
            func erase(key: String) async -> Bool { false }
            func remind(id: UUID, key: String) async -> RequestsAnywhere.RemindAnswer { .failed }
        }
        let flaky = RequestsAnywhere(
            requests: shima.requests, server: Flaky(shima.server), key: { [secret = shima.secret] in secret },
            privateKey: { [key = shima.key] in key }, mayAsk: { _ in true }, defaults: shima.defaults
        )
        #expect(await flaky.sync().isEmpty)
        #expect(world.rows[sent.id]?.state == "waiting")
        #expect(await shima.anywhere.sync().received.count == 1)
    }

    // MARK: Failures

    @Test func whatDidNotReachTheServerGoesAgain() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let sent = try await jean.ask(shima).get()
        await shima.anywhere.sync()
        world.reachable = false
        shima.requests.decline(sent.id)
        await shima.anywhere.report()
        #expect(world.rows[sent.id]?.state == "waiting")
        #expect(shima.requests.request(id: sent.id)?.reported != true)
        world.reachable = true
        await shima.anywhere.sync()
        #expect(world.rows[sent.id]?.state == "answered")
        #expect(shima.requests.request(id: sent.id)?.reported == true)
    }

    @Test func aRequestNotSentIsNotKept() async {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        let old = Phone("Old StarHash", "0788555555", in: world, takesRequests: false)
        #expect(await jean.ask(old) == .failure(.takesNoRequests))
        world.reachable = false
        #expect(await jean.ask(shima) == .failure(.notOnStarHash))
        world.reachable = true
        world.directory[jean.number] = nil
        #expect(await jean.ask(shima) == .failure(.notListed))
        #expect(jean.requests.requests.isEmpty)
    }

    @Test func twentyADay() async throws {
        let busy = Phone("Busy", "0788300000", in: world)
        var people: [Phone] = []
        for index in 1...21 { people.append(Phone("P\(index)", "07883\(String(format: "%05d", index))", in: world)) }
        for person in people.prefix(20) { _ = try await busy.ask(person).get() }
        #expect(await busy.ask(people[20]) == .failure(.tooMany))
        #expect(busy.requests.requests.count == 20)
        world.now = Self.start.addingTimeInterval(86_401)
        #expect(try await busy.ask(people[20]).get().status == .waiting)
    }

    // MARK: Expiry

    @Test func aRequestExpiresAfterItsWeekAndIsClosedThere() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        shima.knows(jean)
        let sent = try await jean.ask(shima).get()
        await shima.anywhere.sync()
        let week = Self.start.addingTimeInterval(MoneyRequest.lifetime + 1)
        world.now = week
        jean.requests.settle(with: [], at: week)
        shima.requests.settle(with: [], at: week)
        #expect(jean.requests.request(id: sent.id)?.status == .expired)
        #expect(shima.requests.request(id: sent.id)?.status == .expired)
        await jean.anywhere.sync(at: week)
        #expect(world.rows[sent.id]?.state == "closed")
        // And once expired, the pair may ask again.
        #expect(try await jean.ask(shima).get().status == .waiting)
    }

    // MARK: Delete All Data

    @Test func deleteAllDataErasesWhatTheServerHolds() async throws {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        let shima = Phone("Shima Serein", "0788123456", in: world)
        let sent = try await jean.ask(shima).get()
        world.reachable = false
        jean.anywhere.erase { jean.requests.removeAll(); jean.defaults.removePersistentDomain(forName: jean.defaults.suiteName) }
        await jean.anywhere.settle()
        #expect(world.rows[sent.id]?.state == "waiting")
        world.reachable = true
        await jean.anywhere.sync()
        #expect(world.rows[sent.id]?.state == "closed")
        #expect(jean.server.erased == [jean.secret])
        await jean.anywhere.sync()
        #expect(jean.server.erased.count == 1)
    }

    @Test func deleteAllDataLeavesTheServerAloneWhenItNeverHeldAny() async {
        let jean = Phone("Jean Bosco", "0788000102", in: world)
        jean.anywhere.erase { jean.requests.removeAll() }
        await jean.anywhere.sync()
        #expect(jean.server.erased.isEmpty)
    }

    // MARK: Notifications

    @Test func aRequestReceivedOrDeclinedIsWorthAWord() throws {
        let asked = MoneyRequest(
            direction: .received, person: Recipient(name: "Jean", destination: "0788000102", kind: .phone), amount: 5_000,
            note: "Lunch", createdAt: Self.start
        )
        let item = try #require(NotificationPlan.requestReceived(asked, name: "Jean Bosco", settings: .init()))
        #expect(item.kind == .requestReceived && item.requestID == asked.id && item.transactionID == nil)
        #expect(item.body.contains("Jean Bosco") && item.body.contains("5,000") && item.body.contains("Lunch"))
        let hidden = try #require(NotificationPlan.requestReceived(asked, name: "Jean Bosco", settings: .init(showsAmounts: false)))
        #expect(!hidden.body.contains("5,000") && !hidden.body.contains("Lunch"))
        #expect(NotificationPlan.requestReceived(asked, name: "Jean", settings: .init(requests: false)) == nil)

        var declined = MoneyRequest(
            direction: .sent, person: Recipient(name: "Jean", destination: "0788000102", kind: .phone), amount: 5_000, createdAt: Self.start
        )
        #expect(NotificationPlan.requestDeclined(declined, name: "Jean", settings: .init()) == nil)
        declined.status = .declined
        #expect(NotificationPlan.requestDeclined(declined, name: "Jean", settings: .init())?.kind == .requestDeclined)
    }
}
