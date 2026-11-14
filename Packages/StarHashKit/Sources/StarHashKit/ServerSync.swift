import Foundation

/// What StarHash keeps on its server, and when it sends it: the owner's
/// photo, under a random id their QR code carries; their Show My Name
/// listing (their numbers with their name and that photo's id); and the
/// daily count, a random id once each Kigali day StarHash is used. Nothing
/// else ever goes: no payment, no contact, no place.
///
/// Every send that does not reach the server, offline say, is made again:
/// the photo on the next `wake` until the server takes it, the listing
/// until the server has what the owner shows, and the day until it is
/// counted. Delete All Data keeps what the server still holds through the
/// wipe (`erase(through:)`) and deletes it there after.
///
/// The server and the secret key that proves the owner's photo and listing
/// are theirs sit behind its seam: the app's `StarHashCloud` speaks HTTP
/// and the Keychain, and tests hand in a server in memory and a fixed key.
@MainActor
public final class ServerSync {
    /// What the server made of a photo sent or deleted.
    public enum PhotoAnswer: Sendable {
        /// Saved, deleted, or already gone.
        case taken
        /// The id is held under another key.
        case notYours
        /// Not reached, or refused for another reason: try again later.
        case failed
    }

    /// StarHash's server, as `ServerSync` needs it.
    @MainActor
    public protocol Server {
        /// Puts `data` under `id`, or deletes what is there when it is nil.
        func sendPhoto(_ data: Data?, id: UUID, key: String) async -> PhotoAnswer
        /// Puts the owner's listing, or deletes it when it is nil: whether
        /// the server took it.
        func sendListing(_ listing: Listing?, key: String) async -> Bool
        /// Counts this copy of StarHash as used today: whether the server
        /// counted it.
        func ping(installID: String, version: String) async -> Bool
    }

    /// The owner's secret key, made once: nil when it cannot be read or
    /// made, and nothing that needs it is sent.
    public typealias KeySource = @MainActor () async -> String?
    /// The owner's photo as the server keeps it, nil when they have none.
    public typealias PhotoSource = @MainActor () -> Data?
    /// Whether the owner has a photo, without reading it: what their QR
    /// code and listing ask, often, while it is drawn.
    public typealias HasPhoto = @MainActor () -> Bool

    /// What the owner's Show My Name listing holds.
    public struct Listing: Equatable, Sendable {
        public var numbers: [String]
        public var name: String
        public var photo: UUID?

        public init(numbers: [String], name: String, photo: UUID?) {
            self.numbers = numbers
            self.name = name
            self.photo = photo
        }

        /// One line that changes whenever the listing does.
        public var state: String { [numbers.joined(separator: ","), name, photo?.uuidString ?? ""].joined(separator: "|") }
    }

    /// The keys StarHash has always kept these under, so an update picks up
    /// where the last version left off.
    enum Key {
        static let photoID = "cloudPhotoID"
        /// Set from a photo change until the server has taken it.
        static let photoUnsent = "cloudPhotoUnsent"
        /// A photo's id whose delete the server has not confirmed, kept
        /// through Delete All Data.
        static let photoToDelete = "cloudPhotoToDelete"
        static let listingState = "cloudDirectoryState"
        static let listingSentAt = "cloudDirectorySentAt"
        static let lastPingDay = "cloudLastPingDay"
        static let installID = "cloudInstallID"
    }

    /// What was last sent when the owner has no listing.
    static let unlisted = "off"
    /// The server drops a listing unseen for 45 days: it is sent again
    /// after a week.
    static let listingRefresh: TimeInterval = 7 * 86_400

    private let server: any Server
    private let key: KeySource
    private let owner: Owner
    private let photo: PhotoSource
    private let hasPhoto: HasPhoto
    private let defaults: UserDefaults
    private let version: String
    /// The Simulator never lists the owner or counts the day, so test
    /// owners stay off the server and test runs out of the numbers. The
    /// photo goes, as a scanned code needs it.
    private let isSimulator: Bool

