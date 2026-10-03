import SwiftUI

/// The floating bar at the foot of every page, after GO Club's, measured
/// from its screen recordings: a capsule of clear Liquid Glass holding
/// three symbols, Activity, Pay and Settings, and a grey glass lens under
/// the one showing. The lens's place is wider than the others, so the
/// symbols glide aside as it moves, on the same spring: it overshoots
/// about a tenth and settles, and overshooting at either end it stretches
/// the bar with it, as liquid would. The page
/// changes at once, with a heavy layered haptic that lands with the lens
/// (`NavigationHaptics`). A finger dragged along the bar carries the lens,
/// knocking at each symbol it passes, and chooses wherever it lets go. The bar shrinks to 0.8, towards the foot of the screen, while a
/// page scrolls down, comes back on the way up, and steps aside for
/// pushed screens and Activity's search.
struct StarHashTabBar: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where a finger dragging along the bar holds the lens, while it does.
    @State private var dragX: CGFloat?
    /// The symbol a dragged lens is over, for the knock as it passes one.
    @State private var dragIndex: Int?

    private let items = TabBarItem.allCases

    var body: some View {
        let selected = TabBarItem(router.selectedTab)
        let selectedIndex = items.firstIndex(of: selected) ?? 0
        let layout = TabBarLayout(selected: selectedIndex, count: items.count)
        let lensCenter = dragX.map { min(max($0, layout.centers[0]), layout.centers[items.count - 1]) }
            ?? layout.centers[selectedIndex]

        ZStack(alignment: .topLeading) {
            TabBarGlass(
                width: layout.width,
                lensMinX: lensCenter - TabBarMetrics.lensWidth / 2,
                lensMaxX: lensCenter + TabBarMetrics.lensWidth / 2
            )

            lens
                .offset(x: lensCenter - TabBarMetrics.lensWidth / 2, y: TabBarMetrics.lensInset)

            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                icon(item, isSelected: index == selectedIndex)
                    .position(x: layout.centers[index], y: TabBarMetrics.height / 2)
            }
        }
        .frame(width: layout.width, height: TabBarMetrics.height, alignment: .topLeading)
        .contentShape(Capsule())
        .gesture(choosing(layout))
        // The bar is narrower with an end chosen. Centred here, in a frame
        // of the widest bar, so the re-centring rides the same spring as
        // everything else; left to the page, it would jump the symbols
        // sideways on the first frame of every switch.
        .offset(x: (TabBarLayout.widest - layout.width) / 2)
        .animation(dragX == nil ? lensSpring : .interactiveSpring(response: 0.18), value: lensCenter)
        .animation(lensSpring, value: layout)
        .frame(width: TabBarLayout.widest, height: TabBarMetrics.height, alignment: .topLeading)
        // Towards the foot of the screen, not the bar's own: it shrinks
        // and sinks, as the reference's does.
        .scaleEffect(
            router.isTabBarCompact ? TabBarMetrics.compactScale : 1,
            anchor: UnitPoint(x: 0.5, y: 1 + TabBarMetrics.bottomGap / TabBarMetrics.height)
        )
        .animation(reduceMotion ? .smooth(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.78), value: router.isTabBarCompact)
        .onAppear { NavigationHaptics.shared.prepare() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }

    /// The reference's: about a tenth past the mark, back a touch, and
    /// still in under half a second. A plain ease with Reduce Motion.
    private var lensSpring: Animation {
        reduceMotion ? .smooth(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.61)
    }

    /// Grey glass: the palette's grey, faint, with the light top edge and
    /// dark sides glass has.
    private var lens: some View {
        Capsule()
            .fill(Color.tabBarLens)
            .overlay {
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [.tabBarLensEdgeLight, .tabBarLensEdgeDark, .tabBarLensEdgeDark, .tabBarLensEdgeLight.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
            }
            .frame(width: TabBarMetrics.lensWidth, height: TabBarMetrics.height - TabBarMetrics.lensInset * 2)
            .accessibilityHidden(true)
    }

    private func icon(_ item: TabBarItem, isSelected: Bool) -> some View {
        let symbol = item.symbol(payPage: router.payPage)
        return Image(systemName: symbol)
            .font(.system(size: TabBarMetrics.symbolSize, weight: .semibold))
            .foregroundStyle(Color.starhashPrimaryText)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: TabBarMetrics.itemWidth, height: TabBarMetrics.height)
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
    private func choosing(_ layout: TabBarLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard dragX != nil || abs(value.translation.width) > 8 else { return }
                dragX = value.location.x
                let index = layout.nearestIndex(to: value.location.x)
                if let dragIndex, index != dragIndex { NavigationHaptics.shared.passSymbol() }
                dragIndex = index
            }
            .onEnded { value in
                select(items[layout.nearestIndex(to: value.location.x)])
                dragX = nil
                dragIndex = nil
            }
    }

    /// Another page: it shows at once, and the haptic's layers follow the
    /// lens there. The page showing already does nothing.
    private func select(_ item: TabBarItem) {
        guard item != TabBarItem(router.selectedTab) else { return }
        NavigationHaptics.shared.switchPage(landsWithLens: !reduceMotion)
        switch item {
        case .activity: router.show(.activity)
        case .pay: router.show(router.payPage)
        case .settings: router.show(.settings)
        }
    }
}

