import StarHashKit
import SwiftUI

/// The side menu, laid out like X's: the main pages (Pay, Buy, Activity)
/// large and bold at the top, and Settings and Help
/// smaller at the bottom, under a hairline. The page showing has a filled
/// symbol. Taller than the screen (large text), it all scrolls together.
struct SideMenu: View {
    @Environment(AppRouter.self) private var router

    private static let primary: [AppTab] = [.pay, .buy, .activity]
    private static let secondary: [AppTab] = [.settings, .help]

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Self.primary) { tab in
                        row(tab, isPrimary: true)
                    }

                    Spacer(minLength: 32)

                    Rectangle()
                        .fill(Color.starhashSeparator)
                        .frame(height: 1)
                        .padding(.bottom, 12)
                        .accessibilityHidden(true)

                    ForEach(Self.secondary) { tab in
                        row(tab, isPrimary: false)
                    }
                }
                .padding(.leading, 28)
                .padding(.trailing, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .frame(minHeight: viewport.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private func row(_ tab: AppTab, isPrimary: Bool) -> some View {
        let isShowing = router.selectedTab == tab
        return Button {
            router.show(tab)
        } label: {
            HStack(spacing: isPrimary ? 20 : 18) {
                Image(systemName: isShowing ? tab.selectedSymbol : tab.symbol)
                    .starhashFont(isPrimary ? 24 : 20, relativeTo: isPrimary ? .title2 : .title3)
                    .frame(width: isPrimary ? 32 : 28)
                    .accessibilityHidden(true)
                Text(tab.title)
                    .starhashFont(isPrimary ? 24 : 18, weight: isPrimary ? .bold : .regular, relativeTo: isPrimary ? .title2 : .body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if tab == .buy {
                    Text("Soon")
                        .font(.starhash(.footnote, weight: .semibold))
                        .foregroundStyle(Color.starhashSecondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.starhashPrimaryText.opacity(0.08), in: Capsule())
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.starhashPrimaryText)
            .padding(.vertical, isPrimary ? 14 : 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isShowing ? .isSelected : [])
    }
}

extension AppTab {
    /// The symbol for the page showing.
    var selectedSymbol: String {
        switch self {
        case .pay: "number.circle.fill"
        case .buy: "bag.fill"
        case .activity: "list.bullet.rectangle.fill"
        case .settings: "gearshape.fill"
        case .help: "questionmark.circle.fill"
        }
    }
}

/// Opens the side menu: the round glass button at the top left of Pay,
/// Buy and Activity.
struct SideMenuButton: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        StarHashCircleButton("line.3.horizontal", label: "Menu") {
            router.isMenuOpen = true
        }
    }
}

/// The same, as a navigation bar item, for pages in a NavigationStack
/// (Settings, Help), where the system draws the glass.
struct SideMenuToolbarItem: ToolbarContent {
    @Environment(AppRouter.self) private var router

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                router.isMenuOpen = true
            } label: {
                Image(systemName: "line.3.horizontal")
            }
            .accessibilityLabel("Menu")
        }
    }
}
