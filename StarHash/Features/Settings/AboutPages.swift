import StarHashKit
import SwiftUI

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
                    SettingsRow(symbol: "chevron.left.forwardslash.chevron.right", title: "Source code", caption: "StarHash's code is public on GitHub") {
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
