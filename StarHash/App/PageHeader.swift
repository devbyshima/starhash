import SwiftUI

/// The top of the pages without a navigation bar (Pay, Buy, Activity),
/// drawn to match the system bar on the others (Settings, Help): 44pt tall
/// at the top of the safe area, 16pt in from the edges, the menu button on
/// the left, the title or a control centred on the screen, an action (if
/// any) on the right. The centre keeps clear of the side buttons.
struct PageHeader<Center: View, Trailing: View>: View {
    @ViewBuilder var center: Center
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            SideMenuButton()
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

extension PageHeader where Trailing == EmptyView {
    init(@ViewBuilder center: () -> Center) {
        self.init(center: center) { EmptyView() }
    }
}

extension PageHeader where Center == PageTitle, Trailing == EmptyView {
    /// A plain centred title, set like the system bar's.
    init(title: String) {
        self.init { PageTitle(text: title) } trailing: { EmptyView() }
    }
}

/// A page title as the system navigation bar sets it: Headline, centred.
struct PageTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Color.starhashPrimaryText)
            .accessibilityAddTraits(.isHeader)
    }
}
