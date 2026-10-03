#if DEBUG
import Foundation
import StarHashKit

/// Launch arguments for screenshots and previews (DEBUG builds only):
///   -inMemory        a fresh in-memory store with sample transactions
///   -emptyStore      with -inMemory, no sample transactions (empty states)
///   -tab <name>      pay, activity or settings
///   -skipOnboarding  start on the tabs
@MainActor
enum DebugLaunch {
    static let arguments = ProcessInfo.processInfo.arguments

    static var inMemory: Bool { arguments.contains("-inMemory") }

    static func value(after flag: String) -> String? {
        guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    static func seededStore() -> StarHashStore {
        let store = StarHashStore(fileURL: nil)
        guard !arguments.contains("-emptyStore") else { return store }
        for t in SampleData.transactions() { store.add(t) }
        return store
    }

    /// Places for the sample merchants around Kigali Heights, so
    /// `-nearbyHere` has something to suggest.
    static func seededPlaces() -> PlaceMemory {
        let places = PlaceMemory(fileURL: nil)
        for visit in SampleData.places() {
            places.record(visit.recipient, latitude: visit.latitude, longitude: visit.longitude, accuracy: visit.accuracy, date: visit.date)
        }
        return places
    }

    /// `-nearbyHere`: Pay acts as if the phone were at Kigali Heights, for
    /// screenshots of the picker's Nearby section.
    static var nearbyFix: LocationFix? {
        guard arguments.contains("-nearbyHere") else { return nil }
        return LocationFix(latitude: SampleData.kigaliHeights.latitude, longitude: SampleData.kigaliHeights.longitude, accuracy: 8)
    }
}
#endif
