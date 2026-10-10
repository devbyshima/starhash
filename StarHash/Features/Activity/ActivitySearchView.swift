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
    let onVerify: (StarHashKit.Transaction) -> Void
    let onFail: (StarHashKit.Transaction) -> Void
    let onDelete: (StarHashKit.Transaction) -> Void
    let onSwipeDelete: (StarHashKit.Transaction) -> Void

    private var query: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.smooth(duration: 0.25), value: results.map(\.id))
    }

    @ViewBuilder
    private var content: some View {
        if query.isEmpty {
            EmptyStateView(
                doodle: .search,
                title: "Search Transactions",
                message: "Find a name, number, merchant code, amount or reference."
            )
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        } else if results.isEmpty {
            EmptyStateView(
                doodle: .results,
                title: "No Results",
                message: String(localized: "No transactions match \u{201C}\(query)\u{201D}.")
            )
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ActivityTransactionRows(
                        transactions: results,
                        showsDate: true,
                        onOpen: onOpen,
                        onVerify: onVerify,
                        onFail: onFail,
                        onDelete: onDelete,
                        onSwipeDelete: onSwipeDelete
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
