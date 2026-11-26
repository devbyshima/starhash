import Foundation
import Testing
@testable import StarHashKit

@Suite("People Nearby")
struct PeopleNearbyTests {
    static let photo = UUID(uuidString: "3F2A1B4C-0000-4000-8000-123456789ABC")!
    static let mtn = Recipient(destination: "0788123456", kind: .phone)

    // MARK: What a phone announces

    @Test func anAnnouncementReadsBackAsItWasMade() throws {
        let made = try #require(PeopleNearby.Announcement(name: "Ariane", photoID: Self.photo, number: Self.mtn))
        #expect(PeopleNearby.Announcement(discoveryInfo: made.discoveryInfo) == made)
        #expect(made.discoveryInfo["p"] == "3f2a1b4c-0000-4000-8000-123456789abc")
    }

    /// Anyone nearby can read it, so the number is never in it.
    @Test func anAnnouncementNeverCarriesTheNumber() throws {
        let made = try #require(PeopleNearby.Announcement(name: "Ariane", photoID: nil, number: Self.mtn))
        #expect(!made.discoveryInfo.values.contains { $0.contains("788123456") })
        #expect(made.discoveryInfo["p"] == nil)
    }

    @Test func onlyAnOwnerATapCouldPayAndTellApartIsAnnounced() {
        // No number, or one that is no Rwandan mobile number.
        #expect(PeopleNearby.Announcement(name: "Ariane", photoID: nil, number: nil) == nil)
        #expect(PeopleNearby.Announcement(name: "Ariane", photoID: nil, number: Recipient(destination: "020205", kind: .merchant)) == nil)
        // No name, even with a photo.
        #expect(PeopleNearby.Announcement(name: "  ", photoID: Self.photo, number: Self.mtn) == nil)
    }

    @Test func aNameIsTrimmedAndCutToShowMyNamesLength() throws {
        let long = String(repeating: "a", count: 80)
        let made = try #require(PeopleNearby.Announcement(name: "  \(long)\n", photoID: nil, number: Self.mtn))
        #expect(made.name.count == 60)
    }

    @Test func anAnnouncementStarHashCannotShowIsPassedOver() {
        #expect(PeopleNearby.Announcement(discoveryInfo: nil) == nil)
        // Another version of the service.
        #expect(PeopleNearby.Announcement(discoveryInfo: ["v": "2", "n": "Ariane"]) == nil)
        // No name.
        #expect(PeopleNearby.Announcement(discoveryInfo: ["v": "1", "n": " "]) == nil)
        // A photo id that is not one is dropped, the name kept.
        #expect(PeopleNearby.Announcement(discoveryInfo: ["v": "1", "n": "Ariane", "p": "nope"]) == .init(name: "Ariane"))
    }

    // MARK: What a tapped phone hands over

    @Test func aHandoffReadsBackAsItWasMade() throws {
        let made = try #require(PeopleNearby.Handoff(number: Self.mtn))
        #expect(PeopleNearby.Handoff(data: made.data) == made)
        #expect(made.number == "0788123456")
    }

    @Test func onlyARwandanMobileNumberIsHandedOverOrTaken() throws {
        #expect(PeopleNearby.Handoff(number: nil) == nil)
        #expect(PeopleNearby.Handoff(number: Recipient(destination: "020205", kind: .merchant)) == nil)
        func data(_ json: String) -> Data { Data(json.utf8) }
        #expect(PeopleNearby.Handoff(data: data(#"{"v":1,"number":"+250 722 123 456"}"#))?.number == "0722123456")
        #expect(PeopleNearby.Handoff(data: data(#"{"v":1,"number":"020205"}"#)) == nil)
        #expect(PeopleNearby.Handoff(data: data(#"{"v":1,"number":"0612345678"}"#)) == nil)
        #expect(PeopleNearby.Handoff(data: data(#"{"v":2,"number":"0788123456"}"#)) == nil)
        #expect(PeopleNearby.Handoff(data: data("nonsense")) == nil)
    }

    @Test func aPersonIsPaidUnderTheirNameAtTheNumberHandedOver() throws {
        let person = PeopleNearby.Person(id: "a", announcement: .init(name: "Ariane", photoID: Self.photo))
        let handoff = try #require(PeopleNearby.Handoff(number: Self.mtn))
        let recipient = person.recipient(handoff)
        #expect(recipient == Recipient(name: "Ariane", destination: "0788123456", kind: .phone))
        #expect(recipient.isPayable)
    }

    // MARK: Who is nearby

    static func person(_ id: String, _ name: String, photo: UUID? = nil) -> PeopleNearby.Person {
        PeopleNearby.Person(id: id, announcement: .init(name: name, photoID: photo))
    }

    @Test func theNewestComeFirstAndTheFoundAgainKeepTheirPlace() {
        var found = PeopleNearby.Found()
        found.found(Self.person("a", "Ariane"))
        found.found(Self.person("b", "Jean"))
        #expect(found.people.map(\.id) == ["b", "a"])
        // Ariane changed her name: found again, in the same place.
        found.found(Self.person("a", "Ariane I."))
        #expect(found.people.map(\.name) == ["Jean", "Ariane I."])
        found.lost(id: "b")
        #expect(found.people.map(\.id) == ["a"])
    }

    /// A phone that opens StarHash again comes back under a new id before
    /// its old one is lost: it shows once.
    @Test func aPhoneBackUnderANewIdShowsOnce() {
        var found = PeopleNearby.Found()
        found.found(Self.person("old", "Ariane", photo: Self.photo))
        found.found(Self.person("new", "Ariane", photo: Self.photo))
        #expect(found.people.map(\.id) == ["new"])
        // Two people with one name and no photo are two people.
        found.found(Self.person("x", "Jean"))
        found.found(Self.person("y", "Jean"))
        #expect(found.people.count == 3)
    }

    @Test func theRowShowsAtMostItsLimit() {
        var found = PeopleNearby.Found()
        for index in 0..<12 { found.found(Self.person("\(index)", "Person \(index)")) }
        #expect(found.row.count == PeopleNearby.rowLimit)
        #expect(found.row.first?.id == "11")
    }
}
