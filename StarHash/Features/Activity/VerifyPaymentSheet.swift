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
/// Once it settles the payment, the sheet's Distortion Wave turns it into
/// what came of it (`SheetOutcome`): Confirmed in green, or Failed in red.
struct VerifyPaymentSheet: View {
    let transactionID: UUID

    @Environment(StarHashStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var height: CGFloat = 520
    /// What the last paste said, when it settled nothing.
    @State private var note: Note?
    /// What came of it, once it is settled.
    @State private var outcome: Outcome?

    private struct Note: Equatable {
        var text: String
        var isProblem: Bool
    }

    private enum Outcome {
        case confirmed, failed

        /// The wave's light.
        var tint: Color { self == .confirmed ? .waveConfirmed : .waveFailed }
        /// The icon's circle: the green of Confirmed on the payment's page,
        /// so the two read as one.
        var iconTint: Color { self == .confirmed ? .starhashConfirmed : .waveFailed }
    }

    private var transaction: StarHashKit.Transaction? { store.transaction(id: transactionID) }

    var body: some View {
        Group {
            if let outcome, let transaction {
                outcomeView(outcome, transaction)
            } else {
                question
            }
        }
        // The sheet keeps its height as it turns into its outcome, so the
        // wave plays over one still shape.
        .sheetHeight(outcome == nil ? $height : .constant(height))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Into the home indicator's inset, as Turn Off Auto-verify's sheet.
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
        #if DEBUG
        // -verifyMessage <text>: pasted as the sheet opens, for screenshots.
        .task {
            guard let text = DebugLaunch.value(after: "-verifyMessage") else { return }
            try? await Task.sleep(for: .milliseconds(800))
            verify(text)
        }
        // -verifyConfirm: Confirm Without Message, as if tapped.
        .task {
            guard DebugLaunch.arguments.contains("-verifyConfirm"), let transaction else { return }
            try? await Task.sleep(for: .milliseconds(1500))
            confirmWithoutMessage(transaction)
        }
        #endif
    }

    private var question: some View {
        VStack(spacing: 0) {
            SheetHeader("Verify")

            if let transaction {
                VStack(spacing: 14) {
                    paymentCard(transaction)

                    if let note {
                        Text(catalog: note.text)
                            .font(.sheet(14, .semibold, relativeTo: .subheadline))
                            .foregroundStyle(note.isProblem ? AnyShapeStyle(Color.starhashDestructive) : AnyShapeStyle(Color.sheetBrandText))
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
    }

    /// Confirmed, with what the message filled in, or Failed, with why.
    private func outcomeView(_ outcome: Outcome, _ transaction: StarHashKit.Transaction) -> some View {
        var rows: [(label: String, value: String)] = []
        if outcome == .confirmed {
            if let fee = transaction.fee { rows.append((String(starhash: "Fee"), Money.formatWithCurrency(fee))) }
            if let reference = transaction.reference { rows.append((String(starhash: "Code"), reference)) }
            if let balance = transaction.balanceAfter { rows.append((String(starhash: "Balance"), Money.formatWithCurrency(balance))) }
        }
        rows.append((transaction.counterparty.kind == .phone ? String(starhash: "Number") : String(starhash: "Merchant code"), transaction.counterparty.formattedDestination))
        return SheetOutcome(
            symbol: outcome == .confirmed ? "checkmark" : "xmark",
            tint: outcome.iconTint,
            label: outcome == .confirmed ? String(starhash: "Confirmed") : String(starhash: "Failed"),
            title: Money.formatWithCurrency(transaction.amount),
            detail: transaction.counterparty.displayName,
            rows: Array(rows.prefix(3)),
            onDone: { dismiss() }
        )
    }

    /// What to find in Messages: how much, to whom, and when.
    private func paymentCard(_ transaction: StarHashKit.Transaction) -> some View {
        let rows: [(String, String)] = [
            ("Amount", Money.formatWithCurrency(transaction.amount)),
            ("To", transaction.counterparty.displayName),
            (transaction.counterparty.kind == .phone ? "Number" : "Merchant code", transaction.counterparty.formattedDestination),
            ("Dialled", transaction.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(.starhash))),
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
            settle(.confirmed)
        case .failed:
            // Failed, with the wallet's message as the reason on the page.
            settle(.failed)
        case .overdraft(let paid):
            let fee = Money.formatWithCurrency(paid.accessFee ?? 0)
            show(Note(text: String(starhash: "MoMoAdvance's fee of \(fee) is added. Now paste the payment's own message."), isProblem: false))
        case .anotherPayment, .confirmedAnother, .notAMessage:
            // Another payment's message, one already used, or not a
            // wallet's at all: all the same to the owner, the wrong one.
            show(Note(text: "That's not the right message.", isProblem: true))
        }
    }

    /// Its fee from the carriers' prices, for the wallet it was dialled
    /// with, as Mark as Confirmed did.
    private func confirmWithoutMessage(_ transaction: StarHashKit.Transaction) {
        withAnimation(.smooth(duration: 0.3)) { _ = store.confirmByHand(transaction.id, fallback: AppEnvironment.owner.wallet) }
        settle(.confirmed)
    }

    /// Turns the sheet into its outcome on the sheet's wave.
    private func settle(_ new: Outcome) {
        SheetOutcome.reveal(
            tint: new.tint,
            dark: colorScheme == .dark,
            reduceMotion: reduceMotion,
            feel: new == .confirmed ? .success : .warning,
            show: { outcome = new }
        )
    }

    /// What a paste said, felt as well: a problem buzzes as an error.
    private func show(_ new: Note) {
        note = new
        UINotificationFeedbackGenerator().notificationOccurred(new.isProblem ? .error : .success)
        UIAccessibility.post(notification: .announcement, argument: new.text)
    }
}
