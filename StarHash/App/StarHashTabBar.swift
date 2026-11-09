import SwiftUI

/// The floating bar at the foot of every page, after GO Club's, measured
/// from its screen recordings: a capsule of clear Liquid Glass holding
/// three symbols, Activity, Pay and Settings, and a grey glass lens under
/// the one showing. The lens's place is wider than the others, so the
/// symbols glide aside as it moves, on the same spring: it overshoots
/// about a tenth and settles, and overshooting at either end it stretches
/// the bar with it, as liquid would. The page
/// changes at once, with one heavy haptic (`NavigationHaptics`); the
/// lens's bounce is seen, not felt. A finger dragged along the bar carries
/// the lens and chooses wherever it lets go. The bar shrinks to 0.8, towards the foot of the screen, while a
/// page scrolls down, comes back on the way up, and steps aside for
/// pushed screens and Activity's search.
struct StarHashTabBar: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where a finger dragging along the bar holds the lens, while it does.
    @State private var dragX: CGFloat?

    private let items = TabBarItem.allCases

    var body: some View {
        let selected = TabBarItem(router.selectedTab)
        let selectedIndex = items.firstIndex(of: selected) ?? 0
        let layout = TabBarLayout(selected: selectedIndex, count: items.count)
        let lensCenter = dragX.map { min(max($0, layout.centers[0]), layout.centers[items.count - 1]) }
            ?? layout.centers[selectedIndex]

        ZStack(alignment: .topLeading) {
            LensGlass(
                width: layout.width,
                height: TabBarMetrics.height,
                sideInset: TabBarMetrics.lensSideInset,
                lensMinX: lensCenter - TabBarMetrics.lensWidth / 2,
                lensMaxX: lensCenter + TabBarMetrics.lensWidth / 2
            )

            GlassLens()
                .frame(width: TabBarMetrics.lensWidth, height: TabBarMetrics.height - TabBarMetrics.lensInset * 2)
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
        // Clear glass over the white page: near-black symbols in light
        // mode, which also read over a card scrolling under.
        .starhashContainerSurface()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }

    private var lensSpring: Animation {
        LensMotion.spring(reduceMotion: reduceMotion)
    }

    private func icon(_ item: TabBarItem, isSelected: Bool) -> some View {
        let symbol = item.symbol(payPage: router.payPage)
        return glyph(symbol, isSelected: isSelected)
            // The page showing in the accent, the rest in the text colour.
            .foregroundStyle(isSelected ? Color.starhashAccentText : Color.starhashPrimaryText)
            .animation(.smooth(duration: 0.2), value: isSelected)
            .frame(width: TabBarMetrics.itemWidth, height: TabBarMetrics.height)
            .contentShape(Rectangle())
            .accessibilityElement()
            .accessibilityLabel(LocalizedStringKey(item.title(payPage: router.payPage)))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { select(item) }
            .accessibilityShowsLargeContentViewer {
                Label(LocalizedStringKey(item.title(payPage: router.payPage)), symbol: symbol)
            }
    }

    /// Pay is StarHash's own mark, Pay being StarHash; the rest are their
    /// icons. The mark is drawn at the size the icons' filled shapes reach,
    /// in the same colours, so it sits in the row as one of them. Between
    /// Pay and Buy the two blur into each other, as the icons' replace does.
    ///
    /// The page showing is filled, the rest in outline. An icon's two forms
    /// are both drawn and one shown, so the swap rides the colour's own fade
    /// rather than setting off the symbols' replace effect; the mark's two
    /// forms do the same, with nothing of their own on top.
    @ViewBuilder
    private func glyph(_ symbol: String, isSelected: Bool) -> some View {
        if symbol == AppTab.pay.symbol {
            ZStack {
                TabMarkShape()
                    .opacity(isSelected ? 0 : 1)
                StarHashMarkShape()
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(width: TabBarMetrics.markSize, height: TabBarMetrics.markSize)
            .transition(.blurReplace)
        } else {
            ZStack {
                iconImage(symbol, outline: true)
                    .opacity(isSelected ? 0 : 1)
                iconImage(symbol, outline: false)
                    .opacity(isSelected ? 1 : 0)
            }
            .transition(.blurReplace)
        }
    }

    private func iconImage(_ symbol: String, outline: Bool) -> some View {
        Image(symbol: symbol, outline: outline)
            .font(.system(size: TabBarMetrics.symbolSize * TabBarMetrics.glyphScale(symbol), weight: .semibold))
            .contentTransition(.symbolEffect(.replace))
            .transition(.blurReplace)
    }

    /// A tap chooses the symbol under it; a drag carries the lens and
    /// chooses wherever the finger lets go.
    private func choosing(_ layout: TabBarLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard dragX != nil || abs(value.translation.width) > 8 else { return }
                dragX = value.location.x
            }
            .onEnded { value in
                select(items[layout.nearestIndex(to: value.location.x)])
                dragX = nil
            }
    }

    /// Another page: it shows at once, with the switch's haptic. The page
    /// showing already does nothing.
    private func select(_ item: TabBarItem) {
        guard item != TabBarItem(router.selectedTab) else { return }
        NavigationHaptics.shared.switchPage()
        switch item {
        case .activity: router.show(.activity)
        case .pay: router.show(router.payPage)
        case .settings: router.show(.settings)
        }
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

extension EnvironmentValues {
    /// How far above the safe area's foot the tab bar's foot sits (below
    /// it, on a phone with a home indicator), for a bar that takes the tab
    /// bar's place while it steps aside.
    @Entry var floatingBarBottom: CGFloat = 8
}

/// The reference's measurements, in points: a capsule whose foot is 28pt
/// above the screen's, a 93.3 by 59 lens, and 66pt for each symbol it is
/// not under. The reference's capsule is 75 tall, the lens 8 from its top
/// and foot; the owner brought it down to 71 so the lens sits 6 from every
/// edge, as from its sides.
enum TabBarMetrics {
    static let height: CGFloat = 71
    static let lensWidth: CGFloat = 93.33
    static let lensSideInset: CGFloat = 6
    static let lensInset: CGFloat = 6
    static let itemWidth: CGFloat = 66
    static let endInset: CGFloat = 8
    static let symbolSize: CGFloat = 24
    /// The mark's square on Pay's tab: its star fills about four fifths of
    /// it, a little wider than tall, as much ink as the gear beside it.
    static let markSize: CGFloat = 28
    /// The outlined mark's line: as much ink as the outlined gear beside
    /// it, measured at 3x (2,093 pixels against the gear's 2,156; 2.2 was
    /// heavier), and the 6 pixels of the receipt's line.
    static let markLine: CGFloat = 2

    /// Each icon's scale, so the bar's glyphs look one size. At one font
    /// size they did not: measured on screen (3x), the receipt was 65 by 79
    /// pixels and the bag 65 by 72, both solid, against the gear's 72
    /// square with its teeth and hole. A solid shape looks bigger than its
    /// box, so each is scaled halfway between matching the gear's box and
    /// matching its ink.
    static func glyphScale(_ symbol: String) -> CGFloat {
        switch symbol {
        case AppTab.activity.symbol: 0.87
        case AppTab.buy.symbol: 0.94
        default: 1
        }
    }
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

    /// Centres an empty state in the space the page has for it: from under
    /// its header (or the status bar) to the tab bar's top edge, which
    /// stands `height - 6` above the safe area's foot, so it sits in the
    /// middle of what shows rather than of a frame running behind the bar.
    func starhashCentredOverTabBar() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, TabBarMetrics.height - 6)
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
        SwapGlassButton(symbol: target.symbol, label: String(starhash: "Switch to \(target.title)"), pressHaptic: false) {
            NavigationHaptics.shared.switchPage()
            router.show(target)
        }
    }
}

/// Pay's mark in the tab bar while another page shows: a line inside the
/// star's own edge, so it and the filled mark (`StarHashMarkShape`, on Pay)
/// share one silhouette, round where the star turns inward; the triangle
/// stays solid, as an outline would close it to a speck. The two are
/// stacked and one shown, as every icon's two forms are.
struct TabMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / StarHashMarkShape.side
        let origin = CGPoint(x: rect.midX - StarHashMarkShape.side / 2 * scale, y: rect.midY - StarHashMarkShape.side / 2 * scale)
        func point(_ p: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
        }
        var star = Path()
        star.addLines(StarHashMarkShape.star.map(point))
        star.closeSubpath()
        var triangle = Path()
        triangle.addLines(StarHashMarkShape.triangle.map(point))
        triangle.closeSubpath()

        // Twice the line, half of it outside the edge and cut away.
        var mark = star
            .strokedPath(StrokeStyle(lineWidth: 2 * TabBarMetrics.markLine, lineJoin: .round))
            .intersection(star)
        mark.addPath(triangle)
        return mark
    }
}
