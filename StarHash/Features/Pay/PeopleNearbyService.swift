import Foundation
@preconcurrency import MultipeerConnectivity
import Observation
import StarHashKit
import UIKit

/// People Nearby on this iPhone: who is close by, and the tap that asks
/// one of them for their number. It only runs while StarHash is in front
/// (`PeopleNearbySync`): iOS gives an app in the background no way to be
/// found that it could count on, and a phone in a pocket has no one to pay.
///
/// What phones say to each other is StarHashKit's `PeopleNearby`; this is
/// only the radio. Everything it hears comes to the main actor as values,
/// so the views read `found` like any other state.
@MainActor
@Observable
final class PeopleNearbyService {
    /// Who is nearby, newest first.
    private(set) var found = PeopleNearby.Found()
    /// The person a tap is asking for their number, until it comes or the
    /// tap gives up.
    private(set) var reaching: String?

    /// What the service should be doing, from the app's state.
    struct Setup: Equatable {
        /// Looking for people: StarHash in front, the feature on and its
        /// intro past (iOS asks for the local network the first time).
        var browses = false
        /// Being seen, under this name and photo. Nil keeps the owner out
        /// of sight.
        var announcement: PeopleNearby.Announcement?
        /// The number handed to a phone that taps the owner.
        var handoff: PeopleNearby.Handoff?
    }

    @ObservationIgnored private var setup = Setup()
    @ObservationIgnored private var transport: NearbyTransport?
    /// Each tap waiting for its number, under its own token, so a tap's
    /// timeout never ends a later tap on the same person.
    @ObservationIgnored private var waiting: [String: (token: UUID, continuation: CheckedContinuation<PeopleNearby.Handoff?, Never>)] = [:]

    /// What another phone sends over a tap's connection beyond the number
    /// (a request, an answer to one), with the phone it came from.
    @ObservationIgnored var onMessage: ((_ from: String, Data) -> Void)?

    func apply(_ next: Setup) {
        #if DEBUG
        if PeopleNearbyDebug.samples != nil {
            applySamples(next)
            return
        }
        #endif
        guard next != setup else { return }
        setup = next
        guard next.browses || next.announcement != nil else {
            transport?.stop()
            transport = nil
            forgetEveryone()
            return
        }
        let transport = transport ?? NearbyTransport { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        self.transport = transport
        transport.update(browses: next.browses, announcement: next.announcement, handoff: next.handoff)
        if !next.browses { forgetEveryone() }
    }

    /// Asks `person`'s phone for their number, and who to pay once it
    /// comes. Nil when it doesn't: they moved away, locked their phone or
    /// stopped being seen. With a `message` (a request), it goes to them
    /// once the number is in, and the connection stays open for their
    /// answer until `close`.
    func reach(_ person: PeopleNearby.Person, sending message: Data? = nil) async -> Recipient? {
        guard reaching == nil else { return nil }
        reaching = person.id
        defer { reaching = nil }
        #if DEBUG
        if PeopleNearbyDebug.samples != nil {
            let recipient = await PeopleNearbyDebug.reach(person)
            if recipient != nil, let message { PeopleNearbyDebug.answer(message, from: person.id) { self.onMessage?($0, $1) } }
            return recipient
        }
        #endif
        guard let transport else { return nil }
        let token = UUID()
        let handoff = await withCheckedContinuation { continuation in
            waiting[person.id] = (token, continuation)
            transport.reach(person.id, sending: message)
            Task {
                try? await Task.sleep(for: PeopleNearby.reachTimeout)
                if waiting[person.id]?.token == token { finish(person.id, with: nil) }
            }
        }
        return handoff.map(person.recipient)
    }

    /// Sends `data` to the phone `id` over the connection open between
    /// them: an answer to its request. False when there is none any more.
    @discardableResult
    func send(_ data: Data, to id: String) -> Bool {
        transport?.send(data, to: id) ?? false
    }

    /// Ends the connection a request kept open to `id`.
    func close(_ id: String) {
        transport?.close(id)
    }

    private func handle(_ event: NearbyTransport.Event) {
        switch event {
        case .found(let id, let announcement):
            guard setup.browses else { return }
            found.found(PeopleNearby.Person(id: id, announcement: announcement))
        case .lost(let id):
            found.lost(id: id)
        case .handoff(let id, let handoff):
            finish(id, with: handoff)
        case .unreachable(let id):
            finish(id, with: nil)
        case .message(let id, let data):
            onMessage?(id, data)
        }
    }

    private func finish(_ id: String, with handoff: PeopleNearby.Handoff?) {
        waiting.removeValue(forKey: id)?.continuation.resume(returning: handoff)
    }

    private func forgetEveryone() {
        found.removeAll()
        for id in Array(waiting.keys) { finish(id, with: nil) }
    }

    #if DEBUG
    /// `-peopleNearby`: sample people while it would browse, with no radio.
    private func applySamples(_ next: Setup) {
        setup = next
        found = next.browses ? PeopleNearbyDebug.found : PeopleNearby.Found()
    }
    #endif
}

/// The radio under `PeopleNearbyService`: MultipeerConnectivity's
/// advertiser (being seen), browser (seeing) and a session per tap.
///
/// Multipeer calls its delegates on queues of its own, so everything here
/// is behind one lock and reaches the service only as `Event` values.
/// Peers are known by the random name each phone takes for the run (its
/// `MCPeerID`'s), never by the owner's name, which may repeat.
private final class NearbyTransport: NSObject, @unchecked Sendable {
    enum Event: Sendable {
        case found(id: String, PeopleNearby.Announcement)
        case lost(id: String)
        /// The number `id`'s phone handed over.
        case handoff(id: String, PeopleNearby.Handoff)
        /// A tap on `id` that will get no number.
        case unreachable(id: String)
        /// Anything else `id`'s phone sent over an open connection.
        case message(id: String, Data)
    }

