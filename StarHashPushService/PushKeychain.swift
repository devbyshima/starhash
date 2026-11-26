import Foundation
import Security
import StarHashKit

/// What StarHash's Notification Service Extension reads from the app,
/// through the app's Keychain (the extension lists the app's own access
/// group under `keychain-access-groups`, in a build with push only): the
/// key requests to the owner are sealed to, which the app keeps there
/// already (`StarHashCloud.requestKey()`), and the few choices that decide
/// what a request's notification says. Compiled into both targets. No App
/// Group: that is a switch of its own (`STARHASH_APP_GROUPS`).
enum PushKeychain {
    /// The choices the extension follows, as the app last wrote them.
    struct Settings: Codable, Equatable, Sendable {
        /// The language chosen in StarHash (`StarHashLanguage.locale`).
        var language: String
        /// Settings, Notifications, Show amounts.
        var showsAmounts: Bool
        /// Settings, Enable contacts: without it the app cannot tell who
        /// asks either.
        var contacts: Bool
        /// The server the directory is asked (`StarHashCloud.baseURL`).
        var server: URL
    }

    private static let service = "StarHashCloud"
    private static let settingsAccount = "pushSettings"

    /// The owner's request key, made and kept by the app.
    static func requestKey() -> RequestSeal.PrivateKey? {
        read("requestKey").flatMap(RequestSeal.privateKey(raw:))
    }

    static func settings() -> Settings? {
        read(settingsAccount).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) }
    }

    /// The app's side: written as StarHash comes and goes, and as any of
    /// them changes. Kept on this iPhone only.
    static func write(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings), settings != self.settings() else { return }
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: settingsAccount,
        ]
        let values: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        if SecItemUpdate(item as CFDictionary, values as CFDictionary) == errSecItemNotFound {
            SecItemAdd(item.merging(values) { $1 } as CFDictionary, nil)
        }
    }

    private static func read(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var found: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess else { return nil }
        return found as? Data
    }
}
