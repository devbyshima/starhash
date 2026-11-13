import SwiftUI

/// The top of Pay and Buy, drawn to match the system bar on the others
/// (Settings): 44pt tall at the top of the safe area, 16pt in from the
/// edges, the Pay and Buy switcher on the left, the title or a control
/// centred on the screen, an action (if any) on the right. The centre
/// keeps clear of the side buttons.
struct PageHeader<Center: View, Trailing: View>: View {
    /// Pay or Buy, for the switcher.
    let page: AppTab
    @ViewBuilder var center: Center
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            PayBuySwitcher(page: page)
            Spacer(minLength: 0)
            trailing
        }
        .frame(minHeight: 44)
        .overlay {
            center
                .lineLimit(1)
                .padding(.horizontal, 44 + 12)
        }
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .starhashReadableWidth()
    }
}

extension Font {
    /// The page title: 21pt bold, following Dynamic Type from the
    /// headline's size.
    static var starhashPageTitle: Font {
        .sheet(StarHashMetrics.pageTitleSize, .bold, relativeTo: .headline)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(page: AppTab, @ViewBuilder center: () -> Center) {
        self.init(page: page, center: center) { EmptyView() }
    }
}

extension PageHeader where Center == PageTitle, Trailing == EmptyView {
    /// A plain centred title, set like the system bar's.
    init(page: AppTab, title: String) {
        self.init(page: page) { PageTitle(text: title) } trailing: { EmptyView() }
    }
}

/// A page title, as every page sets it (`Font.starhashPageTitle`), centred.
struct PageTitle: View {
    let text: String

    var body: some View {
        Text(catalog: text)
            .font(.starhashPageTitle)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Color.starhashPrimaryText)
            .accessibilityAddTraits(.isHeader)
    }
}
