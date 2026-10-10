import Contacts
import StarHashKit
import SwiftUI

/// A contact as the recipient picker needs it: a name and the MoMo numbers
/// it can send to, already in local form ("0788 123 456").
struct PayContact: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// One recipient per distinct number, named after the contact. A saved
    /// number of fewer than 10 digits is a merchant code, as anywhere else
    /// in StarHash, so a till saved as a contact ("Moto", 020205) is paid
    /// as a merchant.
    let recipients: [Recipient]
    /// Whether the contact has a photo. The photo itself is loaded only
    /// when its row shows (`ContactPhotos`).
    let hasPhoto: Bool

    /// "AI" for "Ariane Ishimwe", "M" for "Moto".
    var initials: String { PayContact.initials(for: name) }

    static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace || $0 == "(" })
        let letters = words.prefix(2).compactMap { $0.first(where: \.isLetter) }
        return letters.isEmpty ? "#" : String(letters).uppercased()
    }
}

/// The person's contacts, read with their permission and only while the
/// "Enable contacts" preference is on. Reading happens off the main actor:
/// a few thousand contacts take long enough to drop frames. One list is
/// shared by the recipient picker and Pay's chosen-recipient chip.
@MainActor
@Observable
final class PayContacts {
    static let shared = PayContacts()

    enum Access: Equatable {
        case notDetermined
        case authorized
        /// iOS 18's "Limited Access": only the contacts the person picked.
        case limited
        case denied
    }

    private(set) var access: Access = PayContacts.currentAccess()
    private(set) var contacts: [PayContact] = [] {
        didSet {
            var withPhotos: [String: String] = [:]
            var byName: [String: String] = [:]
            var names: [String: String] = [:]
            for contact in contacts {
                for recipient in contact.recipients {
                    names[recipient.kind.rawValue + recipient.destination] = names[recipient.kind.rawValue + recipient.destination] ?? contact.name
                }
            }
            contactNames = names
            for contact in contacts where contact.hasPhoto {
                for recipient in contact.recipients {
                    withPhotos[recipient.kind.rawValue + recipient.destination] = withPhotos[recipient.kind.rawValue + recipient.destination] ?? contact.id
                }
                byName[PayContacts.nameKey(contact.name)] = byName[PayContacts.nameKey(contact.name)] ?? contact.id
            }
            photoContactIDs = withPhotos
            photoContactIDsByName = byName
        }
    }
    private(set) var hasLoaded = false
    /// Which contact's photo shows for a number or code, by kind and
    /// destination, so a recent recipient saved in Contacts shows their
    /// photo too.
    private var photoContactIDs: [String: String] = [:]
    /// The same by name, for money received: MTN's SMS hides most of the
    /// sender's number ("*********998") but gives their name.
    private var photoContactIDsByName: [String: String] = [:]
    /// Each saved number's or code's name in Contacts, by kind and
    /// destination.
    private var contactNames: [String: String] = [:]

    /// The name `recipient`'s number or code is saved under in Contacts,
    /// nil when it is not saved there.
    func contactName(for recipient: Recipient) -> String? {
        guard !recipient.destination.isEmpty else { return nil }
        return contactNames[recipient.kind.rawValue + recipient.destination]
    }

    /// Whether `recipient`'s number is saved in Contacts. Nearby remembers
    /// only numbers and codes that are not: a contact is already a tap away.
    func isContact(_ recipient: Recipient) -> Bool {
        contacts.contains { contact in
            contact.recipients.contains { $0.kind == recipient.kind && $0.destination == recipient.destination }
        }
    }

    /// The contact with a photo that `recipient`'s number or code belongs
    /// to, or failing that, a contact with a photo and the same name.
    func photoContactID(for recipient: Recipient) -> String? {
        if let id = photoContactIDs[recipient.kind.rawValue + recipient.destination] { return id }
        guard let name = recipient.name, !name.isEmpty else { return nil }
        return photoContactIDsByName[PayContacts.nameKey(name)]
    }

