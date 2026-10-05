import Foundation

/// What a carrier SMS (MTN MoMo or Airtel Money, Rwanda) says happened.
public struct ParsedSMS: Hashable, Sendable {
    /// Whose message it was.
    public var wallet: Recipient.Network
    public var direction: Transaction.Direction
    public var counterparty: Recipient
    public var amount: Int
    public var fee: Int?
    public var date: Date?
    public var reference: String?
    public var balanceAfter: Int?

    public init(
        wallet: Recipient.Network = .mtn,
        direction: Transaction.Direction,
        counterparty: Recipient,
        amount: Int,
        fee: Int? = nil,
        date: Date? = nil,
        reference: String? = nil,
        balanceAfter: Int? = nil
    ) {
        self.wallet = wallet
        self.direction = direction
        self.counterparty = counterparty
        self.amount = amount
        self.fee = fee
        self.date = date
        self.reference = reference
        self.balanceAfter = balanceAfter
    }
}

/// Reads MTN MoMo and Airtel Money confirmation messages, Rwanda's.
///
/// The carriers change their wording every so often and the messages
/// arrive with odd spacing ("balance:47000 RWF", "at 2024-10-20 16:13:05 ."),
/// so parsing is a handful of tolerant patterns rather than one strict
/// grammar: first tell whose message it is by its marks, then find what
/// kind of movement it describes (its shape), then pick the fee, balance,
/// date and reference out of the rest wherever they are. Anything that
/// matches no shape (promotions, OTPs, failed attempts) is not a
/// transaction.
///
/// Airtel Money's shapes follow the template Airtel Africa sends in every
/// country it runs Airtel Money in ("SENT.TID 143284610198. UGX 1,000 to
/// ... Fee UGX 100. Bal UGX 2,214. Date 20-March-2026 20:36." in Uganda),
/// in RWF, with the currency before the amount as Rwanda's messages write
/// it. No Rwandan message has been published to check them against, so
/// they are deliberately loose.
public enum CarrierSMS {
    /// Nil when the text is not a MoMo or Airtel Money transaction message.
    public static func parse(_ text: String) -> ParsedSMS? {
        let message = normalized(text)
        // Failed or cancelled attempts mention an amount but moved nothing
        // (`parseFailure` reads them).
        if matches(failureWords, message) {
            return nil
        }
        let wallet: Recipient.Network
        let shape: Shape
        if isMoMo(message), let found = mtnShape(of: message) {
            (wallet, shape) = (.mtn, found)
        } else if isAirtelMoney(message), let found = airtelShape(of: message) {
            (wallet, shape) = (.airtel, found)
        } else {
            return nil
        }
        guard shape.amount > 0 else { return nil }
        return ParsedSMS(
            wallet: wallet,
            direction: shape.direction,
            counterparty: shape.counterparty,
            amount: shape.amount,
            fee: fee(in: message),
            date: date(in: message),
            reference: reference(in: message),
            balanceAfter: balance(in: message)
        )
    }

    /// A payment that did not go through, as the wallet tells it: "Your
    /// transfer of 5000 RWF to John Doe (250788123456) failed. Insufficient
    /// balance." Only a message that names the amount and the number or code
    /// it was going to, since that is what ties it to the payment StarHash
    /// dialled; one that says less ("Transaction of 9000 RWF was
    /// cancelled") is left alone. Always outgoing.
    public static func parseFailure(_ text: String) -> ParsedSMS? {
        let message = normalized(text)
        guard matches(failureWords, message) else { return nil }
        let wallet: Recipient.Network
        if isMoMo(message) {
            wallet = .mtn
        } else if isAirtelMoney(message) {
            wallet = .airtel
        } else {
            return nil
        }
        guard let found = failedPayment(in: message),
              found.amount > 0, !found.counterparty.destination.isEmpty else { return nil }
        return ParsedSMS(
            wallet: wallet,
            direction: .outgoing,
            counterparty: found.counterparty,
            amount: found.amount,
            date: date(in: message),
            reference: reference(in: message)
        )
    }

    private static let failureWords = #"\b(failed|unsuccessful|insufficient|cancell?ed|declined)\b"#

    /// Where a failed payment was going, in either wallet's wording.
    private static func failedPayment(in message: String) -> (counterparty: Recipient, amount: Int)? {
        // "5000 RWF to John Doe (250788123456)"
        if let m = captures(amount + #"\s+to\s+([^(]+?)\s*\(([^)]*)\)"#, message) {
            return (party(name: m[1], number: m[2]), money(m[0]))
        }
        // "1,000 RWF to 0732561240 Jean Bosco"
        if let m = captures(amount + #"\s+to\s+"# + airtelNumber + #"[\s,]+(.+?)"# + nameEnd, message) {
            return (party(name: m[2], number: m[1]), money(m[0]))
        }
        // "1,000 RWF to JEAN BOSCO 0732561240"
        if let m = captures(amount + #"\s+to\s+(.+?)[\s,]+"# + airtelNumber, message) {
            return (party(name: m[1], number: m[2]), money(m[0]))
        }
        // "15,000 RWF to PILI-PILI INVEST 020205": a merchant and its code.
        if let m = captures(amount + #"\s+to\s+(.+?)\s+(\d{3,9})\b"#, message) {
            return (Recipient(name: displayName(m[1]), destination: m[2], kind: .merchant), money(m[0]))
        }
        return nil
    }

