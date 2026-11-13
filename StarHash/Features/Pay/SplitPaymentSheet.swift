import StarHashKit
import SwiftUI

/// A payment Pay sends in parts (`SplitPlan`), while its sheet is up. Its
/// id is the split's, so every part it dials carries it.
struct SplitPaymentRequest: Identifiable {
    let id = UUID()
    let recipient: Recipient
    let plan: SplitPlan
    let wallet: Recipient.Network
}

/// With Split Large Payments on, a payment that costs less in parts: the
/// parts, what they cost against one payment, and a button that dials the
/// next part. Each part is a call prompt and a PIN of its own, so the sheet
/// stays up between them and shows how each went: waiting for its SMS,
/// confirmed or failed. Before the first part, the whole amount can still
/// go as one payment. Once a part has gone, a swipe down no longer closes
/// it: Stop Here does, so the remaining parts are never left by accident.
struct SplitPaymentSheet: View {
    let request: SplitPaymentRequest
    /// Records part `split.part` as a pending payment when transactions
    /// are kept, returning its id. The sheet dials it.
    let recordPart: (_ amount: Int, _ split: StarHashKit.Transaction.Split) -> UUID?
    /// Closes the sheet and sends the whole amount as one payment.
    let sendWhole: () -> Void

    @Environment(StarHashStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 480
    /// How many parts have been dialled, in order.
    @State private var dialled = 0
    /// Each dialled part's payment, by its index.
    @State private var recorded: [Int: UUID] = [:]
    /// A code the system would not dial (the simulator, an iPad), shown so
    /// it can be dialled by hand. Pay's own alert cannot show over a sheet.
    @State private var undialledCode: String?

    private var parts: [Int] { request.plan.parts }
    private var allDialled: Bool { dialled == parts.count }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(String(starhash: "Send in \(parts.count) parts"))

            VStack(spacing: 14) {
                partsCard
                feesCard
                buttons
                    .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
        .interactiveDismissDisabled(dialled > 0 && !allDialled)
        .animation(.smooth(duration: 0.25), value: dialled)
        .alert(
            "Can't dial on this device",
            isPresented: Binding(get: { undialledCode != nil }, set: { if !$0 { undialledCode = nil } }),
            presenting: undialledCode
        ) { code in
            Button("Copy Code") {
                UIPasteboard.general.string = code
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Button("OK", role: .cancel) {}
        } message: { code in
            Text("Dial \(code) on your phone to finish.")
        }
        #if DEBUG
        .onAppear(perform: applyDebugLaunch)
        #endif
    }

    // MARK: Cards

    /// Each part's amount, with how it went.
    private var partsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, amount in
                if index > 0 { SheetDivider() }
                partRow(index, amount: amount)
            }
        }
        .padding(.horizontal, 16)
        .sheetCard()
    }

    private func partRow(_ index: Int, amount: Int) -> some View {
        let status = status(of: index)
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Part \(index + 1)")
                    .font(.sheetBody)
                    .foregroundStyle(Color.starhashPrimaryText)
                Text(verbatim: status.text)
                    .font(.sheet(14, index == dialled ? .semibold : .medium, relativeTo: .subheadline))
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
    private var feesCard: some View {
        VStack(spacing: 0) {
            SheetInfoRow(String(starhash: "Fees in parts"), Money.formatWithCurrency(request.plan.fee))
            SheetDivider()
            SheetInfoRow(String(starhash: "Fee as one payment"), Money.formatWithCurrency(request.plan.feeAsOne))
        }
        .padding(.horizontal, 16)
        .sheetCard()
    }

    // MARK: Buttons

    private var buttons: some View {
        VStack(spacing: 4) {
            if allDialled {
                Button("Done") { dismiss() }
                    .buttonStyle(.sheetPrimary)
            } else {
                Button(String(starhash: "Send Part \(dialled + 1)")) { send(dialled) }
                    .buttonStyle(.sheetPrimary)
            }
            if dialled == 0 {
                SheetTextButton("Send as One Payment") {
                    dismiss()
                    sendWhole()
                }
            } else if canDialAgain(dialled - 1) {
                // A call cancelled at the system's prompt: the same part,
                // the same pending payment.
                SheetTextButton(String(starhash: "Dial Part \(dialled) Again")) { dial(dialled - 1) }
            }
            if dialled > 0, !allDialled {
                SheetTextButton("Stop Here") { dismiss() }
            }
        }
    }

    // MARK: Actions

    /// Dials part `index` and moves on to the next.
    private func send(_ index: Int) {
        dial(index)
        dialled = index + 1
    }

    /// Records part `index` (again, for a retry: the store keeps it one
    /// payment) and dials it.
    private func dial(_ index: Int) {
        let amount = parts[index]
        let split = StarHashKit.Transaction.Split(id: request.id, part: index + 1, count: parts.count, total: request.plan.amount)
        if let id = recordPart(amount, split) { recorded[index] = id }
        let code = USSD.payment(to: request.recipient, amount: amount, from: request.wallet)
        Task {
            if await !USSDDialer.dial(code) { undialledCode = code }
        }
    }

    /// Only a part still waiting is dialled again: one its SMS confirmed
    /// went through.
    private func canDialAgain(_ index: Int) -> Bool {
        guard let id = recorded[index] else { return true }
        return store.transaction(id: id)?.status == .pending
    }

    /// "Next", "Waiting for SMS", "Confirmed" or "Failed", in the app's
    /// language and the status's colour as Activity shows it.
    private func status(of index: Int) -> (text: String, color: AnyShapeStyle) {
        if index >= dialled {
            return index == dialled
                ? (String(starhash: "Next"), AnyShapeStyle(Color.sheetBrandText))
                : (String(starhash: "Not sent yet"), AnyShapeStyle(Color.sheetSecondaryText))
        }
        guard let id = recorded[index], let payment = store.transaction(id: id) else {
            return (String(starhash: "Part dialled"), AnyShapeStyle(Color.sheetSecondaryText))
        }
        switch payment.status {
        case .pending: return (String(starhash: "Waiting for SMS"), AnyShapeStyle(Color.starhashUrgentText))
        case .confirmed: return (String(starhash: "Confirmed"), AnyShapeStyle(Color.starhashConfirmedText))
        case .failed: return (String(starhash: "Failed"), AnyShapeStyle(Color.starhashDestructive))
        }
    }

    // MARK: Debug

    #if DEBUG
    /// -paySplitDialled <n>: the first n parts recorded as dialled, without
    /// dialling, and -paySplitConfirmed the first of them confirmed, for
    /// screenshots of the sheet partway through.
    private func applyDebugLaunch() {
        guard dialled == 0, let count = DebugLaunch.value(after: "-paySplitDialled").flatMap(Int.init) else { return }
        for index in 0..<min(count, parts.count) {
            let split = StarHashKit.Transaction.Split(id: request.id, part: index + 1, count: parts.count, total: request.plan.amount)
            if let id = recordPart(parts[index], split) { recorded[index] = id }
        }
        dialled = min(count, parts.count)
        if DebugLaunch.arguments.contains("-paySplitConfirmed"), let first = recorded[0] {
            store.confirmByHand(first, fallback: request.wallet)
        }
    }
    #endif
}
