import StarHashKit
import SwiftUI

/// Settings: what StarHash saves, its lock, and More (the terms of service,
/// the privacy policy, a feature request, and About StarHash, which holds
/// What's New, onboarding, the note and the source code), then Delete All
/// Data. (The wallet switcher lives on
/// Pay.) Its own NavigationStack, with each page pushed onto it, over which
/// the tab bar steps aside.
struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @State private var path: [SettingsPage] = SettingsLaunch.initialPath

    var body: some View {
        NavigationStack(path: $path) {
            SettingsRootList { path.append(.autoVerify) }
                .starhashNavigationTitle("Settings")
                .navigationDestination(for: SettingsPage.self) { page in
                    // The setup brings its own back button, which steps
                    // back through it first.
                    if page == .autoVerify {
                        page.destination
                    } else {
                        page.destination.starhashBackButton()
                    }
                }
        }
        // A light tap as a page opens, which the rows that open pages leave
        // to this (`SettingsLinkRow`), so the auto-verify switch's push
        // taps too.
        .sensoryFeedback(.impact(weight: .light), trigger: path.count) { old, new in new > old }
        .onChange(of: path.isEmpty, initial: true) { _, isEmpty in
            router.setHidesTabBar(!isEmpty, on: .settings)
        }
    }
}

/// Every page pushed in the Settings tab.
enum SettingsPage: Hashable {
    case autoVerify
    case whatsNew
    case release(String)
    case terms
    case privacy
    case about

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .terms: TermsOfServiceView()
        case .privacy: PrivacyPolicyView()
        case .about: AboutStarHashView()
        case .autoVerify: AutoVerificationGuide()
        case .whatsNew: WhatsNewView()
        case .release(let version): ReleaseDetailView(version: version)
        }
    }
}

private struct SettingsRootList: View {
    /// Opens the auto-verify setup, the only way to turn it on.
    let setUpAutoVerify: () -> Void

    @Environment(StarHashStore.self) private var store
    @Environment(AppRouter.self) private var router

    @AppStorage(PreferenceKey.saveTransactions) private var saveTransactions = true
    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @AppStorage(PreferenceKey.nearbyLocation) private var nearbyLocation = false
    @AppStorage(PreferenceKey.saveRecents) private var saveRecents = true
    @AppStorage(PreferenceKey.confirmDeletes) private var confirmDeletes = true
    @AppStorage(PreferenceKey.defaultPage) private var defaultPage = AppTab.pay.rawValue
    @AppStorage(PreferenceKey.appearance) private var appearance = AppAppearance.system
    @AppStorage(PreferenceKey.lastVerifiedAt) private var lastVerifiedAt: Double = 0
    @AppStorage(PreferenceKey.autoVerifySetUp) private var autoVerifySetUp = false
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn
    @AppStorage(PreferenceKey.appLock) private var appLock = false

    @State private var confirmsDeleteAll = false
    @State private var confirmsAutoVerifyOff = SettingsLaunch.confirmsAutoVerifyOff
    @State private var locationRefused = false

    var body: some View {
        ScrollViewReader { proxy in
            list
                #if DEBUG
                // -settingsScrolled: start at the bottom, to check the top edge.
                .task {
                    guard DebugLaunch.arguments.contains("-settingsScrolled") else { return }
                    try? await Task.sleep(for: .milliseconds(500))
                    proxy.scrollTo("starhash", anchor: .bottom)
                }
                #endif
        }
    }

    private var list: some View {
        settingsList
            .starhashTabBarClearance()
            .starhashTabBarFollowsScroll()
    }

