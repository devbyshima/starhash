import StarHashKit
import SwiftUI

/// The one store and router the app, its views and its App Intents share.
@MainActor
enum AppEnvironment {
    static let store: StarHashStore = {
        #if DEBUG
        if DebugLaunch.inMemory { return DebugLaunch.seededStore() }
        #endif
        return StarHashStore(fileURL: StarHashStore.defaultFileURL)
    }()

    /// Buy's codes. Debug launches with -inMemory start from the defaults
    /// in a throwaway list.
    static let shortcuts: USSDShortcutList = {
        #if DEBUG
        if DebugLaunch.inMemory {
            let name = "StarHashDebugShortcuts"
            UserDefaults().removePersistentDomain(forName: name)
            let list = USSDShortcutList(defaults: UserDefaults(suiteName: name) ?? .standard)
            // -buyPinned [n]: the first n codes pinned (two by default),
            // with sample codes added when the four defaults are not enough.
            if DebugLaunch.arguments.contains("-buyPinned") {
                let count = DebugLaunch.value(after: "-buyPinned").flatMap(Int.init) ?? 2
                let samples = [
                    ("Airtime", "*182*2*1#", "phone.fill"), ("Bundles", "*182*2*1*2#", "wifi"),
                    ("Cash Power", "*662*1#", "bolt.fill"), ("Balance", "*182*6*1#", "banknote.fill"),
                    ("Water", "*182*3*1#", "drop.fill"),
                ]
                for sample in samples where list.shortcuts.count < count + 1 {
                    list.add(name: sample.0, code: sample.1, symbol: sample.2)
                }
                for shortcut in list.shortcuts.prefix(count) { list.setPinned(shortcut.id, true) }
            }
            // -buyEmpty: no codes at all, for Buy's empty state.
            if DebugLaunch.arguments.contains("-buyEmpty") {
                for shortcut in list.shortcuts { list.remove(shortcut.id) }
            }
            return list
        }
        #endif
        return USSDShortcutList()
    }()

    static let router: AppRouter = {
        let router = AppRouter()
        #if DEBUG
        if let tab = DebugLaunch.value(after: "-tab").flatMap(AppTab.init(rawValue:)) {
            router.show(tab)
        }
        #endif
        return router
    }()
}