    /// Names compared without case, accents or extra spaces ("ARIANE
    /// ISHIMWE" is "Ariane Ishimwe").
    private static func nameKey(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Asks for access the first time, then reads every contact with a
    /// phone number.
    func load() async {
        if access == .notDetermined {
            _ = await PayContacts.requestAccess()
            access = PayContacts.currentAccess()
        }
        guard access == .authorized || access == .limited else {
            contacts = []
            hasLoaded = true
            return
        }
        contacts = await PayContacts.fetch()
        hasLoaded = true
    }

    /// Reads the contacts once when access is already granted, and never
    /// asks for it: for places other than the picker, which is where the
    /// permission prompt belongs.
    func loadIfAllowed() async {
        access = PayContacts.currentAccess()
        guard !hasLoaded, access == .authorized || access == .limited else { return }
        await load()
    }

    static func currentAccess() -> Access {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .limited: .limited
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }

    @concurrent
    private nonisolated static func requestAccess() async -> Bool {
        (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
    }

    @concurrent
    private nonisolated static func fetch() async -> [PayContact] {
        let keys: [any CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactOrganizationNameKey as any CNKeyDescriptor,
            CNContactPhoneNumbersKey as any CNKeyDescriptor,
            CNContactImageDataAvailableKey as any CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault
        var result: [PayContact] = []
        try? CNContactStore().enumerateContacts(with: request) { contact, _ in
            let formatted = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            let name = formatted.isEmpty ? contact.organizationName : formatted
            var seen = Set<String>()
            let recipients = contact.phoneNumbers.compactMap { labelled -> Recipient? in
                guard let recipient = Recipient(input: labelled.value.stringValue, name: name.isEmpty ? nil : name),
                      seen.insert(recipient.kind.rawValue + recipient.destination).inserted else { return nil }
                return recipient
            }
            guard !recipients.isEmpty else { return }
            result.append(PayContact(
                id: contact.identifier,
                name: name.isEmpty ? recipients[0].formattedDestination : name,
                recipients: recipients,
                hasPhoto: contact.imageDataAvailable
            ))
        }
        return result
    }
}

/// How the picker's search field matches. Letters search names; digits
/// (spaces and "+" ignored) search numbers and codes, so "0788", "788" and
/// "+250 788" all find 0788 123 456.
struct RecipientSearch {
    let query: String

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasLetters: Bool { trimmed.contains(where: \.isLetter) }
    private var digits: String { trimmed.filter { $0.isASCII && $0.isNumber } }

    var isEmpty: Bool { trimmed.isEmpty }

    /// What to mark in names: the query when it searches names, nothing
    /// when it is a number.
    var nameQuery: String { hasLetters ? trimmed : "" }

    /// The typed number or code itself, when the field holds digits only.
    var typedRecipient: Recipient? {
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

    func matches(name: String?, destinations: [String]) -> Bool {
        if isEmpty { return true }
        if hasLetters { return name?.localizedStandardContains(trimmed) ?? false }
        return destinations.contains { destination in
            digitNeedles.contains { destination.contains($0) }
        }
    }

    func matches(_ recipient: Recipient) -> Bool {
        matches(name: recipient.name, destinations: [recipient.destination])
    }

    func matches(_ contact: PayContact) -> Bool {
        matches(name: contact.name, destinations: contact.recipients.map(\.destination))
    }
}

extension Recipient {
    /// The name to show: the one its number or code is saved under in
    /// Contacts, while contacts are on, ahead of any other (the name a
    /// wallet's message gave, or a merchant's registered name), since it is
    /// the name the owner chose; otherwise `displayName`.
    @MainActor
    var shownName: String {
        if StarHashPreferences.enableContacts, let saved = PayContacts.shared.contactName(for: self) {
            return saved
        }
        return displayName
    }
}
