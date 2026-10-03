import Foundation

/// One shipped version, for Settings' What's New list and its detail page.
public struct Release: Identifiable, Hashable, Sendable {
    public struct Highlight: Hashable, Sendable {
        public let symbol: String
        public let title: String
        public let detail: String

        public init(symbol: String, title: String, detail: String) {
            self.symbol = symbol
            self.title = title
            self.detail = detail
        }
    }

    /// Marketing version without the "v": "1.0.0".
    public let version: String
    /// Release day as "yyyy-MM-dd", shown as is under the version.
    public let date: String
    public let summary: String
    public let highlights: [Highlight]

    public init(version: String, date: String, summary: String, highlights: [Highlight]) {
        self.version = version
        self.date = date
        self.summary = summary
        self.highlights = highlights
    }

    public var id: String { version }

    /// "v1.0.0".
    public var title: String { "v\(version)" }
}

public enum ReleaseHistory {
    /// Newest first. Add a release at the top when shipping an update.
    public static let releases: [Release] = [
        Release(
            version: "1.0.0",
            date: "2026-10-02",
            summary: "The first release of StarHash: pay with MTN MoMo or Airtel Money without typing USSD codes, and keep every payment in one place.",
            highlights: [
                .init(symbol: "number", title: "Pay in a few taps",
                      detail: "Type an amount, pick who gets it, and StarHash dials your wallet's code for you. Your PIN is only ever typed into your wallet's own prompt."),
                .init(symbol: "storefront.fill", title: "Numbers and merchant codes",
                      detail: "Type a merchant code or a number, or pick a contact. Saved numbers and codes come up by name, with their photo."),
                .init(symbol: "clock.fill", title: "Every payment in Activity",
                      detail: "See what you spent by day, week, month or year, with a chart, search and the details of each payment."),
                .init(symbol: "checkmark.message.fill", title: "Auto-verify",
                      detail: "Add one shortcut and your M\u{2011}Money messages confirm each payment, with its fee and your new balance."),
                .init(symbol: "lock.fill", title: "Private by design",
                      detail: "No account, no servers and no tracking. Everything stays on your iPhone."),
                .init(symbol: "heart.fill", title: "Free and open source",
                      detail: "StarHash is free, and its code is open for anyone to read and improve."),
            ]
        ),
    ]
}
