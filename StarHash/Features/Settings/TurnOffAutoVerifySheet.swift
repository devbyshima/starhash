import StarHashKit
import SwiftUI

/// Asks before auto-verify goes off, in Beam's sheet language and sized to
/// its content: the question as the title, a card of the three things
/// that stop working, then Keep On (the filled button, the safe choice)
/// and Turn Off in red under it. Turn Off plays the sheet's Distortion
/// Wave in red into its outcome, with Done.
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
            onDone: { dismiss() }
        )
    }

    private var question: some View {
        VStack(spacing: 0) {
            SheetHeader("Turn Off Auto-verify?")

            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    ForEach(Array(losses.enumerated()), id: \.offset) { index, loss in
                        if index > 0 { SheetDivider().padding(.leading, 52) }
                        HStack(spacing: 14) {
                            SheetIconCircle(symbol: loss.symbol)
                            Text(catalog: loss.text)
                                .font(.sheetBody)
                                .foregroundStyle(Color.starhashPrimaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 16)
                .sheetCard()

                VStack(spacing: 4) {
                    // The sheets' one button colour, as Buy's sheets have.
                    Button("Keep On") { dismiss() }
                        .buttonStyle(.sheetPrimary)
                    SheetTextButton("Turn Off", role: .destructive) { turnOff() }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
        }
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
