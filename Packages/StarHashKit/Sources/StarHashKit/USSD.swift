import Foundation

/// The USSD codes StarHash dials. MTN MoMo and Airtel Money in Rwanda share
/// the *182# menu: 1, 1 sends to a number on the wallet's own network, 1, 2
/// to the other network, and 8, 1 pays a merchant code.
public enum USSD {
    /// Send on the same network: *182*1*1*Number*Amount#
    /// Send to the other network: *182*1*2*Number*Amount#
    /// Pay a merchant code: *182*8*1*Code*Amount#
    public static func payment(to recipient: Recipient, amount: Int, from wallet: Recipient.Network) -> String {
        switch (recipient.kind, recipient.network) {
        case (.phone, wallet): "*182*1*1*\(recipient.destination)*\(amount)#"
        case (.phone, _): "*182*1*2*\(recipient.destination)*\(amount)#"
        case (.merchant, _): "*182*8*1*\(recipient.destination)*\(amount)#"
        }
    }

    /// Check the wallet's balance. Airtel Money has no balance shortcut we
    /// could confirm, so it opens the top of its menu, where the balance is
    /// one choice away, rather than guess at a path that might lead to a
    /// payment.
    public static func balance(for wallet: Recipient.Network) -> String {
        switch wallet {
        case .mtn: "*182*6*1#"
        case .airtel: "*182#"
        }
    }

    /// A tel: URL the system dialer accepts, with # escaped.
    public static func telURL(for code: String) -> URL? {
        let escaped = code.replacingOccurrences(of: "#", with: "%23")
        return URL(string: "tel:" + escaped)
    }
}
