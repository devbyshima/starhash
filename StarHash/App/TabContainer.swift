import SwiftUI

/// Everything after onboarding: the page showing, and the tab bar floating
/// at its foot. Pages change at once, as the reference's do, while the
/// bar's lens travels. Each page is built the first time it shows and then kept,
/// so it keeps its state (a typed amount, a scroll position) while another
/// page shows.
struct TabContainer: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visited: Set<AppTab> = []

    var body: some View {
        GeometryReader { proxy in
            pages
                .overlay(alignment: .bottom) {
                    StarHashTabBar()
                        // 28pt above the screen's foot, as the reference's,
                        // a little into the home indicator's inset; phones
                        // without one get a margin of their own.
                        .padding(.bottom, proxy.safeAreaInsets.bottom > 0 ? TabBarMetrics.bottomGap - proxy.safeAreaInsets.bottom : 12)
                        .offset(y: router.isTabBarHidden ? TabBarMetrics.height + proxy.safeAreaInsets.bottom + 24 : 0)
                        .opacity(router.isTabBarHidden ? 0 : 1)
                        .allowsHitTesting(!router.isTabBarHidden)
                        .accessibilityHidden(router.isTabBarHidden)
                        .animation(reduceMotion ? .smooth(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.85), value: router.isTabBarHidden)
                }
        }
        .background(Color.starhashBackground.ignoresSafeArea())
        .onChange(of: router.selectedTab, initial: true) { _, tab in visited.insert(tab) }
    }

    private var pages: some View {
        ZStack {
            ForEach(AppTab.allCases) { tab in
                if visited.contains(tab) || router.selectedTab == tab {
                    let isShowing = router.selectedTab == tab
                    page(tab)
                        .opacity(isShowing ? 1 : 0)
                        .allowsHitTesting(isShowing)
                        .accessibilityHidden(!isShowing)
                }
            }
        }
    }

    @ViewBuilder
    private func page(_ tab: AppTab) -> some View {
        switch tab {
        case .pay: PayView()
        case .buy: BuyView()
        case .activity: ActivityView()
        case .settings: SettingsView()
        }
    }
}
