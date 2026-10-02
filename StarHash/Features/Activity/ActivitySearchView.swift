import StarHashKit
import SwiftUI

/// Search takes over the whole tab, as Keaser's does: matching transactions
/// at the top in the usual card, "Search Transactions" or "No Results" in
/// the middle otherwise, and at the bottom, just above the keyboard, the
/// field in a glass capsule beside a round glass button that leaves search.
///
/// It looks through every transaction, not only the chosen period: a
/// MoMo log is searched for one payment, whenever it was.
struct ActivitySearchView: View {
    let results: [StarHashKit.Transaction]
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onOpen: (StarHashKit.Transaction) -> Void
    let onConfirm: (StarHashKit.Transaction) -> Void
    let onDelete: (StarHashKit.Transaction) -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var query: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .starhashBottomBar { bar }
            .animation(.smooth(duration: 0.25), value: results.map(\.id))
    }

    @ViewBuilder
    private var content: some View {
        if query.isEmpty {
            ActivitySearchMessage(
                title: "Search Transactions",
                message: "Find a name, number, merchant code, amount or reference"
            )
            .transition(.opacity)
        } else if results.isEmpty {
            ActivitySearchMessage(
                title: "No Results",
                message: "No transactions match \u{201C}\(query)\u{201D}."
            )
            .transition(.opacity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ActivityTransactionRows(
                        transactions: results,
                        showsDate: true,
                        onOpen: onOpen,
                        onConfirm: onConfirm,
                        onDelete: onDelete
                    )
                }
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .padding(.top, ActivityLayout.searchResultsTop)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .starhashSoftBottomEdge()
            .activitySwipeActionsContainer()
            .starhashReadableScrollContent()
            .transition(.opacity)
        }
    }

    // MARK: Bottom bar

    /// With the keyboard down the bar floats in from the screen edges;
    /// typing widens it to nearly the full width.
    private var bar: some View {
        StarHashGlassContainer(spacing: 8) {
            HStack(spacing: 12) {
                field
                closeButton
            }
        }
        .padding(.horizontal, isFocused.wrappedValue ? 8 : 28)
        .padding(.bottom, isFocused.wrappedValue ? 10 : 0)
        .starhashReadableWidth()
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.3), value: isFocused.wrappedValue)
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.starhashPrimaryText)
                .accessibilityHidden(true)
            TextField(
                "Search transactions",
                text: $text,
                prompt: Text("Search transactions").foregroundStyle(Color.starhashSecondaryText)
            )
            .font(.body)
            .foregroundStyle(Color.starhashPrimaryText)
            .focused(isFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityLabel("Search transactions")
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Taps across 44pt but takes the drawn glyph's room.
                .padding(-10)
                .accessibilityLabel("Clear Search")
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.leading, 15)
        .padding(.trailing, 14)
        .frame(minHeight: ActivityLayout.searchBarHeight)
        .contentShape(Capsule())
        .onTapGesture { isFocused.wrappedValue = true }
        .starhashGlass()
        .animation(.snappy(duration: 0.2), value: text.isEmpty)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.starhashPrimaryText)
                .frame(width: ActivityLayout.searchBarHeight, height: ActivityLayout.searchBarHeight)
                .contentShape(Circle())
                .starhashGlass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close Search")
        .accessibilityShowsLargeContentViewer {
            Label("Close Search", systemImage: "xmark")
        }
    }
}

/// The magnifier, a bold title and a grey line, centred over the space
/// above the search bar, sized like Activity's other empty state.
private struct ActivitySearchMessage: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .starhashFont(40)
                .foregroundStyle(Color.starhashMutedIcon)
                .padding(.bottom, 21)
                .accessibilityHidden(true)
            Text(title)
                .starhashFont(20, weight: .bold)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .starhashFont(20)
                .foregroundStyle(Color.starhashSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .accessibilityElement(children: .combine)
    }
}
