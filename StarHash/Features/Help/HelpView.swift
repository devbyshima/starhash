import SwiftUI

/// Help: how StarHash works, setting up auto-verify, privacy and the
/// version, in Settings' look. Its own NavigationStack, with each guide
/// pushed onto it.
struct HelpView: View {
    @Environment(AppRouter.self) private var router
    @State private var path: [HelpPage] = HelpLaunch.initialPath

    var body: some View {
        NavigationStack(path: $path) {
            HelpRootList()
                .navigationTitle("Help")
                .navigationBarTitleDisplayMode(.inline)
                .starhashSideMenuToolbar()
                .navigationDestination(for: HelpPage.self) { $0.destination.starhashBackButton() }
        }
        .onChange(of: path.isEmpty, initial: true) { _, isEmpty in
            router.setPushedScreen(!isEmpty, on: .help)
        }
    }
}

/// Every page pushed in Help.
enum HelpPage: Hashable {
    case howItWorks
    case autoVerify
    case privacy

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .howItWorks: HowStarHashWorksView()
        case .autoVerify: AutoVerificationGuide()
        case .privacy: PrivacyView()
        }
    }
}

private struct HelpRootList: View {
    var body: some View {
        List {
            Section {
                SettingsSectionTitle("Guides")
                NavigationLink(value: HelpPage.howItWorks) {
                    SettingsRow(symbol: "number.square.fill", title: "How StarHash works", caption: "Amount, recipient, and the USSD code")
                }
                .settingsCardRow(.first)
                NavigationLink(value: HelpPage.autoVerify) {
                    SettingsRow(symbol: "checkmark.message.fill", title: "Set up auto-verify", caption: "Log payments from MoMo messages")
                }
                .settingsCardRow(.last)
            }

            Section {
                SettingsSectionTitle("About")
                NavigationLink(value: HelpPage.privacy) {
                    SettingsRow(symbol: "lock.fill", title: "Privacy", caption: "Everything stays on this iPhone")
                }
                .settingsCardRow(.first)
                Link(destination: HelpLinks.sourceCode) {
                    SettingsRow(symbol: "chevron.left.forwardslash.chevron.right", title: "Source code", caption: "StarHash is free and open source") {
                        Image(systemName: "arrow.up.right")
                            .starhashFont(14, weight: .semibold, relativeTo: .footnote)
                            .foregroundStyle(Color.starhashTertiaryText)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(HighlightRowButtonStyle())
                .settingsCardRow(.middle)
                SettingsRow(symbol: "info.circle.fill", title: "Version", value: SettingsVersion.short)
                    .settingsCardRow(.last)
            }

            Section {
                SettingsFooter()
                    .settingsPlainRow()
            }
        }
        .settingsListStyle(sectionSpacing: 14)
    }
}

/// `-helpPage howItWorks|privacy` (DEBUG only, with `-tab help`) opens
/// that page at launch.
@MainActor
enum HelpLaunch {
    static var initialPath: [HelpPage] {
        #if DEBUG
        switch DebugLaunch.value(after: "-helpPage") {
        case "howItWorks": [.howItWorks]
        case "privacy": [.privacy]
        default: []
        }
        #else
        []
        #endif
    }
}

enum HelpLinks {
    /// StarHash's code on GitHub, under the GNU GPL v3.
    static let sourceCode = URL(string: "https://github.com/devbyshima/starhash")!
}