    private let me = MCPeerID(displayName: UUID().uuidString)
    private let onEvent: @Sendable (Event) -> Void

    private let lock = NSLock()
    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var announcement: PeopleNearby.Announcement?
    private var handoff: PeopleNearby.Handoff?
    /// Everyone found, by their run's name.
    private var peers: [String: MCPeerID] = [:]
    /// A tap's session, by the tapped phone's name, until its number comes.
    private var reaching: [String: MCSession] = [:]
    /// What a tap sends once the number is in (a request).
    private var outgoing: [String: Data] = [:]
    /// Sessions kept open after the number came, for an answer.
    private var talking: [String: (session: MCSession, peer: MCPeerID)] = [:]
    /// Sessions opened by phones that tapped the owner, until they leave.
    private var serving: [MCSession] = []
    /// The phones that tapped the owner, by their run's name, to answer.
    private var servingPeers: [String: (session: MCSession, peer: MCPeerID)] = [:]

    init(onEvent: @escaping @Sendable (Event) -> Void) {
        self.onEvent = onEvent
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func update(browses: Bool, announcement: PeopleNearby.Announcement?, handoff: PeopleNearby.Handoff?) {
        let (startBrowser, stopBrowser, startAdvertiser, stopAdvertiser) = locked {
            self.handoff = handoff
            var startBrowser: MCNearbyServiceBrowser?
            var stopBrowser: MCNearbyServiceBrowser?
            if browses, browser == nil {
                let made = MCNearbyServiceBrowser(peer: me, serviceType: PeopleNearby.serviceType)
                made.delegate = self
                browser = made
                startBrowser = made
            } else if !browses, let browser {
                stopBrowser = browser
                self.browser = nil
                peers.removeAll()
            }
            // A new name or photo is a new announcement: the old one stops.
            var startAdvertiser: MCNearbyServiceAdvertiser?
            var stopAdvertiser: MCNearbyServiceAdvertiser?
            if announcement != self.announcement {
                stopAdvertiser = advertiser
                advertiser = nil
                if let announcement {
                    let made = MCNearbyServiceAdvertiser(peer: me, discoveryInfo: announcement.discoveryInfo, serviceType: PeopleNearby.serviceType)
                    made.delegate = self
                    advertiser = made
                    startAdvertiser = made
                }
                self.announcement = announcement
            }
            return (startBrowser, stopBrowser, startAdvertiser, stopAdvertiser)
        }
        stopBrowser?.stopBrowsingForPeers()
        stopAdvertiser?.stopAdvertisingPeer()
        startBrowser?.startBrowsingForPeers()
        startAdvertiser?.startAdvertisingPeer()
    }

    func stop() {
        let (browser, advertiser, sessions) = locked {
            let taken = (self.browser, self.advertiser, Array(reaching.values) + serving + talking.values.map(\.session))
            self.browser = nil
            self.advertiser = nil
            announcement = nil
            peers.removeAll()
            reaching.removeAll()
            outgoing.removeAll()
            talking.removeAll()
            serving.removeAll()
            servingPeers.removeAll()
            return taken
        }
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        sessions.forEach { $0.disconnect() }
    }

    /// Asks the phone found as `id` for its number, over a session of its
    /// own, encrypted, and sends `message` once the number is in.
    func reach(_ id: String, sending message: Data?) {
        let (browser, peer, session) = locked { () -> (MCNearbyServiceBrowser?, MCPeerID?, MCSession?) in
            guard let browser, let peer = peers[id] else { return (nil, nil, nil) }
            reaching[id]?.disconnect()
            talking.removeValue(forKey: id)?.session.disconnect()
            outgoing[id] = message
            let session = MCSession(peer: me, securityIdentity: nil, encryptionPreference: .required)
            session.delegate = self
            reaching[id] = session
            return (browser, peer, session)
        }
        guard let browser, let peer, let session else {
            onEvent(.unreachable(id: id))
            return
        }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }

    /// Sends `data` to `id` over whichever session is open with it: one a
    /// request kept open, or one it opened by tapping the owner.
    func send(_ data: Data, to id: String) -> Bool {
        guard let open = locked({ talking[id] ?? servingPeers[id] }) else { return false }
        return (try? open.session.send(data, toPeers: [open.peer], with: .reliable)) != nil
    }

    func close(_ id: String) {
        locked { talking.removeValue(forKey: id) }?.session.disconnect()
    }
}

extension NearbyTransport: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let id = peerID.displayName
        guard id != me.displayName, let announcement = PeopleNearby.Announcement(discoveryInfo: info) else { return }
        locked { peers[id] = peerID }
        onEvent(.found(id: id, announcement))
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let id = peerID.displayName
        locked { _ = peers.removeValue(forKey: id) }
        onEvent(.lost(id: id))
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        // Most often the local network refused in Settings: nobody shows,
        // which is all there is to say.
    }
}

