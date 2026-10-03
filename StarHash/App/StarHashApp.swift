import StarHashKit
import SwiftUI

@main
struct StarHashApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let store = AppEnvironment.store
    private let router = AppEnvironment.router

    init() {
        #if DEBUG
        if DebugLaunch.arguments.contains("-skipOnboarding") {
            UserDefaults.standard.set(true, forKey: PreferenceKey.hasOnboarded)
            // Seen too, so it does not cover the page a screenshot is after
            // (-note shows it anyway).
            UserDefaults.standard.set(true, forKey: PreferenceKey.hasSeenDeveloperNote)
            // Onboarding asks for the wallet; skipping it needs one.
            if (UserDefaults.standard.string(forKey: PreferenceKey.wallet) ?? "").isEmpty {
                UserDefaults.standard.set(Recipient.Network.mtn.rawValue, forKey: PreferenceKey.wallet)
            }
        }
        if let wallet = DebugLaunch.value(after: "-wallet") {
            // "none" clears it, for onboarding as a fresh install sees it.
            let network = Recipient.Network(rawValue: wallet)
            UserDefaults.standard.set(network?.rawValue ?? "", forKey: PreferenceKey.wallet)
        }
        if DebugLaunch.arguments.contains("-nearbyHere") {
            UserDefaults.standard.set(true, forKey: PreferenceKey.nearbyLocation)
        }
        if DebugLaunch.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: PreferenceKey.hasOnboarded)
        }
        #endif
        Self.useSpaceGroteskInNavigationBars()
    }

    /// Navigation bar titles (Settings and its pages, a transaction) are
    /// UIKit's, outside SwiftUI's font environment: the page title's 21pt
    /// bold, scaled for the text size at launch up to 28.
    private static func useSpaceGroteskInNavigationBars() {
        let bar = UINavigationBar.appearance()
        let title = UIFont.starhash(StarHashMetrics.pageTitleSize, weight: 700)
        bar.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: title, maximumPointSize: 28)]
        bar.largeTitleTextAttributes = [.font: UIFont.starhash(34, weight: 700)]
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Text with no font of its own (list rows, fields) is in
                // Space Grotesk too.
                .font(.starhash(.body))
                .environment(store)
                .environment(router)
                .tint(Color.starhashPrimaryText)
                .onOpenURL { router.handle($0) }
        }
        .onChange(of: scenePhase) { _, phase in
            // The Process Carrier SMS shortcut may have written while we
            // were in the background.
            if phase == .active { store.reloadFromDisk() }
        }
    }
}

private extension UIFont {
    /// Space Grotesk at a point on its weight axis (300 to 700). Asked for
    /// by name alone, UIKit gives the variable font's default, Light.
    static func starhash(_ size: CGFloat, weight: CGFloat) -> UIFont {
        let wght = 0x7767_6874 // the 'wght' axis tag
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: Font.starhashFamily,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wght: weight],
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}
