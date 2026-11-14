import Foundation
import Security
import StarHashKit
import UIKit

/// StarHash's server (`server/` in the repo), over HTTP. What StarHash
/// sends it, and when, is `ServerSync`'s (StarHashKit): this is its adapter,
/// `Server`, with the owner's secret key from the Keychain. The reads stay
/// here, since no rule decides them: a scanned code's photo, and who lists
/// a number typed to pay.
@MainActor
enum StarHashCloud {
    nonisolated static let baseURL = URL(string: "https://starhash.devbyshima.workers.dev")!

    /// What `ServerSync` sends, over HTTP.
    struct Server: ServerSync.Server {
        func sendPhoto(_ data: Data?, id: UUID, key: String) async -> ServerSync.PhotoAnswer {
            var request = URLRequest(url: baseURL.appending(path: "v1/photos/\(id.uuidString.lowercased())"))
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            if let data {
                request.httpMethod = "PUT"
                request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                request.httpBody = data
            } else {
                request.httpMethod = "DELETE"
            }
            guard let (_, response) = try? await URLSession.shared.data(for: request),
                  let status = (response as? HTTPURLResponse)?.statusCode else { return .failed }
            switch status {
            case 200: return .taken
            case 403: return .notYours
            default: return .failed
            }
        }

        func sendListing(_ listing: ServerSync.Listing?, key: String) async -> Bool {
            var request = URLRequest(url: baseURL.appending(path: "v1/directory"))
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            if let listing {
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                var body: [String: Any] = ["numbers": listing.numbers, "name": listing.name]
                if let photo = listing.photo { body["photo"] = photo.uuidString.lowercased() }
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            } else {
                request.httpMethod = "DELETE"
            }
            guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
            return (response as? HTTPURLResponse)?.statusCode == 200
        }

        func ping(installID: String, version: String) async -> Bool {
            var request = URLRequest(url: baseURL.appending(path: "v1/ping"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["id": installID, "version": version])
            guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
            return (response as? HTTPURLResponse)?.statusCode == 200
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

    // MARK: Show My Name

    /// What the server lists for a number: the name its owner gave, and
    /// their photo's id.
    struct DirectoryEntry: Equatable, Sendable {
        var name: String?
        var photoID: UUID?
    }

    /// Looked-up numbers, found or not, kept for the run.
    private static var entries: [String: DirectoryEntry?] = [:]

    /// The name and photo listed for `number`, or nil when no one lists it
    /// or the server cannot be reached. Only a Rwandan mobile number is
    /// asked about, as only those are listed.
    static func entry(for number: String) async -> DirectoryEntry? {
        guard Recipient(destination: number, kind: .phone).isRwandanMobile else { return nil }
        #if DEBUG
        if let name = DebugLaunch.value(after: "-directoryName") {
            return DirectoryEntry(name: name)
        }
        #endif
        if let kept = entries[number] { return kept }
        var request = URLRequest(url: baseURL.appending(path: "v1/directory/lookup"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["number": number])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return nil }
        guard status == 200,
              let found = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if status == 404 { entries[number] = .some(nil) }
            return nil
        }
        let entry = DirectoryEntry(
            name: (found["name"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            photoID: (found["photo"] as? String).flatMap(UUID.init(uuidString:))
        )
        entries[number] = entry
        return entry
    }

    // MARK: The key

    /// The owner's secret key, for their photo and their listing alike: 32
    /// random bytes, made once and kept in the Keychain. It goes into the
    /// iPhone's encrypted backups (never iCloud Keychain), so a new iPhone
    /// restored from one can still replace or delete the photo and the
    /// listing the old one made, and it outlives Delete All Data, so what
    /// was left on the server can still be deleted after it. (Its Keychain
    /// account is still "photoKey", from when the photo was all it was
    /// for.)
    nonisolated static func secretKey() async -> String? {
        let account = "photoKey"
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "StarHashCloud",
            kSecAttrAccount as String: account,
        ]
        var query = item
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        var found: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
           let attributes = found as? [String: Any],
           let data = attributes[kSecValueData as String] as? Data,
           let key = String(data: data, encoding: .utf8) {
            // Earlier builds kept the key on its iPhone only, so a restored
            // iPhone lost it; it moves into the backups from now on.
            if attributes[kSecAttrAccessible as String] as? String != kSecAttrAccessibleAfterFirstUnlock as String {
                let moved: [String: Any] = [kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
                SecItemUpdate(item as CFDictionary, moved as CFDictionary)
            }
            return key
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
        let key = Data(bytes).base64EncodedString()
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "StarHashCloud",
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: Data(key.utf8),
        ]
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess ? key : nil
    }
}
