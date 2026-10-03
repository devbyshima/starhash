import SwiftUI

/// The floating bar at the foot of every page, after GO Club's: a glass
/// capsule of three symbols, Activity, Pay and Settings, with a lens that
/// slides to the one showing and overshoots a little as it lands. The bar
/// swells under a finger, and a finger dragged along it carries the lens
/// with it, choosing wherever it lets go. It shrinks while a page scrolls
/// down and comes back on the way up, and it steps aside for pushed
/// screens and Activity's search.
struct StarHashTabBar: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var isPressed = false
    /// Where a finger dragging along the bar holds the lens, while it does.
    @State private var dragX: CGFloat?

    private let items = TabBarItem.allCases

    var body: some View {
        let selected = TabBarItem(router.selectedTab)
        ZStack(alignment: .topLeading) {
            lens
                .offset(x: lensCenter(for: selected) - TabBarMetrics.lensWidth / 2, y: TabBarMetrics.inset)
                .animation(lensAnimation, value: lensCenter(for: selected))

            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                icon(item, isSelected: item == selected)
                    .position(x: TabBarMetrics.center(of: index), y: TabBarMetrics.height / 2)
            }
        }
        .frame(width: TabBarMetrics.width, height: TabBarMetrics.height, alignment: .topLeading)
        .contentShape(Capsule())
        .starhashGlass(in: Capsule())
        .gesture(choosing)
        .scaleEffect(scale, anchor: .bottom)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isPressed)
        .animation(.smooth(duration: 0.3), value: router.isTabBarCompact)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }

    /// The bar swells a touch under a finger, and shrinks while a page
    /// scrolls down.
    private var scale: CGFloat {
        if isPressed { return 1.04 }
        return router.isTabBarCompact ? TabBarMetrics.compactScale : 1
    }

    /// Springy, so it overshoots a little and settles, as the reference's
    /// does; a plain fade of position with Reduce Motion.
    private var lensAnimation: Animation {
        if reduceMotion { return .smooth(duration: 0.2) }
        return dragX == nil ? .spring(response: 0.42, dampingFraction: 0.68) : .interactiveSpring(response: 0.18)
    }

    private func lensCenter(for selected: TabBarItem) -> CGFloat {
        if let dragX {
            return min(max(dragX, TabBarMetrics.center(of: 0)), TabBarMetrics.center(of: items.count - 1))
        }
        return TabBarMetrics.center(of: items.firstIndex(of: selected) ?? 0)
    }

    private var lens: some View {
        Capsule()
            .fill(Color.tabBarLens)
            .overlay(Capsule().strokeBorder(Color.tabBarLensEdge, lineWidth: 1))
            .frame(width: TabBarMetrics.lensWidth, height: TabBarMetrics.height - TabBarMetrics.inset * 2)
            .accessibilityHidden(true)
    }

    private func icon(_ item: TabBarItem, isSelected: Bool) -> some View {
        let symbol = item.symbol(payPage: router.payPage)
        return Image(systemName: symbol)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Color.starhashPrimaryText)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: TabBarMetrics.pitch, height: TabBarMetrics.height)
            .contentShape(Rectangle())
            .accessibilityElement()
            .accessibilityLabel(item.title(payPage: router.payPage))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { select(item) }
            .accessibilityShowsLargeContentViewer {
                Label(item.title(payPage: router.payPage), systemImage: symbol)
            }
    }

    /// A tap chooses the symbol under it; a drag carries the lens and
    /// chooses wherever the finger lets go.
    private var choosing: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, pressed, _ in pressed = true }
            .onChanged { value in
                if dragX != nil || abs(value.translation.width) > 8 {
                    dragX = value.location.x
                }
            }
            .onEnded { value in
                let index = TabBarMetrics.nearestIndex(to: value.location.x, count: items.count)
                select(items[index])
                dragX = nil
            }
    }

    private func select(_ item: TabBarItem) {
        switch item {
        case .activity: router.show(.activity)
        case .pay: router.show(router.payPage)
        case .settings: router.show(.settings)
        }
    }
}

/// The bar's three places, left to right. Pay's holds Buy too: the button
/// at the top left of either switches between them, and the bar returns
/// to whichever showed last.
enum TabBarItem: CaseIterable, Hashable {
    case activity
    case pay
    case settings

    init(_ tab: AppTab) {
        switch tab {
        case .activity: self = .activity
        case .pay, .buy: self = .pay
        case .settings: self = .settings
        }
    }

    func symbol(payPage: AppTab) -> String {
        switch self {
        case .activity: AppTab.activity.symbol
        case .pay: payPage.symbol
        case .settings: AppTab.settings.symbol
        }
    }

    func title(payPage: AppTab) -> String {
        switch self {
        case .activity: AppTab.activity.title
        case .pay: payPage.title
        case .settings: AppTab.settings.title
        }
    }
}

/// The reference's measurements: a 74pt capsule, its lens 92 by 62 and 6pt
/// in from the edge, and a symbol every 70pt.
enum TabBarMetrics {
    static let height: CGFloat = 74
    static let inset: CGFloat = 6
    static let lensWidth: CGFloat = 92
    static let pitch: CGFloat = 70
    static let compactScale: CGFloat = 0.8
    static var width: CGFloat { inset * 2 + lensWidth + pitch * CGFloat(TabBarItem.allCases.count - 1) }
    /// What a page keeps clear at its foot for the bar: its height and the
    /// gap above it.
    static let clearance: CGFloat = height + 12

    static func center(of index: Int) -> CGFloat {
        inset + lensWidth / 2 + pitch * CGFloat(index)
    }

    static func nearestIndex(to x: CGFloat, count: Int) -> Int {
        let raw = ((x - center(of: 0)) / pitch).rounded()
        return min(max(Int(raw), 0), count - 1)
    }
}

extension View {
    /// Room at the foot of a page's first screen for the tab bar floating
    /// over it. A scroll view scrolls on under the bar.
    func starhashTabBarClearance() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: TabBarMetrics.clearance)
        }
    }

    /// Shrinks the tab bar while this scroll view scrolls down, and brings
    /// it back on the way up or at the top, as the reference's does.
    func starhashTabBarFollowsScroll() -> some View {
        modifier(TabBarScrollTracking())
    }
}

private struct TabBarScrollTracking: ViewModifier {
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { old, new in
            if new <= 24 {
                router.setTabBarCompact(false)
            } else if new > old + 1 {
                router.setTabBarCompact(true)
            } else if new < old - 1 {
                router.setTabBarCompact(false)
            }
        }
    }
}

/// The button at the top left of Pay and Buy, where the menu button was:
/// the other page's symbol, and a tap goes there.
struct PayBuySwitcher: View {
    /// The page this button sits on.
    let page: AppTab

    @Environment(AppRouter.self) private var router

    var body: some View {
        let target: AppTab = page == .buy ? .pay : .buy
        SwapGlassButton(symbol: target.symbol, label: "Switch to \(target.title)") {
            router.show(target)
        }
    }
}
