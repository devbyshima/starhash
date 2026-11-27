import Foundation

/// Requests to and from StarHash users anywhere, through StarHash's server:
/// asking someone listed under Show My Name, taking in what others asked,
/// and telling the server how each ended.
///
/// The server never reads one. What a request says (who asks, the number
/// the money goes to, how much, what for) is sealed on the asker's iPhone
/// to the other's public key (`RequestSeal`), and an answer back to the
/// asker's. The server checks the asker's number is one their key lists;
/// the iPhone asked checks it again against the seal, by looking that
/// number up: the key that sealed it must be the key the number is listed
/// under, so nobody asks in another's name.
///
/// Only someone in the owner's Contacts can ask them. A request from anyone
/// else is dropped from the server without an answer, so all its asker sees
/// is that it waits until it expires. While StarHash cannot read Contacts
/// it cannot tell, so requests wait on the server, unread, until it can.
///
/// A request asked of someone nearby goes this way too, under the id it
/// went nearby with (`carry`), so it is one request on both iPhones
/// whichever way reaches them first.
///
/// Requests still settle from the transactions alone
/// (`MoneyRequests.settle`); nothing here marks one paid.
@MainActor
public final class RequestsAnywhere {
    /// What the directory lists for a number.
    public struct Listed: Equatable, Sendable {
        public var name: String?
        public var photoID: UUID?
        /// The public key requests to it are sealed to; nil when its
        /// iPhone takes none (an older StarHash, or requests off).
        public var key: String?

        public init(name: String?, photoID: UUID?, key: String?) {
            self.name = name
            self.photoID = photoID
            self.key = key
        }
    }

    public enum LookUp: Equatable, Sendable {
        case listed(Listed)
        /// No one lists it, or two iPhones do.
        case notListed
        /// The server could not be reached: ask again later.
        case failed
    }

    /// What the server made of a request sent.
    public enum SendAnswer: Equatable, Sendable {
        case sent
        /// The number is not listed, or its iPhone takes no requests.
        case notOnStarHash
        /// One to this person is still waiting.
        case alreadyAsked
        /// Twenty sent in the last day.
        case tooMany
        /// The owner's own number is not listed with their key: Show My
        /// Name off, or their listing not sent yet.
        case notListed
        case failed
    }

    /// What waits on the server for the owner.
    public struct Inbox: Equatable, Sendable {
        /// A request to one of the owner's numbers.
        public struct Asked: Equatable, Sendable {
            public var id: UUID
            /// Nil once the asker closed it.
            public var sealed: String?
            /// The asker's public key.
            public var key: String?
            public var createdAt: Date?
            /// When the asker last reminded the owner of it, if they have.
            public var remindedAt: Date?

            public var isClosed: Bool { sealed == nil }

            public init(id: UUID, sealed: String?, key: String?, createdAt: Date?, remindedAt: Date? = nil) {
                self.id = id
                self.sealed = sealed
                self.key = key
                self.createdAt = createdAt
                self.remindedAt = remindedAt
            }
        }

        /// An answer to a request the owner sent, sealed to them.
        public struct Answer: Equatable, Sendable {
            public var id: UUID
            public var sealed: String

            public init(id: UUID, sealed: String) {
                self.id = id
                self.sealed = sealed
            }
        }

        public var asked: [Asked]
        public var answers: [Answer]

        public init(asked: [Asked], answers: [Answer]) {
            self.asked = asked
            self.answers = answers
        }
    }

    /// StarHash's server, as requests need it. `key` is the owner's secret
    /// key, the one their listing is under.
    @MainActor
    public protocol Server {
        func lookUp(_ number: String) async -> LookUp
        func send(id: UUID, to number: String, from own: String, sealed: String, key: String) async -> SendAnswer
        /// Nil when it could not be read.
        func inbox(key: String) async -> Inbox?
        /// Whether the answer is there, or nothing is left to answer.
        func answer(id: UUID, sealed: String, key: String) async -> Bool
        /// Closes one the owner sent, or drops one they were sent: whether
        /// the server has it so, or has it no longer.
        func close(id: UUID, key: String) async -> Bool
        /// Delete All Data: everything the owner sent closed, and everything
        /// waiting for them dropped.
        func erase(key: String) async -> Bool
        /// Reminds the person asked of one the owner sent.
        func remind(id: UUID, key: String) async -> RemindAnswer
    }

