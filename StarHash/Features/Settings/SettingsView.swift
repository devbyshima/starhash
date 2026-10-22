import StarHashKit
import SwiftUI

/// Settings: what StarHash saves, its notifications, its lock, and More (the terms of service,
/// the privacy policy, a feature request, Ko-fi, and About StarHash, which holds
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
    case notifications
    case whatsNew
    case release(String)
    case terms
    case privacy
    case about
    case featureFlags
    case profile

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .profile: ProfileView()
        case .terms: TermsOfServiceView()
        case .privacy: PrivacyPolicyView()
        case .about: AboutStarHashView()
        case .autoVerify: AutoVerificationGuide()
        case .notifications: NotificationSettingsView()
        case .whatsNew: WhatsNewView()
        case .release(let version): ReleaseDetailView(version: version)
        case .featureFlags: FeatureFlagsView()
        }
    }
}

private struct SettingsRootList: View {
    /// Opens the auto-verify setup, the only way to turn it on.
    let setUpAutoVerify: () -> Void

    @Environment(StarHashStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(USSDShortcutList.self) private var shortcuts

    @AppStorage(PreferenceKey.saveTransactions) private var saveTransactions = true
    @AppStorage(PreferenceKey.scamWarnings) private var scamWarnings = true
    @AppStorage(PreferenceKey.smartCategories) private var smartCategories = true
    @AppStorage(PreferenceKey.profileName) private var profileName = ""
    @AppStorage(PreferenceKey.profileNumber) private var profileNumber = ""
    @AppStorage(PreferenceKey.simCount) private var simCount = 1
    @AppStorage(PreferenceKey.appLanguage) private var appLanguage = AppLanguage.system.rawValue
    @AppStorage(PreferenceKey.secondNumber) private var secondNumber = ""
    @FocusState private var editsSecondNumber: Bool
    /// Going back to one SIM with two numbers in: which one stays.
    @State private var choosesSIMToKeep = false
    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @AppStorage(PreferenceKey.nearbyLocation) private var nearbyLocation = false
    @AppStorage(PreferenceKey.saveRecents) private var saveRecents = true
    @AppStorage(PreferenceKey.confirmDeletes) private var confirmDeletes = true
    @AppStorage(PreferenceKey.defaultPage) private var defaultPage = AppTab.pay.rawValue
    @AppStorage(PreferenceKey.appearance) private var appearance = AppAppearance.system
    @AppStorage(PreferenceKey.lastVerifiedAt) private var lastVerifiedAt: Double = 0
    @AppStorage(PreferenceKey.lastMessageAt) private var lastMessageAt: Double = 0
    @AppStorage(PreferenceKey.autoVerifySince) private var autoVerifySince: Double = 0
    @AppStorage(PreferenceKey.autoVerifySetUp) private var autoVerifySetUp = false
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn
    @OwnWallets private var ownWallets
    @AppStorage(PreferenceKey.appLock) private var appLock = false

    @State private var confirmsDeleteAll = false
    @State private var exportDocument: BackupDocument?
    @State private var isImporting = false
    @State private var importOutcome: DataTransfer.Outcome?
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
            profileCard
            simsCard
            transactionsCard
            recipientsCard
            payBuyCard
            displayCard
            securityCard
            dataCard
            moreCard

            // Last and on its own, as GO Club's Logout: the app's delete
            // button, the width of its words, centred under the cards.
            DeleteButton("Delete All Data", fillsWidth: false) { confirmsDeleteAll = true }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

            SettingsFooter()
                .id("starhash")
        }
        .onChange(of: appearance) { _, appearance in AppAppearance.apply(appearance) }
        .fileExporter(
            isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument,
            contentType: .json,
            defaultFilename: StarHashBackup.fileName()
        ) { result in
            if case .success = result { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            withAnimation(.smooth) {
                importOutcome = DataTransfer.importFile(at: url, store: store, shortcuts: shortcuts)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .alert(item: $importOutcome) { outcome in
            Alert(title: Text(outcome.title), message: Text(outcome.message), dismissButton: .default(Text("OK")))
        }
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
                    lastMessageAt = 0
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

    /// The owner's number under their name, and their other SIM's after
    /// it when they have two.
    private var profileNumbers: String? {
        let numbers = [profileNumber] + (simCount == 2 ? [secondNumber] : [])
        let shown = numbers.compactMap { Recipient.ownNumber($0)?.formattedDestination }
        return shown.isEmpty ? nil : shown.joined(separator: " \u{00B7} ")
    }

    /// The owner's photo, name and numbers, opening Profile.
    private var profileCard: some View {
        SettingsCard {
            NavigationLink(value: SettingsPage.profile) {
                HStack(spacing: 12) {
                    ProfilePhotoView(size: 46)
                    SettingsRowText(
                        title: profileName.isEmpty ? String(starhash: "Profile") : profileName,
                        status: profileNumbers
                    )
                    Spacer(minLength: 8)
                    SettingsChevron()
                }
                .frame(minHeight: 72)
                .settingsRowInset()
                .contentShape(Rectangle())
            }
            .buttonStyle(HighlightRowButtonStyle(pressHaptic: false))
        }
    }

    /// One SIM or two, and the other's number: money between them is
    /// filed as moved between the owner's own accounts.
    private var simsCard: some View {
        SettingsCard("Your SIMs") {
            SettingsRow(
                symbol: "simcard.fill",
                title: "SIMs",
                caption: "With two, money between them is not counted as spent"
            ) {
                SettingsChoiceMenu(title: "SIMs", selection: simCountBinding, choices: [1, 2]) {
                    $0 == 2 ? String(starhash: "Two") : String(starhash: "One")
                }
            }
            // Asked for here until it is in; from then on it is part of the
            // profile (the card above shows it, Profile changes it).
            if simCount == 2, Recipient.ownNumber(secondNumber) == nil {
                SettingsRow(symbol: "simcard.fill", title: "Other SIM") {
                    TextField("07X XXX XXXX", text: $secondNumber)
                        .focused($editsSecondNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .multilineTextAlignment(.trailing)
                        .font(.starhashNumber(16, relativeTo: .body))
                        .frame(maxWidth: 150)
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: Recipient.ownNumber(secondNumber) == nil)
        .sheet(isPresented: $choosesSIMToKeep) {
            KeepSIMSheet(sims: [profileNumber, secondNumber].compactMap(Recipient.ownNumber)) { sim in
                choosesSIMToKeep = false
                keepOnly(sim)
            }
        }
        .onChange(of: simCount) { store.markOwnTransfers() }
        .onChange(of: secondNumber) {
            store.markOwnTransfers()
            // The phone pad has no return key: a whole number is the end of
            // it, so the keyboard goes once one is in, and it is spaced as
            // Profile shows it.
            if let recipient = Recipient.ownNumber(secondNumber) {
                editsSecondNumber = false
                if secondNumber != recipient.formattedDestination { secondNumber = recipient.formattedDestination }
            }
        }
    }

    /// Two SIMs to one: when both numbers are in, the owner says which SIM
    /// stays rather than StarHash dropping the second.
    private var simCountBinding: Binding<Int> {
        Binding(
            get: { simCount },
            set: { count in
                if count == 1, simCount == 2,
                   Recipient.ownNumber(profileNumber) != nil, Recipient.ownNumber(secondNumber) != nil {
                    choosesSIMToKeep = true
                } else {
                    simCount = count
                }
            }
        )
    }

    /// The SIM kept becomes the profile's number, the other is cleared, and
    /// the wallet follows the kept SIM's network, since it is the one that
    /// pays now.
    private func keepOnly(_ sim: Recipient) {
        withAnimation(.smooth(duration: 0.3)) {
            profileNumber = sim.destination
            secondNumber = ""
            simCount = 1
        }
        if let network = sim.network, network != wallet { wallet = network }
    }

    private var transactionsCard: some View {
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
            caption: String(starhash: "Confirm payments from \(ownWallets.messagesName) messages"),
            status: autoVerifyStatus,
            isOn: autoVerifyBinding
        )
        SettingsToggleRow(
            symbol: "questionmark.bubble.fill",
            title: "Ask before deleting",
            caption: "Confirm every delete except a swipe",
            isOn: $confirmDeletes
        )
        SettingsToggleRow(
            symbol: "sparkles",
            title: "Smart categories",
            caption: SmartCategories.isAvailable
                ? "Sort payments into categories with Apple Intelligence"
                : "Sort payments into categories by their names",
            isOn: $smartCategories
        )
        SettingsLinkRow(
            page: .notifications,
            symbol: "bell.fill",
            title: "Notifications",
            caption: "Reminders, confirmations and summaries"
        )
    }
    }

    private var recipientsCard: some View {
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
    }

    private var payBuyCard: some View {
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
    }

    private var displayCard: some View {
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
        // Chosen here and changed at once, without the Settings app.
        SettingsRow(symbol: "globe", title: "Language", caption: "English, French or Kinyarwanda, or your iPhone's") {
            SettingsChoiceMenu(
                title: "Language",
                selection: Binding(
                    get: { AppLanguage(rawValue: appLanguage) ?? .system },
                    set: { chosen in
                        // The lookups first, so the redraw is in it.
                        chosen.apply()
                        appLanguage = chosen.rawValue
                        // The icon's menu, in the new language.
                        QuickActions.update()
                        // The summaries queued with iOS were written in
                        // the language before.
                        Task { await StarHashNotifications.shared.sync() }
                    }
                ),
                choices: AppLanguage.allCases
            ) { $0.title }
        }
    }
    }

    private var securityCard: some View {
    SettingsCard("Security") {
        securityRow
        SettingsToggleRow(
            symbol: "exclamationmark.shield.fill",
            title: "Scam warnings",
            caption: "Warn me about look-alike MoMo messages, and don't log them",
            isOn: $scamWarnings
        )
    }
    }

    private var dataCard: some View {
    SettingsCard("Your Data") {
        Button(action: export) {
            SettingsRow(symbol: "square.and.arrow.up.fill", title: "Export data", caption: "Save your transactions, codes and profile as a file") {
                SettingsChevron()
            }
        }
        .buttonStyle(HighlightRowButtonStyle())
        Button { isImporting = true } label: {
            SettingsRow(symbol: "square.and.arrow.down.fill", title: "Import data", caption: "Add what's in a StarHash file to this iPhone") {
                SettingsChevron()
            }
        }
        .buttonStyle(HighlightRowButtonStyle())
    }
    }

    private var moreCard: some View {
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
        Link(destination: SettingsLinks.koFi) {
            SettingsRow(symbol: "cup.and.saucer.fill", title: "Support on Ko-fi", caption: "Buy Shima a coffee") {
                SettingsChevron(symbol: "arrow.up.right")
            }
        }
        .buttonStyle(HighlightRowButtonStyle())
        .accessibilityHint("Opens Shima's Ko-fi page")
        SettingsLinkRow(page: .about, symbol: "star.fill", title: "About StarHash", caption: "What's new, the note and the source code")
    }
    }

    /// Export: the file is made now, then the system's save sheet asks
    /// where it goes.
    private func export() {
        exportDocument = try? DataTransfer.export(store: store, shortcuts: shortcuts)
    }

    /// No message for a week and the last payments all unconfirmed: the
    /// shortcut has likely stopped, and payments are no longer failed for
    /// want of a message until one comes (`AutoVerify.looksBroken`).
    private var autoVerifyLooksBroken: Bool {
        autoVerifyBinding.wrappedValue && AutoVerify.looksBroken(
            store.transactions,
            lastMessageAt: Date(timeIntervalSince1970: lastMessageAt),
            now: .now
        )
    }

    /// Auto-verify's state when it needs a word: on but still waiting for
    /// its first message through the automation, or quiet for a week.
    /// Nothing while it simply works.
    private var autoVerifyStatus: String? {
        if autoVerifyBinding.wrappedValue,
           !StarHashPreferences.automationProven(lastMessageAt: lastMessageAt, since: autoVerifySince) {
            return String(starhash: "Waiting for a \(ownWallets.messagesName) message to come through")
        }
        return autoVerifyLooksBroken
            ? String(starhash: "No \(ownWallets.messagesName) messages for a week. Check the automation")
            : nil
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
            caption: unlock == .passcode ? String(starhash: "Ask for your passcode to open StarHash") : String(starhash: "Ask for \(unlock.name) to open StarHash"),
            status: available ? nil : String(starhash: "Set a passcode on this iPhone first"),
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
                let reason = isOn ? String(starhash: "Turn on \(name) for StarHash.") : String(starhash: "Turn off \(name) for StarHash.")
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

    /// "StarHash version 1.1.0, build 2, Beta", for VoiceOver.
    static var spoken: String {
        let channel = ReleaseChannel.current
        let spoken = String(starhash: "StarHash version \(short), build \(build)")
        return channel == .production ? spoken : "\(spoken), \(channel.title)"
    }

    /// "1.0.0 (1)", the version and its build, then the channel for a dev
    /// or TestFlight build: "1.1.0 (2) Beta". The App Store's has none.
    static var full: String {
        let channel = ReleaseChannel.current
        return channel == .production ? "\(short) (\(build))" : "\(short) (\(build)) \(channel.title)"
    }
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
        .accessibilityLabel(SettingsVersion.spoken)
    }
}

// MARK: - Launch arguments

/// `-settingsPage whatsNew|release|terms|privacy|about|note|notifications|flags|guide|guide2`
/// (DEBUG only, with `-tab settings`) opens that page or the guide at launch.
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
        if page == "about" || page == "note" { return [.about] }
        if page == "notifications" { return [.notifications] }
        if page == "profile" { return [.profile] }
        if page == "flags" { return [.about, .featureFlags] }
        if page == "release" { return [.whatsNew, .release(ReleaseHistory.releases[0].version)] }
        if page?.hasPrefix("guide") == true { return [.autoVerify] }
        return []
    }

    /// `-settingsPage note` opens About StarHash with its Developer Note up.
    static var opensDeveloperNote: Bool { page == "note" }

    /// `-settingsPage autoVerifyOff` asks to turn auto-verify off.
    static var confirmsAutoVerifyOff: Bool { page == "autoVerifyOff" }

    /// `-settingsPage guide2` starts the guide on its second step.
    static var guideStep: Int {
        guard let page, page.hasPrefix("guide"), let n = Int(page.dropFirst(5)) else { return 0 }
        return max(0, min(n - 1, AutoVerificationGuide.stepCount - 1))
    }

    /// `-settingsPage guideFailed|guideWaiting|guideVerified`: the last
    /// step with its check failed, passed and waiting for a message, or
    /// passed with one through, for screenshots.
    static var guideOutcome: String? {
        guard let page, ["guideFailed", "guideWaiting", "guideVerified"].contains(page) else { return nil }
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

    /// Shima's Ko-fi page, for anyone who wants to give something back.
    /// StarHash stays free, so this is only ever a link: the page and any
    /// payment are Ko-fi's, in the browser.
    static let koFi = URL(string: "https://ko-fi.com/devbyshima")!
}
