import Foundation

/// Who to pay, read from a QR code: the number or merchant code, the name
/// that goes with it, and an amount when the code asks for one.
public struct PaymentRequest: Hashable, Sendable {
    public var recipient: Recipient
    /// Whole RWF, when the code names an amount.
    public var amount: Int?

    public init(recipient: Recipient, amount: Int? = nil) {
        self.recipient = recipient
        self.amount = amount
    }
}

/// StarHash's payment QR codes, and the other codes a merchant's sticker or
/// a friend's phone may show. A StarHash code is a link,
/// `starhash://pay?to=0788123456&name=Ariane`, so the iPhone's own Camera
/// opens StarHash on it too. StarHash also reads a code that is a MoMo
/// USSD string (`*182*8*1*020205#`, or as a tel: link), the EMV payload
/// Rwanda's merchant QR codes carry, or a bare number or merchant code.
public enum PaymentQR {
    /// The link a StarHash QR code holds for `recipient`, with its name
    /// when it has one and an amount when one is asked for.
    public static func link(for recipient: Recipient, amount: Int? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "starhash"
        components.host = "pay"
        var items = [URLQueryItem(name: "to", value: recipient.destination)]
        if let name = recipient.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            items.append(URLQueryItem(name: "name", value: name))
        }
        if let amount, amount > 0 {
            items.append(URLQueryItem(name: "amount", value: String(amount)))
        }
        components.queryItems = items
        return components.url!
    }

    /// Who a scanned code says to pay, or nil when it says nothing StarHash
    /// can pay (a website, a Wi-Fi code, a masked number).
    public static func parse(_ text: String) -> PaymentRequest? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request = link(trimmed) ?? ussd(trimmed) ?? emv(trimmed) ?? loose(trimmed)
        guard var request, request.recipient.isPayable else { return nil }
        if let amount = request.amount, amount <= 0 || amount > Money.maximumAmount { request.amount = nil }
        return request
    }

    // MARK: Links

    /// starhash://pay?to=..., or any link whose query names a number or code
    /// (to, phone, number, msisdn, code, merchant, till).
    private static func link(_ text: String) -> PaymentRequest? {
        guard let components = URLComponents(string: text), let scheme = components.scheme?.lowercased() else { return nil }
        if scheme == "tel" {
            let code = (components.path.removingPercentEncoding ?? components.path)
            return ussd(code)
        }
        let items = components.queryItems ?? []
        func value(_ names: [String]) -> String? {
            items.first { names.contains($0.name.lowercased()) }?.value?.trimmingCharacters(in: .whitespaces)
        }
        guard let destination = value(["to", "phone", "number", "msisdn", "code", "merchant", "merchantcode", "till", "momo"]),
              var recipient = Recipient(input: destination) else { return nil }
        // A link from anywhere but StarHash only counts when what it names is
        // plainly a number or a code.
        if scheme != "starhash", recipient.kind == .phone, !recipient.isRwandanMobile { return nil }
        if let name = value(["name", "merchantname"]), !name.isEmpty { recipient.name = name }
        let amount = value(["amount", "amt"]).flatMap { Int($0.filter(\.isASCIIDigit)) }
        return PaymentRequest(recipient: recipient, amount: amount)
    }

    // MARK: USSD

    /// A MoMo code to dial: *182*8*1*<code>[*<amount>]# pays a merchant,
    /// *182*1*1*<number>[*<amount>]# (or *182*1*2*) sends to a number.
    private static func ussd(_ text: String) -> PaymentRequest? {
        let code = text.filter { !$0.isWhitespace }
        if let m = captures(#"^\*182\*8\*1\*(\d{3,9})(?:\*(\d+))?#?$"#, code) {
            return PaymentRequest(recipient: Recipient(destination: m[0], kind: .merchant), amount: Int(m[1]))
        }
        if let m = captures(#"^\*182\*1\*[12]\*(\+?\d{10,13})(?:\*(\d+))?#?$"#, code),
           let recipient = Recipient(input: m[0]) {
            return PaymentRequest(recipient: recipient, amount: Int(m[1]))
        }
        return nil
    }

    // MARK: EMV

    /// The EMV merchant-presented payload ("000201..."): two-digit tags, each
    /// with a two-digit length. The merchant's account is in one of the
    /// templates 26 to 51, under a sub-tag of its own; the name is tag 59
    /// and an amount tag 54. A template's first sub-tag (00) names the
    /// scheme, so it is skipped; the first run of digits after it that is a
    /// merchant code or a Rwandan number is the account.
    private static func emv(_ text: String) -> PaymentRequest? {
        guard text.hasPrefix("000201"), let fields = tlv(text) else { return nil }
        var recipient: Recipient?
        for tag in 26...51 {
            guard let template = fields[String(format: "%02d", tag)], let inner = tlv(template) else { continue }
            for key in inner.keys.sorted() where key != "00" {
                guard let value = inner[key], let found = account(value) else { continue }
                recipient = found
                break
            }
            if recipient != nil { break }
        }
        // Some put the wallet number among the additional data (62, its
        // mobile number under 02).
        if recipient == nil, let extra = fields["62"].flatMap(tlv), let mobile = extra["02"] {
            recipient = account(mobile)
        }
        guard var recipient else { return nil }
        if let name = fields["59"]?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            recipient.name = CarrierSMS.displayName(name) ?? name
        }
        let amount = fields["54"].flatMap { Double($0) }.map { Int($0.rounded()) }
        return PaymentRequest(recipient: recipient, amount: amount)
    }

    /// A merchant code (3 to 9 digits) or a Rwandan mobile number.
    private static func account(_ value: String) -> Recipient? {
        let digits = value.filter(\.isASCIIDigit)
        guard digits.count == value.filter({ !$0.isWhitespace && $0 != "+" }).count,
              let recipient = Recipient(input: digits) else { return nil }
        switch recipient.kind {
        case .merchant: return (3...9).contains(digits.count) ? recipient : nil
        case .phone: return recipient.isRwandanMobile ? recipient : nil
        }
    }

    /// The tag-length-value fields of an EMV payload, nil when it does not
    /// read as one.
    private static func tlv(_ text: String) -> [String: String]? {
        var fields: [String: String] = [:]
        var index = text.startIndex
        while index < text.endIndex {
            guard let tagEnd = text.index(index, offsetBy: 2, limitedBy: text.endIndex),
                  let lengthEnd = text.index(tagEnd, offsetBy: 2, limitedBy: text.endIndex),
                  let length = Int(text[tagEnd..<lengthEnd]),
                  let valueEnd = text.index(lengthEnd, offsetBy: length, limitedBy: text.endIndex) else { return nil }
            fields[String(text[index..<tagEnd])] = String(text[lengthEnd..<valueEnd])
            index = valueEnd
        }
        return fields.isEmpty ? nil : fields
    }

    // MARK: Anything else

    /// A code holding a number or merchant code and little else: "020205",
    /// "0788 123 456", "+250788123456", or a line naming one ("MoMo Pay:
    /// 020205"). A longer text is only read for a Rwandan mobile number.
    private static func loose(_ text: String) -> PaymentRequest? {
        if let m = captures(#"(?<!\d)((?:\+?250|0)7[2389]\d{7})(?!\d)"#, text.replacingOccurrences(of: " ", with: "")),
           let recipient = Recipient(input: m[0]) {
            return PaymentRequest(recipient: recipient)
        }
        let digits = text.filter(\.isASCIIDigit)
        let others = text.filter { !$0.isASCIIDigit && !$0.isWhitespace }
        guard (3...9).contains(digits.count), others.count <= 12 else { return nil }
        if let m = captures(#"^(?:[A-Za-z' ]*(?:code|pay|momo|till)[A-Za-z' ]*[:#-]?\s*)?(\d{3,9})$"#, text) {
            return PaymentRequest(recipient: Recipient(destination: m[0], kind: .merchant))
        }
        return nil
    }

    private static func captures(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }
}

extension Recipient {
    /// A Rwandan mobile number in local form: 10 digits, 078 or 079 (MTN),
    /// 072 or 073 (Airtel).
    public var isRwandanMobile: Bool {
        kind == .phone && destination.count == 10
            && ["078", "079", "072", "073"].contains(where: destination.hasPrefix)
    }

    /// `input` as the owner's own number for their QR code: a Rwandan mobile
    /// number, however it was typed ("0788 123 456", "+250 788 123 456"),
    /// or nil when it is not one.
    public static func ownNumber(_ input: String) -> Recipient? {
        guard let recipient = Recipient(input: input), recipient.isRwandanMobile else { return nil }
        return recipient
    }
}
