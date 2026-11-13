import Foundation
import Testing
@testable import StarHashKit

/// The recipient list, from what the picker hands it: each person or till
/// once, wherever else they show.
@Suite("The recipient list")
struct RecipientListTests {
    struct Contact: RecipientContact {
        let name: String
        let recipients: [Recipient]
        init(_ name: String, _ numbers: String...) {
            self.name = name
            recipients = numbers.map { Recipient(input: $0, name: name)! }
        }
    }

    static let aline = Contact("Aline Uwase", "0788123456")
    static let jean = Contact("Jean Mugisha", "0788111222", "0722333444")
    static let pili = Recipient(name: "Pili-Pili", destination: "020205", kind: .merchant)
    static let alineRecent = Recipient(name: "ALINE U", destination: "0788123456", kind: .phone)
    static let jeanRecent = Recipient(name: nil, destination: "0722333444", kind: .phone)

    static func list(_ query: String, nearby: [Recipient] = [], recents: [Recipient] = [alineRecent, jeanRecent, pili]) -> RecipientList<Contact> {
        RecipientList(query: query, nearby: nearby, recents: recents, namedPast: recents.filter { $0.name != nil }, contacts: [aline, jean])
    }

    @Test func nothingTypedShowsEverythingOnceNearbyFirst() {
        let list = Self.list("", nearby: [Self.pili])
        #expect(list.nearby == [Self.pili])
        #expect(list.recents.map(\.destination) == ["0788123456", "0722333444"])
        #expect(list.contacts.map(\.name) == ["Aline Uwase", "Jean Mugisha"])
        #expect(list.typed == nil)
    }

    /// A search is looking for someone in particular: Nearby steps aside.
    @Test func searchingHidesNearby() {
        #expect(Self.list("pili", nearby: [Self.pili]).nearby.isEmpty)
    }

    /// While searching, a one-number contact Recent already shows, and a
    /// recent number of a contact with several, show once.
    @Test func searchingShowsAPersonOnce() {
        let byName = Self.list("aline")
        #expect(byName.recents.map(\.destination) == ["0788123456"])
        #expect(byName.contacts.isEmpty)
        let byNumber = Self.list("0722")
        #expect(byNumber.recents.isEmpty)
        #expect(byNumber.contacts.map(\.name) == ["Jean Mugisha"])
    }

    /// A number typed whole is paid by the name it is saved under.
    @Test func aTypedNumberTakesItsSavedName() {
        let list = Self.list("+250 788 123 456")
        #expect(list.savedMatches.map(\.name) == ["Aline Uwase", "ALINE U"])
        #expect(list.typed?.name == "Aline Uwase")
        #expect(list.recents.isEmpty)
        #expect(list.contacts.isEmpty)
    }

    @Test func anUnknownNumberIsPaidAsTyped() {
        let list = Self.list("0788999000")
        #expect(list.savedMatches.isEmpty)
        #expect(list.typed?.destination == "0788999000")
        #expect(!list.findsNothing)
        #expect(Self.list("nobody").findsNothing)
    }

    @Test func identityIgnoresTheName() {
        #expect(Self.alineRecent.identity == Self.aline.recipients[0].identity)
        #expect(Self.alineRecent != Self.aline.recipients[0])
    }
}
