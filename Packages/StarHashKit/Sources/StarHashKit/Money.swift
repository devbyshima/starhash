import Foundation

/// Amounts are whole Rwandan francs. Formatting is fixed ("15,000"), so it
/// reads the same whatever the phone's region.
public enum Money {
    public static let currency = "RWF"
    /// The most one payment can be: the top of MTN's published tariff.
    public static let maximumAmount = 10_000_000

    public static func format(_ amount: Int) -> String {
        let negative = amount < 0
        var digits = String(abs(amount))
        var groups: [String] = []
        while digits.count > 3 {
            groups.insert(String(digits.suffix(3)), at: 0)
            digits.removeLast(3)
        }
        groups.insert(digits, at: 0)
        return (negative ? "-" : "") + groups.joined(separator: ",")
    }

    /// "15,000 RWF"
    public static func formatWithCurrency(_ amount: Int) -> String {
        format(amount) + " " + currency
    }

    /// "843k", "1.2M", "950": for chart labels and stat tiles.
    public static func compact(_ amount: Int) -> String {
        let value = Double(abs(amount))
        let sign = amount < 0 ? "-" : ""
        switch value {
        case 1_000_000...:
            return sign + trimmed(value / 1_000_000) + "M"
        case 1_000...:
            return sign + trimmed(value / 1_000) + "k"
        default:
            return sign + String(Int(value))
        }
    }

    private static func trimmed(_ value: Double) -> String {
        value >= 100 ? String(Int(value.rounded())) : String(format: "%.1f", value).replacingOccurrences(of: ".0", with: "")
    }
}
