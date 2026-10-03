import SwiftUI
import UIKit

/// Everything after onboarding: the page showing, and the side menu
/// behind it. The menu button or a swipe in from the left edge slides the
/// page to the right as a rounded card, as X does; tapping or swiping that
/// card back closes it. The edge swipe only opens the menu on a page's
/// first screen; on a pushed one it is the system's swipe back. Each page
/// is built the first time it shows and then kept, so it keeps its state
/// (a typed amount, a scroll position) while another page shows.
struct SideMenuContainer: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visited: Set<AppTab> = []
    /// How far the open page has been dragged back to the left (negative).
    @State private var drag: CGFloat = 0
    /// How far an edge swipe has pulled the closed page to the right.
    @State private var edgeDrag: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = Self.menuWidth(for: proxy.size.width)
            let progress = router.isMenuOpen
                ? max(0, 1 + drag / width)
                : min(1, edgeDrag / width)

            ZStack(alignment: .topLeading) {
                SideMenu()
                    .frame(width: width)
                    // Drifts in a little behind the page, as the page leaves.
                    .offset(x: reduceMotion ? 0 : (progress - 1) * 40)
                    .opacity(0.3 + 0.7 * progress)
                    .accessibilityHidden(!router.isMenuOpen)

                pages
                    // The card's corners and edge, drawn across the whole
                    // screen (status bar and home indicator included).
                    .mask {
                        RoundedRectangle(cornerRadius: 44 * progress, style: .continuous)
                            .ignoresSafeArea()
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 44 * progress, style: .continuous)
                            .strokeBorder(Color.starhashSeparator, lineWidth: progress > 0 ? 1 : 0)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        if router.isMenuOpen { closeTarget(width: width, progress: progress) }
                    }
                    .offset(x: width * progress)
                    .gesture(edgeSwipe(width: width))
                    .accessibilityHidden(router.isMenuOpen)
            }
        }
        .background(Color.starhashBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.35), value: router.isMenuOpen)
        .onChange(of: router.selectedTab, initial: true) { _, tab in visited.insert(tab) }
        .onChange(of: router.isMenuOpen) { _, isOpen in
            drag = 0
            // A keyboard left up would sit over the menu.
            if isOpen { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        }
        .accessibilityAction(.escape) { router.isMenuOpen = false }
    }

    /// Follows the finger in from the edge; past a third of the menu, or
    /// flicked, it opens, otherwise the page settles back.
    private func edgeSwipe(width: CGFloat) -> EdgeSwipeGesture {
        EdgeSwipeGesture(isEnabled: router.edgeSwipeOpensMenu) { translation in
            if edgeDrag == 0 {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            edgeDrag = translation
        } onEnded: { translation, velocity in
            let opens = translation > width * 0.33 || velocity > 600
            withAnimation(.smooth(duration: 0.3)) {
                if opens { router.isMenuOpen = true }
                edgeDrag = 0
            }
        }
    }

    /// X's proportion: most of the width, leaving a strip of the page.
    static func menuWidth(for screen: CGFloat) -> CGFloat {
        min(screen * 0.8, 340)
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

    /// Over the open page: dims it, closes on a tap, and follows a drag back
    /// to the left.
    private func closeTarget(width: CGFloat, progress: CGFloat) -> some View {
        Color.black.opacity(0.35 * progress)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { router.isMenuOpen = false }
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in drag = min(0, value.translation.width) }
                    .onEnded { value in
                        if value.predictedEndTranslation.width < -width * 0.4 || value.translation.width < -width * 0.3 {
                            router.isMenuOpen = false
                        } else {
                            withAnimation(.smooth(duration: 0.25)) { drag = 0 }
                        }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Close menu")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { router.isMenuOpen = false }
    }
}
