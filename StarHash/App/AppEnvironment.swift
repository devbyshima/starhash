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

    static let router: AppRouter = {
        let router = AppRouter()
        #if DEBUG
        if let tab = DebugLaunch.value(after: "-tab").flatMap(AppTab.init(rawValue:)) {
            router.selectedTab = tab
        }
        router.isMenuOpen = DebugLaunch.arguments.contains("-menu")
        #endif
        return router
    }()
}

/// The pages of the side menu, in its order.
enum AppTab: String, Hashable, CaseIterable, Identifiable {
    case pay
    case buy
    case activity
    case settings
    case help

    var id: Self { self }

    var title: String {
        switch self {
        case .pay: "Pay"
        case .buy: "Buy"
        case .activity: "Activity"
        case .settings: "Settings"
        case .help: "Help"
        }
    }

    var symbol: String {
        switch self {
        case .pay: "number"
        case .buy: "bag"
        case .activity: "list.bullet.rectangle"
        case .settings: "gearshape"
        case .help: "questionmark.circle"
        }
    }
}

/// Which page shows, whether the side menu is open, and which transaction
/// (if any) is open. Routes from URLs and intents go through here.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .pay
    var isMenuOpen = false
    /// Pages showing a pushed screen, where a swipe from the left edge goes
    /// back instead of opening the menu.
    private(set) var pagesWithPushedScreens: Set<AppTab> = []

    func setPushedScreen(_ isPushed: Bool, on tab: AppTab) {
        if isPushed { pagesWithPushedScreens.insert(tab) } else { pagesWithPushedScreens.remove(tab) }
    }

    /// Whether a swipe from the left edge opens the menu: only on a page's
    /// first screen.
    var edgeSwipeOpensMenu: Bool {
        !isMenuOpen && !pagesWithPushedScreens.contains(selectedTab)
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

    /// Shows `tab` and closes the menu.
    func show(_ tab: AppTab) {
        selectedTab = tab
        isMenuOpen = false
    }

    /// starhash://pay, starhash://buy, starhash://activity,
    /// starhash://settings, starhash://help, starhash://transaction/<uuid>
    func handle(_ url: URL) {
        guard url.scheme == "starhash" else { return }
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
