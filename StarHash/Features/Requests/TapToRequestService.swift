import Foundation
@preconcurrency import NearbyInteraction
import Observation
import StarHashKit
import UIKit

/// Tap to Request on this iPhone (`TapToRequest` in StarHashKit): holding
/// out a request for someone to tap (`hold`), and being tapped by one held
/// out. Both travel over People Nearby's radio (`PeopleNearbyService`'s tap
/// connections); how far apart the two iPhones are comes from Nearby
/// Interaction over ultra wideband, which iPhone 11 and later have, but not
/// the SE or the 16e (`isSupported`).
///
/// The owner holding out a request offers it to everyone nearby. Each phone
/// with StarHash open that finds it connects, a few at a time, the two trade
/// tokens and measure. The phone asked says when it measures them touching,
/// and the first to say so gets the request; it takes the request only if
/// it measured the touch itself, and then from anyone, not only Contacts.
/// Pay stays the owner's to tap, and their number goes to the asker only
/// then (`NearbyRequests.willPay`).
///
/// It runs only while StarHash is in front, as People Nearby does.
@MainActor
@Observable
final class TapToRequestService {
    /// Where a request the owner holds out stands.
    enum Hold: Equatable {
        /// Waiting for someone to hold their iPhone to this one.
        case waiting
        /// It went to the iPhone held to this one.
        case sent(UUID)
        /// They tapped Pay, under their name when they have one.
        case paying(UUID, name: String?)
        /// They declined.
        case declined
        /// Nearby Interaction is off for StarHash in Settings: no distance,
        /// so no tap.
        case notAllowed
    }

    /// The request the owner holds out, while they do (`HoldNearSheet`).
    private(set) var hold: Hold?
    /// What it asks for.
    private(set) var holdAsk: MoneyRequest.Message.Ask?
    /// The sheet holding it out, so one closing as another opens never
    /// ends the new one's.
    @ObservationIgnored private var holder: UUID?

    /// Whether People Nearby offers the owner to be tapped: only until
    /// someone does.
    var offersTap: Bool { hold == .waiting }

    /// How close the nearest iPhone is while the request waits, 0 (apart)
    /// to 1 (touching), nil with none measured: what the Hold Near screen
    /// shows as they come together (`TapToRequest.progress`).
    private(set) var holdProgress: Double?

    /// Whether this iPhone can measure how far another is.
    static let isSupported: Bool = {
        #if DEBUG
        if TapToRequestDebug.pretendsSupported { return true }
        #endif
        return NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }()

    @ObservationIgnored private let nearby: PeopleNearbyService
    @ObservationIgnored private let requests: MoneyRequests
    @ObservationIgnored private let nearbyRequests: NearbyRequests
    /// Each phone a tap connection is open with, measuring.
    @ObservationIgnored private var links: [String: TapLink] = [:]
    /// Phones asked to open one, until it opens or doesn't.
    @ObservationIgnored private var connecting: Set<String> = []
    /// Phones holding out a request that wait for a free place, first found
    /// first.
    @ObservationIgnored private var offers: [String] = []
    /// The phone the owner's request went to, kept for its answer.
    @ObservationIgnored private var holdPeer: String?
    /// Requests the owner held out in this run, for an answer that comes
    /// after the sheet closed.
    @ObservationIgnored private var heldOut: [UUID: MoneyRequest.Message.Ask] = [:]
    /// False once Nearby Interaction was refused, until StarHash leaves the
    /// front (Settings may change meanwhile).
    @ObservationIgnored private var isAllowed = true
    /// No new taps until then, once one brought a request: the owner is
    /// answering it.
    @ObservationIgnored private var quietUntil = Date.distantPast
    /// The last distance each link measured, for `holdProgress`.
    @ObservationIgnored private var distances: [String: Float] = [:]
    /// The phone of the person the owner chose to pay by touch, while
    /// Bring Phones Together measures the distance to it.
    @ObservationIgnored private var rangeTarget: String?

    init(nearby: PeopleNearbyService, requests: MoneyRequests, nearbyRequests: NearbyRequests) {
        self.nearby = nearby
        self.requests = requests
        self.nearbyRequests = nearbyRequests
        nearby.onTap = { [weak self] event in self?.handle(event) }
        // Bring Phones Together (touch to pay) measures through this too,
        // unless -holdNear (DEBUG) simulates its distance.
        #if DEBUG
        let simulated = DebugLaunch.arguments.contains("-holdNear")
        #else
        let simulated = false
        #endif
        if !simulated {
            let holdNear = HoldNear.shared
            holdNear.isAvailable = Self.isSupported && FeatureFlags.tapToRequest
            holdNear.start = { [weak self] person in self?.startRanging(person) }
            holdNear.stop = { [weak self] in self?.stopRanging() }
        }
    }

