import StarHashKit
import SwiftUI

/// Activity's floating bar, a `PageHeader`: the menu button on the left,
/// the period picker centred like a title (a glass capsule opening a native
/// menu), and the search button on the right.
struct ActivityTopBar: View {
    let period: ActivityPeriod
    let onPeriod: @MainActor (ActivityPeriod) -> Void
    let onSearch: () -> Void

    var body: some View {
        StarHashGlassContainer(spacing: 12) {
            PageHeader {
                periodMenu
            } trailing: {
                searchButton
            }
            .starhashClearsWindowControls()
        }
        .background(alignment: .top) {
            // Content scrolling under the bar fades into the canvas instead
            // of clashing with the glass, like the system's scroll edge
            // effect.
            LinearGradient(
                colors: [.starhashBackground, .starhashBackground.opacity(0.85), .starhashBackground.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.bottom, -18)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    // Like a system toolbar, the bar's text stops growing at the largest
    // standard size so it stays one row tall; the Large Content Viewer shows
    // each control bigger at accessibility sizes.

    private var periodMenu: some View {
        Menu {
            Picker(selection: Binding(get: { period }, set: onPeriod)) {
                ForEach(ActivityPeriod.allCases) { option in
                    Text(option.title).tag(option)
                }
            } label: {
                Label("Period", systemImage: "calendar")
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 5) {
                Text(period.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(Color.starhashPrimaryText)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.horizontal, 17)
            .frame(minHeight: ActivityLayout.topBarHeight)
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Capsule())
            .starhashGlass(interactive: true)
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
        .accessibilityLabel("Period")
        .accessibilityValue(period.title)
        .accessibilityShowsLargeContentViewer {
            Label(period.title, systemImage: "chevron.up.chevron.down")
        }
    }

    private var searchButton: some View {
        Button(action: onSearch) {
            Image(systemName: "magnifyingglass")
                .starhashFont(21, weight: .medium, relativeTo: .title3)
                .foregroundStyle(Color.starhashPrimaryText)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(width: ActivityLayout.topBarHeight, height: ActivityLayout.topBarHeight)
                .contentShape(Circle())
                .starhashGlass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search")
        .accessibilityShowsLargeContentViewer {
            Label("Search", systemImage: "magnifyingglass")
        }
    }
}
