import StarHashKit
import SwiftUI

/// Activity's header, after the owner's reference: the page's title large
/// on the left, and on the right the report, search and the owner's photo,
/// each round. Searching, a close button comes in on the left and the field
/// from the right as the title goes out to the left.
struct ActivityTopBar: View {
    let isSearching: Bool
    @Binding var searchText: String
    var searchFocused: FocusState<Bool>.Binding
    let onReport: () -> Void
    let onProfile: () -> Void
    let onSearch: () -> Void
    let onCloseSearch: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            if !isSearching {
                Text("Activity")
                    .starhashFont(34, weight: .bold, relativeTo: .largeTitle)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                    .transition(.offset(x: -36).combined(with: .opacity))
            }
            // One glass container, so the buttons and the search capsule
            // melt into one another as the search opens and closes.
            StarHashGlassContainer(spacing: 12) {
                HStack(spacing: 12) {
                    if isSearching {
                        SwapGlassButton(symbol: "xmark", label: "Close search", action: onCloseSearch)
                            .transition(.opacity)
                        searchField
                            .transition(.offset(x: 80).combined(with: .opacity))
                    } else {
                        Spacer(minLength: 0)
                        SwapGlassButton(symbol: "chart.bar.fill", label: "Report", action: onReport)
                            .transition(.opacity)
                        SwapGlassButton(symbol: "magnifyingglass", label: "Search", action: onSearch)
                            .transition(.opacity)
                        OwnerAvatarButton(action: onProfile)
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
    }

    /// The recipient screen's search bar: a glass capsule with the
    /// magnifier, the field and a clear button.
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(symbol: "magnifyingglass")
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
                    Image(symbol: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.sheetSecondaryText)
                        .frame(width: 28, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.sheet(17, relativeTo: .body))
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: 44)
        // Clear, as the buttons it melts into.
        .starhashGlass(interactive: true, tint: .clear)
    }
}

/// The owner's photo in a round button, as the reference's avatar: their
/// photo when there is one, else their initial on the green, else a
/// person. Opens Profile.
struct OwnerAvatarButton: View {
    let action: () -> Void

    @AppStorage(PreferenceKey.profileName) private var name = ""

    var body: some View {
        Button(action: action) {
            Group {
                if let image = ProfilePhoto.shared.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let initial = name.first(where: \.isLetter) {
                    Text(String(initial).uppercased())
                        .font(.starhashFixed(19, weight: .semibold))
                        .foregroundStyle(Color.starhashOnInk)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.starhashInk)
                } else {
                    Image(symbol: "person.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.starhashOnInk)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.starhashInk)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityLabel("Profile")
    }
}
