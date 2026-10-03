import SwiftUI

/// Onboarding the first time, the side menu and its pages after. An
/// install that finished onboarding before it asked for the wallet is
/// asked for it once, on its own page. Shima's welcome note is onboarding's
/// last screen; two weeks on, the note asking for a rating shows once,
/// over the app.
struct RootView: View {
    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PreferenceKey.wallet) private var wallet = ""
    @AppStorage(PreferenceKey.hasSeenReviewNote) private var hasSeenReviewNote = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var forcesNote = DeveloperNoteLaunch.forcesNote
    @State private var showsReviewNote = false

    var body: some View {
        Group {
            if !hasOnboarded {
                OnboardingView { withAnimation(.smooth) { hasOnboarded = true } }
                    .transition(.opacity)
            } else if wallet.isEmpty {
                OnboardingWalletPage {}
                    .background(Color.starhashBackground.ignoresSafeArea())
                    .transition(.opacity)
            } else {
                SideMenuContainer()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: wallet.isEmpty)
        .sheet(isPresented: $forcesNote) {
            DeveloperNoteSheet()
        }
        .sheet(isPresented: $showsReviewNote, onDismiss: { hasSeenReviewNote = true }) {
            ReviewNoteSheet()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            checkReviewNote()
        }
        .onChange(of: hasOnboarded) { checkReviewNote() }
        .background(Color.starhashBackground.ignoresSafeArea())
    }

    /// Two weeks after StarHash was first set up, the rating note, once.
    private func checkReviewNote() {
        guard hasOnboarded, !wallet.isEmpty else { return }
        ReviewNote.startClockIfNeeded()
        if ReviewNote.isDue() { showsReviewNote = true }
    }
}
