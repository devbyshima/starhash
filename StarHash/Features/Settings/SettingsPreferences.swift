import StarHashKit
import SwiftUI

extension PreferenceKey {
    /// Where StarHash opens, and where the tab bar's middle place starts:
    /// "pay" or "buy". Pay unless chosen otherwise in Settings.
    static let defaultPage = "defaultPage"
    /// The app's look, an `AppAppearance` raw value: as the iPhone is set
    /// unless chosen otherwise in Settings.
    static let appearance = "appearance"
    /// The language StarHash speaks (`AppLanguage`), the iPhone's until one
    /// is chosen.
    static let appLanguage = "appLanguage"
    /// Whether the hint to set the iPhone's default voice line, shown the
    /// first time an owner with two SIMs changes the default one, has been
    /// seen.
    static let seenVoiceLineHint = "seenVoiceLineHint"
    /// Whether the notice that Show My Name is on has been seen: once,
    /// for owners set up before it came. Onboarding tells new ones.
    static let seenShowMyNameNotice = "seenShowMyNameNotice"
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

/// Settings' choices read outside a view, where `@AppStorage` cannot be;
/// the choices themselves and their defaults are `Preferences`'.
enum StarHashPreferences {
    /// Pay or Buy, the page StarHash opens on.
    static var defaultPage: AppTab {
        UserDefaults.standard.string(forKey: PreferenceKey.defaultPage) == AppTab.buy.rawValue ? .buy : .pay
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
        SmartCategories.reset()
        StarHashWidgetData.erase()
        ProfilePhoto.shared.remove()
        // What the server still has from this iPhone outlives the wipe, so
        // the owner's listing and photo are deleted from it after it.
        AppEnvironment.serverSync.erase {
            if let domain = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: domain)
            }
        }
        // The owner's name, SIMs and wallet went with the rest, and
        // auto-verify's state.
        AppEnvironment.owner.reload()
        AppEnvironment.autoVerify.reload()
        try? FileManager.default.removeItem(at: URL.temporaryDirectory.appending(path: "Shortcut", directoryHint: .isDirectory))
        router.openTransactionID = nil
        router.show(.pay)
        // Set, not only removed, so every @AppStorage view sees it change
        // and the root swaps to onboarding.
        UserDefaults.standard.set(false, forKey: PreferenceKey.hasOnboarded)
        AppAppearance.apply(.system)
    }
}
