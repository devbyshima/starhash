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
    // iOS 26 reads `supportedModes`, earlier iOS the flag: in the app's
    // foreground, where `perform()` hands the link to the router. Drop the
    // flag once StarHash needs iOS 26.
    static let openAppWhenRun = true
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

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
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        AppEnvironment.router.handle(StarHashLink.scan.url)
        #endif
        return .result()
    }
}
