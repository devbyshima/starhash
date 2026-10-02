import StarHashKit
import SwiftUI

/// Activity's measurements, ported from Keaser's Home (points on a 402pt
/// wide screen).
enum ActivityLayout {
    /// From the bottom of the top bar to the summary card.
    static let contentTop: CGFloat = 24
    static let topBarHeight: CGFloat = 44
    /// Where the hairline between rows starts: past the 16pt margin, the
    /// 42pt symbol tile and the 16pt gap, under the name.
    static let rowSeparatorLeading: CGFloat = 74
    /// From the top of the safe area to the first search result.
    static let searchResultsTop: CGFloat = 35
    /// The search field capsule and the round button beside it.
    static let searchBarHeight: CGFloat = 48
}

/// Where a row sits in its card, so its background rounds the right corners.
enum ActivityCardPosition {
    case single, first, middle, last

    init(index: Int, count: Int) {
        switch (index, count) {
        case (_, ...1): self = .single
        case (0, _): self = .first
        case (count - 1, _): self = .last
        default: self = .middle
        }
    }

    var roundsTop: Bool { self == .single || self == .first }
    var roundsBottom: Bool { self == .single || self == .last }
}

/// One row's slice of a rounded card. Each row draws its own slice, so a
/// day's card can sit in a lazy stack and still be built row by row.
struct ActivityCardRowBackground: View {
    let position: ActivityCardPosition
    var fill: Color = .starhashCard

    var body: some View {
        let top = position.roundsTop ? StarHashMetrics.cardRadius : 0
        let bottom = position.roundsBottom ? StarHashMetrics.cardRadius : 0
        UnevenRoundedRectangle(
            topLeadingRadius: top,
            bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom,
            topTrailingRadius: top,
            style: .continuous
        )
        .fill(fill)
    }
}

/// The question before one transaction is deleted: the title and the
/// buttons, little else, since the transaction is right there. Don't Ask
/// Again deletes and stops asking; Settings, Ask Before Deleting, brings it
/// back.
private struct DeleteTransactionDialog: ViewModifier {
    @Binding var transaction: StarHashKit.Transaction?
    let onDelete: (StarHashKit.Transaction) -> Void

    @AppStorage(PreferenceKey.confirmDeletes) private var confirmDeletes = true

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete Transaction?",
            isPresented: Binding(get: { transaction != nil }, set: { if !$0 { transaction = nil } }),
            titleVisibility: .visible,
            presenting: transaction
        ) { transaction in
            Button("Delete", role: .destructive) { onDelete(transaction) }
            Button("Delete, Don't Ask Again", role: .destructive) {
                confirmDeletes = false
                onDelete(transaction)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It is removed from StarHash only.")
        }
    }
}

extension View {
    /// Asks before deleting `transaction` while it is set.
    func deleteTransactionDialog(
        _ transaction: Binding<StarHashKit.Transaction?>,
        onDelete: @escaping (StarHashKit.Transaction) -> Void
    ) -> some View {
        modifier(DeleteTransactionDialog(transaction: transaction, onDelete: onDelete))
    }
}

// Swipe to delete on Activity's own rows, which sit in a lazy stack rather
// than a List. iOS 27 lets swipe actions work there once the scroll view
// coordinates them; earlier systems keep only the long-press menu, so both
// helpers do nothing there.
extension View {
    /// Swiping the row towards the leading edge reveals Delete (with the
    /// same confirmation as the long-press menu). iOS 27 and later; the
    /// scroll view holding the row needs `activitySwipeActionsContainer()`.
    @ViewBuilder
    func activitySwipeToDelete(_ onDelete: @escaping () -> Void) -> some View {
        if #available(iOS 27.0, *) {
            swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            self
        }
    }

    /// Lets the rows inside this scroll view open their swipe actions, one
    /// at a time, as in a List. iOS 27 and later.
    @ViewBuilder
    func activitySwipeActionsContainer() -> some View {
        if #available(iOS 27.0, *) {
            swipeActionsContainer()
        } else {
            self
        }
    }
}

/// The labels a transaction can carry. Stored in `Transaction.category` by
/// raw value, so a label the app no longer lists still shows (as "Other"'s
/// symbol and its own name).
enum TransactionCategory: String, CaseIterable, Identifiable {
    case restaurant, groceries, transport, bills, shopping, health, family, other

    var id: Self { self }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .restaurant: "fork.knife"
        case .groceries: "cart.fill"
        case .transport: "car.fill"
        case .bills: "doc.text.fill"
        case .shopping: "bag.fill"
        case .health: "heart.fill"
        case .family: "person.2.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}

extension StarHashKit.Transaction {
    /// Up and to the right when money left, down and to the left when it
    /// came in.
    var activityArrowSymbol: String {
        direction == .outgoing ? "arrow.up.right" : "arrow.down.left"
    }

    /// Red out, green in: the only two hues besides ink.
    var activityArrowColor: Color {
        direction == .outgoing ? .starhashDestructive : .starhashIncoming
    }

    /// The amount's colour: primary text when money left, green when it
    /// came in. Ink stays the only accent.
    var activityAmountColor: Color {
        direction == .outgoing ? .starhashPrimaryText : .starhashIncoming
    }

    var activityCategory: TransactionCategory? {
        category.flatMap(TransactionCategory.init(rawValue:))
    }

    /// What VoiceOver reads for a row.
    var activityAccessibilityLabel: String {
        var parts = [
            counterparty.displayName,
            (direction == .outgoing ? "Sent " : "Received ") + Money.formatWithCurrency(amount),
            date.formatted(date: .abbreviated, time: .shortened),
        ]
        if status == .pending { parts.append("Pending") }
        if status == .failed { parts.append("Failed") }
        return parts.joined(separator: ", ")
    }
}

/// The small grey capsule beside a pending transaction's name.
struct ActivityStatusBadge: View {
    let status: StarHashKit.Transaction.Status

    var body: some View {
        if status != .confirmed {
            Text(status == .pending ? "Pending" : "Failed")
                .starhashFont(12, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(status == .failed ? Color.starhashDestructive : Color.starhashSecondaryText)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.starhashCardRaised, in: Capsule())
                .lineLimit(1)
                .fixedSize()
                .accessibilityHidden(true)
        }
    }
}
