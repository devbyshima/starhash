import SwiftUI

/// Onboarding the first time, the side menu and its pages after. An
/// install that finished onboarding before it asked for the MoMo number is
/// asked for it once, on its own page.
struct RootView: View {
    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PreferenceKey.ownerNumber) private var ownerNumber = ""

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
        .background(Color.starhashBackground.ignoresSafeArea())
    }
}
