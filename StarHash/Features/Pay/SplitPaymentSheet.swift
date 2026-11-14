import StarHashKit
import SwiftUI

/// With Split Large Payments on, a payment that costs less in parts: the
/// parts, what they cost against one payment, and a button that dials the
/// next part. Each part is a call prompt and a PIN of its own, so the sheet
/// stays up between them and shows how each went: waiting for its SMS,
/// confirmed or failed. Before the first part, the whole amount can still
/// go as one payment. Once a part has gone, a swipe down no longer closes
/// it: Stop Here does, so the remaining parts are never left by accident.
///
/// It only draws `Paying.split` and calls `Paying`'s verbs: which part is
/// next, what dialling one records and when one can be dialled again are
/// `Paying`'s. Pay stops the split when the sheet goes.
struct SplitPaymentSheet: View {
    @Environment(Paying.self) private var paying
    @Environment(StarHashStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 480
    /// The split as it last was, so the sheet keeps its content while it
    /// slides away after Send as One Payment ends it.
    @State private var shown: Paying.SplitPayment?

    private var split: Paying.SplitPayment? { paying.split ?? shown }

    var body: some View {
        VStack(spacing: 0) {
            if let split {
                SheetHeader(String(starhash: "Send in \(split.plan.parts.count) parts"))

                VStack(spacing: 14) {
                    partsCard(split)
                    feesCard(split)
                    buttons(split)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
        .interactiveDismissDisabled((split?.dialled ?? 0) > 0 && split?.allDialled == false)
        .animation(.smooth(duration: 0.25), value: split?.dialled)
        .dialFailureAlert()
        .onChange(of: paying.split, initial: true) { _, split in
            if let split { shown = split }
        }
        #if DEBUG
        .onAppear(perform: applyDebugLaunch)
        #endif
    }

    // MARK: Cards

    /// Each part's amount, with how it went.
    private func partsCard(_ split: Paying.SplitPayment) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(split.plan.parts.enumerated()), id: \.offset) { index, amount in
                if index > 0 { SheetDivider() }
                partRow(index, amount: amount, isNext: index == split.dialled)
            }
        }
        .padding(.horizontal, 16)
        .sheetCard()
    }

    private func partRow(_ index: Int, amount: Int, isNext: Bool) -> some View {
        let status = words(for: paying.status(ofPart: index))
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Part \(index + 1)")
                    .font(.sheetBody)
                    .foregroundStyle(Color.starhashPrimaryText)
                Text(verbatim: status.text)
                    .font(.sheet(14, isNext ? .semibold : .medium, relativeTo: .subheadline))
                    .foregroundStyle(status.color)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 12)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Money.format(amount))
                    .font(.starhashNumber(17, relativeTo: .body))
                    .foregroundStyle(Color.starhashPrimaryText)
                Text(Money.currency)
                    .font(.sheet(12, relativeTo: .footnote))
                    .foregroundStyle(Color.sheetSecondaryText)
            }
            .lineLimit(1)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(starhash: "Part \(index + 1), \(Money.formatWithCurrency(amount)), \(status.text)"))
    }

    /// What the parts cost together, and what one payment would.
    private func feesCard(_ split: Paying.SplitPayment) -> some View {
        VStack(spacing: 0) {
            SheetInfoRow(String(starhash: "Fees in parts"), Money.formatWithCurrency(split.plan.fee))
            SheetDivider()
            SheetInfoRow(String(starhash: "Fee as one payment"), Money.formatWithCurrency(split.plan.feeAsOne))
        }
        .padding(.horizontal, 16)
        .sheetCard()
    }

    // MARK: Buttons

    private func buttons(_ split: Paying.SplitPayment) -> some View {
        VStack(spacing: 4) {
            if split.allDialled {
                Button("Done") { dismiss() }
                    .buttonStyle(.sheetPrimary)
            } else {
                Button(String(starhash: "Send Part \(split.dialled + 1)")) { paying.sendNextPart() }
                    .buttonStyle(.sheetPrimary)
            }
            if split.dialled == 0 {
                SheetTextButton("Send as One Payment") {
                    // Dialled once the sheet has gone (`Paying`'s wait).
                    paying.sendWhole()
                    dismiss()
                }
            } else if paying.canDialPartAgain {
                // A call cancelled at the system's prompt: the same part,
                // the same pending payment.
                SheetTextButton(String(starhash: "Dial Part \(split.dialled) Again")) { paying.dialPartAgain() }
            }
            if split.dialled > 0, !split.allDialled {
                SheetTextButton("Stop Here") { dismiss() }
            }
        }
    }

    /// "Next", "Waiting for SMS", "Confirmed" or "Failed", in the app's
    /// language and the status's colour as Activity shows it.
    private func words(for status: Paying.PartStatus) -> (text: String, color: AnyShapeStyle) {
        switch status {
        case .next: (String(starhash: "Next"), AnyShapeStyle(Color.sheetBrandText))
        case .notSent: (String(starhash: "Not sent yet"), AnyShapeStyle(Color.sheetSecondaryText))
        case .dialled: (String(starhash: "Part dialled"), AnyShapeStyle(Color.sheetSecondaryText))
        case .pending: (String(starhash: "Waiting for SMS"), AnyShapeStyle(Color.starhashUrgentText))
        case .confirmed: (String(starhash: "Confirmed"), AnyShapeStyle(Color.starhashConfirmedText))
        case .failed: (String(starhash: "Failed"), AnyShapeStyle(Color.starhashDestructive))
        }
    }

    // MARK: Debug

    #if DEBUG
    /// -paySplitDialled <n>: the first n parts sent, with nothing dialled
    /// (`Dialler`), and -paySplitConfirmed the first of them confirmed, for
    /// screenshots of the sheet partway through.
    private func applyDebugLaunch() {
        guard paying.split?.dialled == 0, let count = DebugLaunch.value(after: "-paySplitDialled").flatMap(Int.init) else { return }
        for _ in 0..<count { paying.sendNextPart() }
        if DebugLaunch.arguments.contains("-paySplitConfirmed"), let first = paying.split?.payments[0] {
            store.confirmByHand(first, fallback: paying.split?.wallet ?? .mtn)
        }
    }
    #endif
}