    /// What the server made of a reminder.
    public enum RemindAnswer: Equatable, Sendable {
        /// Kept, at this time.
        case reminded(Date)
        /// Asked, or reminded of, within the last day.
        case tooSoon
        /// Declined, closed or expired: nothing to remind of.
        case notWaiting
        case failed
    }

    /// Why a reminder did not go.
    public enum RemindFailure: Error, Equatable, Sendable {
        case tooSoon
        case notWaiting
        case failed
    }

    /// Why a request was not sent.
    public enum AskFailure: Error, Equatable, Sendable {
        case notOnStarHash
        /// Listed, but their iPhone takes no requests yet.
        case takesNoRequests
        case alreadyAsked
        case tooMany
        case notListed
        case failed
    }

    /// What a sync brought, for the owner to hear of.
    public struct News: Equatable, Sendable {
        public var received: [MoneyRequest] = []
        public var declined: [MoneyRequest] = []
        /// Requests the owner was asked before, reminded of since.
        public var reminded: [MoneyRequest] = []

        public init(received: [MoneyRequest] = [], declined: [MoneyRequest] = [], reminded: [MoneyRequest] = []) {
            self.received = received
            self.declined = declined
            self.reminded = reminded
        }

        public var isEmpty: Bool { received.isEmpty && declined.isEmpty && reminded.isEmpty }
    }

    /// The owner's secret key (the listing's), nil when it cannot be read.
    public typealias KeySource = @MainActor () async -> String?
    /// The private key requests to the owner are sealed to, made once.
    public typealias PrivateKeySource = @MainActor () async -> RequestSeal.PrivateKey?
    /// Whether `asker` may ask the owner: in their Contacts. Nil when
    /// StarHash cannot tell (Contacts off or not allowed).
    public typealias MayAsk = @MainActor (Recipient) async -> Bool?

    enum Key {
        /// Set once the server held a request of the owner's, so Delete All
        /// Data knows there may be some to erase.
        static let used = "requestsUsedServer"
        /// Delete All Data's erase, until the server confirms it.
        static let toErase = "requestsToErase"
    }

    private let requests: MoneyRequests
    private let server: any Server
    private let key: KeySource
    private let privateKey: PrivateKeySource
    private let mayAsk: MayAsk
    private let defaults: UserDefaults
    /// The sync on its way, so a second one waits for it rather than
    /// taking the same requests in twice.
    private var syncing: Task<News, Never>?
    /// Delete All Data's first try, so tests can wait for it.
    private var erasing: Task<Void, Never>?

    public init(
        requests: MoneyRequests, server: any Server, key: @escaping KeySource, privateKey: @escaping PrivateKeySource,
        mayAsk: @escaping MayAsk, defaults: UserDefaults = .standard
    ) {
        self.requests = requests
        self.server = server
        self.key = key
        self.privateKey = privateKey
        self.mayAsk = mayAsk
        self.defaults = defaults
    }

    // MARK: Asking

    /// Who lists `number`, and whether they take requests.
    public func lookUp(_ number: String) async -> LookUp {
        await server.lookUp(number)
    }

    /// Sends `ask` to `person`, whom the directory lists as `listed`, and
    /// keeps it among the owner's requests.
    public func ask(_ ask: MoneyRequest.Message.Ask, to person: Recipient, listed: Listed, at now: Date = .now) async
        -> Result<MoneyRequest, AskFailure> {
        guard let theirs = listed.key, RequestSeal.isPublicKey(theirs) else { return .failure(.takesNoRequests) }
        guard let secret = await key(), let own = await privateKey(),
              let sealed = RequestSeal.seal(MoneyRequest.Message.ask(ask).data, id: ask.id, purpose: .ask, to: theirs, from: own)
        else { return .failure(.failed) }
        switch await server.send(id: ask.id, to: person.destination, from: ask.number, sealed: sealed, key: secret) {
        case .sent:
            defaults.set(true, forKey: Key.used)
            let named = person.name == nil ? Recipient(name: listed.name, destination: person.destination, kind: .phone) : person
            let request = requests.ask(
                named, id: ask.id, photoID: listed.photoID, amount: ask.amount, note: ask.note, at: now, key: theirs
            )
            // One sent nearby may have ended while it went: the server
            // hears at once.
            if request.status != .waiting { await report() }
            return .success(requests.request(id: request.id) ?? request)
        case .notOnStarHash: return .failure(.notOnStarHash)
        case .alreadyAsked: return .failure(.alreadyAsked)
        case .tooMany: return .failure(.tooMany)
        case .notListed: return .failure(.notListed)
        case .failed: return .failure(.failed)
        }
    }