    private var settingsList: some View {
        SettingsScroll {
            SettingsCard("Transactions") {
                SettingsToggleRow(
                    symbol: "tray.full.fill",
                    title: "Save transactions",
                    caption: "Keep a history of what you pay and receive",
                    isOn: $saveTransactions
                )
                SettingsToggleRow(
                    symbol: "checkmark.message.fill",
                    title: "Auto-verify transactions",
                    caption: "Confirm payments from \(wallet.messagesName) messages",
                    isOn: autoVerifyBinding
                )
                SettingsToggleRow(
                    symbol: "questionmark.bubble.fill",
                    title: "Ask before deleting",
                    caption: "Confirm every delete except a swipe",
                    isOn: $confirmDeletes
                )
            }

            SettingsCard("Recipients") {
                SettingsToggleRow(
                    symbol: "person.crop.circle.fill",
                    title: "Enable contacts",
                    caption: "Pick who to pay from your contacts",
                    isOn: contactsBinding
                )
                SettingsToggleRow(
                    symbol: "location.fill",
                    title: "Nearby",
                    caption: "Suggest who you paid at the place you're in",
                    isOn: locationBinding
                )
                SettingsToggleRow(
                    symbol: "clock.arrow.circlepath",
                    title: "Save recent recipients",
                    caption: "Show who you paid last at the top",
                    isOn: $saveRecents
                )
            }

            SettingsCard("Pay & Buy") {
                SettingsRow(
                    symbol: "house.fill",
                    title: "Default page",
                    caption: "Where StarHash opens"
                ) {
                    SettingsChoiceMenu(
                        title: "Default page",
                        selection: $defaultPage,
                        choices: [AppTab.pay.rawValue, AppTab.buy.rawValue]
                    ) { $0 == AppTab.buy.rawValue ? AppTab.buy.title : AppTab.pay.title }
                }
            }

            SettingsCard("Display") {
                SettingsRow(
                    symbol: "circle.lefthalf.filled",
                    title: "Appearance",
                    caption: "Dark, light or as your iPhone is set"
                ) {
                    SettingsChoiceMenu(
                        title: "Appearance",
                        selection: $appearance,
                        choices: AppAppearance.allCases
                    ) { $0.title }
                }
            }

            SettingsCard("Security") {
                securityRow
            }

            SettingsCard("More") {
                SettingsLinkRow(page: .terms, symbol: "doc.text.fill", title: "Terms of Service", caption: "The terms for using StarHash")
                SettingsLinkRow(page: .privacy, symbol: "lock.fill", title: "Privacy Policy", caption: "Everything stays on this iPhone")
                Link(destination: SettingsLinks.requestFeature) {
                    SettingsRow(symbol: "lightbulb.fill", title: "Request a Feature", caption: "Tell us what StarHash should do next") {
                        SettingsChevron(symbol: "arrow.up.right")
                    }
                }
                .buttonStyle(HighlightRowButtonStyle())
                .accessibilityHint("Opens a feature request form on GitHub")
                SettingsLinkRow(page: .about, symbol: "star.fill", title: "About StarHash", caption: "What's new, the note and the source code")
            }

            // Last and on its own, as GO Club's Logout: the app's delete
            // button, the width of its words, centred under the cards.
            DeleteButton("Delete All Data", fillsWidth: false) { confirmsDeleteAll = true }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

            SettingsFooter()
                .id("starhash")
        }
        .onChange(of: appearance) { _, appearance in AppAppearance.apply(appearance) }
        .alert("Are you sure you want to delete all data?", isPresented: $confirmsDeleteAll) {
            Button("Delete", role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.smooth) { AppReset.eraseEverything(store: store, router: router) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $confirmsAutoVerifyOff) {
            TurnOffAutoVerifySheet {
                withAnimation(.smooth) {
                    StarHashPreferences.turnOffAutoVerify()
                    autoVerifySetUp = false
                    lastVerifiedAt = 0
                }
            }
        }
        .alert("Location is off", isPresented: $locationRefused) {
            Button("Open Settings") { SettingsAppLink.open() }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Allow StarHash your precise location in the Settings app, so it can tell one till from the next.")
        }
    }

    /// On once the setup finished with a working shortcut. Switching it on
    /// opens the setup, which turns it on only after checking the shortcut;
    /// switching it off asks first, since payments then stay Pending.
    private var autoVerifyBinding: Binding<Bool> {
        Binding {
            lastVerifiedAt > 0 && autoVerifySetUp
        } set: { isOn in
            if isOn { setUpAutoVerify() } else { confirmsAutoVerifyOff = true }
        }
    }

    /// The app lock's switch, named for what this iPhone has (Face ID,
    /// Touch ID, or its passcode alone). Without even a passcode there is
    /// nothing to ask for, so it stays off and says why.
    private var securityRow: some View {
        let unlock = DeviceUnlock.current
        let available = DeviceUnlock.isAvailable
        return SettingsToggleRow(
            symbol: unlock.symbol,
            title: unlock == .passcode ? "Passcode Lock" : unlock.name,
            caption: available
                ? (unlock == .passcode ? "Ask for your passcode to open StarHash" : "Ask for \(unlock.name) to open StarHash")
                : "Set a passcode on this iPhone first",
            isOn: appLockBinding
        )
        .disabled(!available && !appLock)
    }

    /// Turning the lock on or off asks for Face ID first, so it is the
    /// owner who changes it; the switch moves only once it is given.
    private var appLockBinding: Binding<Bool> {
        Binding {
            appLock
        } set: { isOn in
            let name = DeviceUnlock.current.name
            Task {
                let reason = isOn ? "Turn on \(name) for StarHash." : "Turn off \(name) for StarHash."
                guard await AppLock.authenticate(reason: reason) else { return }
                withAnimation(.smooth) { appLock = isOn }
            }
        }
    }

    /// Turning contacts on asks for access the first time.
    private var contactsBinding: Binding<Bool> {
        Binding {
            enableContacts
        } set: { isOn in
            enableContacts = isOn
            guard isOn else { return }
            Task { await SettingsContactsAccess.request() }
        }
    }

    /// Turning Nearby on asks for when-in-use location, precise: an
    /// approximate one cannot tell one till from the next, so a refusal or
    /// an approximate grant switches it back off and points to the Settings
    /// app. Turning it off forgets where each payment was made, and with it
    /// every suggestion.
    private var locationBinding: Binding<Bool> {
        Binding {
            nearbyLocation
        } set: { isOn in
            nearbyLocation = isOn
            guard isOn else {
                store.clearLocations()
                return
            }
            Task {
                let allowed = await SettingsLocationAccess.shared.request()
                if !allowed || !PaymentLocation.isAuthorized {
                    withAnimation { nearbyLocation = false }
                    locationRefused = true
                }
            }
        }
    }
}

// MARK: - Footer

enum SettingsVersion {
    static var short: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// The build: which App Store upload this is, 1 for the first, raised
    /// in project.yml for each one after (`CURRENT_PROJECT_VERSION`).
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// "1.0.0 (1)", the version and its build.
    static var full: String { "\(short) (\(build))" }
}

/// The mark, then the name and version on two centred lines.
struct SettingsFooter: View {
    var body: some View {
        VStack(spacing: 16) {
            StarHashMark(size: 56)
            VStack(spacing: 0) {
                Text("StarHash")
                Text(SettingsVersion.full)
            }
            .font(.starhash(.body))
            .foregroundStyle(Color.starhashSecondaryText)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("StarHash version \(SettingsVersion.short), build \(SettingsVersion.build)")
    }
}

// MARK: - Launch arguments

/// `-settingsPage whatsNew|release|terms|privacy|about|guide|guide2` (DEBUG only, with
/// `-tab settings`) opens that page or the guide at launch.
@MainActor
enum SettingsLaunch {
    private static var page: String? {
        #if DEBUG
        DebugLaunch.value(after: "-settingsPage")
        #else
        nil
        #endif
    }

