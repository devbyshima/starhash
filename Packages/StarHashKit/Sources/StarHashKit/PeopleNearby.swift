import Foundation

/// People Nearby: StarHash users close by, found while their StarHash is
/// open, whom a tap pays. Phones find each other with MultipeerConnectivity
/// (the app's `PeopleNearbyService`); what they say to each other is made
/// and read here, so it can be tested.
///
/// A phone its owner lets be seen announces their name and their photo's id,
/// never their number: anyone nearby can read an announcement. The number
/// goes only to a phone that taps them, over the connection the tap opens,
/// so that it can pay them.
public enum PeopleNearby {
    /// The Bonjour service both ends use. Info.plist lists it under
    /// `NSBonjourServices`, as `_starhash-near._tcp` and `._udp`.
    public static let serviceType = "starhash-near"

    /// The most faces Pay's row shows: a market can hold dozens.
    public static let rowLimit = 8

    /// How long a tap waits for the number before giving up: the other
    /// phone may have left, or locked.
    public static let reachTimeout: Duration = .seconds(10)

    /// Names as Show My Name keeps them, at most this long.
    static let maximumNameLength = 60

    // MARK: Announcement

    /// What a phone that may be seen tells everyone nearby: a name, and a
    /// photo's id when the owner has one on StarHash's server.
    public struct Announcement: Hashable, Sendable {
        public var name: String
        public var photoID: UUID?

        public init(name: String, photoID: UUID? = nil) {
            self.name = name
            self.photoID = photoID
        }

        /// What an owner announces, or nil when they are not one a tap
        /// could pay (no Rwandan mobile number) or tell apart (no name).
        public init?(name: String, photoID: UUID?, number: Recipient?) {
            guard let number, number.isRwandanMobile, let name = Self.clean(name) else { return nil }
            self.init(name: name, photoID: photoID)
        }

        /// One read from a phone nearby, or nil when it says nothing
        /// StarHash can show: from another version of the service, or with
        /// no name.
        public init?(discoveryInfo: [String: String]?) {
            guard let info = discoveryInfo, info[Key.version] == Self.version,
                  let name = info[Key.name].flatMap(Self.clean) else { return nil }
            self.init(name: name, photoID: info[Key.photo].flatMap(UUID.init(uuidString:)))
        }

        /// The announcement as Bonjour carries it: short keys, since
        /// everything in it travels in one small record.
        public var discoveryInfo: [String: String] {
            var info = [Key.version: Self.version, Key.name: name]
            if let photoID { info[Key.photo] = photoID.uuidString.lowercased() }
            return info
        }

        static let version = "1"

        enum Key {
            static let version = "v"
            static let name = "n"
            static let photo = "p"
        }

        /// A name trimmed and cut to Show My Name's length, or nil when
        /// nothing is left.
        static func clean(_ name: String) -> String? {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return String(trimmed.prefix(maximumNameLength))
        }
    }

    // MARK: Handoff

    /// The number a phone hands over to one that tapped it.
    public struct Handoff: Hashable, Sendable {
        public var number: String

        /// The owner's default SIM, or nil when it is no number a tap can
        /// pay.
        public init?(number: Recipient?) {
            guard let number, number.isRwandanMobile else { return nil }
            self.number = number.destination
        }

        /// One received, or nil for anything but a Rwandan mobile number
        /// from this version.
        public init?(data: Data) {
            guard let body = try? JSONDecoder().decode(Body.self, from: data), body.v == 1,
                  let number = Recipient(input: body.number), number.isRwandanMobile else { return nil }
            self.number = number.destination
        }

        public var data: Data {
            (try? JSONEncoder().encode(Body(v: 1, number: number))) ?? Data()
        }

        private struct Body: Codable {
            var v: Int
            var number: String
        }
    }

    // MARK: Who is nearby

    /// Someone found nearby, under the id their phone uses for this run.
    public struct Person: Hashable, Identifiable, Sendable {
        public let id: String
        public var announcement: Announcement

        public init(id: String, announcement: Announcement) {
            self.id = id
            self.announcement = announcement
        }

        public var name: String { announcement.name }
        public var photoID: UUID? { announcement.photoID }

        /// Who to pay, once their phone handed over its number.
        public func recipient(_ handoff: Handoff) -> Recipient {
            Recipient(name: name, destination: handoff.number, kind: .phone)
        }
    }

    /// Everyone found, newest first. Someone found again keeps their place,
    /// so faces don't jump about as phones come and go.
    public struct Found: Hashable, Sendable {
        public private(set) var people: [Person] = []

        public init(people: [Person] = []) {
            self.people = people
        }

        /// The faces Pay's row shows.
        public var row: [Person] { Array(people.prefix(PeopleNearby.rowLimit)) }

        public mutating func found(_ person: Person) {
            if let index = people.firstIndex(where: { $0.id == person.id }) {
                people[index] = person
                return
            }
            // A phone that opened StarHash again comes back under a new id
            // before its old one is lost. A photo's id is the owner's own,
            // so the same one under the same name is the same phone.
            if let photoID = person.photoID {
                people.removeAll { $0.photoID == photoID && $0.name == person.name }
            }
            people.insert(person, at: 0)
        }

        public mutating func lost(id: String) {
            people.removeAll { $0.id == id }
        }

        public mutating func removeAll() {
            people.removeAll()
        }
    }
}
