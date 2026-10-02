import Foundation

/// What a carrier (MTN MoMo Rwanda) SMS says happened.
public struct ParsedSMS: Hashable, Sendable {
    public var direction: Transaction.Direction
    public var counterparty: Recipient
    public var amount: Int
    public var fee: Int?
    public var date: Date?
    public var reference: String?
    public var balanceAfter: Int?

    public init(
        direction: Transaction.Direction,
        counterparty: Recipient,
        amount: Int,
        fee: Int? = nil,
        date: Date? = nil,
        reference: String? = nil,
        balanceAfter: Int? = nil
    ) {
        self.direction = direction
        self.counterparty = counterparty
        self.amount = amount
        self.fee = fee
        self.date = date
        self.reference = reference
        self.balanceAfter = balanceAfter
    }
}

/// Reads MTN MoMo Rwanda confirmation messages.
///
/// The carrier changes its wording every so often and the messages arrive
/// with odd spacing ("balance:47000 RWF", "at 2024-10-20 16:13:05 ."), so
/// parsing is a handful of tolerant patterns rather than one strict grammar:
/// first find what kind of movement the message describes (its shape), then
/// pick the fee, balance, date and reference out of the rest wherever they
/// are. Anything that matches no shape (promotions, OTPs, failed attempts)
/// is not a transaction.
public enum CarrierSMS {
    /// Nil when the text is not a MoMo transaction message.
    public static func parse(_ text: String) -> ParsedSMS? {
        let message = normalized(text)
        guard isMoMo(message), let shape = shape(of: message), shape.amount > 0 else { return nil }
        return ParsedSMS(
            direction: shape.direction,
            counterparty: shape.counterparty,
            amount: shape.amount,
            fee: fee(in: message),
            date: date(in: message),
            reference: reference(in: message),
            balanceAfter: balance(in: message)
        )
    }

    /// Whether the message is MTN MoMo's own. Banks text in RWF too, and
    /// some of their messages read much like MoMo's ("You have received RWF
    /// 50,000 from ..."), so a message must also carry one of MoMo's marks:
    /// a USSD-style prefix (*165*S*, *164*S*, *113*R*), a TxId, a Financial
    /// Transaction Id, "mobile money" or "MoMo".
    static func isMoMo(_ message: String) -> Bool {
        let marks = [#"^\*\d{3}\*[A-Z]\*"#, #"\bTxId\b"#, #"Financial Transaction Id"#, #"mobile money"#, #"\bMoMo\b"#]
        return marks.contains { message.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    // MARK: Shapes

    private struct Shape {
        var direction: Transaction.Direction
        var counterparty: Recipient
        var amount: Int
    }

    /// An amount as the carrier writes it ("5000", "15,000", "5000.00"),
    /// followed by RWF. `normalized` puts every amount in that order.
    private static let amount = #"(\d[\d,]*(?:\.\d{1,2})?)\s*RWF"#

    private static func shape(of message: String) -> Shape? {
        // Failed or cancelled attempts mention an amount but moved nothing.
        if matches(#"\b(failed|unsuccessful|insufficient|cancell?ed|declined)\b"#, message) {
            return nil
        }

        // "*165*S*5000 RWF transferred to John Doe (250788123456) from ..."
        if let m = captures(amount + #"\s+transferred to\s+(.+?)\s*\(([^)]*)\)"#, message) {
            return Shape(direction: .outgoing, counterparty: party(name: m[1], number: m[2]), amount: money(m[0]))
        }

        // "Your payment of 15,000 RWF to PILI-PILI INVEST 020205 has been completed"
        if let m = captures(#"payment of\s+"# + amount + #"\s+to\s+(.+?)\s+(?:has been|was|is)\s+(?:successfully\s+)?completed"#, message) {
            return Shape(direction: .outgoing, counterparty: merchant(m[1]), amount: money(m[0]))
        }

        // "A transaction of 5000 RWF by KONGEZA LTD on your MOMO account was
        // successfully completed": a payment the user approved from a
        // merchant's prompt.
        if let m = captures(#"transaction of\s+"# + amount + #"\s+by\s+(.+?)\s+on your\b"#, message) {
            return Shape(direction: .outgoing, counterparty: merchant(m[1]), amount: money(m[0]))
        }

        // "You have received 35000 RWF from Ariane ISHIMWE (*********998) on your ..."
        if let m = captures(#"received\s+"# + amount + #"\s+from\s+([^(]+?)\s*\(([^)]*)\)"#, message) {
            return Shape(direction: .incoming, counterparty: party(name: m[1], number: m[2]), amount: money(m[0]))
        }
        // The same without the number in brackets.
        if let m = captures(#"received\s+"# + amount + #"\s+from\s+(.+?)\s+(?:on your|at \d{4}-)"#, message) {
            return Shape(direction: .incoming, counterparty: party(name: m[1], number: ""), amount: money(m[0]))
        }

        // "A bank deposit of 20000 RWF has been added to your mobile money account"
        if let m = captures(#"bank deposit of\s+"# + amount, message) {
            return Shape(
                direction: .incoming,
                counterparty: Recipient(name: "Bank deposit", destination: "", kind: .merchant),
                amount: money(m[0])
            )
        }

        return nil
    }

    /// A person and the number in brackets. A masked number
    /// ("*********998") keeps its visible digits, which is enough to tell
    /// people apart; the name is what the app shows.
    private static func party(name: String, number: String) -> Recipient {
        let name = displayName(name)
        let digits = number.filter { $0.isASCII && $0.isNumber }
        if digits.count >= 10, let recipient = Recipient(input: digits, name: name) {
            return recipient
        }
        return Recipient(name: name, destination: digits, kind: .phone)
    }

    /// "PILI-PILI INVEST 020205": a merchant name, then its MoMo Pay code
    /// when the last word is all digits.
    private static func merchant(_ text: String) -> Recipient {
        var words = text.split(separator: " ").map(String.init)
        var code = ""
        if let last = words.last, words.count > 1, last.allSatisfy({ $0.isASCII && $0.isNumber }) {
            code = last
            words.removeLast()
        }
        let name = displayName(words.joined(separator: " "))
        if code.count >= 10, let recipient = Recipient(input: code, name: name) { return recipient }
        return Recipient(name: name, destination: code, kind: .merchant)
    }

    /// Names arrive in capitals ("PILI-PILI INVEST", "Ariane ISHIMWE"). A
    /// word written all in capitals becomes "Pili-Pili", "Ishimwe"; mixed
    /// case is left as the sender wrote it.
    static func displayName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: " .,:;-*"))
        guard !trimmed.isEmpty else { return nil }
        let words = trimmed.split(separator: " ").map { word -> String in
            let letters = word.filter(\.isLetter)
            guard letters.count > 1, letters == letters.uppercased() else { return String(word) }
            return word.lowercased().capitalized
        }
        return words.joined(separator: " ")
    }

