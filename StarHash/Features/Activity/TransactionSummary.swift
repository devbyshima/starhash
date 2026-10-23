import StarHashKit
import SwiftUI

/// Who, when and how much, down the middle: the tile, the name in bold,
/// the date and time in grey, then the amount large, struck through when
/// it failed, with RWF after it at half its size on its baseline. The top
/// of a transaction's page, and of the preview a long press lifts.
struct TransactionHero: View {
    let transaction: StarHashKit.Transaction

    var body: some View {
        VStack(spacing: 0) {
            TransactionTile(transaction: transaction, size: 64)
                .padding(.bottom, 18)
            Text(transaction.counterparty.shownName)
                .starhashFont(28, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)
            Text(transaction.date.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(.starhash)))
                .starhashFont(17, relativeTo: .body)
                .foregroundStyle(Color.starhashSecondaryText)
                .padding(.bottom, 14)
            // One Text, so the amount and "RWF" shrink together.
            (Text((transaction.direction == .incoming ? "+" : "") + Money.format(transaction.amount))
                .foregroundStyle(transaction.activityAmountColor)
                .strikethrough(transaction.status == .failed)
                + Text(" " + Money.currency)
                .font(.starhashNumber(20, relativeTo: .title3))
                .foregroundStyle(Color.starhashSecondaryText))
                .font(.starhashNumber(40, weight: .bold, relativeTo: .largeTitle))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
    }
}

/// The reference's three cards, with StarHash's details in them: how it
/// went and the wallet it went through; who it went to and the carrier's
/// code for it; and the money, the amount with its fee and the balance it
/// left. A row with nothing to say is left out. The category row under
/// Status is the caller's: the page's menu, or the preview's words.
struct TransactionDetailCards<CategoryRow: View>: View {
    let transaction: StarHashKit.Transaction
    @ViewBuilder var categoryRow: CategoryRow

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                DetailRow(label: "Status") { statusValue(transaction.status) }
                if transaction.status == .failed, let reason = failureText {
                    DetailRow("Reason", reason)
                }
                categoryRow
                if let wallet = transaction.wallet {
                    DetailRow("Payment", wallet.walletName)
                }
            }
            .starhashOutlinedCard()

            VStack(spacing: 0) {
                DetailRow(
                    transaction.counterparty.kind == .phone ? "Number" : "Merchant code",
                    transaction.counterparty.formattedDestination,
                    numeric: true
                )
                DetailRow(
                    "Code",
                    transaction.reference ?? (transaction.status == .pending ? "Waiting for SMS" : "None"),
                    numeric: transaction.reference != nil
                )
            }
            .starhashOutlinedCard()

            VStack(spacing: 0) {
                DetailRow("Amount", Money.formatWithCurrency(transaction.amount), numeric: true)
                // The fee only once the carrier's SMS has confirmed it;
                // until then the row is left out rather than guessed.
                // MoMoAdvance's access fee gets a row of its own, so the
                // wallet's fee reads as its message gave it.
                if transaction.status == .confirmed, let fee = transaction.walletFee {
                    DetailRow("Fee", fee == 0 ? "Free" : Money.formatWithCurrency(fee), numeric: fee != 0)
                    if let accessFee = transaction.accessFee {
                        DetailRow("MoMoAdvance fee", Money.formatWithCurrency(accessFee), numeric: true)
                    }
                    DetailRow("Total", Money.formatWithCurrency(transaction.amount + (transaction.fee ?? 0)), numeric: true)
                }
                if let balance = transaction.balanceAfter {
                    DetailRow("Balance after", Money.formatWithCurrency(balance), numeric: true)
                }
            }
            .starhashOutlinedCard()
        }
    }

    /// A dot and the word, in the status's colour.
    private func statusValue(_ status: StarHashKit.Transaction.Status) -> some View {
        let color: AnyShapeStyle = switch status {
        case .confirmed: AnyShapeStyle(Color.starhashIncoming)
        case .pending: AnyShapeStyle(Color.starhashUrgentText)
        case .failed: AnyShapeStyle(Color.starhashDestructive)
        }
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(statusTitle(status))
                .starhashFont(17, relativeTo: .body)
                .foregroundStyle(color)
        }
    }

    /// Why StarHash failed it, when it did rather than its owner.
    private var failureText: String? {
        switch transaction.failureReason {
        case .noMessage: "No message within an hour"
        case .message: "The wallet said it failed"
        case nil: nil
        }
    }

    private func statusTitle(_ status: StarHashKit.Transaction.Status) -> String {
        switch status {
        case .pending: "Pending"
        case .confirmed: "Confirmed"
        case .failed: "Failed"
        }
    }
}
