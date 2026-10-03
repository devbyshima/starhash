import StarHashKit
import SwiftUI

/// Settings: what StarHash saves. (The owner and the wallet switcher live
/// on Pay and in the side menu; how StarHash works, privacy and the
/// version in Help.) Its own NavigationStack, with the auto-verify setup
/// and What's New pushed onto it.
struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @State private var path: [SettingsPage] = SettingsLaunch.initialPath

    var body: some View {
        NavigationStack(path: $path) {
            SettingsRootList { path.append(.autoVerify) }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .starhashSideMenuToolbar()
                .navigationDestination(for: SettingsPage.self) { $0.destination.starhashBackButton() }
        }
        .onChange(of: path.isEmpty, initial: true) { _, isEmpty in
            router.setPushedScreen(!isEmpty, on: .settings)
        }
    }
}

/// Every page pushed in the Settings tab.
enum SettingsPage: Hashable {
    case autoVerify
    case whatsNew
    case release(String)

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
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
    @AppStorage(PreferenceKey.lastVerifiedAt) private var lastVerifiedAt: Double = 0
    @AppStorage(PreferenceKey.autoVerifySetUp) private var autoVerifySetUp = false
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = true

    @State private var confirmsDeleteAll = false
    @State private var showsDeveloperNote = false
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
        List {
            Section {
                SettingsSectionTitle("Transactions")
                SettingsToggleRow(
                    symbol: "tray.full.fill",
                    title: "Save transactions",
                    caption: "Keep a history of what you pay and receive",
                    isOn: $saveTransactions
                )
                .settingsCardRow(.first)
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
                .settingsCardRow(.first)
                SettingsToggleRow(
                    symbol: "location.fill",
                    title: "Nearby",
                    caption: "Note where you paid, to show it on a map",
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
                SettingsSectionTitle("StarHash")
                NavigationLink(value: SettingsPage.whatsNew) {
                    SettingsRow(symbol: "sparkles", title: "What's New", caption: "What each version brought")
                }
                .settingsCardRow(.first)
                Button {
                    withAnimation(.smooth) { hasOnboarded = false }
                } label: {
                    SettingsRow(symbol: "play.circle.fill", title: "Replay Onboarding", caption: "See the welcome screens again")
                }
                .buttonStyle(HighlightRowButtonStyle())
                .settingsCardRow(.middle)
                Button { showsDeveloperNote = true } label: {
                    SettingsRow(symbol: "envelope.open.fill", title: "Developer Note", caption: "A few words on why StarHash exists")
                }
                .buttonStyle(HighlightRowButtonStyle())
                .settingsCardRow(.last)
                .id("starhash")
            }

            // Last, apart, as an account's delete sits in other apps.
            Section {
                Button(role: .destructive) { confirmsDeleteAll = true } label: {
                    Text("Delete All Data")
                        .font(.starhash(.body, weight: .medium))
                        .foregroundStyle(Color.starhashDestructive)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HighlightRowButtonStyle())
                .settingsCardRow(.single, insets: .settingsTextRow)
            } footer: {
                SettingsFootnote("Erases everything StarHash keeps on this iPhone: transactions, recents, your wallet and settings. StarHash starts again from the welcome screens. Your contacts and the StarHash SMS shortcut are not touched.")
            }

        }
        .settingsListStyle(sectionSpacing: 14)
        .alert("Delete all data?", isPresented: $confirmsDeleteAll) {
            Button("Delete All Data", role: .destructive) {
                withAnimation(.smooth) { AppReset.eraseEverything(store: store, router: router) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your transactions, wallet and settings will be erased from this iPhone. This cannot be undone.")
        }
        .sheet(isPresented: $showsDeveloperNote) {
            DeveloperNoteSheet()
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
            Text("Allow StarHash to use your location in the Settings app to note where you pay.")
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

    /// Turning Nearby on asks for when-in-use location; a refusal switches
    /// it back off and points to the Settings app.
    private var locationBinding: Binding<Bool> {
        Binding {
            nearbyLocation
        } set: { isOn in
            nearbyLocation = isOn
            guard isOn else { return }
            Task {
                let allowed = await SettingsLocationAccess.shared.request()
                if !allowed {
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

/// `-settingsPage whatsNew|release|guide|guide2|guide3` (DEBUG only, with
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
}
