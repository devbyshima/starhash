import Foundation
import Observation

/// Where numbers and codes were paid, so StarHash can suggest them when
/// the person is back there ("Nearby"). Kept only on the device, in its
/// own file, sealed whenever the phone is locked; nothing leaves the
/// phone, and no place is ever named or looked up: a visit is a
/// recipient, a point, how accurate the point was, and when.
///
/// Only fixes accurate enough to tell one shop from the next are kept
/// (`Visit.maximumAccuracy`), and a suggestion needs the person to be
/// within the two fixes' uncertainty of a visit, never less than
/// `minimumRadius`.
@MainActor
@Observable
public final class PlaceMemory {
    public struct Visit: Codable, Hashable, Sendable {
        public var recipient: Recipient
        public var latitude: Double
        public var longitude: Double
        /// The fix's horizontal accuracy, in metres.
        public var accuracy: Double
        public var date: Date

        public init(recipient: Recipient, latitude: Double, longitude: Double, accuracy: Double, date: Date) {
            self.recipient = recipient
            self.latitude = latitude
            self.longitude = longitude
            self.accuracy = accuracy
            self.date = date
        }

        /// A fix any worse than this cannot tell neighbouring tills apart,
        /// so it is not kept.
        public static let maximumAccuracy: Double = 50
    }

    /// A recipient paid near the person, with how close the nearest visit
    /// was and how often they were paid around here.
    public struct Suggestion: Hashable, Sendable {
        public var recipient: Recipient
        public var distance: Double
        public var visits: Int
    }

    /// The smallest radius a suggestion is looked for in, in metres: one
    /// shopfront and its doorway.
    public static let minimumRadius: Double = 40

    /// Oldest first.
    public private(set) var visits: [Visit] = []

    /// Bumped by every erase. A payment captures it when it starts
    /// locating and passes it to `record`, so a fix that arrives after the
    /// person erased (or turned Nearby off) is dropped, not written back.
    public private(set) var generation = 0

    @ObservationIgnored private let fileURL: URL?

    /// `fileURL` nil keeps everything in memory (tests, previews).
    public init(fileURL: URL?) {
        self.fileURL = fileURL
        load()
    }

    public static var defaultFileURL: URL {
        let folder = URL.applicationSupportDirectory.appending(path: "StarHash", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "places.json")
    }

    // MARK: Recording

    /// Remembers paying `recipient` here, when the fix is accurate enough.
    /// Returns whether it was kept.
    @discardableResult
    public func record(
        _ recipient: Recipient, latitude: Double, longitude: Double, accuracy: Double,
        date: Date = .now, generation expected: Int? = nil
    ) -> Bool {
        if let expected, expected != generation { return false }
        guard recipient.isPayable, accuracy >= 0, accuracy <= Visit.maximumAccuracy else { return false }
        visits.append(Visit(recipient: recipient, latitude: latitude, longitude: longitude, accuracy: accuracy, date: date))
        save()
        return true
    }

    // MARK: Suggesting

    /// Recipients paid near here, nearest first, then the most visited:
    /// one entry each, at most `limit`. Nothing for a fix too rough to
    /// trust.
    public func suggestions(latitude: Double, longitude: Double, accuracy: Double, limit: Int = 3) -> [Suggestion] {
        guard accuracy >= 0, accuracy <= Visit.maximumAccuracy else { return [] }
        var best: [String: Suggestion] = [:]
        for visit in visits {
            let distance = Self.distance(latitude, longitude, visit.latitude, visit.longitude)
            let radius = max(Self.minimumRadius, accuracy + visit.accuracy)
            guard distance <= radius else { continue }
            let key = Self.key(visit.recipient)
            if var found = best[key] {
                found.visits += 1
                if distance < found.distance {
                    found.distance = distance
                }
                // The latest name a recipient was paid under.
                found.recipient = visit.recipient
                best[key] = found
            } else {
                best[key] = Suggestion(recipient: visit.recipient, distance: distance, visits: 1)
            }
        }
        // Nearest first, by ten-metre bands (closer than that, GPS cannot
        // really tell), the more visited first within a band.
        return best.values
            .sorted { a, b in
                let bandA = Int(a.distance / 10), bandB = Int(b.distance / 10)
                if bandA != bandB { return bandA < bandB }
                if a.visits != b.visits { return a.visits > b.visits }
                if a.distance != b.distance { return a.distance < b.distance }
                return Self.key(a.recipient) < Self.key(b.recipient)
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Erasing

    /// Every remembered place, and the file, gone.
    public func eraseAll() {
        generation += 1
        visits.removeAll()
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: Geometry

    /// Metres between two points along the Earth's surface (haversine).
    static func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let radius = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, sqrt(a)))
    }

    private static func key(_ recipient: Recipient) -> String {
        recipient.kind.rawValue + recipient.destination
    }

    // MARK: Disk

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        visits = (try? decoder.decode([Visit].self, from: data)) ?? []
    }

    /// Sealed whenever the phone is locked: places are only read while the
    /// person is paying, so they never need to be readable in the
    /// background.
    private func save() {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(visits) {
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            // Out of iCloud and computer backups too: on this iPhone only.
            var url = fileURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
    }
}
