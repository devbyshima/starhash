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
    /// Release day as "yyyy-MM-dd", in Kigali; shown written out.
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
            date: "2026-10-04",
            summary: "The first release of StarHash: pay with MTN MoMo or Airtel Money without typing USSD codes, and keep every payment in one place.",
            highlights: [
                .init(symbol: "number", title: "Pay in a few taps",
                      detail: "Type an amount, pick who gets it, and StarHash dials your wallet's code for you. Your PIN is only ever typed into your wallet's own prompt."),
                .init(symbol: "storefront.fill", title: "Numbers and merchant codes",
                      detail: "Type a merchant code or a number, or pick a contact. Saved numbers and codes come up by name, with their photo."),
                .init(symbol: "phone.fill", title: "Buy",
                      detail: "Keep the codes you dial often, like pending approvals, cash out and bundles, and dial them in a tap. Pin up to eight to the top."),
                .init(symbol: "location.fill", title: "Nearby",
                      detail: "Turn it on and StarHash remembers where you paid a number or a code, and suggests it when you are back there."),
                .init(symbol: "clock.fill", title: "Every payment in Activity",
                      detail: "See what you spent by day, week, month or year, with a chart, search and the details of each payment."),
                .init(symbol: "checkmark.message.fill", title: "Auto-verify",
                      detail: "Add one shortcut and your MTN MoMo or Airtel Money messages confirm each payment, with its fee and your new balance."),
                .init(symbol: "bell.fill", title: "Notifications",
                      detail: "A reminder when a payment is still pending or didn't go through, and your week and month summed up. Choose which ones come, and whether they show amounts, in Settings."),
                .init(symbol: "lock.fill", title: "Private by design",
                      detail: "No account, no servers and no tracking. Everything stays on your iPhone."),
                .init(symbol: "faceid", title: "Face ID lock",
                      detail: "Turn it on in Settings and only your face, fingerprint or passcode opens StarHash."),
                .init(symbol: "heart.fill", title: "Free and open source",
                      detail: "StarHash is free, and its code is open for anyone to read and improve."),
            ]
        ),
    ]
}
