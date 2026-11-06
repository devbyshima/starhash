#if DEBUG
import StarHashKit
import SwiftUI
import UIKit

/// Every screen StarHash shows, each stood up on its own with sample data,
/// for the Screens Mac app. The pages run on a store, owner and code list of
/// their own (`ScreensSample`), so nothing here touches the real ones.
@MainActor
enum ScreensCatalog {
    static let entries: [ScreensEntry] = [
        // Launch
        entry("splash", "Splash", "Launch") { SplashView(onFinish: {}).screensStill() },

        // Onboarding, each screen of `OnboardingView` at its stage.
        entry("onboarding-reel", "Reel", "Onboarding") { onboarding(.reel) },
        entry("onboarding-wallet", "Wallet", "Onboarding") { onboarding(.wallet) },
        entry("onboarding-number", "Number", "Onboarding") { onboarding(.number) },
        entry("onboarding-photo", "Photo", "Onboarding") { onboarding(.photo) },
        entry("onboarding-contacts", "Contacts", "Onboarding") { onboarding(.contacts) },
        entry("onboarding-nearby", "Nearby", "Onboarding") { onboarding(.nearby) },
        entry("onboarding-notifications", "Notifications", "Onboarding") { onboarding(.notifications) },
        entry("onboarding-auto-verify", "Auto-verify", "Onboarding") { onboarding(.autoVerify) },
        entry("onboarding-setup", "Auto-verify Setup", "Onboarding") { onboarding(.setup) },
        entry("welcome-note", "Welcome Note", "Onboarding") {
            ScreensSheet(base: tabs(.pay)) { DeveloperNoteSheet(afterOnboarding: true) }
        },

        // Pay
        entry("pay", "Pay", "Pay") { tabs(.pay) },
        entry("pay-recipients", "Recipients", "Pay") {
            NavigationStack {
                RecipientPickerView(amount: 5_000) { _ in }
            }
        },
        entry("pay-contact-details", "Contact Details", "Pay") {
            ScreensSheet(base: tabs(.pay)) {
                ContactDetailSheet(contact: ScreensSample.contact, amount: 5_000) { _ in }
            }
        },
        entry("pay-choose-number", "Choose Number", "Pay") {
            ScreensSheet(base: tabs(.pay)) {
                ChooseNumberSheet(contact: ScreensSample.contact) { _ in }
            }
        },
        entry("pay-scanner", "Scan to Pay", "Pay") { QRScannerView { _ in } },
        entry("pay-my-code", "My Code", "Pay") {
            ScreensSheet(base: QRScannerView { _ in }) { MyCodeSheet() }
        },
        entry("pay-voice-line-hint", "Voice Line Hint", "Pay") {
            ScreensSheet(base: tabs(.pay)) {
                VoiceLineHintSheet(wallet: ScreensSample.twoSIMOwner.wallets.selected ?? ScreensSample.twoSIMOwner.wallets.wallets[0])
            }
        },
        entry("pay-scam-notice", "Scam Notice", "Pay") {
            ScreensSheet(base: tabs(.pay)) {
                ScamNoticeSheet(notice: ScamNotice(message: "Someone asked you to send back money they say they sent by mistake."))
            }
        },

        // Buy
        entry("buy", "Buy", "Buy") { tabs(.buy) },
        entry("buy-pinned", "Buy, Pinned", "Buy") { tabs(.buy, shortcuts: ScreensSample.pinnedShortcuts) },
        entry("buy-empty", "Buy, Empty", "Buy") { tabs(.buy, shortcuts: ScreensSample.emptyShortcuts) },

        // Transactions
        entry("activity", "Transactions", "Transactions") { tabs(.activity) },
        entry("activity-empty", "Transactions, Empty", "Transactions") { tabs(.activity, store: ScreensSample.emptyStore) },
        entry("activity-report", "Report", "Transactions") {
            ScreensPushed(page: ScreensRoute.report) { _ in ReportPage() }
        },
        entry("transaction-confirmed", "Transaction", "Transactions") {
            transaction(in: ScreensSample.store) { $0.status == .confirmed && $0.direction == .outgoing }
        },
        entry("transaction-pending", "Transaction, Pending", "Transactions") {
            transaction(in: ScreensSample.store) { $0.status == .pending }
        },
        entry("transaction-failed", "Transaction, Failed", "Transactions") {
            transaction(in: ScreensSample.failedStore) { $0.status == .failed }
        },
        entry("transaction-verify", "Verify Payment", "Transactions") {
            let pending = ScreensSample.store.transactions.first { $0.status == .pending }
            ScreensSheet(base: transaction(in: ScreensSample.store) { $0.id == pending?.id }) {
                VerifyPaymentSheet(transactionID: pending?.id ?? UUID())
            }
        },

        // Settings
        entry("settings", "Settings", "Settings") { tabs(.settings) },
        entry("settings-profile", "Profile", "Settings") { settings(.profile) },
        entry("settings-photo-options", "Photo Options", "Settings") {
            ScreensSheet(base: settings(.profile)) {
                ProfilePhotoOptionsSheet(hasPhoto: true) { _ in }
            }
        },
        entry("settings-photo-crop", "Move and Scale", "Settings") {
            PhotoCropView(image: ScreensSample.photo, onCancel: {}, onChoose: { _ in })
        },
        entry("settings-notifications", "Notifications", "Settings") { settings(.notifications) },
        entry("settings-auto-verify", "Auto-verify", "Settings") { settings(.autoVerify) },
        entry("settings-turn-off-auto-verify", "Turn Off Auto-verify", "Settings") {
            ScreensSheet(base: tabs(.settings)) { TurnOffAutoVerifySheet {} }
        },
        entry("settings-keep-sim", "Keep SIM", "Settings") {
            ScreensSheet(base: tabs(.settings, owner: ScreensSample.twoSIMOwner)) {
                KeepSIMSheet(sims: ScreensSample.twoSIMOwner.wallets.wallets.compactMap(\.sim)) { _ in }
            }
        },
        entry("settings-whats-new", "What's New", "Settings") { settings(.whatsNew) },
        entry("settings-release", "Release Notes", "Settings") {
            settings(.release(ReleaseHistory.releases.first?.version ?? "1.0.0"))
        },
        entry("settings-about", "About StarHash", "Settings") { settings(.about) },
        entry("settings-developer-note", "Developer Note", "Settings") {
            ScreensSheet(base: settings(.about)) { DeveloperNoteSheet() }
        },
        entry("settings-review-note", "Review Note", "Settings") {
            ScreensSheet(base: tabs(.pay)) { ReviewNoteSheet() }
        },
        entry("settings-terms", "Terms of Service", "Settings") { settings(.terms) },
        entry("settings-privacy", "Privacy Policy", "Settings") { settings(.privacy) },
        entry("settings-licences", "Licences", "Settings") { settings(.licences) },
        entry("settings-licence", "Licence", "Settings") { settings(.licence(ThirdPartyPiece.all[0])) },
        entry("settings-feature-flags", "Feature Flags", "Settings") { settings(.featureFlags) },

        // What's New
        entry("whats-new", "What's New", "What's New") {
            ScreensSheet(base: tabs(.pay)) {
                WhatsNewSheet(announcement: WhatsNewLaunch.preview, window: WhatsNewWindow(width: 402, bottomInset: 34))
            }
        },

        // Widgets
        entry("widgets", "Widgets", "Widgets") { WidgetGallery() },
    ]

