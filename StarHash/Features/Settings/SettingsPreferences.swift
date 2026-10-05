import StarHashKit
import SwiftUI

extension PreferenceKey {
    /// When the Process Carrier SMS action last ran (seconds since 1970).
    /// The auto verification guide watches it to know the shortcut works,
    /// and Settings shows Auto-verify as On once it is set.
    static let lastVerifiedAt = "lastVerifiedAt"
    /// Whether deleting one transaction asks first. Turned off with Don't
    /// Ask Again on the question itself, back on in Settings.
    static let confirmDeletes = "confirmDeletes"
    /// Where StarHash opens, and where the tab bar's middle place starts:
    /// "pay" or "buy". Pay unless chosen otherwise in Settings.
    static let defaultPage = "defaultPage"
    /// The app's look, an `AppAppearance` raw value: as the iPhone is set
    /// unless chosen otherwise in Settings.
    static let appearance = "appearance"
}

/// The app's look, chosen in Settings: as the iPhone is set, or always
/// dark or light.
enum AppAppearance: String, CaseIterable {
    case system
    case dark
    case light

    var title: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    /// The one saved in Settings.
    static var stored: AppAppearance {
        UserDefaults.standard.string(forKey: PreferenceKey.appearance).flatMap(AppAppearance.init(rawValue:)) ?? .system
    }

    /// Puts it on StarHash's windows, so sheets and alerts follow, and
    /// System hands them back to the iPhone's own setting.
    @MainActor
    static func apply(_ appearance: AppAppearance) {
        let style: UIUserInterfaceStyle = switch appearance {
        case .system: .unspecified
        case .dark: .dark
        case .light: .light
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
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

    /// Pay or Buy, the page StarHash opens on.
    static var defaultPage: AppTab {
        UserDefaults.standard.string(forKey: PreferenceKey.defaultPage) == AppTab.buy.rawValue ? .buy : .pay
    }

    /// MTN MoMo until the owner picks a wallet, which onboarding asks for
    /// before anything can be dialled.
    static var wallet: Recipient.Network { chosenWallet ?? .mtn }

    /// The wallet the owner picked, nil before onboarding has asked: what a
    /// Shortcuts or Siri action checks, since it can run before onboarding.
    static var chosenWallet: Recipient.Network? {
        UserDefaults.standard.string(forKey: PreferenceKey.wallet).flatMap(Recipient.Network.init(rawValue:))
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
        UserDefaults.standard.removeObject(forKey: PreferenceKey.autoVerifySince)
    }

    static func markVerified(at date: Date = .now) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: PreferenceKey.lastVerifiedAt)
    }
}

/// "Delete All Data" in Settings: StarHash as a fresh install, as an
/// account's delete is elsewhere. The transactions file and its set-aside
/// copies go (where each payment was made with them), every preference goes (the wallet, the switches, auto-verify,
/// whether onboarding and the note were seen), the shortcut's temporary
/// copy goes, and the app returns to onboarding. Contacts and the
/// Shortcuts automation belong to the system and stay.
@MainActor
enum AppReset {
    static func eraseEverything(store: StarHashStore, router: AppRouter) {
        store.eraseAll()
        StarHashNotifications.shared.removeAll()
        AppEnvironment.shortcuts.reset()
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        try? FileManager.default.removeItem(at: URL.temporaryDirectory.appending(path: "Shortcut", directoryHint: .isDirectory))
        router.openTransactionID = nil
        router.show(.pay)
        // Set, not only removed, so every @AppStorage view sees it change
        // and the root swaps to onboarding.
        UserDefaults.standard.set(false, forKey: PreferenceKey.hasOnboarded)
        AppAppearance.apply(.system)
    }
}
