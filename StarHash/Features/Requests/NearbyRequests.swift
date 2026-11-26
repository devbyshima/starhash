import StarHashKit
import SwiftUI

/// Requests between people nearby: sending one over a tap's connection,
/// taking one in, and the answer. The requests themselves are
/// StarHashKit's `MoneyRequests`; this is how they travel.
///
/// Only people in the owner's Contacts can ask them. A request from anyone
/// else is dropped without an answer, so all its sender sees is that it
/// waits until it expires.
@MainActor
final class NearbyRequests {
    private let requests: MoneyRequests
    private let nearby: PeopleNearbyService
    /// The phone each request went to or came from in this run, for its
    /// answer. A request outlives the connection; its answer may not.
    private var peers: [UUID: String] = [:]

    init(requests: MoneyRequests, nearby: PeopleNearbyService) {
        self.requests = requests
        self.nearby = nearby
        nearby.onMessage = { [weak self] peer, data in
            Task { await self?.handle(data, from: peer) }
        }
    }

    /// Why the owner can't ask anyone yet, or nil when they can: a request
    /// carries their name and the number the money goes to.
    static func missing(in owner: Owner) -> String? {
        guard PeopleNearby.Announcement(name: owner.name, photoID: nil, number: owner.defaultSIM) != nil else {
            return String(starhash: "Add your name and number in Profile first")
        }
        return nil
    }

    /// Asks `person` for `amount`: their phone hands over its number, then
    /// gets the request. Nil when it didn't (they left, or locked).
    func ask(_ person: PeopleNearby.Person, amount: Int, note: String?, owner: Owner, photoID: UUID?) async -> MoneyRequest? {
        guard let number = owner.defaultSIM, Self.missing(in: owner) == nil else { return nil }
        let ask = MoneyRequest.Message.Ask(
            id: UUID(), name: owner.name.trimmingCharacters(in: .whitespacesAndNewlines), number: number.destination,
            photoID: photoID, amount: amount, note: note
        )
        guard let recipient = await nearby.reach(person, sending: MoneyRequest.Message.ask(ask).data) else { return nil }
        peers[ask.id] = person.id
        return requests.ask(recipient, id: ask.id, photoID: person.photoID, amount: amount, note: ask.note)
    }

    /// The owner declined: their phone says so, while the asker's
    /// connection is still open.
    func decline(_ request: MoneyRequest) {
        requests.decline(request.id)
        guard let peer = peers.removeValue(forKey: request.id) else { return }
        nearby.send(MoneyRequest.Message.declined(id: request.id).data, to: peer)
    }

    private func handle(_ data: Data, from peer: String) async {
        switch MoneyRequest.Message(data: data) {
        case .ask(let ask):
            let asker = Recipient(name: ask.name, destination: ask.number, kind: .phone)
            guard await Self.mayAsk(asker) else { return }
            if requests.receive(ask) != nil { peers[ask.id] = peer }
        case .declined(let id):
            requests.theyDeclined(id)
            peers[id] = nil
            nearby.close(peer)
        case nil:
            break
        }
    }

    /// Only someone in the owner's Contacts. With Contacts off or not
    /// allowed, StarHash can't tell, so nobody.
    private static func mayAsk(_ asker: Recipient) async -> Bool {
        #if DEBUG
        if DebugLaunch.arguments.contains("-requestsFromAnyone") { return true }
        #endif
        return await PayContacts.shared.knowsContact(asker) == true
    }
}

/// Requests settle from the transactions (`MoneyRequests.settle`): each
/// time they change, and each time StarHash comes to the front, when a
/// week may have passed.
struct RequestsSync: ViewModifier {
    @Environment(StarHashStore.self) private var store
    @Environment(MoneyRequests.self) private var requests
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            // Listening for requests from people nearby starts with the app.
            .onAppear { _ = AppEnvironment.nearbyRequests }
            .onChange(of: store.transactions, initial: true) { _, transactions in
                requests.settle(with: transactions)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                requests.reload()
                requests.settle(with: store.transactions)
            }
    }
}

#if DEBUG
/// `-requests` (with `-inMemory`): sample requests, one waiting for the
/// owner from Jean and the rest in each state, for the card and the page.
@MainActor
enum RequestsDebug {
    static func seeded() -> MoneyRequests {
        let requests = MoneyRequests(fileURL: nil)
        guard DebugLaunch.arguments.contains("-requests") else { return requests }
        let now = Date.now
        let ariane = Recipient(name: "Ariane Uwase", destination: "0788000101", kind: .phone)
        let grace = Recipient(name: "Grace Mutoni", destination: "0789000103", kind: .phone)
        let paid = requests.ask(grace, photoID: nil, amount: 12_000, note: "Concert tickets", at: now.addingTimeInterval(-3 * 86_400))
        requests.markPaid(paid.id, at: now.addingTimeInterval(-2 * 86_400))
        requests.ask(ariane, photoID: PeopleNearbyDebug.photoID, amount: 2_500, note: "Taxi", at: now.addingTimeInterval(-3_600))
        let declined = MoneyRequest.Message.Ask(id: UUID(), name: "Eric Nshuti", number: "0788000104", photoID: nil, amount: 3_000, note: nil)
        requests.receive(declined, at: now.addingTimeInterval(-86_400))
        requests.decline(declined.id)
        let jean = MoneyRequest.Message.Ask(id: UUID(), name: "Jean Bosco", number: "0722000102", photoID: nil, amount: 5_000, note: "Lunch")
        requests.receive(jean, at: now.addingTimeInterval(-300))
        return requests
    }
}
#endif
