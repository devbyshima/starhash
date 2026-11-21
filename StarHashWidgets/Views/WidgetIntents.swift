import AppIntents
import Foundation
import StarHashKit

// In the app and the widgets alike, in every build: `openAppWhenRun` opens
// StarHash and runs `perform()` in the app, which only happens when the
// app knows the intent too (in Release a tap did nothing at all). And the
// app follows the link itself, through its router, as it does a link
// opened from outside: handing it to `OpenURLIntent` opened StarHash but
// never followed it, since that takes universal links, not `starhash://`
// ones.

/// A widget's tile, pill or circle: opens StarHash at one of its links
/// (Pay, the scanner, Buy, Activity, or dialling a code). A button with an
/// intent, since a small widget takes no links of its own.
struct OpenStarHashIntent: AppIntent {
    static let title: LocalizedStringResource = "Open StarHash"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Link") var link: String

    init() {}

    init(link: String) {
        self.link = link
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        if let url = URL(string: link) { AppEnvironment.router.handle(url) }
        #endif
        return .result()
    }
}

/// Scan to Pay in Control Center: opens StarHash on its scanner.
struct OpenScannerIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan to Pay"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        AppEnvironment.router.handle(StarHashLink.scan.url)
        #endif
        return .result()
    }
}
