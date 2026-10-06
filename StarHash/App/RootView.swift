import StarHashKit
import SwiftUI

/// Onboarding the first time, the pages and their tab bar after. An
/// install that finished onboarding before it asked for the wallet is
/// asked for it once, on its own page. As onboarding ends, Shima's welcome
/// note opens over Pay; two weeks on, the note asking for a rating shows
/// once, over the app. The first launch after an update to a release with
/// news shows What's New, never a new install's.
struct RootView: View {
    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PreferenceKey.wallet) private var wallet = ""
    @AppStorage(PreferenceKey.hasSeenDeveloperNote) private var hasSeenDeveloperNote = false
    @AppStorage(PreferenceKey.hasSeenReviewNote) private var hasSeenReviewNote = false
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    /// The notes wait for the launch splash to go.
    @Environment(\.splashActive) private var splashActive
    @State private var forcesNote = DeveloperNoteLaunch.forcesNote
    @State private var showsReviewNote = false
    @State private var whatsNew = WhatsNewLaunch.pending
    @State private var whatsNewStartPage = WhatsNewLaunch.startPage
    /// What's New's height follows it.
    @State private var window = WhatsNewWindow()

    var body: some View {
        Group {
            if !hasOnboarded {
                OnboardingView {
                    // The note closes to the default page (Pay unless Buy is
                    // chosen), a replay from Settings included.
                    router.showDefaultPage()
                    WhatsNewLaunch.markSeen()
                    withAnimation(.smooth) { hasOnboarded = true }
                }
                    .transition(.opacity)
            } else if wallet.isEmpty {
                OnboardingWalletPage {}
                    .background(Color.starhashBackground.ignoresSafeArea())
                    .transition(.opacity)
            } else {
                TabContainer()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: wallet.isEmpty)
        .sheet(isPresented: welcomeNotePresented) {
            DeveloperNoteSheet(afterOnboarding: true)
        }
        .sheet(isPresented: reviewNotePresented, onDismiss: { hasSeenReviewNote = true }) {
            ReviewNoteSheet()
        }
        .sheet(isPresented: whatsNewPresented) {
            if let whatsNew {
                WhatsNewSheet(announcement: whatsNew, window: window, startPage: whatsNewStartPage)
            }
        }
        #if DEBUG
        .onChange(of: router.whatsNewPreviewPage) { _, page in
            guard let page else { return }
            whatsNewStartPage = page
            whatsNew = WhatsNewLaunch.preview
            router.whatsNewPreviewPage = nil
        }
        #endif
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            checkReviewNote()
        }
        .onChange(of: hasOnboarded) { checkReviewNote() }
        .background {
            Color.starhashBackground
                .ignoresSafeArea()
                // The whole window, its safe area's foot included.
                .onGeometryChange(for: WhatsNewWindow.self) { proxy in
                    WhatsNewWindow(width: proxy.size.width, bottomInset: proxy.safeAreaInsets.bottom)
                } action: { window = $0 }
        }
    }

    /// Owed from the moment onboarding ends until it is closed.
    private var welcomeNotePresented: Binding<Bool> {
        Binding(
            get: { !splashActive && (forcesNote || (hasOnboarded && !wallet.isEmpty && !hasSeenDeveloperNote)) },
            set: { presented in
                guard !presented else { return }
                hasSeenDeveloperNote = true
                forcesNote = false
            }
        )
    }

    /// Over the app once the splash has gone, and never over onboarding or
    /// the welcome note.
    private var whatsNewPresented: Binding<Bool> {
        Binding(
            get: { whatsNew != nil && window.width > 0 && !splashActive && hasOnboarded && !wallet.isEmpty && hasSeenDeveloperNote && !forcesNote },
            set: { presented in
                guard !presented else { return }
                whatsNew = nil
            }
        )
    }

    private var reviewNotePresented: Binding<Bool> {
        Binding(
            get: { showsReviewNote && !splashActive },
            set: { showsReviewNote = $0 }
        )
    }

    /// Two weeks after StarHash was first set up, the rating note, once,
    /// never on top of the welcome note or What's New.
    private func checkReviewNote() {
        guard hasOnboarded, !wallet.isEmpty, hasSeenDeveloperNote, whatsNew == nil else { return }
        ReviewNote.startClockIfNeeded()
        if ReviewNote.isDue() { showsReviewNote = true }
    }
}
