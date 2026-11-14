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
    @Environment(Owner.self) private var owner
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
    @AppStorage(Preferences.showMyName) private var showMyName: Bool
    @AppStorage(PreferenceKey.seenShowMyNameNotice) private var seenShowMyNameNotice = false
    @State private var forcesShowMyNameNotice = ShowMyNameNoticeSheet.forcedAtLaunch
    /// The tabs have been on screen a moment. The notes and sheets that open
    /// on their own wait for it: opened in the same instant the tabs take
    /// onboarding's place, the welcome note was just there, with no slide.
    @State private var tabsSettled = false

    var body: some View {
        Group {
            if !hasOnboarded {
                OnboardingView {
                    // The note closes to the default page (Pay unless Buy is
                    // chosen), a replay from Settings included.
                    router.showDefaultPage()
                    WhatsNewLaunch.markSeen()
                    // Onboarding's number page said who sees the name.
                    seenShowMyNameNotice = true
                    withAnimation(.smooth) { hasOnboarded = true }
                }
                    .transition(.opacity)
            } else if owner.chosenWallet == nil {
                OnboardingWalletPage {}
                    .background(Color.starhashBackground.ignoresSafeArea())
                    .transition(.opacity)
            } else {
                TabContainer()
                    .transition(.opacity)
                    // Once onboarding's fade into the tabs is over.
                    .task {
                        try? await Task.sleep(for: .milliseconds(450))
                        tabsSettled = true
                    }
                    .onDisappear { tabsSettled = false }
            }
        }
        .animation(.smooth, value: owner.chosenWallet == nil)
        .sheet(isPresented: welcomeNotePresented) {
            DeveloperNoteSheet(afterOnboarding: true)
        }
        .sheet(isPresented: reviewNotePresented, onDismiss: { hasSeenReviewNote = true }) {
            ReviewNoteSheet()
        }
        // A scam warning's notification, tapped.
        .sheet(item: Binding(get: { router.scamNotice }, set: { router.scamNotice = $0 })) { notice in
            ScamNoticeSheet(notice: notice)
        }
        .sheet(isPresented: whatsNewPresented) {
            if let whatsNew {
                WhatsNewSheet(announcement: whatsNew, window: window, startPage: whatsNewStartPage)
            }
        }
        .sheet(isPresented: showMyNameNoticePresented) {
            ShowMyNameNoticeSheet()
        }
        // The owner's listing follows their name, numbers, photo and Show My
        // Name, two seconds after the last change, so a name typed letter
        // by letter is sent once.
        .task(id: "\(showMyName)|\(AppEnvironment.serverSync.listing?.state ?? "off")") {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            AppEnvironment.serverSync.ownerChanged()
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

    /// What `FirstRun` decides from, now.
    private var firstRun: FirstRun.State {
        FirstRun.State(
            hasOnboarded: hasOnboarded,
            hasWallet: owner.chosenWallet != nil,
            hasSeenWelcomeNote: hasSeenDeveloperNote,
            forcesWelcomeNote: forcesNote,
            whatsNewPending: whatsNew != nil,
            // Once, for owners set up before Show My Name came, while it is on.
            showMyNameNoticeDue: forcesShowMyNameNotice || (!seenShowMyNameNotice && showMyName && owner.defaultSIM != nil),
            reviewNoteDue: showsReviewNote
        )
    }

    /// Whether `sheet` is the one `FirstRun` says comes next, once the tabs
    /// have settled and the splash has gone.
    private func shows(_ sheet: FirstRun.Sheet) -> Bool {
        tabsSettled && !splashActive && FirstRun.next(firstRun) == sheet
    }

    /// Owed from the moment onboarding ends until it is closed.
    private var welcomeNotePresented: Binding<Bool> {
        Binding(
            get: { shows(.welcomeNote) },
            set: { presented in
                guard !presented else { return }
                hasSeenDeveloperNote = true
                forcesNote = false
            }
        )
    }

    /// Over the app once its window is measured, for the sheet's height.
    private var whatsNewPresented: Binding<Bool> {
        Binding(
            get: { shows(.whatsNew) && window.width > 0 },
            set: { presented in
                guard !presented else { return }
                whatsNew = nil
            }
        )
    }

    private var showMyNameNoticePresented: Binding<Bool> {
        Binding(
            get: { shows(.showMyNameNotice) },
            set: { presented in
                guard !presented else { return }
                seenShowMyNameNotice = true
                forcesShowMyNameNotice = false
            }
        )
    }

    private var reviewNotePresented: Binding<Bool> {
        Binding(
            get: { shows(.reviewNote) },
            set: { showsReviewNote = $0 }
        )
    }

    /// Two weeks after StarHash was first set up, the rating note, once,
    /// when nothing else is waiting to show.
    private func checkReviewNote() {
        guard FirstRun.reviewNoteMayCome(firstRun) else { return }
        ReviewNote.startClockIfNeeded()
        if ReviewNote.isDue() { showsReviewNote = true }
    }
}
