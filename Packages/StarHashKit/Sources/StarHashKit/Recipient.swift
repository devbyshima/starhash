import Foundation

/// Who a payment goes to: a phone number (MoMo transfer) or a merchant
/// code (MoMo Pay). Anything of 10 digits or more is a number; fewer is a
/// merchant code.
public struct Recipient: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case phone
        case merchant
    }

    /// The mobile network a phone number is on, which is also the wallet
    /// the owner pays from (MTN MoMo or Airtel Money). Each wallet sends to
    /// both, with a different code and fee for its own network and the
    /// other one.
    public enum Network: String, CaseIterable, Sendable {
        case mtn
        case airtel

        public var name: String {
            switch self {
            case .mtn: "MTN"
            case .airtel: "Airtel"
            }
        }

        /// The mobile money wallet on this network.
        public var walletName: String {
            switch self {
            case .mtn: "MTN MoMo"
            case .airtel: "Airtel Money"
            }
        }

        /// What the wallet's confirmation messages are called, after the
        /// name they arrive under, kept on one line (a hyphen and a space
        /// that do not break).
        public var messagesName: String {
            switch self {
            case .mtn: "M\u{2011}Money"
            case .airtel: "Airtel\u{00A0}Money"
            }
        }
    }

    /// A contact or merchant name, when one is known.
    public var name: String?
    /// Digits only. Phone numbers in local form (07XXXXXXXX).
    public var destination: String
    public var kind: Kind

    public init(name: String? = nil, destination: String, kind: Kind) {
        self.name = name
        self.destination = destination
        self.kind = kind
    }

    /// Classifies typed or pasted input ("+250 781 234 567", "0781234567",
    /// "020205"). Nil when it holds no digits.
    public init?(input: String, name: String? = nil) {
        let digits = input.filter(\.isASCIIDigit)
        guard !digits.isEmpty else { return nil }
        if digits.count >= 10 {
            self.init(name: name, destination: Recipient.localNumber(digits), kind: .phone)
        } else {
            self.init(name: name, destination: digits, kind: .merchant)
        }
    }

    /// The network of a phone number, from its prefix: 072 and 073 are
    /// Airtel, anything else MTN (078, 079). Nil for merchant codes.
    public var network: Network? {
        guard kind == .phone else { return nil }
        return destination.hasPrefix("072") || destination.hasPrefix("073") ? .airtel : .mtn
    }

    /// "250781234567" becomes "0781234567"; anything else is kept.
    public static func localNumber(_ digits: String) -> String {
        if digits.hasPrefix("250"), digits.count == 12 { return "0" + digits.dropFirst(3) }
        if digits.hasPrefix("00250"), digits.count == 14 { return "0" + digits.dropFirst(5) }
        return digits
    }

    /// What to show for the destination: "0781 234 567" for numbers, the
    /// code as is for merchants.
    public var formattedDestination: String {
        guard kind == .phone, destination.count == 10 else { return destination }
        let d = Array(destination)
        return String(d[0..<4]) + " " + String(d[4..<7]) + " " + String(d[7..<10])
    }

    /// Whether StarHash can dial a payment to it: a full phone number, or a
    /// merchant code. A sender read from a carrier SMS can be masked
    /// ("*********998" keeps "998") or have no number at all (a bank
    /// deposit); dialling those would send money to the wrong place.
    public var isPayable: Bool {
        guard !destination.isEmpty, destination.allSatisfy(\.isASCIIDigit) else { return false }
        switch kind {
        case .phone: return destination.count >= 10
        case .merchant: return destination.count < 10
        }
    }

    /// The name when known, otherwise the formatted destination.
    public var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return formattedDestination
    }
}

extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
