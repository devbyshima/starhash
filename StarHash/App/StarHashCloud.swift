import Foundation
import Security
import StarHashKit
import UIKit

/// StarHash's server (`server/` in the repo), over HTTP. What StarHash
/// sends it, and when, is `ServerSync`'s (StarHashKit): this is its adapter,
/// `Server`, with the owner's secret key from the Keychain; requests are
/// `RequestsAnywhere`'s, through `RequestServer`, with the key they are
/// sealed to. The reads stay here, since no rule decides them: a scanned
/// code's photo, and who lists a number typed to pay.
@MainActor
enum StarHashCloud {
    nonisolated static let liveURL = URL(string: "https://starhash.devbyshima.workers.dev")!

    /// The live Worker, or in a Debug run `-server <url>`, a Worker run on
    /// the Mac (`npm run dev` in server/), for two Simulators to send each
    /// other requests through.
    nonisolated static let baseURL: URL = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-server"), flag + 1 < arguments.count,
           let url = URL(string: arguments[flag + 1]) { return url }
        #endif
        return liveURL
    }()

    /// Whether this run talks to the Worker on the Mac, which the Simulator
    /// may list owners on: none of them reach the live one.
    nonisolated static var isLocal: Bool { baseURL != liveURL }

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
                if let key = listing.key { body["key"] = key }
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

        func registerPush(_ token: PushToken, replacing: String?, key: String) async -> Bool {
            var body: [String: Any] = ["token": token.hex, "sandbox": token.sandbox]
            if let replacing { body["replaces"] = replacing }
            return await sendPush("PUT", body: body, key: key)
        }

        func removePush(_ hex: String, key: String) async -> Bool {
            await sendPush("DELETE", body: ["token": hex], key: key)
        }

        /// The token in a body, never in a URL.
        private func sendPush(_ method: String, body: [String: Any], key: String) async -> Bool {
            var request = URLRequest(url: baseURL.appending(path: "v1/push"))
            request.httpMethod = method
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
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

    /// What the server lists for a number: the name its owner gave, their
    /// photo's id, and the public key requests to them are sealed to.
    struct DirectoryEntry: Equatable, Sendable {
        var name: String?
        var photoID: UUID?
        var publicKey: String?
    }

    /// Looked-up numbers, found or not, kept for the run.
    private static var entries: [String: DirectoryEntry?] = [:]

    /// The name and photo listed for `number`, or nil when no one lists it
    /// or the server cannot be reached. Only a Rwandan mobile number is
    /// asked about, as only those are listed.
    static func entry(for number: String) async -> DirectoryEntry? {
        if case .listed(let entry) = await lookUp(number) { return entry }
        return nil
    }

    /// Who lists `number`, telling a number no one lists from a server not
    /// reached, which a request must not take for the same. `fresh` asks
    /// the server whatever this run already heard: a request trusts the key
    /// a number is listed under now, and someone may have joined since.
    static func lookUp(_ number: String, fresh: Bool = false) async -> Found {
        guard Recipient(destination: number, kind: .phone).isRwandanMobile else { return .notListed }
        #if DEBUG
        if let name = DebugLaunch.value(after: "-directoryName") {
            return .listed(DirectoryEntry(name: name))
        }
        #endif
        if !fresh, let kept = entries[number] { return kept.map(Found.listed) ?? .notListed }
        var request = URLRequest(url: baseURL.appending(path: "v1/directory/lookup"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["number": number])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return .failed }
        guard status == 200,
              let found = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            guard status == 404 else { return .failed }
            entries[number] = .some(nil)
            return .notListed
        }
        let entry = DirectoryEntry(
            name: (found["name"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            photoID: (found["photo"] as? String).flatMap(UUID.init(uuidString:)),
            publicKey: (found["key"] as? String).flatMap { RequestSeal.isPublicKey($0) ? $0 : nil }
        )
        entries[number] = entry
        return .listed(entry)
    }

    enum Found: Equatable, Sendable {
        case listed(DirectoryEntry)
        case notListed
        case failed
    }

    /// The most numbers the server checks in one go.
    private static let listedBatch = 500

    /// Which of `numbers` the directory lists, asked in one go (500 at a
    /// time) as Request opens, so the owner's contacts on StarHash come
    /// first. Only Rwandan mobile numbers are sent, in the request's body,
    /// and the server answers with nothing but which are listed and keeps
    /// nothing of the question. Numbers already looked up this run are
    /// answered from what was heard. Nil when the server cannot be reached.
    static func listed(among numbers: [String]) async -> Set<String>? {
        #if DEBUG
        // -directoryListed <n1,n2,...>: these listed, every other not, with
        // no server (the Simulator's contacts and screenshots).
        if let given = DebugLaunch.value(after: "-directoryListed") {
            return Set(given.split(separator: ",").map(String.init)).intersection(numbers)
        }
        #endif
        var listed: Set<String> = []
        var unknown: [String] = []
        for number in Set(numbers) where Recipient(destination: number, kind: .phone).isRwandanMobile {
            switch entries[number] {
            case .some(.some): listed.insert(number)
            case .some(.none): continue
            case .none: unknown.append(number)
            }
        }
        for start in stride(from: 0, to: unknown.count, by: listedBatch) {
            let batch = Array(unknown[start..<min(start + listedBatch, unknown.count)])
            var request = URLRequest(url: baseURL.appending(path: "v1/directory/lookup"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["numbers": batch])
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let found = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let answer = found["listed"] as? [String] else { return nil }
            listed.formUnion(answer)
        }
        return listed
    }

    // MARK: Requests

    /// What `RequestsAnywhere` asks of the server, over HTTP. The number
    /// asked travels in a body, never in a URL.
    struct RequestServer: RequestsAnywhere.Server {
        func lookUp(_ number: String) async -> RequestsAnywhere.LookUp {
            switch await StarHashCloud.lookUp(number, fresh: true) {
            case .listed(let entry): .listed(.init(name: entry.name, photoID: entry.photoID, key: entry.publicKey))
            case .notListed: .notListed
            case .failed: .failed
            }
        }

        func send(id: UUID, to number: String, from own: String, sealed: String, key: String) async -> RequestsAnywhere.SendAnswer {
            let body: [String: Any] = ["id": id.uuidString.lowercased(), "to": number, "from": own, "sealed": sealed]
            guard let (_, status) = await call("POST", "v1/requests", key: key, body: body) else { return .failed }
            return switch status {
            case 200: .sent
            case 404: .notOnStarHash
            case 409: .alreadyAsked
            case 429: .tooMany
            case 403: .notListed
            default: .failed
            }
        }

        func inbox(key: String) async -> RequestsAnywhere.Inbox? {
            guard let (data, status) = await call("GET", "v1/requests", key: key), status == 200,
                  let found = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let asked = (found["asked"] as? [[String: Any]] ?? []).compactMap { row -> RequestsAnywhere.Inbox.Asked? in
                guard let id = (row["id"] as? String).flatMap(UUID.init(uuidString:)) else { return nil }
                let created = (row["created_at"] as? String).flatMap(Self.date)
                let reminded = (row["reminded_at"] as? String).flatMap(Self.date)
                return .init(id: id, sealed: row["sealed"] as? String, key: row["key"] as? String, createdAt: created, remindedAt: reminded)
            }
            let answers = (found["answers"] as? [[String: Any]] ?? []).compactMap { row -> RequestsAnywhere.Inbox.Answer? in
                guard let id = (row["id"] as? String).flatMap(UUID.init(uuidString:)), let sealed = row["answer"] as? String else { return nil }
                return .init(id: id, sealed: sealed)
            }
            return .init(asked: asked, answers: answers)
        }

        func answer(id: UUID, sealed: String, key: String) async -> Bool {
            guard let (_, status) = await call("POST", "v1/requests/\(id.uuidString.lowercased())/answer", key: key, body: ["sealed": sealed])
            else { return false }
            // Gone, or no longer waiting: nothing left to answer.
            return [200, 404, 409].contains(status)
        }

        func close(id: UUID, key: String) async -> Bool {
            guard let (_, status) = await call("DELETE", "v1/requests/\(id.uuidString.lowercased())", key: key) else { return false }
            return status == 200 || status == 404
        }

        func erase(key: String) async -> Bool {
            await call("DELETE", "v1/requests", key: key)?.status == 200
        }

        func remind(id: UUID, key: String) async -> RequestsAnywhere.RemindAnswer {
            guard let (data, status) = await call("POST", "v1/requests/\(id.uuidString.lowercased())/remind", key: key) else { return .failed }
            switch status {
            case 200:
                let found = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                return .reminded((found?["reminded_at"] as? String).flatMap(Self.date) ?? .now)
            case 429: return .tooSoon
            case 409: return .notWaiting
            // 404 too: a Worker from before reminders has no such route.
            default: return .failed
            }
        }

        /// "2026-11-26T15:04:05.123Z", as the Worker writes a moment.
        private static func date(_ text: String) -> Date? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: text)
        }

        private func call(_ method: String, _ path: String, key: String, body: [String: Any]? = nil) async -> (data: Data, status: Int)? {
            var request = URLRequest(url: baseURL.appending(path: path))
            request.httpMethod = method
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            }
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let status = (response as? HTTPURLResponse)?.statusCode else { return nil }
            return (data, status)
        }
    }

    /// The key requests to the owner are sealed to: a Curve25519 key made
    /// once and kept in the Keychain, as the secret key is (into the
    /// iPhone's encrypted backups, never iCloud Keychain), so a restored
    /// iPhone still opens what was sealed to the old one. Only its public
    /// half leaves the iPhone, with the listing.
    static func requestKey() -> RequestSeal.PrivateKey? {
        if let kept = requestKeyKept { return kept }
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "StarHashCloud",
            kSecAttrAccount as String: "requestKey",
        ]
        var query = item
        query[kSecReturnData as String] = true
        var found: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
           let data = found as? Data, let key = RequestSeal.privateKey(raw: data) {
            requestKeyKept = key
            return key
        }
        let key = RequestSeal.makeKey()
        var add = item
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecValueData as String] = key.rawRepresentation
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { return nil }
        requestKeyKept = key
        return key
    }

    /// Read once a run: the listing asks for its public half often.
    private static var requestKeyKept: RequestSeal.PrivateKey?

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
