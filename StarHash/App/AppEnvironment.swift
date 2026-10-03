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

    /// Where numbers and codes were paid, for Nearby.
    static let places: PlaceMemory = {
        #if DEBUG
        if DebugLaunch.inMemory { return DebugLaunch.seededPlaces() }
        #endif
        return PlaceMemory(fileURL: PlaceMemory.defaultFileURL)
    }()

    /// Buy's codes. Debug launches with -inMemory start from the defaults
    /// in a throwaway list.
    static let shortcuts: USSDShortcutList = {
        #if DEBUG
        if DebugLaunch.inMemory {
            let name = "StarHashDebugShortcuts"
            UserDefaults().removePersistentDomain(forName: name)
            return USSDShortcutList(defaults: UserDefaults(suiteName: name) ?? .standard)
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
        case .activity: "list.bullet.rectangle.fill"
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
    /// Someone to pay, asked for outside the Pay tab (Pay Again on a
    /// transaction), until Pay takes it with `takePayRequest()`.
    private(set) var payRequest: PayRequest?

    /// Switches to Pay with `recipient` chosen under the amount; Pay then
    /// dials them once there is an amount.
    func pay(_ recipient: Recipient) {
        payRequest = PayRequest(recipient: recipient)
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
    /// from before Help moved into Settings, opens Settings.
    func handle(_ url: URL) {
        guard url.scheme == "starhash" else { return }
        if url.host() == "help" {
            show(.settings)
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
        default: break
        }
    }
}

/// One "pay this person" hand-off to the Pay tab. Its own id, so asking
/// twice for the same recipient still reads as a new request.
struct PayRequest: Identifiable, Equatable {
    let id = UUID()
    let recipient: Recipient
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
