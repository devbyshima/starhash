import Foundation

/// A message that reads like a wallet's but may not be one: the "I sent you
/// money by mistake, send it back" trick, where a fake MoMo message arrives
/// from someone's own number and a call asking for the money back follows.
public struct ScamWarning: Hashable, Sendable {
    public enum Reason: String, Hashable, Sendable {
        /// From a phone number, an email or a name that is not the
        /// wallet's: MTN MoMo's come from M-Money, Airtel Money's from
        /// AirtelMoney.
        case unofficialSender
        /// The wallet never writes this: asking for money back, saying it
        /// was sent by mistake, giving a number to call.
        case suspiciousWording
    }

    public var reason: Reason
    /// The wallet the message pretends to be from.
    public var wallet: Recipient.Network
    /// Who it came from, as the Shortcuts automation passed it on.
    public var sender: String?
    /// What it claims, when it reads as a transaction: received money,
    /// usually.
    public var claimed: ParsedSMS?

    public init(reason: Reason, wallet: Recipient.Network, sender: String? = nil, claimed: ParsedSMS? = nil) {
        self.reason = reason
        self.wallet = wallet
        self.sender = sender
        self.claimed = claimed
    }
}

/// Tells a wallet's own messages from look-alikes before StarHash logs
/// anything from them.
public enum ScamCheck {
    /// The names MTN MoMo's and Airtel Money's messages arrive under, folded
    /// as `fold` folds a sender (lower case, letters and digits only).
    static let officialSenders: [Recipient.Network: Set<String>] = [
        .mtn: ["mmoney", "momo", "mtn", "mtnmomo", "mtnrwanda", "momopay", "mtnmobilemoney", "mobilemoney"],
        .airtel: ["airtelmoney", "airtel", "airtelrwanda", "airtelmobilemoney"],
    ]

    /// Words a wallet's own message never has. Folded to lower case.
    static let scamPhrases = [
        "by mistake", "mistakenly", "wrongly sent", "sent it by error",
        "send it back", "send back", "sendback", "send the money back", "return the money", "refund me",
        "please return", "reverse it", "reverse the", "call me", "call this number", "contact me",
        "nyohereza", "nyoherereze", "ndakwinginze", "nibeshye", "mwibeshye", "ndibeshye", "nsubiza",
        "subiza amafaranga", "ohereza amafaranga",
    ]

    /// A warning when `text` reads as a wallet's message but should not be
    /// trusted: it came from `sender` when that is not the wallet's own
    /// (a phone number or an email always; another name when the text reads
    /// as a whole transaction), or it asks for the money back. Nil for a
    /// message that is not a wallet's at all, and for a genuine one.
    /// `sender` is nil when the automation does not pass it on, as a
    /// shortcut set up before it could does not.
    public static func check(_ text: String, sender: String?) -> ScamWarning? {
        let claimed = CarrierSMS.parse(text)
        let wallet: Recipient.Network
        if let claimed {
            wallet = claimed.wallet
        } else if CarrierSMS.isMoMo(text), mentionsMoney(text) {
            wallet = .mtn
        } else if CarrierSMS.isAirtelMoney(text), mentionsMoney(text) {
            wallet = .airtel
        } else {
            return nil
        }

        if let sender = sender?.trimmingCharacters(in: .whitespacesAndNewlines), !sender.isEmpty {
            let folded = fold(sender)
            let official = officialSenders.values.contains { $0.contains(folded) }
            if !official, isPersonal(sender) || claimed != nil {
                return ScamWarning(reason: .unofficialSender, wallet: wallet, sender: sender, claimed: claimed)
            }
        }

        let lower = text.lowercased()
        if scamPhrases.contains(where: lower.contains) {
            return ScamWarning(reason: .suspiciousWording, wallet: wallet, sender: sender, claimed: claimed)
        }
        return nil
    }

    /// Whether `sender` is a person rather than a name a business registers:
    /// a phone number, or an email (an iMessage).
    static func isPersonal(_ sender: String) -> Bool {
        if sender.contains("@") { return true }
        let digits = sender.filter { $0.isASCII && $0.isNumber }
        let rest = sender.filter { !($0.isASCII && $0.isNumber) && !" +-()".contains($0) }
        return digits.count >= 7 && rest.isEmpty
    }

    /// "M-Money" and "MTN MoMo" as "mmoney" and "mtnmomo".
    static func fold(_ sender: String) -> String {
        String(sender.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func mentionsMoney(_ text: String) -> Bool {
        text.range(of: #"\d[\d,]*\s*RWF|RWF\s*\d"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
