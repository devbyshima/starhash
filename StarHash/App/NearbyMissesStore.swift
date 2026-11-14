import Foundation
import StarHashKit

/// The Nearby suggestions passed over (`NearbyMisses`), kept on the device
/// in UserDefaults, as the other preferences are (so Delete All Data
/// clears it with them). Nothing to do with where anyone was: only how
/// often a suggestion was passed over.
@MainActor
enum NearbyMissesStore {
    private static var misses: NearbyMisses {
        get { NearbyMisses.stored(in: .standard) }
        set { newValue.save(in: .standard) }
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

    // A payment, however it was chosen, is noted by `Paying`.
}
