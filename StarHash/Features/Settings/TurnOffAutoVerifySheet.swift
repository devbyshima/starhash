import StarHashKit
import SwiftUI

/// Asks before auto-verify goes off, in Beam's sheet language: auto-verify's
/// icon where the outcome's comes, the question, a card of the three things
/// that stop working, then Keep On (the filled button, the safe choice) and
/// Turn Off in red under it, at the foot. Turn Off plays the sheet's
/// Distortion Wave in red from the icon into its outcome: the icon turns
/// red, Turned off and how to turn it on again over the same card, and
/// Done where the buttons were.
struct TurnOffAutoVerifySheet: View {
    let onTurnOff: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOff = false

    private let losses: [(symbol: String, text: String)] = [
        ("hourglass", "Payments won't be confirmed"),
        ("arrow.down.left", "Money received won't be logged"),
        ("banknote", "Fees and balance won't fill in"),
    ]

    var body: some View {
        Group {
            if isOff {
                outcome
            } else {
                question
            }
        }
        .outcomeSheet(settled: isOff) { outcome }
    }

    private var outcome: some View {
        SheetOutcome(
            symbol: "xmark",
            tint: .waveFailed,
            label: String(starhash: "Turned off"),
            title: String(starhash: "Auto-verify"),
            detail: String(starhash: "Turn it on again any time in Settings."),
            points: losses,
            titleIsFigure: false,
            onDone: { dismiss() }
        )
    }

    private var question: some View {
        VStack(spacing: 0) {
            // Settings' own icon for auto-verify, on the sheet's chip.
            SheetOutcomeIcon(symbol: "checkmark.message.fill", glyph: Color.starhashPrimaryText, fill: .sheetChip)
            Text(catalog: "Turn Off Auto-verify?")
                .font(.sheet(26, .bold, relativeTo: .title2))
                .tracking(StarHashTracking.display(26))
                .foregroundStyle(Color.sheetBrandText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .accessibilityAddTraits(.isHeader)

            SheetIconRows(rows: losses)
                .padding(.top, 20)

            // At the foot, where Done comes.
            Spacer(minLength: 18)

            VStack(spacing: 4) {
                // The sheets' one button colour, as Buy's sheets have.
                Button("Keep On") { dismiss() }
                    .buttonStyle(.sheetPrimary)
                SheetTextButton("Turn Off", role: .destructive) { turnOff() }
            }
        }
        .padding(.horizontal, 18)
    }

    private func turnOff() {
        onTurnOff()
        SheetOutcome.reveal(
            tint: .waveFailed,
            dark: colorScheme == .dark,
            reduceMotion: reduceMotion,
            feel: .warning,
            show: { isOff = true }
        )
    }
}
