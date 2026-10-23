import StarHashKit
import UIKit

/// The menu a long press on StarHash's icon shows: Scan to Pay, Balance,
/// Buy and Activity, as Quick Pay's medium widget offers them. Set by the
/// app rather than Info.plist, so they are in the language chosen in
/// Settings and Balance dials the wallet's own code; each carries one of
/// StarHash's links, which the router follows once the app is in front.
@MainActor
enum QuickActions {
    private static let linkKey = "link"

    /// A link chosen from the menu, waiting for the app to come to the
    /// front: at launch the router has nothing on screen to act on yet, and
    /// a code dialled before then would not reach the call screen.
    private static var pending: URL?

    /// Hands iOS the menu as things stand: run as StarHash comes to the
    /// front and goes to the background, and when the language changes.
    static func update() {
        let wallet = StarHashPreferences.wallet
        UIApplication.shared.shortcutItems = [
            item(String(starhash: "Scan to Pay"), symbol: "qrcode", link: "starhash://scan"),
            item(String(starhash: "Balance"), subtitle: wallet.walletName, symbol: "banknote.fill",
                 link: "starhash://dial?code=" + (USSD.balance(for: wallet).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")),
            item(String(starhash: "Buy"), symbol: "bag.fill", link: "starhash://buy"),
            item(String(starhash: "Transactions"), symbol: "clock.fill", link: "starhash://activity"),
        ]
    }

    /// A choice from the menu: followed now when StarHash is already in
    /// front, else kept for `performPending()`.
    @discardableResult
    static func perform(_ item: UIApplicationShortcutItem, now: Bool) -> Bool {
        guard let link = (item.userInfo?[linkKey] as? String).flatMap(URL.init(string:)) else { return false }
        if now {
            AppEnvironment.router.handle(link)
        } else {
            pending = link
        }
        return true
    }

    /// The choice that opened StarHash, once it is in front.
    static func performPending() {
        guard let link = pending else { return }
        pending = nil
        AppEnvironment.router.handle(link)
    }

    private static func item(_ title: String, subtitle: String? = nil, symbol: String, link: String) -> UIApplicationShortcutItem {
        // StarHash's own icon, from the asset catalog, as everywhere else.
        let icon = StarIcon(symbol: symbol).map { UIApplicationShortcutIcon(templateImageName: $0.assetName) }
        return UIApplicationShortcutItem(
            type: link,
            localizedTitle: title,
            localizedSubtitle: subtitle,
            icon: icon,
            userInfo: [linkKey: link as NSString]
        )
    }
}

/// Hears a quick action: iOS gives the one that launched StarHash with the
/// scene's connection, and later ones to the scene's delegate.
final class StarHashAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let item = options.shortcutItem {
            QuickActions.perform(item, now: false)
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = StarHashSceneDelegate.self
        return configuration
    }
}

final class StarHashSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(QuickActions.perform(shortcutItem, now: windowScene.activationState == .foregroundActive))
    }
}
