import Foundation

extension Recipient {
    /// Who a payment goes to, whatever name either side saved it under:
    /// the same number or code, of the same kind. A recipient's own
    /// equality takes its name in too, so "the same person" asks this.
    public struct Identity: Hashable, Sendable {
        public let kind: Kind
        public let destination: String
    }

    public var identity: Identity { Identity(kind: kind, destination: destination) }
}

/// A saved contact with the numbers and codes it can be paid at.
public protocol RecipientContact {
    var name: String { get }
    /// One recipient per distinct number or code, named after the contact.
    var recipients: [Recipient] { get }
}

/// What the recipient list shows for what is typed, each person or till
/// once: Nearby before anything is typed, the saved recipients a typed
/// number or code belongs to, then Recent and Contacts. The picker hands
/// it what the owner's settings let it read, and lays out what it says.
public struct RecipientList<Contact: RecipientContact> {
    public let search: RecipientSearch
    /// Paid where the phone is now; only before anything is typed, since a
    /// search is looking for someone in particular.
    public let nearby: [Recipient]
    /// Past recipients matching the search, less any Nearby or the typed
    /// number already shows, and, while searching, less a number that
    /// belongs to a contact with several, whose row offers them all.
    public let recents: [Recipient]
    /// Contacts matching the search, less one holding the typed number,
    /// and, while searching, less a one-number contact Recent shows.
    public let contacts: [Contact]
    /// Saved recipients (contacts first, then past ones with a name) whose
    /// number or code is exactly the one typed, one per name: they take the
    /// top of the list in the bare number's place.
    public let savedMatches: [Recipient]

    public init(query: String, nearby: [Recipient], recents: [Recipient], namedPast: [Recipient], contacts: [Contact]) {
        let search = RecipientSearch(query: query)
        let typed = search.typedRecipient?.identity
        func isTyped(_ recipient: Recipient) -> Bool { recipient.identity == typed }

        self.search = search
        self.nearby = search.isEmpty ? nearby : []
        let nearbyShown = Set(self.nearby.map(\.identity))
        let matchingRecents = recents.filter {
            search.matches($0) && !isTyped($0) && !nearbyShown.contains($0.identity)
        }
        let matchingContacts = contacts.filter { search.matches($0) && !$0.recipients.contains(where: isTyped) }

        if search.isEmpty {
            self.recents = matchingRecents
            self.contacts = matchingContacts
        } else {
            let inMultiNumberContacts = Set(matchingContacts.filter { $0.recipients.count > 1 }.flatMap { $0.recipients.map(\.identity) })
            self.recents = matchingRecents.filter { !inMultiNumberContacts.contains($0.identity) }
            let recentShown = Set(matchingRecents.map(\.identity))
            self.contacts = matchingContacts.filter { !($0.recipients.count == 1 && recentShown.contains($0.recipients[0].identity)) }
        }

        if typed != nil {
            var names = Set<String>()
            savedMatches = (contacts.flatMap(\.recipients) + namedPast).filter {
                isTyped($0) && names.insert(($0.name ?? "").lowercased()).inserted
            }
        } else {
            savedMatches = []
        }
    }

    /// What the keyboard's Search key pays: the saved recipient the typed
    /// number or code belongs to, or the number or code itself.
    public var typed: Recipient? { savedMatches.first ?? search.typedRecipient }

    /// A search that finds no one: no number typed, and no past recipient
    /// or contact matches.
    public var findsNothing: Bool {
        !search.isEmpty && search.typedRecipient == nil && recents.isEmpty && contacts.isEmpty
    }
}

/// What is typed in the recipient list's search field: a name, or digits
/// of a number or code ("250" in front read as "0").
public struct RecipientSearch: Sendable {
    public let query: String

    public init(query: String) {
        self.query = query
    }

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasLetters: Bool { trimmed.contains(where: \.isLetter) }
    private var digits: String { trimmed.filter { $0.isASCII && $0.isNumber } }

    public var isEmpty: Bool { trimmed.isEmpty }

    /// What to mark in names: the query when it searches names, nothing
    /// when it is a number.
    public var nameQuery: String { hasLetters ? trimmed : "" }

    /// The typed number or code itself, when the field holds digits only.
    public var typedRecipient: Recipient? {
        guard !hasLetters, !digits.isEmpty else { return nil }
        return Recipient(input: trimmed)
    }

    /// The digit strings to look for: what was typed, and its local form
    /// when it starts with the country code.
    private var digitNeedles: [String] {
        var needles = [digits]
        if digits.hasPrefix("250"), digits.count > 3 { needles.append("0" + digits.dropFirst(3)) }
        return needles
    }

    public func matches(name: String?, destinations: [String]) -> Bool {
        if isEmpty { return true }
        if hasLetters { return name?.localizedStandardContains(trimmed) ?? false }
        return destinations.contains { destination in
            digitNeedles.contains { destination.contains($0) }
        }
    }

    public func matches(_ recipient: Recipient) -> Bool {
        matches(name: recipient.name, destinations: [recipient.destination])
    }

    public func matches(_ contact: some RecipientContact) -> Bool {
        matches(name: contact.name, destinations: contact.recipients.map(\.destination))
    }
}