    /// Counts the photo's sends, so only the latest one's answer decides
    /// whether the photo is still unsent.
    private var photoSends = 0
    private var listingSending = false
    /// A change made while a listing was on its way, sent after it.
    private var listingWaiting = false
    /// A ping on its way, so coming back to the front while it is out
    /// sends no second one.
    private var pinging = false
    /// Every send on its way, so tests can wait for them (`settle`).
    private var running: [UUID: Task<Void, Never>] = [:]

    public init(
        server: any Server,
        key: @escaping KeySource,
        owner: Owner,
        photo: @escaping PhotoSource,
        hasPhoto: @escaping HasPhoto,
        defaults: UserDefaults = .standard,
        version: String,
        isSimulator: Bool
    ) {
        self.server = server
        self.key = key
        self.owner = owner
        self.photo = photo
        self.hasPhoto = hasPhoto
        self.defaults = defaults
        self.version = version
        self.isSimulator = isSimulator
    }

    // MARK: The owner's photo

    /// The id the owner's code carries for their photo, when they have one.
    public var sharedPhotoID: UUID? {
        hasPhoto() ? photoID : nil
    }

    /// The photo's id, made once.
    private var photoID: UUID {
        if let saved = defaults.string(forKey: Key.photoID).flatMap(UUID.init(uuidString:)) { return saved }
        let made = UUID()
        defaults.set(made.uuidString, forKey: Key.photoID)
        return made
    }

    /// The owner's photo was set, replaced or removed: it goes to the
    /// server, or is deleted there, and is sent again on each `wake` until
    /// the server has taken it.
    public func photoChanged() {
        defaults.set(true, forKey: Key.photoUnsent)
        photoSends += 1
        let send = photoSends
        let id = photoID
        let data = photo()
        start { [self] in
            let answer = await sendPhoto(data, id: id)
            if data == nil, answer != .failed { forgetPhotoToDelete(id) }
            guard send == photoSends else { return }
            switch answer {
            case .taken:
                defaults.removeObject(forKey: Key.photoUnsent)
            case .notYours where data != nil:
                // The id belongs to a key this iPhone does not have: one
                // restored from a backup made before the key went into
                // backups. A new id takes the photo, and the listing
                // follows it.
                defaults.removeObject(forKey: Key.photoID)
                photoChanged()
                ownerChanged()
            case .notYours:
                // Nothing this iPhone can delete.
                defaults.removeObject(forKey: Key.photoUnsent)
            case .failed:
                break
            }
        }
    }

    /// A photo Delete All Data left on the server, deleted until the server
    /// confirms it.
    private func deleteLeftoverPhoto() {
        guard let id = defaults.string(forKey: Key.photoToDelete).flatMap(UUID.init(uuidString:)) else { return }
        start { [self] in
            if await sendPhoto(nil, id: id) != .failed { forgetPhotoToDelete(id) }
        }
    }

    private func forgetPhotoToDelete(_ id: UUID) {
        guard defaults.string(forKey: Key.photoToDelete) == id.uuidString else { return }
        defaults.removeObject(forKey: Key.photoToDelete)
    }

    private func sendPhoto(_ data: Data?, id: UUID) async -> PhotoAnswer {
        guard let key = await key() else { return .failed }
        return await server.sendPhoto(data, id: id, key: key)
    }

    // MARK: Show My Name

    /// What the owner's listing should be now: their Rwandan mobile
    /// numbers, name and photo, or nil when there is nothing to list (Show
    /// My Name off, no number yet, or neither a name nor a photo to show).
    public var listing: Listing? {
        let numbers = [owner.defaultSIM, owner.otherSIM].compactMap { $0 }.filter(\.isRwandanMobile).map(\.destination)
        let name = owner.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let photo = sharedPhotoID
        guard Preferences.showMyName.value(in: defaults), !numbers.isEmpty, !name.isEmpty || photo != nil else { return nil }
        return Listing(numbers: numbers, name: name, photo: photo)
    }

    /// The owner's name, numbers, photo or Show My Name changed: the
    /// listing is sent when it differs from what the server has, or is a
    /// week old, and cleared there once there is none.
    public func ownerChanged(at now: Date = .now) {
        sendListing(listing, at: now)
    }

