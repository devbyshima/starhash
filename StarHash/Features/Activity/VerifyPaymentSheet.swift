import StarHashKit
import SwiftUI
import UIKit

/// Verify: settles a payment with its wallet's own message. iOS lets no
/// app read Messages, so the owner copies the message and pastes it here,
/// and StarHash reads it as the automation would, applying it only when it
/// is this payment's (`StarHashStore.verify(_:withMessage:)`). Beam's sheet
/// language, sized to its content: the title, what to do, the payment to
/// look for in a card, what the last paste said, then Paste Message, with
/// Confirm Without Message under it for a message deleted or never sent.
struct VerifyPaymentSheet: View {
    let transactionID: UUID

    @Environment(StarHashStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 520
    /// What the last paste said, when it settled nothing.
    @State private var note: Note?

    private struct Note: Equatable {
        var text: String
        var isProblem: Bool
    }

    private var transaction: StarHashKit.Transaction? { store.transaction(id: transactionID) }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader("Verify")

            if let transaction {
                VStack(spacing: 14) {
                    Text("Copy the \((transaction.wallet ?? StarHashPreferences.wallet).messagesName) message about this payment, then paste it here.")
                        .font(.sheetSubheadline)
                        .foregroundStyle(Color.sheetBrandText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    paymentCard(transaction)

                    if let note {
                        Text(note.text)
                            .font(.sheet(14, .semibold, relativeTo: .subheadline))
                            .foregroundStyle(note.isProblem ? Color.starhashDestructive : Color.sheetBrandText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }

                    VStack(spacing: 4) {
                        Button("Paste Message") { paste() }
                            .buttonStyle(.sheetPrimary)
                        // The last resort: a message deleted, or one that
                        // never came. The fee comes from the carriers' prices.
                        SheetTextButton("Confirm Without Message") { confirmWithoutMessage(transaction) }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .animation(.smooth(duration: 0.25), value: note)
            }
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Into the home indicator's inset, as Turn Off Auto-verify's sheet.
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
        #if DEBUG
        // -verifyMessage <text>: pasted as the sheet opens, for screenshots.
        .task {
            guard let text = DebugLaunch.value(after: "-verifyMessage") else { return }
            try? await Task.sleep(for: .milliseconds(500))
            verify(text)
        }
        #endif
    }

    /// What to find in Messages: how much, to whom, and when.
    private func paymentCard(_ transaction: StarHashKit.Transaction) -> some View {
        let rows: [(String, String)] = [
            ("Amount", Money.formatWithCurrency(transaction.amount)),
            ("To", transaction.counterparty.displayName),
            (transaction.counterparty.kind == .phone ? "Number" : "Merchant code", transaction.counterparty.formattedDestination),
            ("Dialled", transaction.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())),
        ]
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { SheetDivider() }
                SheetInfoRow(row.0, row.1)
            }
        }
        .padding(.horizontal, 16)
        .sheetCard()
    }

    // MARK: Actions

    /// Reads what was copied. iOS asks first, unless Paste from Other Apps
    /// is set to Allow for StarHash.
    private func paste() {
        guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            show(Note(text: "Nothing is copied. Copy the message in Messages first.", isProblem: true))
            return
        }
        verify(text)
    }

    private func verify(_ text: String) {
        guard let result = withAnimation(.smooth(duration: 0.3), { store.verify(transactionID, withMessage: text) }) else {
            dismiss()
            return
        }
        switch result {
        case .confirmed:
            // The page says what it became: Confirmed, with its fee. Played
            // here rather than by the sheet, which is going.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        case .failed:
            // Failed, with the wallet's message as the reason.
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            dismiss()
        case .overdraft(let paid):
            let fee = Money.formatWithCurrency(paid.accessFee ?? 0)
            show(Note(text: "MoMoAdvance's fee of \(fee) is added. Now paste the payment's own message.", isProblem: false))
        case .anotherPayment, .confirmedAnother, .notAMessage:
            // Another payment's message, one already used, or not a
            // wallet's at all: all the same to the owner, the wrong one.
            show(Note(text: "That's not the right message.", isProblem: true))
        }
    }

    /// Its fee from the carriers' prices, for the wallet it was dialled
    /// with, as Mark as Confirmed did.
    private func confirmWithoutMessage(_ transaction: StarHashKit.Transaction) {
        let confirmed = transaction.confirmedByHand(wallet: StarHashPreferences.wallet)
        withAnimation(.smooth(duration: 0.3)) { store.update(confirmed) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    /// What a paste said, felt as well: a problem buzzes as an error.
    private func show(_ new: Note) {
        note = new
        UINotificationFeedbackGenerator().notificationOccurred(new.isProblem ? .error : .success)
        UIAccessibility.post(notification: .announcement, argument: new.text)
    }
}
