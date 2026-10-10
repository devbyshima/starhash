#if DEBUG || WIDGET_EXTENSION
import AppIntents
import Foundation

/// Which page of codes the Buy widget shows, kept in the extension's own
/// defaults, since only the widget changes it.
enum WidgetChoices {
    private static let pageKey = "buyPage"

    static var buyPage: Int {
        get { UserDefaults.standard.integer(forKey: pageKey) }
        set { UserDefaults.standard.set(newValue, forKey: pageKey) }
    }
}

/// Buy's More: the next page of codes, run in the widget without opening
/// StarHash.
struct NextCodesPageIntent: AppIntent {
    static let title: LocalizedStringResource = "Show More Codes"
    static let isDiscoverable = false

    /// How many pages there are, so the last wraps round to the first.
    @Parameter(title: "Pages") var pages: Int

    init() {}

    init(pages: Int) {
        self.pages = pages
    }

    func perform() async throws -> some IntentResult {
        WidgetChoices.buyPage = (WidgetChoices.buyPage + 1) % max(pages, 1)
        return .result()
    }
}
#endif
