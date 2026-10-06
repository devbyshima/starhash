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

    /// The What's New sheet for an update: a first page listing the
    /// release's news, then a page for each feature with a video of it. It
    /// shows once, to someone who updates to the release (`WhatsNew`), and
    /// never on a fresh install.
    public struct Announcement: Hashable, Sendable {
        /// The first page's rows, four at most, as the sheet has room for.
        public let highlights: [Highlight]
        /// One page each after it.
        public let pages: [Page]

        public init(highlights: [Highlight], pages: [Page]) {
            self.highlights = highlights
            self.pages = pages
        }
    }

    /// A feature's page: its video over its name and a few lines on it.
    public struct Page: Hashable, Sendable {
        /// Shown on the video's card while there is no video to play.
        public let symbol: String
        public let title: String
        public let detail: String
        /// The video's name in the app's bundle, without ".mp4".
        public let video: String

        public init(symbol: String, title: String, detail: String, video: String) {
            self.symbol = symbol
            self.title = title
            self.detail = detail
            self.video = video
        }
    }

    /// Marketing version without the "v": "1.0.0".
    public let version: String
    /// Release day as "yyyy-MM-dd", in Kigali; shown written out.
    public let date: String
    public let summary: String
    public let highlights: [Highlight]
    /// The sheet shown once after updating to it; nil for a release with
    /// nothing to show off, such as a patch or the first release.
    public let announcement: Announcement?

    public init(version: String, date: String, summary: String, highlights: [Highlight], announcement: Announcement? = nil) {
        self.version = version
        self.date = date
        self.summary = summary
        self.highlights = highlights
        self.announcement = announcement
    }

    public var id: String { version }

    /// "v1.0.0".
    public var title: String { "v\(version)" }
}

public enum ReleaseHistory {
    /// Newest first. Add a release at the top when shipping an update, with
    /// an `announcement` for a new MAJOR.MINOR (RELEASING.md).
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