    // MARK: - Building blocks

    /// One entry, with the app's environment round its screen.
    /// The screen comes back as an `AnyView` from inside its closure, on
    /// the main actor, so no view's conformance has to cross into the
    /// catalog's nonisolated list.
    private static func entry(
        _ id: String,
        _ title: String,
        _ flow: String,
        @ScreenBuilder _ make: @escaping @MainActor () -> AnyView
    ) -> ScreensEntry {
        ScreensEntry(id: id, title: title, flow: flow) { _ in
            MainActor.assumeIsolated { ScreensBox(AnyView(make().screensEnvironment())) }.view
        }
    }

    /// The tabs as the app shows them, on `tab`.
    private static func tabs(
        _ tab: AppTab,
        store: StarHashStore = ScreensSample.store,
        owner: Owner = ScreensSample.owner,
        shortcuts: USSDShortcutList = ScreensSample.shortcuts
    ) -> some View {
        let router = AppRouter()
        router.show(tab)
        return TabContainer()
            .environment(store)
            .environment(owner)
            .environment(router)
            .environment(shortcuts)
    }

    /// A transaction's page, pushed on Activity as a tap opens it.
    private static func transaction(in store: StarHashStore, where matches: (StarHashKit.Transaction) -> Bool) -> some View {
        let router = AppRouter()
        router.show(.activity)
        router.openTransactionID = store.transactions.first(where: matches)?.id
        return TabContainer()
            .environment(store)
            .environment(router)
    }

    /// A Settings page, pushed as its row opens it.
    private static func settings(_ page: SettingsPage) -> some View {
        ScreensPushed(page: page) { $0.destination }
    }

    /// An onboarding screen. `OnboardingView` starts on the stage saved in
    /// the defaults, so the stage is saved just before it is made.
    private static func onboarding(_ stage: OnboardingView.Stage) -> some View {
        UserDefaults.standard.set(stage.rawValue, forKey: PreferenceKey.onboardingStage)
        return OnboardingView {}.screensStill()
    }
}

/// One screen, as an `AnyView`.
@resultBuilder
enum ScreenBuilder {
    @MainActor static func buildBlock(_ screen: some View) -> AnyView { AnyView(screen) }
}

/// Carries a view out of `MainActor.assumeIsolated`, which wants a
/// Sendable result. Made and read on the main actor only.
private struct ScreensBox: @unchecked Sendable {
    let view: AnyView
    init(_ view: AnyView) { self.view = view }
}

/// Pages pushed on a stack of their own, so they show their back button.
private enum ScreensRoute: Hashable {
    case report
}

