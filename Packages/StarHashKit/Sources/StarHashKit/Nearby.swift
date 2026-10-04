import Foundation

/// Nearby: the numbers and codes paid where the person is now, suggested
/// at the top of the recipient list. Built from the payments themselves: a
/// payment from StarHash keeps where it was made when it went to a
/// merchant code or to a number that is not one of the person's contacts,
/// and nothing else is kept, so deleting a payment forgets its place. No
/// place is ever named or looked up.
///
/// Only fixes accurate enough to tell one shop from the next count
/// (`maximumAccuracy`), and a suggestion needs the person to be within the
/// two fixes' uncertainty of a payment, never less than `minimumRadius`.
public enum Nearby {
    /// A fix any worse than this cannot tell neighbouring tills apart.
    public static let maximumAccuracy: Double = 50

    /// The smallest radius a suggestion is looked for in, in metres: one
    /// shopfront and its doorway.
    public static let minimumRadius: Double = 40

    /// A recipient paid near the person, with how close the nearest payment
    /// was and how often they were paid around here.
    public struct Suggestion: Hashable, Sendable {
        public var recipient: Recipient
        public var distance: Double
        public var visits: Int
    }

    /// Recipients paid near here, nearest first, then the most paid: one
    /// entry each, at most `limit`, under the latest name each was paid
    /// under (a merchant's registered one, once its message is in). Failed
    /// payments do not count. Nothing for a fix too rough to trust.
    /// `transactions` newest first, as the store keeps them.
    public static func suggestions(
        from transactions: [Transaction], latitude: Double, longitude: Double, accuracy: Double, limit: Int = 3
    ) -> [Suggestion] {
        guard accuracy >= 0, accuracy <= maximumAccuracy else { return [] }
        var best: [String: Suggestion] = [:]
        for t in transactions where t.direction == .outgoing && t.status != .failed && t.counterparty.isPayable {
            // A place saved before its accuracy was kept counts as the
            // roughest one allowed.
            guard let place = t.location else { continue }
            let placeAccuracy = place.accuracy ?? maximumAccuracy
            guard placeAccuracy >= 0, placeAccuracy <= maximumAccuracy else { continue }
            let distance = Self.distance(latitude, longitude, place.latitude, place.longitude)
            guard distance <= max(minimumRadius, accuracy + placeAccuracy) else { continue }
            let key = t.counterparty.kind.rawValue + t.counterparty.destination
            if var found = best[key] {
                found.visits += 1
                found.distance = min(found.distance, distance)
                if found.recipient.name == nil { found.recipient.name = t.counterparty.name }
                best[key] = found
            } else {
                best[key] = Suggestion(recipient: t.counterparty, distance: distance, visits: 1)
            }
        }
        // Nearest first, by ten-metre bands (closer than that, GPS cannot
        // really tell), the more paid first within a band.
        return best.values
            .sorted { a, b in
                let bandA = Int(a.distance / 10), bandB = Int(b.distance / 10)
                if bandA != bandB { return bandA < bandB }
                if a.visits != b.visits { return a.visits > b.visits }
                if a.distance != b.distance { return a.distance < b.distance }
                return a.recipient.kind.rawValue + a.recipient.destination < b.recipient.kind.rawValue + b.recipient.destination
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Metres between two points along the Earth's surface (haversine).
    static func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let radius = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, sqrt(a)))
    }
}
