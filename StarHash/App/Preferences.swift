import Foundation

/// UserDefaults keys, used with @AppStorage. One place, so every screen
/// reads and writes the same key.
enum PreferenceKey {
    static let hasOnboarded = "hasOnboarded"
    /// Whether the developer note has been seen after onboarding.
    static let hasSeenDeveloperNote = "hasSeenDeveloperNote"
    static let saveTransactions = "saveTransactions"
    static let enableContacts = "enableContacts"
    static let nearbyLocation = "nearbyLocation"
    static let saveRecents = "saveRecents"
    static let autoVerifySetUp = "autoVerifySetUp"
    /// The wallet StarHash pays from: a `Recipient.Network` raw value,
    /// empty until onboarding asks.
    static let wallet = "wallet"
}
