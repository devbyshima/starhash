import SwiftUI

/// Onboarding the first time, the side menu and its pages after. An
/// install that finished onboarding before it asked for the MoMo number is
/// asked for it once, on its own page. The developer note shows once, over
/// the app, right after onboarding.
struct RootView: View {
    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PreferenceKey.ownerNumber) private var ownerNumber = ""
    @AppStorage(PreferenceKey.hasSeenDeveloperNote) private var hasSeenDeveloperNote = false
    @State private var forcesNote = DeveloperNoteLaunch.forcesNote

    var body: some View {
        Group {
            if !hasOnboarded {
                OnboardingView { withAnimation(.smooth) { hasOnboarded = true } }
                    .transition(.opacity)
            } else if ownerNumber.isEmpty {
                OnboardingNumberPage {}
                    .background(OnboardingPalette.background.ignoresSafeArea())
                    .transition(.opacity)
            } else {
                SideMenuContainer()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: ownerNumber.isEmpty)
        .sheet(isPresented: developerNotePresented) {
            DeveloperNoteSheet()
        }
        .background(Color.starhashBackground.ignoresSafeArea())
    }

    private var developerNotePresented: Binding<Bool> {
        Binding(
            get: { forcesNote || (hasOnboarded && !ownerNumber.isEmpty && !hasSeenDeveloperNote) },
            set: { presented in
                if !presented {
                    hasSeenDeveloperNote = true
                    forcesNote = false
                }
            }
        )
    }
}
