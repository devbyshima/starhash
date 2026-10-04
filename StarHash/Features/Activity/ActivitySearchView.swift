import StarHashKit
import SwiftUI

/// What shows under Activity's bar while it searches (the field is in the
/// bar, as on the recipient screen): matching transactions in the usual
/// card, or "Search Transactions" or "No Results" in the middle.
///
/// It looks through every transaction, not only the chosen period: a
/// MoMo log is searched for one payment, whenever it was.
struct ActivitySearchView: View {
    let results: [StarHashKit.Transaction]
    let text: String
    let onOpen: (StarHashKit.Transaction) -> Void
    let onConfirm: (StarHashKit.Transaction) -> Void
    let onDelete: (StarHashKit.Transaction) -> Void
    let onSwipeDelete: (StarHashKit.Transaction) -> Void
    var leaving: Set<UUID> = []

    private var query: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        onDelete: onDelete,
                        onSwipeDelete: onSwipeDelete,
                        leaving: leaving
                    )
                }
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .padding(.top, ActivityLayout.contentTop)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .starhashSoftEdge()
            .activitySwipeActionsContainer()
            .starhashReadableScrollContent()
            .transition(.opacity)
        }
    }
}

/// The magnifier, a bold title and a grey line, centred in the space under
/// the bar, sized like Activity's other empty state.
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
        .accessibilityElement(children: .combine)
    }
}
