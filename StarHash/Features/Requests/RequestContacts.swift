import StarHashKit
import SwiftUI

/// One number Request can ask through StarHash's server: a contact's, or
/// one typed in full.
struct RequestContactRow: Identifiable, Hashable {
    let recipient: Recipient
    /// The contact's name, nil for a number typed.
    let name: String?
    let contactID: String?
    let hasPhoto: Bool

    var id: String { recipient.destination }

    /// The name shown, or the number for one typed.
    var shownName: String { name ?? recipient.formattedDestination }

    /// The first word of the name, or the number, for what StarHash says
    /// back ("Ariane isn't on StarHash").
    var firstName: String {
        name.map { $0.split(separator: " ").first.map(String.init) ?? $0 } ?? recipient.formattedDestination
    }

    /// The contact's photo, their initials, or a silhouette for a number.
    var tile: RecipientRow.Tile {
        let initials: RecipientRow.Tile = name.map { .monogram(PayContact.initials(for: $0)) } ?? .shadow(seed: recipient.destination)
        guard let contactID, hasPhoto else { return initials }
        return .photo(contactID: contactID, fallback: initials)
    }
}

/// The people Request lists to ask through StarHash's server, for
/// Request's sheet and Request in Bulk alike.
@MainActor
enum RequestContacts {
    /// A number typed in full first, then the contacts' numbers matching
    /// the search, never the owner's own.
    static func rows(query: String, owner: Owner, contacts: PayContacts, enableContacts: Bool) -> [RequestContactRow] {
        let search = RecipientSearch(query: query)
        let own = Set([owner.defaultSIM, owner.otherSIM].compactMap { $0?.destination })
        var rows: [RequestContactRow] = []
        var seen = own
        if let typed = search.typedRecipient, typed.kind == .phone, typed.isRwandanMobile, !seen.contains(typed.destination) {
            let saved = enableContacts ? contacts.contacts.first { $0.recipients.contains { $0.destination == typed.destination } } : nil
            rows.append(RequestContactRow(recipient: typed, name: saved?.name, contactID: saved?.id, hasPhoto: saved?.hasPhoto ?? false))
            seen.insert(typed.destination)
        }
        guard enableContacts else { return rows }
        for contact in contacts.contacts where search.isEmpty || search.matches(contact) {
            for recipient in contact.recipients where recipient.kind == .phone && recipient.isRwandanMobile {
                guard seen.insert(recipient.destination).inserted else { continue }
                rows.append(RequestContactRow(recipient: recipient, name: contact.name, contactID: contact.id, hasPhoto: contact.hasPhoto))
            }
        }
        return rows
    }

    /// Every contact's Rwandan mobile number, and a number typed in full,
    /// for the directory to say which are on StarHash.
    static func numbers(query: String, contacts: PayContacts, enableContacts: Bool) -> [String] {
        let search = RecipientSearch(query: query)
        var numbers: [String] = []
        if let typed = search.typedRecipient, typed.kind == .phone, typed.isRwandanMobile { numbers.append(typed.destination) }
        if enableContacts {
            for contact in contacts.contacts {
                for recipient in contact.recipients where recipient.kind == .phone && recipient.isRwandanMobile {
                    numbers.append(recipient.destination)
                }
            }
        }
        return numbers
    }

    /// What Share Message hands the share sheet: the amount, the note and
    /// the owner's number, for someone to pay by hand.
    static func shareText(amount: Int, note: String, owner: Owner) -> String {
        let money = Money.formatWithCurrency(amount)
        let number = owner.defaultSIM?.formattedDestination ?? ""
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return if !note.isEmpty {
            String(starhash: "Could you send me \(money) for \(note)? My number is \(number).")
        } else {
            String(starhash: "Could you send me \(money)? My number is \(number).")
        }
    }
}

extension RequestsAnywhere.AskFailure {
    /// Why someone was not asked, with their first name.
    func message(name: String) -> String {
        switch self {
        case .notOnStarHash: String(starhash: "\(name) isn't on StarHash")
        case .takesNoRequests: String(starhash: "\(name) can't get requests on StarHash yet")
        case .alreadyAsked: String(starhash: "You already asked \(name). Their answer will show under Requests")
        case .tooMany: String(starhash: "You've sent 20 requests today. Ask again tomorrow")
        case .notListed: String(starhash: "Your name isn't on StarHash yet. Try again in a moment")
        case .failed: String(starhash: "Couldn't reach StarHash. Try again")
        }
    }

    /// Whether StarHash cannot ask them at all, so Share Message can.
    var offersShareMessage: Bool { self == .notOnStarHash || self == .takesNoRequests }
}
