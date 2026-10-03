import StarHashKit
import SwiftUI

/// Activity's floating bar, laid out as the recipient screen's header: the
/// period picker centred like a title (a glass capsule opening a native
/// menu), and the search button on the right. Searching, a close button
/// comes in on the left and the field from the right as the picker goes
/// out to the left.
struct ActivityTopBar: View {
    let period: ActivityPeriod
    let onPeriod: @MainActor (ActivityPeriod) -> Void
    let isSearching: Bool
    @Binding var searchText: String
    var searchFocused: FocusState<Bool>.Binding
    let onSearch: () -> Void
    let onCloseSearch: () -> Void

    var body: some View {
        ZStack {
            if !isSearching {
                periodMenu
                    .padding(.horizontal, 56)
                    .transition(.offset(x: -36).combined(with: .opacity))
            }
            // One glass container, so the buttons and the search capsule
            // melt into one another as the search opens and closes.
            StarHashGlassContainer(spacing: 10) {
                HStack(spacing: 10) {
                    if isSearching {
                        SwapGlassButton(symbol: "xmark", label: "Close search", action: onCloseSearch)
                            .transition(.opacity)
                        searchField
                            .transition(.offset(x: 80).combined(with: .opacity))
                    } else {
                        Spacer(minLength: 0)
                        SwapGlassButton(symbol: "magnifyingglass", label: "Search", action: onSearch)
                            .transition(.opacity)
                    }
                }
            }
        }
        .frame(minHeight: ActivityLayout.topBarHeight)
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .starhashReadableWidth()
        .starhashClearsWindowControls()
        .animation(.smooth(duration: 0.32), value: isSearching)
        // Content scrolling under the bar fades into the canvas instead of
        // clashing with the glass, like the system's scroll edge effect.
        .starhashTopFade()
    }

    /// The recipient screen's search bar: a glass capsule with the
    /// magnifier, the field and a clear button.
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(Color.sheetSecondaryText)
                .accessibilityHidden(true)
            TextField("Search", text: $searchText, prompt: Text("Search transactions").foregroundStyle(Color.sheetSecondaryText))
                .accessibilityLabel("Search transactions")
                .focused(searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.sheetSecondaryText)
                        .frame(width: 28, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.sheet(17, relativeTo: .body))
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: 44)
        .starhashGlass(interactive: true)
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
                    .font(.starhash(.body, weight: .medium))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.starhash(.footnote, weight: .semibold))
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

}