    static var initialPath: [SettingsPage] {
        if page == "whatsNew" { return [.whatsNew] }
        if page == "terms" { return [.terms] }
        if page == "privacy" { return [.privacy] }
        if page == "about" { return [.about] }
        if page == "release" { return [.whatsNew, .release(ReleaseHistory.releases[0].version)] }
        if page?.hasPrefix("guide") == true { return [.autoVerify] }
        return []
    }

    /// `-settingsPage autoVerifyOff` asks to turn auto-verify off.
    static var confirmsAutoVerifyOff: Bool { page == "autoVerifyOff" }

    /// `-settingsPage guide2` starts the guide on its second step.
    static var guideStep: Int {
        guard let page, page.hasPrefix("guide"), let n = Int(page.dropFirst(5)) else { return 0 }
        return max(0, min(n - 1, AutoVerificationGuide.stepCount - 1))
    }

    /// `-settingsPage guideFailed|guideVerified`: step 2 with its check
    /// already failed or passed, for screenshots.
    static var guideOutcome: String? {
        guard let page, page == "guideFailed" || page == "guideVerified" else { return nil }
        return page
    }
}

enum SettingsLinks {
    /// StarHash's code on GitHub, under the PolyForm Noncommercial License 1.0.0.
    static let sourceCode = URL(string: "https://github.com/devbyshima/starhash")!

    /// A new issue from the feature request form (.github/ISSUE_TEMPLATE),
    /// with the version filled in. Opens in the browser; StarHash itself
    /// sends nothing.
    static var requestFeature: URL {
        var components = URLComponents(string: "https://github.com/devbyshima/starhash/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "template", value: "feature_request.yml"),
            URLQueryItem(name: "version", value: SettingsVersion.full),
        ]
        return components.url!
    }
}
