import Foundation

/// The owner's own numbers, when they pay from two SIMs: money between
/// them is moved, not spent or received (`TransactionCategory.ownAccounts`).
/// Money sent shows the full number it went to, so that is matched exactly.
/// Money received shows the sender's number masked ("*********515"), so a
/// sender is the owner's other SIM only when the digits it shows end one of
/// their numbers and its name shares a word with the owner's own: three
/// digits alone would take a stranger for them one time in a thousand.
public struct OwnAccounts: Equatable, Sendable {
    /// Each number as StarHash keeps a destination: 07XXXXXXXX.
    public let numbers: [String]
    /// The owner's name, from Profile, for masked senders.
    public let name: String?

    /// From the numbers as typed; one that is not a Rwandan mobile number
    /// is left out. Nil with none left.
    public init?(numbers: [String], name: String?) {
        let found = numbers.compactMap { Recipient.ownNumber($0)?.destination }
        guard !found.isEmpty else { return nil }
        self.numbers = Array(Set(found)).sorted()
        self.name = name.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
    }

    /// Whether `recipient` is one of the owner's own numbers.
    public func owns(_ recipient: Recipient) -> Bool {
        guard recipient.kind == .phone else { return false }
        let digits = recipient.destination
        if digits.count >= 10 { return numbers.contains(digits) }
        guard digits.count >= 3, numbers.contains(where: { $0.hasSuffix(digits) }),
              let name, let other = recipient.name else { return false }
        return !Self.words(name).isDisjoint(with: Self.words(other))
    }

    /// A name's words worth comparing: three letters or more, in lower
    /// case, without accents.
    private static func words(_ name: String) -> Set<String> {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return Set(folded.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count >= 3 })
    }
}
