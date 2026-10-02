import Foundation

/// The MTN MoMo Rwanda USSD codes StarHash dials.
public enum USSD {
    /// Send to an MTN number: *182*1*1*Number*Amount#
    /// Send to an Airtel number: *182*1*2*Number*Amount#
    /// Pay a merchant code: *182*8*1*Code*Amount#
    public static func payment(to recipient: Recipient, amount: Int) -> String {
        switch (recipient.kind, recipient.network) {
        case (.phone, .airtel): "*182*1*2*\(recipient.destination)*\(amount)#"
        case (.phone, _): "*182*1*1*\(recipient.destination)*\(amount)#"
        case (.merchant, _): "*182*8*1*\(recipient.destination)*\(amount)#"
        }
    }

    /// Check the MoMo balance.
    public static let balance = "*182*6*1#"

    /// A tel: URL the system dialer accepts, with # escaped.
    public static func telURL(for code: String) -> URL? {
        let escaped = code.replacingOccurrences(of: "#", with: "%23")
        return URL(string: "tel:" + escaped)
    }
}