/// The bar's glass, stretched to take in the lens wherever it is: at rest
/// the lens sits 6pt inside, and overshooting an end it pulls the edge out
/// with it. Animatable, so the outline follows the lens frame by frame.
private struct TabBarGlass: View, Animatable {
    var width: CGFloat
    var lensMinX: CGFloat
    var lensMaxX: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(width, AnimatablePair(lensMinX, lensMaxX)) }
        set {
            width = newValue.first
            lensMinX = newValue.second.first
            lensMaxX = newValue.second.second
        }
    }

    var body: some View {
        let minX = min(0, lensMinX - TabBarMetrics.lensSideInset)
        let maxX = max(width, lensMaxX + TabBarMetrics.lensSideInset)
        Color.clear
            .frame(width: maxX - minX, height: TabBarMetrics.height)
            // Clear glass, not the app's deep-blue tint: the reference's
            // frosts whatever is under it.
            .starhashGlass(in: Capsule(), tint: .clear)
            .offset(x: minX)
            .allowsHitTesting(false)
    }
}

/// Where each symbol sits for a given selection: the lens's place 93pt
/// wide and the others 66, 6pt in from the ends, and an unselected end
/// symbol a further 8pt in. So the bar is a little wider with the middle
/// chosen, as the reference's is.
struct TabBarLayout: Equatable {
    let centers: [CGFloat]
    let width: CGFloat

    init(selected: Int, count: Int) {
        var x = TabBarMetrics.lensSideInset
        var centers: [CGFloat] = []
        for index in 0..<count {
            let isSelected = index == selected
            let isEnd = index == 0 || index == count - 1
            let outer = isEnd && !isSelected ? TabBarMetrics.endInset : 0
            let itemWidth = isSelected ? TabBarMetrics.lensWidth : TabBarMetrics.itemWidth
            if index == 0 { x += outer }
            centers.append(x + itemWidth / 2)
            x += itemWidth
            if index == count - 1 { x += outer }
        }
        self.centers = centers
        self.width = x + TabBarMetrics.lensSideInset
    }

    /// The bar at its widest, with a middle symbol chosen.
    static let widest: CGFloat = (0..<TabBarItem.allCases.count)
        .map { TabBarLayout(selected: $0, count: TabBarItem.allCases.count).width }
        .max() ?? 0

    func nearestIndex(to x: CGFloat) -> Int {
        centers.indices.min { abs(centers[$0] - x) < abs(centers[$1] - x) } ?? 0
    }
}

/// The reference's measurements, in points: a 75pt capsule whose foot is
/// 28pt above the screen's, a 93.3 by 59 lens 6pt in from the side and 8
/// from top and foot, and 66pt for each symbol it is not under.
enum TabBarMetrics {
    static let height: CGFloat = 75
    static let lensWidth: CGFloat = 93.33
    static let lensSideInset: CGFloat = 6
    static let lensInset: CGFloat = 8
    static let itemWidth: CGFloat = 66
    static let endInset: CGFloat = 8
    static let symbolSize: CGFloat = 24
    static let bottomGap: CGFloat = 28
    static let compactScale: CGFloat = 0.8
    /// What a page keeps clear at its foot for the bar: its height above
    /// the safe area's foot (it sits a little into it) and a gap.
    static let clearance: CGFloat = height - 6 + 12
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
    /// Only a scroll the person makes moves the bar: a page laying itself
    /// out (out of sight, or as it first shows) changes its offset too.
    @State private var isScrolling = false

    func body(content: Content) -> some View {
        content.onScrollPhaseChange { _, phase in
            isScrolling = phase == .interacting || phase == .decelerating
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { old, new in
            guard isScrolling else { return }
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
            NavigationHaptics.shared.switchPage(landsWithLens: false)
            router.show(target)
        }
    }
}