    /// Whether the message is MTN MoMo's own. Banks text in RWF too, and
    /// some of their messages read much like MoMo's ("You have received RWF
    /// 50,000 from ..."), so a message must also carry one of MoMo's marks:
    /// a USSD-style prefix (*165*S*, *164*S*, *113*R*), a TxId, a Financial
    /// Transaction Id or its short "FT Id" (money received carries only
    /// that), "mobile money" or "MoMo".
    static func isMoMo(_ message: String) -> Bool {
        let marks = [#"^\*\d{3}\*[A-Z]\*"#, #"\bTxId\b"#, #"Financial Transaction Id"#, #"\bFT Id\b"#, #"mobile money"#, #"\bMoMo\b"#]
        return marks.contains { message.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    /// Whether the message is Airtel Money's: its transaction id ("TID",
    /// "Txn. ID", "Trans ID"), which no bank or MTN message uses, or
    /// Airtel's own name.
    static func isAirtelMoney(_ message: String) -> Bool {
        let marks = [#"\bTID\b"#, #"\bTxn\.?\s*ID\b"#, #"\bTrans\.?\s*ID\b"#, #"\bAirtel\b"#]
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

    private static func mtnShape(of message: String) -> Shape? {
        // "*165*S*5000 RWF transferred to John Doe (250788123456) from ..."
        if let m = captures(amount + #"\s+transferred to\s+(.+?)\s*\(([^)]*)\)"#, message) {
            return Shape(direction: .outgoing, counterparty: party(name: m[1], number: m[2]), amount: money(m[0]))
        }

        // "Your payment of 15,000 RWF to PILI-PILI INVEST 020205 has been completed"
        if let m = captures(#"payment of\s+"# + amount + #"\s+to\s+(.+?)\s+(?:has been|was|is)\s+(?:successfully\s+)?completed"#, message) {
            return Shape(direction: .outgoing, counterparty: merchant(m[1]), amount: money(m[0]))
        }

        // "A transaction of 5000 RWF by KONGEZA LTD on your MOMO account was
        // successfully completed", or "... by ITEC Ltd was completed at
        // 2026-09-30 12:37:08": a payment the user approved from a
        // merchant's prompt.
        if let m = captures(#"transaction of\s+"# + amount + #"\s+by\s+(.+?)\s+(?:on your\b|was\s+(?:successfully\s+)?completed)"#, message) {
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

    /// A Rwandan mobile number as Airtel writes it: 0732..., 250732... or,
    /// in money received, 732... with neither, and never part of a longer
    /// run of digits (a transaction id).
    private static let airtelNumber = #"\(?(?<!\d)((?:\+?250|0)?7\d{8})(?!\d)\)?"#

    /// Where a name ends in Airtel's messages: at the end of a sentence, or
    /// where the fee, the balance or the next detail starts.
    private static let nameEnd = #"(?=\.\s|\.$|,|\s+(?:mobile app\s+)?charge\b|\s+fee\b|\s+bal\b|\s+balance\b|\s+in\b|\s+on\b|\s+date\b|$)"#

    private static func airtelShape(of message: String) -> Shape? {
        // "Sent to Jean Bosco in MTN . Amt RWF 2,000": to the other network,
        // which may leave the number out.
        if let m = captures(#"sent to\s+(.+?)\s+in\s+(?:MTN|Airtel)\b.*?\bamt\.?\s*:?\s*"# + amount, message) {
            return Shape(direction: .outgoing, counterparty: party(name: m[0], number: ""), amount: money(m[1]))
        }
        // "Money sent to Jean Bosco on 0732561240. Amount RWF 2,000."
        if let m = captures(#"sent to\s+(.+?)\s+on\s+"# + airtelNumber + #".*?\bamount\s*:?\s*"# + amount, message) {
            return Shape(direction: .outgoing, counterparty: party(name: m[0], number: m[1]), amount: money(m[2]))
        }
        // "SENT.TID 143284610198. RWF 1,000 to 0732561240 Jean Bosco. Fee RWF 0."
        if let m = captures(#"\bsent\b.*?"# + amount + #"\s+to\s+"# + airtelNumber + #"[\s,]+(.+?)"# + nameEnd, message) {
            return Shape(direction: .outgoing, counterparty: party(name: m[2], number: m[1]), amount: money(m[0]))
        }
        // "SENT.TID 143284610198. RWF 1,000 to Jean Bosco 0732561240. Fee RWF 0."
        if let m = captures(#"\bsent\b.*?"# + amount + #"\s+to\s+(.+?)[\s,]+"# + airtelNumber, message) {
            return Shape(direction: .outgoing, counterparty: party(name: m[1], number: m[2]), amount: money(m[0]))
        }
        // "Payment of RWF 1,500 Till Number 300770 KIGALI COFFEE LTD."
        if let m = captures(#"payment of\s+"# + amount + #"\s+(?:to\s+)?(?:till number|merchant code|merchant)\s*:?\s*(\d+)\s+(.+?)"# + nameEnd, message) {
            let name = displayName(m[2])
            return Shape(direction: .outgoing, counterparty: Recipient(name: name, destination: m[1], kind: .merchant), amount: money(m[0]))
        }
        // "PAID.TID 134346936087. RWF 5,000 to KIGALI COFFEE LTD 300770 Charge RWF 0."
        if let m = captures(#"\bpaid\b.*?"# + amount + #"\s+to\s+(.+?)"# + nameEnd, message) {
            return Shape(direction: .outgoing, counterparty: merchant(m[1]), amount: money(m[0]))
        }
        // "CASH DEPOSIT of RWF 9,000 from KCB BANK RWANDA. Bal RWF 11,214."
        if let m = captures(#"cash deposit of\s+"# + amount + #"\s+from\s+(.+?)"# + nameEnd, message) {
            let name = displayName(m[1]) ?? "Cash deposit"
            return Shape(direction: .incoming, counterparty: Recipient(name: name, destination: "", kind: .merchant), amount: money(m[0]))
        }
        // "RECEIVED. TID 143487144326. RWF 40,000 from 732561240, Jean Bosco."
        if let m = captures(#"\breceived\b.*?"# + amount + #"\s+from\s+"# + airtelNumber + #"[\s,]+(.+?)"# + nameEnd, message) {
            return Shape(direction: .incoming, counterparty: party(name: m[2], number: m[1]), amount: money(m[0]))
        }
        // "...received RWF 40,000 from Jean Bosco 0732561240..."
        if let m = captures(#"\breceived\b.*?"# + amount + #"\s+from\s+(.+?)[\s,]+"# + airtelNumber, message) {
            return Shape(direction: .incoming, counterparty: party(name: m[1], number: m[2]), amount: money(m[0]))
        }
        // "You have received RWF 300 from Jean Bosco. Txn. ID: CI260726.1522.A37452."
        if let m = captures(#"\breceived\b.*?"# + amount + #"\s+from\s+(.+?)"# + nameEnd, message) {
            return Shape(direction: .incoming, counterparty: party(name: m[1], number: ""), amount: money(m[0]))
        }
        return nil
    }

    /// A person and the number in brackets. A masked number
    /// ("*********998") keeps its visible digits, which is enough to tell
    /// people apart; the name is what the app shows.
    private static func party(name: String, number: String) -> Recipient {
        let name = displayName(name)
        var digits = number.filter { $0.isASCII && $0.isNumber }
        // Airtel writes a sender's number without its leading 0.
        if digits.count == 9, digits.first == "7" { digits = "0" + digits }
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

    /// "Fee was: 100 RWF" (MTN), "Fee RWF 100" or "Charge RWF 0" (Airtel).
    private static func fee(in message: String) -> Int? {
        captures(#"\b(?:fees?|charge)\s*(?:was|is|of|paid)?\s*:?\s*"# + amount, message).map { money($0[0]) }
    }

    /// "New balance: 12000 RWF" (MTN), "Bal RWF 2,214" or "Your bal is RWF
    /// 260" (Airtel).
    private static func balance(in message: String) -> Int? {
        captures(#"\b(?:balance|bal)\b\s*(?:is)?\s*:?\s*"# + amount, message).map { money($0[0]) }
    }

    /// The carrier's id for the movement. The number after "from" in a
    /// transfer is the sender's own account id, the same on every message,
    /// so it is not used: the store treats a repeated reference as a message
    /// it has already applied.
    private static func reference(in message: String) -> String? {
        if let mtn = captures(#"\b(?:TxId|Financial Transaction Id|Transaction Id|FT Id)\s*[:.]?\s*(\d{5,})"#, message) {
            return mtn[0]
        }
        // Airtel's: "TID 143284610198", "TID: PP260727.1512.M73944".
        return captures(#"\b(?:TID|Txn\.?\s*ID|Trans\.?\s*ID)\s*:?\s*([A-Z0-9]+(?:\.[A-Z0-9]+)*)"#, message)?[0]
    }

    /// "2024-10-20 16:13:05" (MTN) or "20-March-2026 20:36" (Airtel), in
    /// Kigali time (the messages carry no zone).
    private static func date(in message: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Africa/Kigali")
        if let m = captures(#"(\d{4}-\d{2}-\d{2})[ T](\d{1,2}:\d{2}(?::\d{2})?)"#, message) {
            formatter.dateFormat = m[1].count > 5 ? "yyyy-MM-dd H:mm:ss" : "yyyy-MM-dd H:mm"
            return formatter.date(from: m[0] + " " + m[1])
        }
        if let m = captures(#"(\d{1,2}-[A-Za-z]{3,9}-\d{4})\s+(\d{1,2}:\d{2})"#, message) {
            for format in ["d-MMMM-yyyy H:mm", "d-MMM-yyyy H:mm"] {
                formatter.dateFormat = format
                if let date = formatter.date(from: m[0] + " " + m[1]) { return date }
            }
        }
        return nil
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
