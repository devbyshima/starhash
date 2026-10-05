import StarHashKit
import SwiftUI

@main
struct StarHashApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let store = AppEnvironment.store
    private let router = AppEnvironment.router
    private let shortcuts = AppEnvironment.shortcuts

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
        // Not "-appearance": a launch argument named after a key overrides
        // that key's saved value for the whole run.
        if let appearance = DebugLaunch.value(after: "-appAppearance") {
            UserDefaults.standard.set(appearance, forKey: PreferenceKey.appearance)
        }
        if DebugLaunch.arguments.contains("-nearbyHere") {
            UserDefaults.standard.set(true, forKey: PreferenceKey.nearbyLocation)
        }
        if DebugLaunch.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: PreferenceKey.hasOnboarded)
        }
        #endif
        Self.useSpaceGroteskInNavigationBars()
        // Before launch finishes, so a tap that opened StarHash is heard.
        StarHashNotifications.shared.start()
        // Nearby's own file from before it was built from the payments:
        // nothing reads it now, and its places must not outlive it.
        try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "StarHash/places.json"))
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
            SplashGate {
                RootView()
                    // Text with no font of its own (list rows, fields) is in
                    // Space Grotesk too.
                    .font(.starhash(.body))
                    .environment(store)
                    .environment(router)
                    .environment(shortcuts)
                    .tint(Color.starhashPrimaryText)
                    .onOpenURL { router.handle($0) }
                    // A payment dialled, settled or deleted: its reminder
                    // and the summaries follow.
                    .onChange(of: store.transactions) {
                        Task { await StarHashNotifications.shared.sync() }
                    }
                    // A payment can pass its hour while StarHash is open.
                    .task(id: scenePhase == .active) {
                        while scenePhase == .active, !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(60))
                            PaymentExpiry.run()
                        }
                    }
            }
            // Settings' Appearance, the splash included.
            .onAppear { AppAppearance.apply(.stored) }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // The Process Carrier SMS shortcut may have written while we
            // were in the background, and notifications may have been
            // turned on or off in the Settings app.
            if phase == .active {
                store.reloadFromDisk()
                PaymentExpiry.run()
                Task { await StarHashNotifications.shared.sync() }
            }
            AppLock.shared.sceneChanged(to: phase)
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
