import Foundation
import Testing
@testable import StarHashKit

@Suite("Preferences")
struct PreferencesTests {
    static func defaults() -> UserDefaults {
        let name = "PreferencesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func untouchedEverythingIsOnButNearbyAndTheLock() {
        let defaults = Self.defaults()
        #expect(Preferences.saveTransactions.value(in: defaults))
        #expect(Preferences.enableContacts.value(in: defaults))
        #expect(Preferences.scamWarnings.value(in: defaults))
        #expect(!Preferences.nearbyLocation.value(in: defaults))
        #expect(!Preferences.appLock.value(in: defaults))
        #expect(!Preferences.splitLargePayments.value(in: defaults))
    }

    @Test func aChoiceMadeIsKept() {
        let defaults = Self.defaults()
        defaults.set(false, forKey: Preferences.enableContacts.key)
        defaults.set(45, forKey: Preferences.reminderDelay.key)
        #expect(!Preferences.enableContacts.value(in: defaults))
        #expect(Preferences.reminderDelay.value(in: defaults) == 45)
    }

    /// The Notifications page and the plan agree on every default, because
    /// both read them here.
    @Test func storedNotificationSettingsStartAsThePlansDefaults() {
        let stored = NotificationPlan.Settings.stored(in: Self.defaults(), failsUnconfirmedSince: nil)
        #expect(stored == NotificationPlan.Settings())
    }
}