    // MARK: Details

    private static func fee(in message: String) -> Int? {
        captures(#"\bfees?\s*(?:was|is|of|paid)?\s*:?\s*"# + amount, message).map { money($0[0]) }
    }

    private static func balance(in message: String) -> Int? {
        captures(#"new balance\s*(?:is)?\s*:?\s*"# + amount, message).map { money($0[0]) }
    }

    /// The carrier's id for the movement. The number after "from" in a
    /// transfer is the sender's own account id, the same on every message,
    /// so it is not used: the store treats a repeated reference as a message
    /// it has already applied.
    private static func reference(in message: String) -> String? {
        captures(#"\b(?:TxId|Financial Transaction Id|Transaction Id|FT Id)\s*[:.]?\s*(\d{5,})"#, message)?[0]
    }

    /// "2024-10-20 16:13:05", in Kigali time (the messages carry no zone).
    private static func date(in message: String) -> Date? {
        guard let m = captures(#"(\d{4}-\d{2}-\d{2})[ T](\d{1,2}:\d{2}(?::\d{2})?)"#, message) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Africa/Kigali")
        formatter.dateFormat = m[1].count > 5 ? "yyyy-MM-dd H:mm:ss" : "yyyy-MM-dd H:mm"
        return formatter.date(from: m[0] + " " + m[1])
    }

    // MARK: Text helpers

    /// One line, single spaces, and every "RWF 5,000" turned into
    /// "5,000 RWF", so each pattern only needs one order. An RWF that already
    /// follows an amount ("5000 RWF 2024-...") is left alone.
    private static func normalized(_ text: String) -> String {
        let oneLine = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard let regex = try? NSRegularExpression(pattern: #"(?<![\d,])(?<![\d,] )RWF\s*(\d[\d,]*(?:\.\d{1,2})?)"#, options: [.caseInsensitive]) else {
            return oneLine
        }
        let range = NSRange(oneLine.startIndex..., in: oneLine)
        return regex.stringByReplacingMatches(in: oneLine, range: range, withTemplate: "$1 RWF")
    }

    /// "15,000" or "5000.00" as whole francs.
    private static func money(_ text: String) -> Int {
        let whole = text.split(separator: ".").first.map(String.init) ?? text
        return Int(whole.filter { $0.isASCII && $0.isNumber }) ?? 0
    }

    /// The capture groups of the first match, case-insensitively; nil when
    /// nothing matches. A group that took no part reads as "".
    private static func captures(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        captures(pattern, text) != nil
    }
}
