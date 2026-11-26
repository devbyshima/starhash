import Foundation

/// Tap to Request: asking for money by holding one iPhone to another, as a
/// card reader takes a tap. The phone asking shows the amount and offers
/// itself to People Nearby's browsers (`Offer`). A phone with StarHash open
/// that finds it connects, the two trade Nearby Interaction tokens
/// (`Message.token`) and measure how far apart they are, and when the phone
/// asked measures them touching (`Detector`) it says so (`Message.touched`)
/// and the request comes over the same connection.
///
/// The phone asked takes the request only on its own measurement, so one
/// from someone not in its owner's Contacts shows only when the two iPhones
/// were held together. It never dials: the owner still taps Pay, and only
/// then does their number go to the asker (`MoneyRequest.Message.paying`),
/// so the asker's request can settle from their SMS.
///
/// The radio is the app's (`TapToRequestService`); what the phones say and
/// when a tap counts are here, so they can be tested.
public enum TapToRequest {
    /// Two phones closer than this, in metres, are touching: held together
    /// on purpose, not standing side by side at a counter.
    public static let touchDistance: Float = 0.15

    /// Once touching, they have parted when further apart than this, and a
    /// tap may count again.
    public static let releaseDistance: Float = 0.40

    /// Measurements in a row within `touchDistance` that make a touch, so
    /// one stray reading never does.
    public static let samplesToTouch = 2

    /// Measurements further apart in time than this are not in a row:
    /// Nearby Interaction lost the other phone in between.
    public static let sampleGap: TimeInterval = 1

    /// How long after a touch a request that comes over its connection is
    /// still taken: the asker's answer to `touched` is on its way.
    public static let touchMemory: TimeInterval = 5

    /// The most phones offering to be tapped that one connects to at once,
    /// and the most phones one offering takes in: a market can hold dozens.
    public static let maximumPeers = 4

    /// How far apart two phones are when the asker's screen starts to show
    /// them coming together (`progress`), in metres.
    public static let approachDistance: Float = 1.0

    /// How close two phones are, for the asker's screen: 0 at
    /// `approachDistance` or further, 1 at `touchDistance` or closer, nil
    /// with no measurement.
    public static func progress(distance: Float?) -> Double? {
        guard let distance, distance >= 0 else { return nil }
        let span = approachDistance - touchDistance
        return Double(min(max((approachDistance - distance) / span, 0), 1))
    }

    /// How near touch to pay draws the phones before they touch: just
    /// short of together, so the sheet dials only on a touch the `Detector`
    /// counts, never on one close reading.
    public static let untouchedCeiling = 0.97

    /// Touch to pay's progress (Bring Phones Together): `progress`, held
    /// short of 1 until the phones touch.
    public static func approach(distance: Float?, touched: Bool) -> Double? {
        if touched { return 1 }
        return progress(distance: distance).map { min($0, untouchedCeiling) }
    }

    /// What a phone asking to measure the distance to someone it chose to
    /// pay says it wants (Bring Phones Together). The other phone lets it in
    /// when its owner lets people nearby see them, as it would a tap asking
    /// for their number.
    public static let rangeContext = Data("starhash-range-1".utf8)

    /// What a phone connecting to an offer says it wants, so the phone
    /// offering tells it apart from a People Nearby tap asking its number.
    public static let inviteContext = Data("starhash-tap-1".utf8)

    // MARK: Offer

    /// Whether a phone nearby is asking to be tapped: a key in what it
    /// announces, beside its name when its owner lets people see them, or
    /// alone when they don't, so a phone holding out a request shows no
    /// one's name in People Nearby that its owner kept out of sight.
    public enum Offer {
        static let key = "t"

        /// What a phone holding out a request announces: `info` (its People
        /// Nearby announcement, when it makes one) with the offer added.
        public static func discoveryInfo(adding info: [String: String]?) -> [String: String] {
            var info = info ?? [PeopleNearby.Announcement.Key.version: PeopleNearby.Announcement.version]
            info[key] = "1"
            return info
        }

        /// Whether `info`, a phone's announcement, offers to be tapped.
        public static func isOffered(_ info: [String: String]?) -> Bool {
            guard let info, info[PeopleNearby.Announcement.Key.version] == PeopleNearby.Announcement.version else { return false }
            return info[key] == "1"
        }
    }

    // MARK: Between phones

    /// What two phones say to each other about measuring a tap. A request
    /// itself, and the answers to it, are `MoneyRequest.Message`s.
    public enum Message: Hashable, Sendable {
        /// This phone's Nearby Interaction token, archived: the other phone
        /// measures its distance with it.
        case token(Data)
        /// The phone asked measured the two touching: the request may come.
        case touched

        /// A token any bigger than this is no token (one is a few hundred
        /// bytes archived).
        static let maximumTokenSize = 4_096

        public var data: Data {
            let body: Body = switch self {
            case .token(let token): Body(v: 1, kind: "token", token: token)
            case .touched: Body(v: 1, kind: "touched")
            }
            return (try? JSONEncoder().encode(body)) ?? Data()
        }

        /// One received, or nil for anything else: a request, another
        /// version, a token too big to be one.
        public init?(data: Data) {
            guard let body = try? JSONDecoder().decode(Body.self, from: data), body.v == 1 else { return nil }
            switch body.kind {
            case "token":
                guard let token = body.token, !token.isEmpty, token.count <= Self.maximumTokenSize else { return nil }
                self = .token(token)
            case "touched":
                self = .touched
            default:
                return nil
            }
        }

        private struct Body: Codable {
            var v: Int
            var kind: String
            var token: Data?
        }
    }

    // MARK: When a tap counts

    /// Whether two phones are touching, from the distances Nearby
    /// Interaction measures between them several times a second. A touch is
    /// `samplesToTouch` measurements in a row within `touchDistance`; it
    /// counts once, and again only after the phones part beyond
    /// `releaseDistance`, so holding them together never asks twice.
    public struct Detector: Hashable, Sendable {
        /// When the last touch was made.
        public private(set) var touchedAt: Date?
        /// Measurements in a row within `touchDistance`.
        private var run = 0
        /// Touching now: no new touch until they part.
        private var isHeld = false
        private var lastSample: Date?

        public init() {}

        /// One measurement: the distance in metres, or nil when Nearby
        /// Interaction has none (the other phone out of its view). True when
        /// this one makes a touch.
        public mutating func measure(_ distance: Float?, at now: Date) -> Bool {
            defer { lastSample = now }
            // Lost in between: whatever ran before no longer does, and phones
            // held together that long ago may have parted since.
            if let lastSample, now.timeIntervalSince(lastSample) > TapToRequest.sampleGap {
                run = 0
                isHeld = false
            }
            guard let distance, distance >= 0 else {
                run = 0
                return false
            }
            if isHeld {
                if distance > TapToRequest.releaseDistance { isHeld = false }
                return false
            }
            guard distance <= TapToRequest.touchDistance else {
                run = 0
                return false
            }
            run += 1
            guard run >= TapToRequest.samplesToTouch else { return false }
            run = 0
            isHeld = true
            touchedAt = now
            return true
        }

        /// Whether a request that comes now follows a touch closely enough to
        /// be the one it brought.
        public func touchedRecently(at now: Date) -> Bool {
            guard let touchedAt else { return false }
            let since = now.timeIntervalSince(touchedAt)
            return since >= 0 && since <= TapToRequest.touchMemory
        }
    }
}