    /// A request just sent to someone nearby (`ask`, to `person`, whose
    /// phone handed over their number) goes through the server too, under
    /// the same id, when that number is listed with a key. So it still
    /// reaches them if People Nearby's message did not, and their decline
    /// or the owner's cancel still travels once one of them has walked
    /// away. When it cannot (not listed, the pair's limit, no server), it
    /// stays a request between people nearby, as before.
    @discardableResult
    public func carry(_ ask: MoneyRequest.Message.Ask, to person: Recipient, at now: Date = .now) async
        -> Result<MoneyRequest, AskFailure> {
        switch await server.lookUp(person.destination) {
        case .listed(let listed): await self.ask(ask, to: person, listed: listed, at: now)
        case .notListed: .failure(.notOnStarHash)
        case .failed: .failure(.failed)
        }
    }

    // MARK: Reminding

    /// Reminds the person asked of a request the owner sent, at most once a
    /// day (`MoneyRequest.canRemind`). Their iPhone says so the next time it
    /// hears from the server. The time is kept, so Remind waits its day.
    public func remind(_ id: UUID, at now: Date = .now) async -> Result<MoneyRequest, RemindFailure> {
        guard let request = requests.request(id: id), request.isRemindable else { return .failure(.notWaiting) }
        guard request.canRemind(at: now) else { return .failure(.tooSoon) }
        guard let secret = await key() else { return .failure(.failed) }
        switch await server.remind(id: id, key: secret) {
        case .reminded(let time):
            requests.reminded(id, at: time)
            return .success(requests.request(id: id) ?? request)
        case .tooSoon:
            // Reminded elsewhere, or the clocks differ: it waits its day.
            requests.reminded(id, at: now)
            return .failure(.tooSoon)
        case .notWaiting:
            return .failure(.notWaiting)
        case .failed:
            return .failure(.failed)
        }
    }

    // MARK: Keeping in step

    /// Takes in what waits on the server (requests from the owner's
    /// Contacts, the asker's closes, answers to the owner's own), then
    /// tells it how the owner's requests ended. A second call while one is
    /// on its way waits for it and gets the same news, so a refresh that
    /// meets StarHash coming to the front still has word to give.
    @discardableResult
    public func sync(at now: Date = .now) async -> News {
        if let syncing {
            return await syncing.value
        }
        let task = Task { [self] in
            var news = await fetch(at: now)
            await report()
            await eraseIfDue()
            news.received.sort { $0.createdAt < $1.createdAt }
            return news
        }
        syncing = task
        let news = await task.value
        syncing = nil
        return news
    }

    /// Tells the server how the owner's requests ended: a decline, sealed
    /// to the asker, and each one the owner sent that no longer waits,
    /// closed. Whatever does not reach it goes again on the next call.
    public func report() async {
        let due = requests.unreported
        guard !due.isEmpty, let secret = await key() else { return }
        for request in due {
            let told: Bool
            switch request.direction {
            case .received:
                guard let theirs = request.key, let own = await privateKey(),
                      let sealed = RequestSeal.seal(
                          MoneyRequest.Message.declined(id: request.id).data, id: request.id, purpose: .answer, to: theirs, from: own
                      ) else { continue }
                told = await server.answer(id: request.id, sealed: sealed, key: secret)
            case .sent:
                told = await server.close(id: request.id, key: secret)
            }
            if told { requests.markReported(request.id) }
        }
    }

