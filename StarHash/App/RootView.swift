import SwiftUI

/// Onboarding the first time, the side menu and its pages after. An
/// install that finished onboarding before it asked for the wallet is
/// asked for it once, on its own page. As onboarding ends, Shima's welcome
/// note opens over Pay; two weeks on, the note asking for a rating shows
/// once, over the app.
struct RootView: View {
    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PreferenceKey.wallet) private var wallet = ""
    @AppStorage(PreferenceKey.hasSeenDeveloperNote) private var hasSeenDeveloperNote = false
    @AppStorage(PreferenceKey.hasSeenReviewNote) private var hasSeenReviewNote = false
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @State private var forcesNote = DeveloperNoteLaunch.forcesNote
    @State private var showsReviewNote = false

    var body: some View {
        Group {
            if !hasOnboarded {
                OnboardingView {
                    // The note closes to Pay, a replay from Settings included.
                    router.show(.pay)
                    withAnimation(.smooth) { hasOnboarded = true }
                }
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
        .sheet(isPresented: welcomeNotePresented) {
            DeveloperNoteSheet(afterOnboarding: true)
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

    /// Owed from the moment onboarding ends until it is closed.
    private var welcomeNotePresented: Binding<Bool> {
        Binding(
            get: { forcesNote || (hasOnboarded && !wallet.isEmpty && !hasSeenDeveloperNote) },
            set: { presented in
                guard !presented else { return }
                hasSeenDeveloperNote = true
                forcesNote = false
            }
        )
    }

    /// Two weeks after StarHash was first set up, the rating note, once,
    /// never on top of the welcome note.
    private func checkReviewNote() {
        guard hasOnboarded, !wallet.isEmpty, hasSeenDeveloperNote else { return }
        ReviewNote.startClockIfNeeded()
        if ReviewNote.isDue() { showsReviewNote = true }
    }
}