/// The app's pages. The tab bar shows three places, Pay's holding Buy as
/// well (`TabBarItem`).
enum AppTab: String, Hashable, CaseIterable, Identifiable {
    case pay
    case buy
    case activity
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .pay: "Pay"
        case .buy: "Buy"
        case .activity: "Activity"
        case .settings: "Settings"
        }
    }

    /// The tab bar's symbol, and the Pay and Buy switcher's.
    var symbol: String {
        switch self {
        case .pay: "number"
        case .buy: "bag.fill"
        case .activity: "clock.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// Which page shows, how the tab bar stands, and which transaction (if
/// any) is open. Routes from URLs and intents go through here.
@MainActor
@Observable
final class AppRouter {
    private(set) var selectedTab: AppTab
    /// Pay or Buy, whichever showed last: the tab bar's middle place
    /// returns to it.
    private(set) var payPage: AppTab
    /// Pages showing a pushed screen or a search, where the tab bar steps
    /// aside.
    private(set) var pagesHidingTabBar: Set<AppTab> = []
    /// Shrunk while a page scrolls down.
    private(set) var isTabBarCompact = false

    /// Opens on the default page chosen in Settings, Pay or Buy.
    init() {
        let home = StarHashPreferences.defaultPage
        selectedTab = home
        payPage = home
    }

    /// The page chosen to open on, for the tab bar's middle place too.
    func showDefaultPage() {
        show(StarHashPreferences.defaultPage)
    }

    func setHidesTabBar(_ hides: Bool, on tab: AppTab) {
        if hides { pagesHidingTabBar.insert(tab) } else { pagesHidingTabBar.remove(tab) }
    }

    var isTabBarHidden: Bool { pagesHidingTabBar.contains(selectedTab) }

    func setTabBarCompact(_ compact: Bool) {
        if isTabBarCompact != compact { isTabBarCompact = compact }
    }
    /// The transaction whose details page is open on Activity.
    var openTransactionID: UUID?
    /// The month whose report is open on Activity (Reports), by its first
    /// day.
    var openReportMonth: Date?
    /// A scam warning's advice, over the app, from its notification.
    var scamNotice: ScamNotice?
    /// Pay's QR scanner, asked for from outside Pay (a widget, a link),
    /// until Pay opens it. A new value each time.
    private(set) var scanRequest: UUID?

    /// Opens Reports on Activity at `month`'s report.
    func showReport(month: Date) {
        show(.activity)
        openTransactionID = nil
        openReportMonth = Calendar.current.dateInterval(of: .month, for: month)?.start ?? month
    }

    /// Opens Pay with its QR scanner up.
    func scan() {
        show(.pay)
        scanRequest = UUID()
    }

    func takeScanRequest() -> Bool {
        defer { scanRequest = nil }
        return scanRequest != nil
    }
    /// A payment whose page should open Verify's sheet, until it does.
    var verifyTransactionID: UUID?

    /// Opens a payment's page on Activity with Verify's sheet over it.
    func verify(_ id: UUID) {
        show(.activity)
        openTransactionID = id
        verifyTransactionID = id
    }
    #if DEBUG
    /// `starhash://whatsnew?page=<n>` (DEBUG): What's New over the app at
    /// that page, to look at it without an update.
    var whatsNewPreviewPage: Int?
    #endif
    /// Someone to pay, asked for outside the Pay tab (Pay Again on a
    /// transaction), until Pay takes it with `takePayRequest()`.
    private(set) var payRequest: PayRequest?

    /// Switches to Pay with `recipient` chosen under the amount, and the
    /// amount when one is asked for (a scanned code's); Pay then dials them
    /// once there is an amount.
    func pay(_ recipient: Recipient, amount: Int? = nil) {
        payRequest = PayRequest(recipient: recipient, amount: amount)
        show(.pay)
    }

    /// The pending request, cleared so it is used once.
    func takePayRequest() -> PayRequest? {
        defer { payRequest = nil }
        return payRequest
    }

    /// The last word from Shortcuts after StarHash ran a shortcut through
    /// x-callback-url (auto-verify's check). A new value each time.
    private(set) var shortcutCallback: ShortcutCallback?

    /// Shows `tab`, with the tab bar at full size.
    func show(_ tab: AppTab) {
        selectedTab = tab
        if tab == .pay || tab == .buy { payPage = tab }
        setTabBarCompact(false)
    }

    /// starhash://pay, starhash://buy, starhash://activity,
    /// starhash://settings, starhash://transaction/<uuid>. starhash://help,
    /// from before Help moved into Settings, opens Settings. A StarHash QR
    /// code's link, starhash://pay?to=<number or code>, chooses who to pay;
    /// starhash://scan opens the scanner, starhash://report the month's
    /// report, and starhash://dial?code=<code> (or a tel: link a widget
    /// hands over) dials a code. In DEBUG builds,
    /// starhash://whatsnew?page=<n> shows What's New.
    func handle(_ url: URL) {
        if url.scheme == "tel" {
            Task { _ = await USSDDialer.open(url) }
            return
        }
        guard url.scheme == "starhash" else { return }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if url.host() == "help" {
            show(.settings)
            return
        }
        if url.host() == "pay", query.contains(where: { $0.name == "to" }) {
            if let request = PaymentQR.parse(url.absoluteString) {
                pay(request.recipient, amount: request.amount)
            } else {
                show(.pay)
            }
            return
        }
        if let tab = url.host().flatMap(AppTab.init(rawValue:)) {
            show(tab)
            return
        }
        switch url.host() {
        case "shortcut":
            let result = ShortcutCallback.Result(rawValue: url.lastPathComponent) ?? .error
            shortcutCallback = ShortcutCallback(result: result)
        case "transaction":
            if let id = UUID(uuidString: url.lastPathComponent) {
                show(.activity)
                openTransactionID = id
            }
        case "scan":
            scan()
        case "report":
            showReport(month: .now)
        case "dial":
            if let code = query.first(where: { $0.name == "code" })?.value.flatMap(USSDShortcut.code(from:)),
               let tel = USSD.telURL(for: code) {
                Task { _ = await USSDDialer.open(tel) }
            }
        #if DEBUG
        case "whatsnew":
            let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "page" }?.value.flatMap(Int.init)
            whatsNewPreviewPage = page ?? 0
        #endif
        default: break
        }
    }
}

/// One "pay this person" hand-off to the Pay tab. Its own id, so asking
/// twice for the same recipient still reads as a new request.
struct PayRequest: Identifiable, Equatable {
    let id = UUID()
    let recipient: Recipient
    /// The amount a scanned code asked for, typed in for them.
    var amount: Int?
}

/// A scam warning's advice, shown over the app from its notification.
struct ScamNotice: Identifiable, Equatable {
    let id = UUID()
    /// What the notification said.
    let message: String
}

/// How a shortcut StarHash ran through x-callback-url finished.
struct ShortcutCallback: Equatable {
    enum Result: String {
        case success
        case error
        case cancel
    }

    let id = UUID()
    let result: Result
}
