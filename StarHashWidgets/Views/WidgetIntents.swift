#if DEBUG || WIDGET_EXTENSION
import AppIntents
import Foundation

/// A widget's tile, pill or circle: opens StarHash at one of its links
/// (Pay, the scanner, Buy, Activity, or dialling the balance code). A
/// button with an intent, since a small widget takes no links of its own.
struct OpenStarHashIntent: AppIntent {
    static let title: LocalizedStringResource = "Open StarHash"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Link") var link: String

    init() {}

    init(link: String) {
        self.link = link
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: link) ?? URL(string: "starhash://pay")!))
    }
}
#endif