    private func sendListing(_ listing: Listing?, at now: Date) {
        guard !isSimulator else { return }
        let state = listing?.state ?? Self.unlisted
        let sent = defaults.string(forKey: Key.listingState)
        let stale = now.timeIntervalSince1970 - defaults.double(forKey: Key.listingSentAt) > Self.listingRefresh
        // Never listed and nothing to list: nothing to clear either.
        if sent == nil, listing == nil { return }
        guard state != sent || (listing != nil && stale) else { return }
        guard !listingSending else {
            listingWaiting = true
            return
        }
        listingSending = true
        start { [self] in
            let taken: Bool
            if let key = await key() {
                taken = await server.sendListing(listing, key: key)
            } else {
                taken = false
            }
            if taken {
                defaults.set(state, forKey: Key.listingState)
                defaults.set(now.timeIntervalSince1970, forKey: Key.listingSentAt)
            }
            listingSending = false
            if listingWaiting {
                listingWaiting = false
                ownerChanged()
            }
        }
    }

    // MARK: The daily count

    /// Counts this copy as used today, once each day by Kigali's calendar,
    /// as the server counts days. The day is marked only once the server
    /// has counted it.
    private func pingIfDue(at now: Date) {
        guard !isSimulator else { return }
        let day = Self.kigaliDay(of: now)
        guard !pinging, defaults.string(forKey: Key.lastPingDay) != day else { return }
        pinging = true
        let id = installID
        start { [self] in
            let counted = await server.ping(installID: id, version: version)
            pinging = false
            if counted { defaults.set(day, forKey: Key.lastPingDay) }
        }
    }

    /// A random id made on the first count, and nothing else about the
    /// owner.
    private var installID: String {
        if let saved = defaults.string(forKey: Key.installID) { return saved }
        let made = UUID().uuidString.lowercased()
        defaults.set(made, forKey: Key.installID)
        return made
    }

    /// "2026-11-08": the date in Kigali, as the server writes a day.
    public nonisolated static func kigaliDay(of date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Kigali") ?? TimeZone(secondsFromGMT: 2 * 3600)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: Coming to the front, and Delete All Data

    /// StarHash came to the front: today is counted, the listing is sent
    /// again when it changed or is a week old, and the photo, or a photo
    /// left to delete, goes again if the server has not taken it.
    public func wake(at now: Date = .now) {
        pingIfDue(at: now)
        ownerChanged(at: now)
        deleteLeftoverPhoto()
        if defaults.bool(forKey: Key.photoUnsent) { photoChanged() }
    }

    /// Delete All Data: `wipe` erases the settings, and what the server may
    /// still hold from this iPhone is kept through it and deleted there
    /// after. A photo ever given an id, which `wake` deletes until the
    /// server confirms, with the key the Keychain keeps through the wipe;
    /// and the listing last sent, which is cleared now (with the record
    /// wiped too, the owner would pass for one never listed and their name
    /// would stay there). What else runs before or after it does not
    /// matter: it decides from its own record, not the photo or the owner.
    public func erase(through wipe: () -> Void) {
        let sent = defaults.string(forKey: Key.listingState)
        let photoToDelete = defaults.string(forKey: Key.photoToDelete) ?? defaults.string(forKey: Key.photoID)
        wipe()
        if let photoToDelete {
            defaults.set(photoToDelete, forKey: Key.photoToDelete)
            deleteLeftoverPhoto()
        }
        if let sent, sent != Self.unlisted {
            defaults.set(sent, forKey: Key.listingState)
            sendListing(nil, at: .now)
        }
    }

    // MARK: Sends on their way

    private func start(_ work: @escaping @MainActor () async -> Void) {
        let id = UUID()
        running[id] = Task { [self] in
            await work()
            running[id] = nil
        }
    }

    /// Waits until every send on its way, and every send those started, is
    /// done. For tests.
    func settle() async {
        while let task = running.values.first {
            await task.value
        }
    }
}
