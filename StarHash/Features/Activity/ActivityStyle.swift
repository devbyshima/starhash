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
}

/// The question before one transaction is deleted: the title and the
/// buttons, little else, since the transaction is right there. Don't Ask
/// Again deletes and stops asking; Settings, Ask Before Deleting, brings it
/// back.
private struct DeleteTransactionDialog: ViewModifier {
    @Binding var transaction: StarHashKit.Transaction?
    let asAlert: Bool
    let onDelete: (StarHashKit.Transaction) -> Void

    @AppStorage(PreferenceKey.confirmDeletes) private var confirmDeletes = true

    private var isPresented: Binding<Bool> {
        Binding(get: { transaction != nil }, set: { if !$0 { transaction = nil } })
    }

    func body(content: Content) -> some View {
        if asAlert {
            content.alert("Delete Transaction?", isPresented: isPresented, presenting: transaction) { transaction in
                buttons(transaction)
            } message: { _ in
                message
            }
        } else {
            content.confirmationDialog(
                "Delete Transaction?",
                isPresented: isPresented,
                titleVisibility: .visible,
                presenting: transaction
            ) { transaction in
                buttons(transaction)
            } message: { _ in
                message
            }
        }
    }

    @ViewBuilder
    private func buttons(_ transaction: StarHashKit.Transaction) -> some View {
        Button("Delete", role: .destructive) { onDelete(transaction) }
        Button("Delete, Don't Ask Again", role: .destructive) {
            confirmDeletes = false
            onDelete(transaction)
        }
        Button("Cancel", role: .cancel) {}
    }

    private var message: Text { Text("It is removed from StarHash only.") }
}

extension View {
    /// Asks before deleting `transaction` while it is set: a dialog by
    /// the list, or a centred alert (`asAlert`) on the details page.
    func deleteTransactionDialog(
        _ transaction: Binding<StarHashKit.Transaction?>,
        asAlert: Bool = false,
        onDelete: @escaping (StarHashKit.Transaction) -> Void
    ) -> some View {
        modifier(DeleteTransactionDialog(transaction: transaction, asAlert: asAlert, onDelete: onDelete))
    }
}

// Swipe to delete on Activity's own rows, which sit in a lazy stack rather
// than a List. iOS 27 lets swipe actions work there once the scroll view
// coordinates them; earlier systems keep only the long-press menu, so both
// helpers do nothing there.
extension View {
    /// Beam's swipe on a copied item: swiping the row towards the leading
    /// edge reveals a red trash, and a full swipe deletes at once. iOS 27
    /// and later; the scroll view holding the row needs
    /// `activitySwipeActionsContainer()`.
    @ViewBuilder
    func activitySwipeToDelete(_ onDelete: @escaping () -> Void) -> some View {
        if #available(iOS 27.0, *) {
            swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .tint(Color.starhashDestructive)
                .accessibilityLabel("Delete")
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

/// The small capsule beside an unconfirmed transaction's name: Pending
/// filled in the urgent orange, so it stands out from the row; Failed in
/// red on grey.
struct ActivityStatusBadge: View {
    let status: StarHashKit.Transaction.Status

    var body: some View {
        if status != .confirmed {
            let isPending = status == .pending
            Text(isPending ? "Pending" : "Failed")
                .starhashFont(12, weight: .bold, relativeTo: .caption)
                .foregroundStyle(isPending ? Color.starhashOnUrgent : Color.starhashDestructive)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(isPending ? Color.starhashUrgent : Color.starhashCardRaised, in: Capsule())
                .lineLimit(1)
                .fixedSize()
                .accessibilityHidden(true)
        }
    }
}

extension ActivityPeriod {
    /// The periods the control offers: a day, a week, a month and a year.
    static let choices: [ActivityPeriod] = [.today, .week, .month, .year]

    /// The period control's label: a letter, as GO Club's D W M.
    var shortLabel: String {
        switch self {
        case .today: "D"
        case .week: "W"
        case .month: "M"
        case .year: "Y"
        case .allTime: "A"
        }
    }
}
