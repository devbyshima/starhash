import Foundation

/// What StarHash keeps on its server, and when it sends it: the owner's
/// photo, under a random id their QR code carries; their Show My Name
/// listing (their numbers with their name, that photo's id, and the public
/// key requests to them are sealed to); and the daily count, a random id
/// once each Kigali day StarHash is used; and, in a build with push
/// (`STARHASH_PUSH`), the token APNs gave this iPhone, tied to the
/// listing's key while the owner takes requests from anywhere, so a
/// request wakes StarHash. Requests go their own way (`RequestsAnywhere`),
/// sealed. Nothing else ever goes: no payment, no contact, no place.
///
/// Every send that does not reach the server, offline say, is made again:
/// the photo on the next `wake` until the server takes it, the listing
/// and the push token until the server has what the owner shows, and the
/// day until it is counted. Delete All Data keeps what the server still holds through the
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
        /// Ties `token` to the key, so a request to the numbers it lists
        /// wakes this iPhone, in place of `replacing`, the token sent
        /// before: whether the server took it. It takes one only from a key
        /// listed with requests on.
        func registerPush(_ token: PushToken, replacing: String?, key: String) async -> Bool
        /// Unties the token `hex` from the key: whether the server took it.
        func removePush(_ hex: String, key: String) async -> Bool
    }

    /// The owner's secret key, made once: nil when it cannot be read or
    /// made, and nothing that needs it is sent.
    public typealias KeySource = @MainActor () async -> String?
    /// The owner's photo as the server keeps it, nil when they have none.
    public typealias PhotoSource = @MainActor () -> Data?
    /// Whether the owner has a photo, without reading it: what their QR
    /// code and listing ask, often, while it is drawn.
    public typealias HasPhoto = @MainActor () -> Bool

    /// The public key requests to the owner are sealed to, while they take
    /// requests from anywhere; nil otherwise.
    public typealias PublicKeySource = @MainActor () -> String?

    /// What the owner's Show My Name listing holds.
    public struct Listing: Equatable, Sendable {
        public var numbers: [String]
        public var name: String
        public var photo: UUID?
        /// The public key requests to them are sealed to
        /// (`RequestsAnywhere`), when they take them.
        public var key: String?

        public init(numbers: [String], name: String, photo: UUID?, key: String? = nil) {
            self.numbers = numbers
            self.name = name
            self.photo = photo
            self.key = key
        }

        /// One line that changes whenever the listing does. Without a key
        /// it reads as it did before keys, so an update sends nothing new.
        public var state: String {
            let parts = [numbers.joined(separator: ","), name, photo?.uuidString ?? ""] + (key.map { [$0] } ?? [])
            return parts.joined(separator: "|")
        }
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
        /// The token APNs gave this iPhone (`PushToken.state`).
        static let pushToken = "cloudPushToken"
        /// The token the server has, and when it took it.
        static let pushSent = "cloudPushSent"
        static let pushSentAt = "cloudPushSentAt"
    }

    /// What was last sent when the owner has no listing.
    static let unlisted = "off"
    /// The server drops a listing, and a push token, unseen for 45 days:
    /// each is sent again after a week.
    static let listingRefresh: TimeInterval = 7 * 86_400

    private let server: any Server
    private let key: KeySource
    private let owner: Owner
    private let photo: PhotoSource
    private let hasPhoto: HasPhoto
    private let publicKey: PublicKeySource
    private let defaults: UserDefaults
    private let version: String
    /// Whether this build may have push (`STARHASH_PUSH`, which only a
    /// paid team can sign): without it no token is sent, and one an
    /// earlier build sent is removed.
    private let pushEnabled: Bool
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
    /// A token sent or removed on its way, and the moment of a change made
    /// meanwhile, worked out again after it.
    private var pushSending = false
    private var pushWaiting: Date?
    /// The token APNs gave, kept in memory too: it is the iPhone's, not the
    /// owner's, so Delete All Data's wipe of the settings leaves it here,
    /// and it goes with the owner's listing once they list again.
    private var pushToken: PushToken?
    /// Every send on its way, so tests can wait for them (`settle`).
    private var running: [UUID: Task<Void, Never>] = [:]

    public init(
        server: any Server,
        key: @escaping KeySource,
        owner: Owner,
        photo: @escaping PhotoSource,
        hasPhoto: @escaping HasPhoto,
        publicKey: @escaping PublicKeySource = { nil },
        defaults: UserDefaults = .standard,
        version: String,
        isSimulator: Bool,
        pushEnabled: Bool = false
    ) {
        self.server = server
        self.key = key
        self.owner = owner
        self.photo = photo
        self.hasPhoto = hasPhoto
        self.publicKey = publicKey
        self.defaults = defaults
        self.version = version
        self.isSimulator = isSimulator
        self.pushEnabled = pushEnabled
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
    /// numbers, name and photo, and the key requests to them are sealed to
    /// while they take them, or nil when there is nothing to list (Show My
    /// Name off, no number yet, or neither a name nor a photo to show).
    public var listing: Listing? {
        let numbers = [owner.defaultSIM, owner.otherSIM].compactMap { $0 }.filter(\.isRwandanMobile).map(\.destination)
        let name = owner.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let photo = sharedPhotoID
        guard Preferences.showMyName.value(in: defaults), !numbers.isEmpty, !name.isEmpty || photo != nil else { return nil }
        return Listing(numbers: numbers, name: name, photo: photo, key: publicKey())
    }

    /// The owner's name, numbers, photo or Show My Name changed: the
    /// listing is sent when it differs from what the server has, or is a
    /// week old, and cleared there once there is none.
    public func ownerChanged(at now: Date = .now) {
        sendListing(listing, at: now)
    }

    /// The push token follows: once the server has the listing as it
    /// stands, or straight away when nothing is to be sent.
    private func sendListing(_ listing: Listing?, at now: Date) {
        guard !isSimulator else { return }
        let state = listing?.state ?? Self.unlisted
        let sent = defaults.string(forKey: Key.listingState)
        let stale = now.timeIntervalSince1970 - defaults.double(forKey: Key.listingSentAt) > Self.listingRefresh
        // Never listed and nothing to list: nothing to clear either.
        guard sent != nil || listing != nil, state != sent || (listing != nil && stale) else {
            syncPush(at: now)
            return
        }
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
            } else {
                syncPush(at: now)
            }
        }
    }

    // MARK: Push

    /// What to do about the push token on the server (`pushStep`).
    public enum PushStep: Equatable, Sendable {
        /// The server has what it should.
        case keep
        /// Tie the token to the owner's key, in place of the token sent
        /// before, when it was another.
        case register(PushToken, replacing: String?)
        /// Untie the token sent before.
        case remove(String)
    }

    /// The owner's listing, as far as a push to them goes.
    public enum ListingForPush: Sendable {
        /// The server lists them, as they stand now, with the key requests
        /// to them are sealed to.
        case takesRequests
        /// A listing the server does not have yet is on its way, or failed
        /// to reach it: the token waits, as the server takes one only from
        /// a key it lists.
        case onItsWay
        /// Nothing listed, or listed without taking requests: nothing to
        /// wake StarHash for.
        case notTaking
    }

    /// The rule: the token is on the server only while the owner takes
    /// requests from anywhere (Show My Name on, with its key), wants word
    /// of them (Settings, Notifications, Requests) and has a build with
    /// push; then it is sent again each week, as the listing is, so it
    /// never lapses there. Otherwise the one sent before is removed.
    public static func pushStep(
        token: PushToken?, listing: ListingForPush, notifies: Bool, sent: PushToken?, sentAt: Date, now: Date
    ) -> PushStep {
        let wanted: PushToken?
        switch listing {
        case .onItsWay: return .keep
        case .notTaking: wanted = nil
        case .takesRequests: wanted = notifies ? token : nil
        }
        guard let wanted else { return sent.map { .remove($0.hex) } ?? .keep }
        if wanted == sent, now.timeIntervalSince(sentAt) <= listingRefresh { return .keep }
        return .register(wanted, replacing: sent.flatMap { $0.hex == wanted.hex ? nil : $0.hex })
    }

    /// iOS gave StarHash its token (at each launch, in a build with push):
    /// it goes to the server when the owner takes requests, replacing the
    /// one before when it changed.
    public func pushTokenReceived(_ token: PushToken, at now: Date = .now) {
        pushToken = token
        defaults.set(token.state, forKey: Key.pushToken)
        syncPush(at: now)
    }

    /// The owner chose whether to hear of requests (Settings,
    /// Notifications): the token goes, or comes back.
    public func requestNotificationsChanged(at now: Date = .now) {
        syncPush(at: now)
    }

    private var currentPushToken: PushToken? {
        guard pushEnabled else { return nil }
        return pushToken ?? defaults.string(forKey: Key.pushToken).flatMap(PushToken.init(state:))
    }

    private var listingForPush: ListingForPush {
        guard let listing, listing.key != nil else { return .notTaking }
        return defaults.string(forKey: Key.listingState) == listing.state ? .takesRequests : .onItsWay
    }

    private func syncPush(at now: Date) {
        guard !isSimulator else { return }
        guard !pushSending else {
            pushWaiting = now
            return
        }
        let step = Self.pushStep(
            token: currentPushToken,
            listing: listingForPush,
            notifies: Preferences.requestNotifications.value(in: defaults),
            sent: defaults.string(forKey: Key.pushSent).flatMap(PushToken.init(state:)),
            sentAt: Date(timeIntervalSince1970: defaults.double(forKey: Key.pushSentAt)),
            now: now
        )
        guard step != .keep else { return }
        pushSending = true
        start { [self] in
            let key = await key()
            switch step {
            case .register(let token, let replacing):
                if let key, await server.registerPush(token, replacing: replacing, key: key) {
                    defaults.set(token.state, forKey: Key.pushSent)
                    defaults.set(now.timeIntervalSince1970, forKey: Key.pushSentAt)
                }
            case .remove(let hex):
                if let key, await server.removePush(hex, key: key) {
                    defaults.removeObject(forKey: Key.pushSent)
                    defaults.removeObject(forKey: Key.pushSentAt)
                }
            case .keep:
                break
            }
            pushSending = false
            if let waiting = pushWaiting {
                pushWaiting = nil
                syncPush(at: waiting)
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
    /// the listing last sent, which is cleared now (with the record wiped
    /// too, the owner would pass for one never listed and their name would
    /// stay there); and the push token, removed now for the same reason.
    /// What else runs before or after it does not matter: it decides from
    /// its own record, not the photo or the owner.
    public func erase(through wipe: () -> Void) {
        let sent = defaults.string(forKey: Key.listingState)
        let photoToDelete = defaults.string(forKey: Key.photoToDelete) ?? defaults.string(forKey: Key.photoID)
        let pushSent = defaults.string(forKey: Key.pushSent)
        wipe()
        if let pushSent {
            defaults.set(pushSent, forKey: Key.pushSent)
            syncPush(at: .now)
        }
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
