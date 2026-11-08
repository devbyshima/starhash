import Foundation
import Security
import StarHashKit
import UIKit

/// StarHash's server (`server/` in the repo): the one thing kept off the
/// iPhone. The owner's photo, whenever they have one, lives there under a
/// random id their code carries, so whoever scans the code
/// sees it; a secret key in the Keychain is needed to replace or delete it.
/// And once a day a random id, made on the first launch, says this copy of
/// StarHash is in use, with its version, so the people using it can be
/// counted. Nothing else is ever sent: no number, no name, no payment.
@MainActor
enum StarHashCloud {
    nonisolated static let baseURL = URL(string: "https://starhash.devbyshima.workers.dev")!

    // MARK: The owner's photo

    /// The id the owner's code carries for their photo, when they have one.
    static var sharedPhotoID: UUID? {
        guard ProfilePhoto.shared.image != nil else { return nil }
        return photoID
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
    /// have none. Run whenever it changes.
    static func syncPhoto() {
        let id = photoID
        let data = ProfilePhoto.shared.data
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

    /// Says this copy is in use, once on each day it comes to the front, by
    /// Kigali's calendar as the server counts days (so someone using it
    /// late one evening and early the next morning counts on both days).
    /// The day is only marked once the server has counted it: a try that
    /// failed, offline say, is made again the next time StarHash opens.
    /// The Simulator never counts, so test runs stay out of the numbers.
    static func pingIfDue(now: Date = .now) {
        #if targetEnvironment(simulator)
        return
        #else
        let day = Self.kigaliDay(of: now)
        guard !pinging, UserDefaults.standard.string(forKey: lastPingDayKey) != day else { return }
        pinging = true
        let id = installID
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        Task {
            let counted = await Self.sendPing(id: id, version: version)
            pinging = false
            if counted { UserDefaults.standard.set(day, forKey: lastPingDayKey) }
        }
        #endif
    }

    /// Whether the server counted the ping.
    nonisolated private static func sendPing(id: String, version: String) async -> Bool {
        var request = URLRequest(url: baseURL.appending(path: "v1/ping"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["id": id, "version": version])
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    /// A ping on its way, so coming back to the front while it is out
    /// sends no second one.
    private static var pinging = false

    /// "2026-11-08": the date in Kigali, as the server writes a day.
    nonisolated static func kigaliDay(of date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Kigali") ?? TimeZone(secondsFromGMT: 2 * 3600)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static let lastPingDayKey = "cloudLastPingDay"
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
