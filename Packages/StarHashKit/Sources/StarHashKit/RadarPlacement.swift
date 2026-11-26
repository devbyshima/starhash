import Foundation

/// Where someone nearby sits on People Nearby's radar, from what Nearby
/// Interaction measured between the two iPhones: the closer they are, the
/// nearer the middle (the owner's photo), and which way they are from the
/// iPhone, straight up the screen being where it points. Pointing it at
/// someone finds them (`isPointedAt`).
///
/// Measurements jitter, so a placement moves only part of the way to each
/// new one (`Smoothed`). Without a direction (the other phone out of the
/// one's view, or an iPhone that can't tell), it keeps the last one.
public enum RadarPlacement {
    /// The farthest the radar tells apart, in metres: anyone further sits
    /// at its edge.
    public static let farthest: Float = 10

    /// Within this angle either side of straight ahead, in radians, the
    /// iPhone points at someone.
    public static let pointingTolerance: Float = 12 * .pi / 180

    /// How far out someone `distance` metres away sits, 0 at the photo to 1
    /// at the edge: square-rooted, so the steps that matter close by (half
    /// a metre against a metre) read apart, and far ones need not.
    public static func reach(distance: Float) -> Double {
        guard distance.isFinite, distance > 0 else { return 0 }
        return Double((min(distance, farthest) / farthest).squareRoot())
    }

    /// Which way someone is, in radians from straight ahead, clockwise
    /// (positive to the right), from the unit `direction` Nearby
    /// Interaction gives in the iPhone's space (x to the right). Nil when
    /// there is none to read.
    public static func bearing(direction: SIMD3<Float>?) -> Float? {
        guard let direction, direction.x.isFinite else { return nil }
        return asin(min(max(direction.x, -1), 1))
    }

    /// Whether the iPhone points at someone `bearing` away.
    public static func isPointedAt(bearing: Float?) -> Bool {
        guard let bearing else { return false }
        return abs(bearing) <= pointingTolerance
    }

    /// "2.5 m", "80 cm": how far someone is, for the line at the foot.
    public static func spoken(distance: Float) -> String {
        if distance < 1 {
            let centimetres = Int((distance * 100 / 10).rounded()) * 10
            return String(kit: "\(max(centimetres, 10)) cm")
        }
        let tenths = (distance * 10).rounded() / 10
        return tenths >= 10 ? String(kit: "\(Int(tenths.rounded())) m") : String(kit: "\(String(format: "%.1f", tenths)) m")
    }

    /// One person's placement, steadied over readings.
    public struct Smoothed: Hashable, Sendable {
        /// 0 at the photo to 1 at the edge, nil before the first distance.
        public private(set) var reach: Double?
        /// Radians from straight ahead, nil before the first direction.
        public private(set) var bearing: Float?
        /// The last distance, in metres, as measured.
        public private(set) var distance: Float?

        /// How far each reading moves it, 0 to 1.
        static let follow = 0.3

        public init() {}

        public mutating func add(distance: Float?, bearing: Float?) {
            if let distance, distance.isFinite, distance >= 0 {
                let target = RadarPlacement.reach(distance: distance)
                reach = reach.map { $0 + (target - $0) * Self.follow } ?? target
                self.distance = distance
            }
            if let bearing, bearing.isFinite {
                self.bearing = self.bearing.map { $0 + (bearing - $0) * Float(Self.follow) } ?? bearing
            }
        }
    }
}
