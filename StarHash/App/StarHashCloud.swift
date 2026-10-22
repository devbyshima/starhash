import Foundation
import Security
import StarHashKit
import UIKit

/// StarHash's server (`server/` in the repo): the one thing kept off the
/// iPhone. The owner's photo, when they share it with their code, lives
/// there under a random id their code carries, so whoever scans the code
/// sees it; a secret key in the Keychain is needed to replace or delete it.
/// And once a day a random id, made on the first launch, says this copy of
/// StarHash is in use, with its version, so the people using it can be
/// counted. Nothing else is ever sent: no number, no name, no payment.
@MainActor
enum StarHashCloud {
    nonisolated static let baseURL = URL(string: "https://starhash.devbyshima.workers.dev")!

    // MARK: The owner's photo

    /// The id the owner's code carries for their photo, when they share it
    /// and have one.
    static var sharedPhotoID: UUID? {
        guard sharesPhoto, ProfilePhoto.shared.image != nil else { return nil }
        return photoID
    }

    /// Whether the owner shares their photo with their code (Settings), on
    /// until turned off.
    static var sharesPhoto: Bool {
        UserDefaults.standard.object(forKey: PreferenceKey.sharePhoto) as? Bool ?? true
    }

    /// The photo's id, made once.
    private static var photoID: UUID {
        if let saved = UserDefaults.standard.string(forKey: photoIDKey).flatMap(UUID.init(uuidString:)) { return saved }
        let made = UUID()
        UserDefaults.standard.set(made.uuidString, forKey: photoIDKey)
        return made
    }

    private static let photoIDKey = "cloudPhotoID"

    /// Uploads the owner's photo, or deletes it from the server when they
    /// have none or no longer share it. Run whenever either changes.
    static func syncPhoto() {
        let id = photoID
        let data = sharesPhoto ? ProfilePhoto.shared.data : nil
        Task.detached {
            guard let key = await photoKey() else { return }
            var request = URLRequest(url: baseURL.appending(path: "v1/photos/\(id.uuidString.lowercased())"))
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            if let data {
                request.httpMethod = "PUT"
                request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                request.httpBody = data
            } else {
                request.httpMethod = "DELETE"
            }
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    // MARK: A scanned code's photo

    private static var photos: [UUID: UIImage] = [:]

    /// The photo a scanned code points to, fetched once and kept for the
    /// run; nil when there is none or the server cannot be reached.
    static func photo(_ id: UUID) async -> UIImage? {
        if let kept = photos[id] { return kept }
        let url = baseURL.appending(path: "v1/photos/\(id.uuidString.lowercased())")
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data) else { return nil }
        photos[id] = image
        return image
    }

    // MARK: Counting

    /// Says this copy is in use, at most once a day.
    static func pingIfDue(now: Date = .now) {
        let defaults = UserDefaults.standard
        let last = defaults.double(forKey: lastPingKey)
        guard now.timeIntervalSince1970 - last > 20 * 3600 else { return }
        defaults.set(now.timeIntervalSince1970, forKey: lastPingKey)
        let id = installID
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        Task.detached {
            var request = URLRequest(url: baseURL.appending(path: "v1/ping"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["id": id, "version": version])
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    private static let lastPingKey = "cloudLastPing"
    private static let installIDKey = "cloudInstallID"

    private static var installID: String {
        if let saved = UserDefaults.standard.string(forKey: installIDKey) { return saved }
        let made = UUID().uuidString.lowercased()
        UserDefaults.standard.set(made, forKey: installIDKey)
        return made
    }

    // MARK: The key

    /// The photo's secret key: 32 random bytes, made once and kept in the
    /// Keychain, on this iPhone only.
    nonisolated private static func photoKey() async -> String? {
        let account = "photoKey"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "StarHashCloud",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var found: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
           let data = found as? Data, let key = String(data: data, encoding: .utf8) {
            return key
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
        let key = Data(bytes).base64EncodedString()
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "StarHashCloud",
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(key.utf8),
        ]
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess ? key : nil
    }
}