extension NearbyTransport: MCNearbyServiceAdvertiserDelegate {
    /// A phone tapped the owner. Being seen is the owner's yes, so the tap
    /// is let in; it gets the number and nothing else.
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let session = locked { () -> MCSession? in
            guard handoff != nil, announcement != nil else { return nil }
            let session = MCSession(peer: me, securityIdentity: nil, encryptionPreference: .required)
            session.delegate = self
            serving.append(session)
            return session
        }
        invitationHandler(session != nil, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {}
}

extension NearbyTransport: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let id = peerID.displayName
        switch state {
        case .connected:
            // The owner's side: hand the number over, once.
            let data = locked { () -> Data? in
                guard serving.contains(session) else { return nil }
                servingPeers[id] = (session, peerID)
                return handoff?.data
            }
            if let data { try? session.send(data, toPeers: [peerID], with: .reliable) }
        case .notConnected:
            let (wasReaching, wasServing) = locked { () -> (Bool, Bool) in
                let wasReaching = reaching[id] === session
                if wasReaching {
                    reaching[id] = nil
                    outgoing[id] = nil
                }
                if talking[id]?.session === session { talking[id] = nil }
                let wasServing = serving.contains(session)
                serving.removeAll { $0 === session }
                if servingPeers[id]?.session === session { servingPeers[id] = nil }
                return (wasReaching, wasServing)
            }
            if wasReaching { onEvent(.unreachable(id: id)) }
            if wasServing { session.disconnect() }
        case .connecting:
            break
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let id = peerID.displayName
        // A tap's first answer is the number; then its request goes, and the
        // session stays for the reply. Anything else is a message.
        let (isHandoff, message) = locked { () -> (Bool, Data?) in
            guard reaching[id] === session else { return (false, nil) }
            reaching[id] = nil
            let message = outgoing.removeValue(forKey: id)
            if message != nil { talking[id] = (session, peerID) }
            return (true, message)
        }
        guard isHandoff else {
            onEvent(.message(id: id, data))
            return
        }
        guard let handoff = PeopleNearby.Handoff(data: data) else {
            onEvent(.unreachable(id: id))
            session.disconnect()
            return
        }
        if let message {
            // The number came: the request follows on the same session.
            try? session.send(message, toPeers: [peerID], with: .reliable)
        } else {
            session.disconnect()
        }
        onEvent(.handoff(id: id, handoff))
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(
        _ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID,
        at localURL: URL?, withError error: (any Error)?
    ) {}
}

#if DEBUG
/// `-peopleNearby [n]`: n sample people nearby (3 by default), the first
/// with the developer note's photo, and no radio. A tap reaches them after
/// a moment; `-peopleNearbyUnreachable` makes every tap fail.
@MainActor
enum PeopleNearbyDebug {
    static let samples: Int? = {
        guard DebugLaunch.arguments.contains("-peopleNearby") else { return nil }
        return DebugLaunch.value(after: "-peopleNearby").flatMap(Int.init) ?? 3
    }()

