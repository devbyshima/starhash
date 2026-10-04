import StarHashKit
import SwiftUI

/// Privacy, in plain words: everything stays on this iPhone.
struct PrivacyView: View {
    private let points: [(symbol: String, title: String, text: String)] = [
        ("iphone", "Everything stays on this iPhone", "Transactions, recipients and your profile are saved on this device only. There is no account, no login and no server."),
        ("person.crop.circle", "Contacts", "Read on your iPhone to show who you can pay. They are never copied or uploaded."),
        ("location", "Location", "Only when Nearby is on, and only while you pay. Each payment keeps where it was made, for its map, and a number or code that is not in your contacts is suggested when you are back there. All of it stays on this iPhone, out of backups too. Turning Nearby off forgets it all."),
        ("message", "Messages", "StarHash cannot read your SMS. Your own Shortcuts automation passes your wallet's confirmation messages to it, and you can turn that off at any time."),
        ("trash", "Your data, your call", "Delete All Data in Settings erases everything StarHash keeps, or delete the app."),
    ]

    var body: some View {
        SettingsScroll {
            SettingsCard {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: 12) {
                        SettingsSymbol(symbol: point.symbol)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(point.title)
                                .font(.starhash(.body, weight: .semibold))
                                .foregroundStyle(Color.starhashPrimaryText)
                            Text(point.text)
                                .font(.starhash(.subheadline))
                                .foregroundStyle(Color.starhashSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 16)
                    .settingsRowInset()
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .settingsPage("Privacy")
    }
}

/// StarHash itself, one row away from Settings: What's New, the onboarding
/// again, the developer's note and the source code.
struct AboutStarHashView: View {
    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = true
    @State private var showsDeveloperNote = false

    var body: some View {
        SettingsScroll {
            SettingsCard {
                SettingsLinkRow(page: .whatsNew, symbol: "sparkles", title: "What's New", caption: "What each version brought")
                Button {
                    UserDefaults.standard.set(0, forKey: PreferenceKey.onboardingStage)
                    withAnimation(.smooth) { hasOnboarded = false }
                } label: {
                    SettingsRow(symbol: "play.circle.fill", title: "Replay Onboarding", caption: "See the welcome screens again")
                }
                .buttonStyle(HighlightRowButtonStyle())
                Button { showsDeveloperNote = true } label: {
                    SettingsRow(symbol: "envelope.open.fill", title: "Developer Note", caption: "A few words on why StarHash exists")
                }
                .buttonStyle(HighlightRowButtonStyle())
                Link(destination: SettingsLinks.sourceCode) {
                    SettingsRow(symbol: "chevron.left.forwardslash.chevron.right", title: "Source code", caption: "StarHash is free and open source") {
                        SettingsChevron(symbol: "arrow.up.right")
                    }
                }
                .buttonStyle(HighlightRowButtonStyle())
            }
        }
        .settingsPage("About StarHash")
        .sheet(isPresented: $showsDeveloperNote) {
            DeveloperNoteSheet()
        }
    }
}
