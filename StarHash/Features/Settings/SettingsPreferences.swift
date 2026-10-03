import Foundation
import StarHashKit

extension PreferenceKey {
    /// When the Process Carrier SMS action last ran (seconds since 1970).
    /// The auto verification guide watches it to know the shortcut works,
    /// and Settings shows Auto-verify as On once it is set.
    static let lastVerifiedAt = "lastVerifiedAt"
    /// Whether deleting one transaction asks first. Turned off with Don't
    /// Ask Again on the question itself, back on in Settings.
    static let confirmDeletes = "confirmDeletes"
}

/// Preference values read outside a view (App Intents, permission
/// helpers), with the same defaults the Settings toggles show: everything
/// on except Nearby, which needs location permission first. @AppStorage
/// defaults only apply inside views, so code elsewhere reads through here.
enum StarHashPreferences {
    static func bool(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }

    static var saveTransactions: Bool { bool(PreferenceKey.saveTransactions, default: true) }
    static var saveRecents: Bool { bool(PreferenceKey.saveRecents, default: true) }
    static var enableContacts: Bool { bool(PreferenceKey.enableContacts, default: true) }
    static var nearbyLocation: Bool { bool(PreferenceKey.nearbyLocation, default: false) }

    /// MTN MoMo until the owner picks a wallet, which onboarding asks for
    /// before anything can be dialled.
    static var wallet: Recipient.Network {
        UserDefaults.standard.string(forKey: PreferenceKey.wallet).flatMap(Recipient.Network.init(rawValue:)) ?? .mtn
    }

    /// Nil until the shortcut has run once.
    static var lastVerifiedAt: Date? {
        let seconds = UserDefaults.standard.double(forKey: PreferenceKey.lastVerifiedAt)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    /// Auto-verify is on once its setup finished with a working shortcut,
    /// until it is turned off in Settings. While off, the action ignores
    /// every message, even though the automation in Shortcuts still runs.
    static var autoVerifyOn: Bool {
        bool(PreferenceKey.autoVerifySetUp, default: false) && lastVerifiedAt != nil
    }

    /// Turned off in Settings: setting it up again checks the shortcut anew.
    static func turnOffAutoVerify() {
        UserDefaults.standard.set(false, forKey: PreferenceKey.autoVerifySetUp)
        UserDefaults.standard.set(0.0, forKey: PreferenceKey.lastVerifiedAt)
    }

    static func markVerified(at date: Date = .now) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: PreferenceKey.lastVerifiedAt)
    }
}

/// "Delete All Data" in Settings: StarHash as a fresh install, as an
/// account's delete is elsewhere. The transactions file and its set-aside
/// copies go, so do Nearby's remembered places, every preference goes (the wallet, the switches, auto-verify,
/// whether onboarding and the note were seen), the shortcut's temporary
/// copy goes, and the app returns to onboarding. Contacts and the
/// Shortcuts automation belong to the system and stay.
@MainActor
enum AppReset {
    static func eraseEverything(store: StarHashStore, router: AppRouter) {
        store.eraseAll()
        AppEnvironment.places.eraseAll()
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        try? FileManager.default.removeItem(at: URL.temporaryDirectory.appending(path: "Shortcut", directoryHint: .isDirectory))
        router.openTransactionID = nil
        router.show(.pay)
        // Set, not only removed, so every @AppStorage view sees it change
        // and the root swaps to onboarding.
        UserDefaults.standard.set(false, forKey: PreferenceKey.hasOnboarded)
    }
}