    private func fetch(at now: Date) async -> News {
        var news = News()
        guard let secret = await key(), let own = await privateKey(), let inbox = await server.inbox(key: secret) else { return news }
        if !inbox.asked.isEmpty || !inbox.answers.isEmpty { defaults.set(true, forKey: Key.used) }
        for asked in inbox.asked {
            if asked.isClosed {
                requests.theyCancelled(asked.id, at: now)
                continue
            }
            if let kept = requests.request(id: asked.id) {
                await keyFor(kept, from: asked, with: own, secret: secret)
                // Reminded of since: said once, as a new request is.
                if let time = asked.remindedAt, let reminded = requests.remindedOf(kept.id, at: time) {
                    news.reminded.append(reminded)
                }
                continue
            }
            switch await take(asked, with: own) {
            case .taken(let ask, let theirs):
                if let request = requests.receive(ask, at: asked.createdAt ?? now, key: theirs) {
                    news.received.append(request)
                }
            case .drop:
                _ = await server.close(id: asked.id, key: secret)
            case .later:
                break
            }
        }
        for answer in inbox.answers {
            guard let request = requests.request(id: answer.id), request.direction == .sent, request.status == .waiting,
                  let theirs = request.key,
                  let data = RequestSeal.open(answer.sealed, id: answer.id, purpose: .answer, with: own, from: theirs),
                  case .declined(let id) = MoneyRequest.Message(data: data), id == answer.id else { continue }
            requests.theyDeclined(id, at: now)
            if let declined = requests.request(id: id) { news.declined.append(declined) }
        }
        return news
    }

    /// The server's copy of a request that came from someone nearby first
    /// (`carry` on the asker's iPhone): already shown, so not again, but
    /// its key kept, so the owner's decline can follow through the server
    /// once the asker has walked away. It passes the same checks as any
    /// (sealed by the key the asker's number is listed under, from the
    /// owner's Contacts) and must say what the nearby one said; otherwise
    /// it is dropped there, and the nearby one stays as it came.
    private func keyFor(_ kept: MoneyRequest, from asked: Inbox.Asked, with own: RequestSeal.PrivateKey, secret: String) async {
        guard kept.direction == .received, kept.key == nil else { return }
        switch await take(asked, with: own) {
        case .taken(let ask, let theirs) where ask.number == kept.person.destination && ask.amount == kept.amount:
            requests.carried(kept.id, key: theirs)
        case .taken, .drop:
            _ = await server.close(id: asked.id, key: secret)
        case .later:
            break
        }
    }

    private enum Taking {
        case taken(MoneyRequest.Message.Ask, key: String)
        /// Not for the owner to see, ever: from someone not in their
        /// Contacts, from a number its sealer does not list, or sealed
        /// for some other key.
        case drop
        /// Not now: the server or Contacts could not tell.
        case later
    }

    /// Whether a request waiting on the server is one the owner should see.
    private func take(_ asked: Inbox.Asked, with own: RequestSeal.PrivateKey) async -> Taking {
        guard let sealed = asked.sealed, let theirs = asked.key,
              let data = RequestSeal.open(sealed, id: asked.id, purpose: .ask, with: own, from: theirs),
              case .ask(let ask) = MoneyRequest.Message(data: data), ask.id == asked.id else { return .drop }
        // The number the money would go to must be listed under the key
        // that sealed the request.
        switch await server.lookUp(ask.number) {
        case .listed(let listed) where listed.key == theirs: break
        case .failed: return .later
        case .listed, .notListed: return .drop
        }
        switch await mayAsk(Recipient(name: ask.name, destination: ask.number, kind: .phone)) {
        case true?: return .taken(ask, key: theirs)
        case false?: return .drop
        case nil: return .later
        }
    }

    // MARK: Delete All Data

    /// Delete All Data: `wipe` erases the requests and the settings, and
    /// the server closes everything the owner sent and drops everything
    /// waiting for them, now or on a later sync until it confirms.
    public func erase(through wipe: () -> Void) {
        let used = defaults.bool(forKey: Key.used) || defaults.bool(forKey: Key.toErase)
        wipe()
        guard used else { return }
        defaults.set(true, forKey: Key.toErase)
        erasing = Task { await eraseIfDue() }
    }

    private func eraseIfDue() async {
        guard defaults.bool(forKey: Key.toErase), let secret = await key() else { return }
        if await server.erase(key: secret) { defaults.removeObject(forKey: Key.toErase) }
    }

    /// Waits for a sync, or Delete All Data's erase, on its way. For tests.
    func settle() async {
        _ = await syncing?.value
        await erasing?.value
    }
}