    /// The photo id the first sample carries, drawn from the asset catalog.
    static let photoID = UUID(uuidString: "00000000-0000-4000-8000-00000000BEEF")!

    private static let people: [(String, String)] = [
        ("Ariane Uwase", "0788000101"), ("Jean Bosco", "0722000102"), ("Grace Mutoni", "0789000103"),
        ("Eric Nshuti", "0788000104"), ("Diane Ingabire", "0732000105"), ("Patrick Habimana", "0788000106"),
        ("Aline Umutoni", "0789000107"), ("Claude Mugisha", "0788000108"), ("Yvonne Keza", "0722000109"),
    ]

    static var found: PeopleNearby.Found {
        let count = min(samples ?? 0, people.count)
        // Found one after another, so the first is the newest.
        var found = PeopleNearby.Found()
        for (index, person) in people.prefix(count).enumerated().reversed() {
            found.found(PeopleNearby.Person(id: "sample-\(index)", announcement: .init(name: person.0, photoID: index == 0 ? photoID : nil)))
        }
        return found
    }

    static func reach(_ person: PeopleNearby.Person) async -> Recipient? {
        try? await Task.sleep(for: .milliseconds(700))
        guard !DebugLaunch.arguments.contains("-peopleNearbyUnreachable"),
              let index = person.id.split(separator: "-").last.flatMap({ Int($0) }),
              let handoff = PeopleNearby.Handoff(number: Recipient(input: people[index].1)) else { return nil }
        return person.recipient(handoff)
    }

    /// `-peopleNearbyDeclines`: a request to a sample is declined after two
    /// seconds, as its phone would answer.
    static func answer(_ message: Data, from id: String, deliver: @escaping @MainActor (String, Data) -> Void) {
        guard DebugLaunch.arguments.contains("-peopleNearbyDeclines"),
              case .ask(let ask) = MoneyRequest.Message(data: message) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            deliver(id, MoneyRequest.Message.declined(id: ask.id).data)
        }
    }

    static func photo(for id: UUID) -> UIImage? {
        id == photoID ? UIImage(named: "DeveloperPhoto") : nil
    }
}
#endif