/// A page already pushed, as a row or button opens it.
private struct ScreensPushed<Page: Hashable, Destination: View>: View {
    @State var path: [Page]
    let destination: (Page) -> Destination

    init(page: Page, @ViewBuilder destination: @escaping (Page) -> Destination) {
        _path = State(initialValue: [page])
        self.destination = destination
    }

    var body: some View {
        NavigationStack(path: $path) {
            Color.starhashBackground
                .ignoresSafeArea()
                .navigationDestination(for: Page.self, destination: destination)
        }
    }
}

/// A sheet open over a page, as the app presents it.
private struct ScreensSheet<Base: View, Content: View>: View {
    let base: Base
    @ViewBuilder let content: () -> Content
    @State private var isPresented = true

    var body: some View {
        base.sheet(isPresented: $isPresented, content: content)
    }
}

private extension View {
    /// With Reduce Motion on, so a screen that plays itself in (the splash,
    /// onboarding's words rising) is drawn at its end, not caught partway
    /// when Screens takes its picture.
    @ViewBuilder
    func screensStill() -> some View {
        if #available(iOS 26.4, *) {
            environment(\._accessibilityReduceMotion, true)
        } else {
            self
        }
    }

    /// What `StarHashApp` gives every page: the sample store, owner, router
    /// and codes (a screen's own, set closer to it, wins), the brand's type,
    /// the language chosen and the tint.
    func screensEnvironment() -> some View {
        font(.starhash(.body))
            .environment(\.locale, AppLanguage.stored.locale)
            .environment(ScreensSample.store)
            .environment(ScreensSample.owner)
            .environment(AppRouter())
            .environment(ScreensSample.shortcuts)
            .tint(Color.starhashPrimaryText)
            .background(Color.starhashBackground.ignoresSafeArea())
    }
}

// MARK: - Sample data

@MainActor
enum ScreensSample {
    /// The app's sample transactions, in memory.
    static let store: StarHashStore = {
        let store = StarHashStore(fileURL: nil)
        for transaction in SampleData.transactions() { store.add(transaction) }
        return store
    }()

    /// Nothing logged yet.
    static let emptyStore = StarHashStore(fileURL: nil)

    /// The samples with the pending payment failed for want of a message.
    static let failedStore: StarHashStore = {
        let store = StarHashStore(fileURL: nil)
        for transaction in SampleData.transactions() { store.add(transaction) }
        store.expireUnconfirmed(dialledSince: .distantPast)
        return store
    }()

    /// An owner with a name, one MTN SIM and its number, in defaults of
    /// their own.
    static let owner: Owner = {
        let owner = Owner(defaults: defaults("ScreensOwner"))
        owner.setName("Shima Serein")
        owner.setNumber("0788123456")
        owner.choose(.mtn)
        return owner
    }()

    /// Two SIMs, MTN and Airtel, for the default SIM's screens.
    static let twoSIMOwner: Owner = {
        let owner = Owner(defaults: defaults("ScreensTwoSIMOwner"))
        owner.setName("Shima Serein")
        owner.setNumber("0788123456")
        owner.useTwoSIMs()
        owner.setOtherNumber("0722123456")
        owner.choose(.mtn)
        return owner
    }()

    /// Buy's four default codes.
    static let shortcuts = USSDShortcutList(defaults: defaults("ScreensShortcuts"))

    /// The defaults with the first two pinned.
    static let pinnedShortcuts: USSDShortcutList = {
        let list = USSDShortcutList(defaults: defaults("ScreensPinnedShortcuts"))
        for shortcut in list.shortcuts.prefix(2) { list.setPinned(shortcut.id, true) }
        return list
    }()

    /// No codes at all.
    static let emptyShortcuts: USSDShortcutList = {
        let list = USSDShortcutList(defaults: defaults("ScreensEmptyShortcuts"))
        for shortcut in list.shortcuts { list.remove(shortcut.id) }
        return list
    }()

    /// A contact with two numbers, no photo.
    static let contact = PayContact(
        id: "screens-ariane",
        name: "Ariane Ishimwe",
        recipients: [
            Recipient(name: "Ariane Ishimwe", destination: "0788123998", kind: .phone),
            Recipient(name: "Ariane Ishimwe", destination: "0722123998", kind: .phone),
        ],
        hasPhoto: false
    )

    /// A photo to frame: soft green light on the deep green.
    static let photo: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 1200)).image { context in
        UIColor(Color.brandForest).setFill()
        context.fill(CGRect(x: 0, y: 0, width: 900, height: 1200))
        UIColor(Color.brandAccent).setFill()
        context.cgContext.fillEllipse(in: CGRect(x: 250, y: 300, width: 400, height: 400))
        context.cgContext.fillEllipse(in: CGRect(x: 150, y: 760, width: 600, height: 600))
    }

    /// Fresh defaults under `name`, so every launch starts from the same
    /// sample state.
    private static func defaults(_ name: String) -> UserDefaults {
        UserDefaults().removePersistentDomain(forName: name)
        return UserDefaults(suiteName: name) ?? .standard
    }
}
#endif
