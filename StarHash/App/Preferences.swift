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

/// The language StarHash shows itself in: English or Kinyarwanda, chosen in
/// the Settings app (iOS keeps each app's language there).
enum AppLanguage {
    /// The language's own name for itself: "English", "Kinyarwanda".
    static var currentName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        let name = Locale(identifier: code).localizedString(forLanguageCode: code) ?? code
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}
