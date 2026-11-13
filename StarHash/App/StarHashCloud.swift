import Foundation
import Security
import StarHashKit
import UIKit

/// StarHash's server (`server/` in the repo): the one thing kept off the
/// iPhone. The owner's photo, whenever they have one, lives there under a
/// random id their code carries, so whoever scans the code
/// sees it; a secret key in the Keychain is needed to replace or delete it.
/// With Show My Name on (the default), their numbers are listed with their
/// name and that photo's id, so someone typing one of the numbers to pay
/// it sees who it is; the server keeps each number only as a keyed hash.
/// And once a day a random id, made on the first launch, says this copy of
/// StarHash is in use, with its version, so the people using it can be
/// counted. Nothing else is ever sent: no payment, no contact, no place.
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

    // MARK: Show My Name

    /// What the server lists for a number: the name its owner gave, and
    /// their photo's id.
    struct DirectoryEntry: Equatable, Sendable {
        var name: String?
        var photoID: UUID?
    }

    /// What the owner's listing should be now: their numbers, name and
    /// photo, or nil when there is nothing to list (Show My Name off, no
    /// number yet, or neither a name nor a photo to show).
    static func directoryListing(owner: Owner, showMyName: Bool) -> DirectoryListing? {
        let numbers = [owner.defaultSIM, owner.otherSIM].compactMap { $0?.destination }.filter(Self.isListable)
        let name = owner.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let photo = sharedPhotoID
        guard showMyName, !numbers.isEmpty, !name.isEmpty || photo != nil else { return nil }
        return DirectoryListing(numbers: numbers, name: name, photo: photo)
    }

    struct DirectoryListing: Equatable, Sendable {
        var numbers: [String]
        var name: String
        var photo: UUID?

        /// One line that changes whenever the listing does.
        var state: String { [numbers.joined(separator: ","), name, photo?.uuidString ?? ""].joined(separator: "|") }
    }

    /// Sends the owner's listing when it has changed, again once a week so
    /// the server keeps it (it drops listings unseen for 45 days), or
    /// clears it once there is none. A send that failed, offline say, is
    /// made again next time. The Simulator never lists, so test owners
    /// stay off the server, as they stay out of the count.
    static func syncDirectory(owner: Owner) {
        #if targetEnvironment(simulator)
        return
        #else
        let listing = directoryListing(owner: owner, showMyName: Preferences.showMyName.value())
        let state = listing?.state ?? Self.unlisted
        let defaults = UserDefaults.standard
        let sent = defaults.string(forKey: directoryStateKey)
        let sentAt = defaults.double(forKey: directorySentAtKey)
        let stale = Date.now.timeIntervalSince1970 - sentAt > 7 * 86400
        // Never listed and nothing to list: nothing to clear either.
        if sent == nil, listing == nil { return }
        guard state != sent || (listing != nil && stale) else { return }
        guard !syncingDirectory else {
            directorySyncWaiting = true
            return
        }
        syncingDirectory = true
        Task {
            let done = await Self.sendListing(listing)
            if done {
                defaults.set(state, forKey: directoryStateKey)
                defaults.set(Date.now.timeIntervalSince1970, forKey: directorySentAtKey)
            }
            syncingDirectory = false
            // A change made while that one was out.
            if directorySyncWaiting {
                directorySyncWaiting = false
                syncDirectory(owner: owner)
            }
        }
        #endif
    }

    /// Delete All Data: `erase` runs with what was last sent to the
    /// directory kept through it. With the owner's numbers gone there is no
    /// listing, so the next sync deletes theirs from the server, and keeps
    /// trying until it has; with the record wiped too, it took the owner
    /// for one never listed and left their name there for 45 days.
    static func keepingDirectoryState(through erase: () -> Void) {
        let defaults = UserDefaults.standard
        let sent = defaults.string(forKey: directoryStateKey)
        erase()
        if let sent { defaults.set(sent, forKey: directoryStateKey) }
    }

    /// Whether the server took it: a listing put, or none cleared.
    nonisolated private static func sendListing(_ listing: DirectoryListing?) async -> Bool {
        guard let key = await photoKey() else { return false }
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

    private static var syncingDirectory = false
    private static var directorySyncWaiting = false
    private static let unlisted = "off"
    private static let directoryStateKey = "cloudDirectoryState"
    private static let directorySentAtKey = "cloudDirectorySentAt"

    /// A Rwandan mobile number, as the server lists them.
    nonisolated static func isListable(_ number: String) -> Bool {
        number.count == 10 && number.allSatisfy { $0.isASCII && $0.isNumber }
            && ["072", "073", "078", "079"].contains(String(number.prefix(3)))
    }

    /// Looked-up numbers, found or not, kept for the run.
    private static var entries: [String: DirectoryEntry?] = [:]

    /// The name and photo listed for `number`, or nil when no one lists it
    /// or the server cannot be reached.
    static func entry(for number: String) async -> DirectoryEntry? {
        guard isListable(number) else { return nil }
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

    /// The owner's secret key, for their photo and their listing alike: 32
    /// random bytes, made once and kept in the Keychain, on this iPhone
    /// only. (Its Keychain account is still "photoKey", from when the photo
    /// was all it was for.)
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
