import Foundation
import StarHashKit

/// The Nearby suggestions passed over (`NearbyMisses`), kept on the device
/// in UserDefaults, as the other preferences are (so Delete All Data
/// clears it with them). Nothing to do with where anyone was: only how
/// often a suggestion was passed over.
@MainActor
enum NearbyMissesStore {
    private static let key = "nearbyMisses"

    private static var misses: NearbyMisses {
        get {
            UserDefaults.standard.data(forKey: key)
                .flatMap { try? JSONDecoder().decode(NearbyMisses.self, from: $0) } ?? NearbyMisses()
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key)
        }
    }

    /// The suggestions still worth showing.
    static func filter(_ suggestions: [Recipient]) -> [Recipient] {
        misses.filter(suggestions)
    }

    /// The picker showed `shown` and `chosen` was paid.
    static func record(shown: [Recipient], chosen: Recipient) {
        guard !shown.isEmpty else { return }
        misses.record(shown: shown, chosen: chosen)
    }

    /// `recipient` was paid, however it was chosen.
    static func paid(_ recipient: Recipient) {
        misses.paid(recipient)
    }
}
