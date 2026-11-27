import StarHashKit
import SwiftUI

/// Asked before what settles from the wallet's SMS while auto-verify is
/// off: Request (asking one person, Hold Near and Request in Bulk alike)
/// and Split large payments. Laid out as Turn Off Auto-verify's question,
/// its other half: Settings' icon for auto-verify on the sheet's chip, the
/// title, what auto-verify does for this, then Set Up Auto-verify, which
/// opens the setup, and Not Now.
struct AutoVerifyRequiredSheet: View {
    enum Feature: String, Identifiable {
        case requests
        case splitPayments

        var id: String { rawValue }
    }

    let feature: Feature
    /// Set Up Auto-verify: the setup opens once this sheet has gone.
    let onSetUp: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch feature {
        case .requests: "Requests Need Auto-verify"
        case .splitPayments: "Split Payments Need Auto-verify"
        }
    }

    private var points: [(symbol: String, text: String)] {
        switch feature {
        case .requests: [
            ("arrow.down.left", "A request is marked paid when your wallet's SMS shows the money came in"),
            ("hourglass", "Without it, every request waits until you mark it paid"),
        ]
        case .splitPayments: [
            ("banknote", "Each part is confirmed by its own SMS from your wallet"),
            ("hourglass", "Without it, every part would stay pending"),
        ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetOutcomeIcon(symbol: "checkmark.message.fill", glyph: Color.starhashPrimaryText, fill: .sheetChip)
            Text(catalog: title)
                .font(.sheet(26, .bold, relativeTo: .title2))
                .tracking(StarHashTracking.display(26))
                .foregroundStyle(Color.sheetBrandText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)

            SheetIconRows(rows: points)
                .padding(.top, 20)

            Spacer(minLength: 18)

            VStack(spacing: 4) {
                Button("Set Up Auto-verify") {
                    onSetUp()
                    dismiss()
                }
                .buttonStyle(.sheetPrimary)
                SheetTextButton("Not Now") { dismiss() }
            }
        }
        .padding(.horizontal, 18)
        // Sized to the question, as Turn Off Auto-verify's is; there is no
        // outcome to turn to.
        .outcomeSheet(settled: false) { EmptyView() }
    }
}