    // MARK: Touch to pay

    /// Bring Phones Together, for `person`, chosen to pay: measures the
    /// distance to their phone (which lets this one in, as they let people
    /// see them) into `HoldNear.progress`. The sheet dials at 1, which only
    /// a touch the `Detector` counts reaches; the sheet plays the haptic.
    func startRanging(_ person: PeopleNearby.Person) {
        stopRanging()
        rangeTarget = person.id
        HoldNear.shared.progress = 0
        guard isAllowed else { return }
        if links[person.id] == nil, !connecting.contains(person.id) {
            connecting.insert(person.id)
            nearby.connectTap(person.id, ranging: true)
        }
    }

    func stopRanging() {
        guard let id = rangeTarget else { return }
        rangeTarget = nil
        if (links[id]?.isRanging == true && !locating.contains(id)) || connecting.contains(id) { end(id) }
        HoldNear.shared.progress = nil
    }

    // MARK: Where people are

    /// Where each person on People Nearby's radar is, by their phone's id,
    /// while it is open: how far and which way, steadied.
    private(set) var locations: [String: RadarPlacement.Smoothed] = [:]
    /// The phones the radar measures.
    @ObservationIgnored private var locating: Set<String> = []

    /// The radar opened, or who is on it changed: measures the distance and
    /// direction to each of `people` (whose phones let this one in, as they
    /// let people see them), a few at a time, and stops for anyone gone.
    func locate(_ people: [PeopleNearby.Person]) {
        #if DEBUG
        if TapToRequestDebug.placesPeople { return debugLocate(people) }
        #endif
        guard Self.isSupported, FeatureFlags.tapToRequest, isAllowed else { return }
        let wanted = Set(people.prefix(TapToRequest.maximumPeers + 2).map(\.id))
        for id in locating.subtracting(wanted) { stopLocating(id) }
        for id in wanted.subtracting(locating) {
            locating.insert(id)
            if let link = links[id] {
                link.locates = true
            } else if !connecting.contains(id) {
                connecting.insert(id)
                nearby.connectTap(id, ranging: true)
            }
        }
    }

    /// The radar closed: nobody is measured for it any more.
    func stopLocating() {
        #if DEBUG
        debugPlacing?.cancel()
        #endif
        for id in locating { stopLocating(id) }
        locations.removeAll()
    }

    #if DEBUG
    @ObservationIgnored private var debugPlacing: Task<Void, Never>?

