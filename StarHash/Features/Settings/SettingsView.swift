import StarHashKit
import SwiftUI

/// Settings, with what was Help: what StarHash saves, the guides (how it
/// works, privacy, and About StarHash, which holds What's
/// New, onboarding, the note and the source code) and Delete All Data. (The
/// wallet switcher lives on Pay.) Its own NavigationStack, with each page
/// pushed onto it, over which the tab bar steps aside.
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
        // A light tap as a page opens; the list's rows are not buttons of
        // ours, so they do not play the press haptic themselves.
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
    case howItWorks
    case privacy
    case about

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .howItWorks: HowStarHashWorksView()
        case .privacy: PrivacyView()
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
    @AppStorage(PreferenceKey.keypadInk) private var keypadInk = true
    @AppStorage(PreferenceKey.lastVerifiedAt) private var lastVerifiedAt: Double = 0
    @AppStorage(PreferenceKey.autoVerifySetUp) private var autoVerifySetUp = false
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

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
        List {
            Section {
                SettingsSectionTitle("Transactions")
                SettingsToggleRow(
                    symbol: "tray.full.fill",
                    title: "Save transactions",
                    caption: "Keep a history of what you pay and receive",
                    isOn: $saveTransactions
                )
                .settingsCardRow(.firstUnderTitle)
                SettingsToggleRow(
                    symbol: "checkmark.message.fill",
                    title: "Auto-verify transactions",
                    // The SMS reader knows MTN's messages only, so Airtel
                    // payments would stay pending.
                    caption: wallet == .mtn
                        ? "Confirm payments from M\u{2011}Money messages"
                        : "Reads MTN MoMo messages only, for now",
                    isOn: autoVerifyBinding
                )
                .settingsCardRow(.middle)
                SettingsToggleRow(
                    symbol: "questionmark.bubble.fill",
                    title: "Ask before deleting",
                    caption: "Confirm every delete except a swipe",
                    isOn: $confirmDeletes
                )
                .settingsCardRow(.last)
            }

            Section {
                SettingsSectionTitle("Recipients")
                SettingsToggleRow(
                    symbol: "person.crop.circle.fill",
                    title: "Enable contacts",
                    caption: "Pick who to pay from your contacts",
                    isOn: contactsBinding
                )
                .settingsCardRow(.firstUnderTitle)
                SettingsToggleRow(
                    symbol: "location.fill",
                    title: "Nearby",
                    caption: "Suggest who you paid at the place you're in",
                    isOn: locationBinding
                )
                .settingsCardRow(.middle)
                SettingsToggleRow(
                    symbol: "clock.arrow.circlepath",
                    title: "Save recent recipients",
                    caption: "Show who you paid last at the top",
                    isOn: $saveRecents
                )
                .settingsCardRow(.last)
            }

            Section {
                SettingsSectionTitle("Keypad")
                SettingsToggleRow(
                    symbol: "drop.fill",
                    title: "Ink effect",
                    caption: "Ink spreads behind each key you press",
                    isOn: $keypadInk
                )
                .settingsCardRow(.onlyUnderTitle)
            }

            Section {
                SettingsSectionTitle("Help")
                NavigationLink(value: SettingsPage.howItWorks) {
                    SettingsRow(symbol: "number.square.fill", title: "How StarHash works", caption: "Amount, recipient, and the USSD code")
                }
                .settingsCardRow(.firstUnderTitle)
                NavigationLink(value: SettingsPage.privacy) {
                    SettingsRow(symbol: "lock.fill", title: "Privacy", caption: "Everything stays on this iPhone")
                }
                .settingsCardRow(.middle)
                Link(destination: SettingsLinks.requestFeature) {
                    SettingsRow(symbol: "lightbulb.fill", title: "Request a Feature", caption: "Tell us what StarHash should do next") {
                        Image(systemName: "arrow.up.right")
                            .starhashFont(14, weight: .semibold, relativeTo: .footnote)
                            .foregroundStyle(Color.starhashTertiaryText)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(HighlightRowButtonStyle())
                .accessibilityHint("Opens a feature request form on GitHub")
                .settingsCardRow(.middle)
                NavigationLink(value: SettingsPage.about) {
                    SettingsRow(symbol: "star.fill", title: "About StarHash", caption: "What's new, the note and the source code")
                }
                .settingsCardRow(.last)
            }

            // Last and on its own, as GO Club's Logout: a capsule the width
            // of its words, centred under the cards, filled blood red in
            // the app's button look (a gradient fill, 18pt semibold).
            Section {
                Button(role: .destructive) { confirmsDeleteAll = true } label: {
                    Text("Delete All Data")
                        .starhashFont(18, weight: .semibold, relativeTo: .body)
                        .foregroundStyle(Color.starhashOnDestructive)
                        .padding(.horizontal, 44)
                        .frame(minHeight: 57)
                        .background(Color.starhashDestructiveButton.gradient, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .settingsPlainRow()
            }

            Section {
                SettingsFooter()
                    .settingsPlainRow()
                    .id("starhash")
            }

        }
        .settingsListStyle()
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
    /// app. Turning it off forgets every place it remembered, and where each
    /// payment was made.
    private var locationBinding: Binding<Bool> {
        Binding {
            nearbyLocation
        } set: { isOn in
            nearbyLocation = isOn
            guard isOn else {
                AppEnvironment.places.eraseAll()
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
}

/// The mark, then the name and version on two centred lines (Help).
struct SettingsFooter: View {
    var body: some View {
        VStack(spacing: 16) {
            StarHashMark(size: 56)
            VStack(spacing: 0) {
                Text("StarHash")
                Text(SettingsVersion.short)
            }
            .font(.starhash(.body))
            .foregroundStyle(Color.starhashSecondaryText)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("StarHash version \(SettingsVersion.short)")
    }
}

// MARK: - Launch arguments

/// `-settingsPage whatsNew|release|about|guide|guide2|guide3` (DEBUG only, with
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
        if page == "howItWorks" { return [.howItWorks] }
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
    /// StarHash's code on GitHub, under the GNU GPL v3.
    static let sourceCode = URL(string: "https://github.com/devbyshima/starhash")!

    /// A new issue from the feature request form (.github/ISSUE_TEMPLATE),
    /// with the version filled in. Opens in the browser; StarHash itself
    /// sends nothing.
    static var requestFeature: URL {
        var components = URLComponents(string: "https://github.com/devbyshima/starhash/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "template", value: "feature_request.yml"),
            URLQueryItem(name: "version", value: SettingsVersion.short),
        ]
        return components.url!
    }
}
