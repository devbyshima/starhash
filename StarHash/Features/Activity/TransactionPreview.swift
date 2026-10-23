import StarHashKit
import SwiftUI

/// What a long press on a confirmed transaction lifts over the dimmed
/// list, after the owner's reference: the top of its page, who, when and
/// how much and then the details' cards, on a card the width of the list,
/// cut off at the preview's foot. It has no menu: a tap on the row opens
/// the page.
struct TransactionPreview: View {
    let transaction: StarHashKit.Transaction
    let width: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            TransactionHero(transaction: transaction)
                .padding(.bottom, 16)
            TransactionDetailCards(transaction: transaction) {
                DetailRow("Category", transaction.activityCategoryTitle)
            }
        }
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .padding(.top, ActivityLayout.previewTop)
        // Its whole height, as on the page, cut off by the card rather than
        // squeezed into it (the amount would shrink to fit).
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: width, height: ActivityLayout.previewHeight, alignment: .top)
        .clipped()
        .background(Color.starhashBackground)
    }
}

/// What a long press on a payment not yet confirmed lifts, as Contacts
/// lifts a contact: the row itself on a card the width of the list, its
/// tile and words inset from the card's edge, with no line under it, and
/// the menu below.
struct TransactionRowPreview: View {
    let transaction: StarHashKit.Transaction
    let width: CGFloat
    var showsDate = true

    var body: some View {
        ActivityTransactionRow(transaction: transaction, showsDate: showsDate, showsDivider: false)
            .padding(.horizontal, ActivityLayout.rowPreviewInset)
            .padding(.vertical, ActivityLayout.rowPreviewInset - ActivityLayout.rowPadding)
            .frame(width: width)
            .background(Color.starhashBackground)
    }
}