    /// `-radarLocations`: everyone placed at a sample distance, their
    /// bearings swaying slowly as if the iPhone turned, so each comes to
    /// the top and is pointed at in turn. No radio.
    private func debugLocate(_ people: [PeopleNearby.Person]) {
        debugPlacing?.cancel()
        let distances: [Float] = [0.8, 2.6, 5.5, 1.6, 8, 3.8, 0.5, 6.5, 4.4]
        let bearings: [Float] = [-0.5, 0.9, 2.4, -1.9, 1.6, -2.8, 0.2, 3.0, -1.2]
        debugPlacing = Task { @MainActor [weak self] in
            let start = Date.now
            while !Task.isCancelled {
                let time = Float(Date.now.timeIntervalSince(start))
                for (index, person) in people.enumerated() {
                    var placement = self?.locations[person.id] ?? RadarPlacement.Smoothed()
                    let bearing = bearings[index % bearings.count] + 0.7 * sin(time * 0.35)
                    placement.add(distance: distances[index % distances.count], bearing: bearing)
                    self?.locations[person.id] = placement
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
    #endif

    private func stopLocating(_ id: String) {
        locating.remove(id)
        locations[id] = nil
        guard id != rangeTarget else { return }
        if links[id]?.isRanging == true || connecting.contains(id) { end(id) }
    }

    // MARK: Holding out a request

    /// Holds out `ask` for the next iPhone held to this one, for the sheet
    /// `holder`. Whatever this iPhone was measuring as one asked stops.
    func startHolding(_ ask: MoneyRequest.Message.Ask, for holder: UUID) {
        self.holder = holder
        for id in Array(links.keys) { end(id) }
        offers.removeAll()
        connecting.removeAll()
        holdAsk = ask
        heldOut[ask.id] = ask
        holdPeer = nil
        isAllowed = true
        #if DEBUG
        if let state = TapToRequestDebug.state {
            hold = TapToRequestDebug.hold(state, for: ask, in: requests)
            return
        }
        #endif
        hold = .waiting
    }

    /// The same amount and note again, for someone else: after a decline,
    /// or once Nearby Interaction is back on.
    func holdAgain() {
        guard let ask = holdAsk, let holder else { return }
        startHolding(.init(id: UUID(), name: ask.name, number: ask.number, photoID: ask.photoID, amount: ask.amount, note: ask.note), for: holder)
    }

    /// The sheet `holder` closed. The phone the request went to keeps its
    /// connection, so a Pay or Decline still reaches the owner.
    func stopHolding(for holder: UUID) {
        guard holder == self.holder else { return }
        self.holder = nil
        for id in Array(links.keys) where id != holdPeer { end(id) }
        if let holdPeer { links[holdPeer]?.stopMeasuring() }
        hold = nil
        holdAsk = nil
        holdPeer = nil
        updateProgress()
    }

    // MARK: What the radio says

    private func handle(_ event: PeopleNearbyService.TapEvent) {
        switch event {
        case .offered(let id):
            guard links[id] == nil, !connecting.contains(id), !offers.contains(id) else { return }
            offers.append(id)
            connectNext()
        case .withdrawn(let id):
            offers.removeAll { $0 == id }
            // A connection a request came over stays for its answer.
            if hold == nil, let link = links[id], link.requestID == nil { end(id) }
        case .connected(let id, let ranging):
            connecting.remove(id)
            let link = links[id] ?? makeLink(id)
            link.isRanging = ranging
            link.locates = locating.contains(id)
            guard let token = link.token else { return end(id) }
            nearby.sendTap(TapToRequest.Message.token(token).data, to: id)
        case .ended(let id):
            connecting.remove(id)
            // The person chosen walked off, or locked: apart again.
            if id == rangeTarget { HoldNear.shared.progress = nil }
            locations[id] = nil
            locating.remove(id)
            distances[id] = nil
            updateProgress()
            links.removeValue(forKey: id)?.stopMeasuring()
            connectNext()
        case .message(let id, let data):
            receive(data, from: id)
        case .stopped:
            for link in links.values { link.stopMeasuring() }
            links.removeAll()
            if rangeTarget != nil { HoldNear.shared.progress = nil }
            locating.removeAll()
            locations.removeAll()
            distances.removeAll()
            updateProgress()
            connecting.removeAll()
            offers.removeAll()
            isAllowed = true
        }
    }

    /// Whether this iPhone may be tapped for a request now: the feature on,
    /// an iPhone that measures, not holding one out itself, Nearby
    /// Interaction allowed, and not just tapped.
    private var mayBeAsked: Bool {
        FeatureFlags.tapToRequest && Self.isSupported && hold == nil && isAllowed && Date.now >= quietUntil
    }

    /// Connects to the next phones holding out a request, while there is
    /// room.
    private func connectNext() {
        guard mayBeAsked, rangeTarget == nil else { return }
        while links.count + connecting.count < TapToRequest.maximumPeers, !offers.isEmpty {
            let id = offers.removeFirst()
            connecting.insert(id)
            nearby.connectTap(id)
        }
    }

    private func makeLink(_ id: String) -> TapLink {
        let link = TapLink()
        link.onTouch = { [weak self] in self?.touched(id) }
        link.onDistance = { [weak self] distance in self?.measured(distance, by: id) }
        link.onDirection = { [weak self] distance, bearing in self?.placed(distance: distance, bearing: bearing, of: id) }
        link.locates = locating.contains(id)
        link.onInvalidated = { [weak self] notAllowed in self?.invalidated(id, notAllowed: notAllowed) }
        links[id] = link
        return link
    }

    private func receive(_ data: Data, from id: String) {
        switch TapToRequest.Message(data: data) {
        case .token(let token):
            links[id]?.measure(with: token)
            return
        case .touched:
            theyTouched(id)
            return
        case nil:
            break
        }
        switch MoneyRequest.Message(data: data) {
        case .ask(let ask): asked(ask, by: id)
        case .declined(let requestID): theyDeclined(requestID, from: id)
        case .paying(let payer): theyArePaying(payer)
        case nil: break
        }
    }

    /// A link measured: the Hold Near screen follows the nearest phone
    /// while the request waits; Bring Phones Together, the phone chosen.
    /// A link the radar locates measured: the face moves there.
    private func placed(distance: Float?, bearing: Float?, of id: String) {
        guard locating.contains(id) else { return }
        var placement = locations[id] ?? RadarPlacement.Smoothed()
        placement.add(distance: distance, bearing: bearing)
        locations[id] = placement
    }

    private func measured(_ distance: Float?, by id: String) {
        if id == rangeTarget {
            // Held at 1 once touched, until the sheet dials and goes.
            if HoldNear.shared.progress != 1 {
                HoldNear.shared.progress = TapToRequest.approach(distance: distance, touched: false) ?? 0
            }
            return
        }
        guard links[id]?.isRanging != true else { return }
        distances[id] = distance
        updateProgress()
    }

    private func updateProgress() {
        let nearest = hold == .waiting ? distances.values.min() : nil
        let progress = TapToRequest.progress(distance: nearest)
        if progress != holdProgress { holdProgress = progress }
    }

    // MARK: The one asked

    /// This iPhone measured itself touching `id`'s, which holds out a
    /// request: it says so, and the request should follow.
    private func touched(_ id: String) {
        // Touch to pay: the sheet dials. Measuring for someone who chose to
        // pay the owner: their phone does.
        if id == rangeTarget {
            HoldNear.shared.progress = TapToRequest.approach(distance: nil, touched: true)
            return
        }
        guard hold == nil, let link = links[id], !link.isRanging, link.requestID == nil else { return }
        nearby.sendTap(TapToRequest.Message.touched.data, to: id)
    }

    /// The request came. Taken only when this iPhone measured the touch
    /// itself, just now: then from anyone, since they held their iPhones
    /// together, and Pay opens on it.
    private func asked(_ ask: MoneyRequest.Message.Ask, by id: String) {
        guard hold == nil, let link = links[id], link.requestID == nil, link.detector.touchedRecently(at: .now),
              let request = nearbyRequests.receiveTapped(ask, from: id) else { return }
        link.requestID = request.id
        link.stopMeasuring()
        quietUntil = .now.addingTimeInterval(6)
        for other in Array(links.keys) where other != id { end(other) }
        offers.removeAll()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AppEnvironment.router.openRequest(request.id)
    }

    // MARK: The one asking

    /// The phone `id` measured itself touching this one: the request goes
    /// to it, and to no one else.
    private func theyTouched(_ id: String) {
        guard hold == .waiting, let ask = holdAsk,
              nearby.sendTap(MoneyRequest.Message.ask(ask).data, to: id) else { return }
        holdPeer = id
        hold = .sent(ask.id)
        updateProgress()
        for other in Array(links.keys) where other != id { end(other) }
        links[id]?.stopMeasuring()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// They tapped Pay: the request is kept now, under who pays, and
    /// settles from the SMS as any other the owner sent.
    private func theyArePaying(_ payer: MoneyRequest.Message.Payer) {
        guard let ask = heldOut[payer.id] else { return }
        if requests.request(id: ask.id) == nil {
            requests.ask(payer.person, id: ask.id, photoID: nil, amount: ask.amount, note: ask.note)
        }
        if holdAsk?.id == ask.id { hold = .paying(ask.id, name: payer.name) }
    }

    private func theyDeclined(_ requestID: UUID, from id: String) {
        guard heldOut[requestID] != nil else { return }
        requests.theyDeclined(requestID)
        if holdAsk?.id == requestID { hold = .declined }
        end(id)
    }

    // MARK: Ending

    private func invalidated(_ id: String, notAllowed: Bool) {
        if notAllowed {
            isAllowed = false
            // Touch to pay can't measure either: Pay dials as it always has.
            HoldNear.shared.isAvailable = false
            if hold == .waiting { hold = .notAllowed }
            for other in Array(links.keys) where links[other]?.requestID == nil && other != holdPeer { end(other) }
            offers.removeAll()
        } else if links[id]?.requestID == nil, id != holdPeer {
            end(id)
        }
    }

    private func end(_ id: String) {
        distances[id] = nil
        updateProgress()
        links.removeValue(forKey: id)?.stopMeasuring()
        connecting.remove(id)
        nearby.endTap(id)
    }
}

/// One tap connection's measuring: a Nearby Interaction session run with
/// the other phone's token, and the touch it makes (`TapToRequest.Detector`).
/// Its delegate calls come on the main queue.
@MainActor
private final class TapLink: NSObject {
    private let session = NISession()
    private var peerToken: NIDiscoveryToken?
    private(set) var detector = TapToRequest.Detector()
    private var isStopped = false
    /// A request that came over this link: it stays for the answer.
    var requestID: UUID?
    /// Touch to pay's: measuring for a payment, not a request.
    var isRanging = false
    var onTouch: () -> Void = {}
    /// Each distance measured, in metres, or nil when there is none.
    var onDistance: (Float?) -> Void = { _ in }
    /// Each distance with the direction, in radians from straight ahead,
    /// when there is one (`RadarPlacement.bearing`), for the radar.
    var onDirection: (Float?, Float?) -> Void = { _, _ in }
    /// Measured for People Nearby's radar: the direction is passed on too.
    /// Ultra wideband alone, never the camera (the owner's ask), so only
    /// iPhones that give a direction without it (11 to 13) do.
    var locates = false
    /// Nearby Interaction gave up; true when the owner refused it.
    var onInvalidated: (_ notAllowed: Bool) -> Void = { _ in }

    override init() {
        super.init()
        session.delegateQueue = .main
        session.delegate = self
    }

    /// This iPhone's token, archived, for the other phone.
    var token: Data? {
        session.discoveryToken.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
    }

    /// Measures against the other phone's token. iOS asks the owner the
    /// first time.
    func measure(with data: Data) {
        guard !isStopped, let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else { return }
        peerToken = token
        session.run(NINearbyPeerConfiguration(peerToken: token))
    }

    func stopMeasuring() {
        guard !isStopped else { return }
        isStopped = true
        session.invalidate()
    }

    private func runAgain() {
        guard !isStopped, let peerToken else { return }
        session.run(NINearbyPeerConfiguration(peerToken: peerToken))
    }
}

extension TapLink: @preconcurrency NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard !isStopped, let object = nearbyObjects.first(where: { $0.discoveryToken == peerToken }) else { return }
        onDistance(object.distance)
        if locates {
            onDirection(object.distance, RadarPlacement.bearing(direction: object.direction))
        }
        if detector.measure(object.distance, at: .now) { onTouch() }
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        _ = detector.measure(nil, at: .now)
        // Lost for a while, still connected: measure again.
        if reason == .timeout { runAgain() }
    }

    func sessionSuspensionEnded(_ session: NISession) {
        runAgain()
    }

    func session(_ session: NISession, didInvalidateWith error: any Error) {
        guard !isStopped else { return }
        isStopped = true
        onInvalidated((error as? NIError)?.code == .userDidNotAllow)
    }
}

#if DEBUG
/// `-tapSupported`: Request offers Hold Near on an iPhone (or Simulator)
/// that cannot measure. `-tapRequest [state]`, with `-payAmount`: Hold Near's
/// sheet over Pay at launch, in that state, with no radio: waiting (the
/// default), sent, paying, paid, declined or notAllowed; or landing, paying
/// and then paid three seconds on, to watch the Paid moment.
@MainActor
enum TapToRequestDebug {
    static var pretendsSupported: Bool {
        DebugLaunch.arguments.contains("-tapSupported") || DebugLaunch.arguments.contains("-tapRequest")
    }

    static var opensHoldNear: Bool { DebugLaunch.arguments.contains("-tapRequest") }

    /// `-radarLocations`: People Nearby's radar places everyone at sample
    /// distances and bearings, with no radio.
    static var placesPeople: Bool { DebugLaunch.arguments.contains("-radarLocations") }

    static var state: String? {
        guard opensHoldNear else { return nil }
        return DebugLaunch.value(after: "-tapRequest") ?? "waiting"
    }

    static func hold(_ state: String, for ask: MoneyRequest.Message.Ask, in requests: MoneyRequests) -> TapToRequestService.Hold {
        let payer = MoneyRequest.Message.Payer(id: ask.id, name: "Ariane Uwase", number: "0788000101")
        switch state {
        case "sent":
            return .sent(ask.id)
        case "paying", "paid", "landing":
            if requests.request(id: ask.id) == nil {
                requests.ask(payer.person, id: ask.id, photoID: nil, amount: ask.amount, note: ask.note)
            }
            if state == "paid" { requests.markPaid(ask.id) }
            if state == "landing" {
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    requests.markPaid(ask.id)
                }
            }
            return .paying(ask.id, name: payer.name)
        case "declined":
            return .declined
        case "notAllowed":
            return .notAllowed
        default:
            return .waiting
        }
    }
}
#endif
