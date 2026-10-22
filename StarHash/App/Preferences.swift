import StarHashKit
import Foundation

/// UserDefaults keys, used with @AppStorage. One place, so every screen
/// reads and writes the same key.
enum PreferenceKey {
    static let hasOnboarded = "hasOnboarded"
    /// The onboarding screen reached, so a flow left unfinished (the app
    /// closed or killed partway) picks up there. Cleared when it finishes.
    static let onboardingStage = "onboardingStage"
    /// When StarHash was first set up (seconds since 1970), for the note
    /// that asks for a rating two weeks later.
    static let firstUsedAt = "firstUsedAt"
    static let hasSeenReviewNote = "hasSeenReviewNote"
    /// Whether the developer note has been seen after onboarding.
    static let hasSeenDeveloperNote = "hasSeenDeveloperNote"
    /// The marketing version that last launched, so What's New shows once
    /// after an update (`WhatsNewLaunch`).
    static let lastRunVersion = "lastRunVersion"
    static let saveTransactions = "saveTransactions"
    static let enableContacts = "enableContacts"
    static let nearbyLocation = "nearbyLocation"
    static let saveRecents = "saveRecents"
    static let autoVerifySetUp = "autoVerifySetUp"
    /// The wallet StarHash pays from: a `Recipient.Network` raw value,
    /// empty until onboarding asks.
    static let wallet = "wallet"
}

/// The language StarHash speaks, chosen in Settings rather than the
/// Settings app, and changed at once: the iPhone's own, English, French or
/// Kinyarwanda. Every string written out is looked up in it
/// (`String(starhash:)`), and SwiftUI's views take its locale, so the app
/// redraws in it without a restart. The widgets and iOS's own prompts keep
/// the iPhone's language.
enum AppLanguage: String, CaseIterable {
    case system
    case english = "en"
    case french = "fr"
    case kinyarwanda = "rw"

    /// Each language in its own words, the way language pickers name them.
    var title: String {
        switch self {
        case .system: String(starhash: "iPhone's language")
        case .english: "English"
        case .french: "Français"
        case .kinyarwanda: "Ikinyarwanda"
        }
    }

    /// The language chosen, or the iPhone's when none is.
    static var stored: AppLanguage {
        UserDefaults.standard.string(forKey: PreferenceKey.appLanguage).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// For SwiftUI's environment: the language with the region's formats.
    var locale: Locale {
        guard self != .system else { return .autoupdatingCurrent }
        var components = Locale.Components(locale: .autoupdatingCurrent)
        components.languageComponents = Locale.Language.Components(identifier: rawValue)
        return Locale(components: components)
    }

    /// Points every string StarHash writes out at this language, the
    /// app's and the kit's (`String(starhash:)`). Run at launch and
    /// whenever the choice changes.
    func apply() {
        StarHashLanguage.locale = locale
    }
}

extension Locale {
    /// The chosen language with the region's formats, for dates and times
    /// written out as words outside a view's environment.
    static var starhash: Locale { StarHashLanguage.locale }
}
