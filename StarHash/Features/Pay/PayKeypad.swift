import StarHashKit
import SwiftUI

/// Pay's amount: the number alone, very large and bold, the digits rolling
/// as they change. Zero is drawn grey, so an empty amount reads as a
/// placeholder rather than a value. The currency is its own pill, above
/// the keypad (`PayCurrencyPill`).
struct PayAmountDisplay: View {
    let amount: Int

    var body: some View {
        Text(Money.format(amount))
            .starhashFont(96, weight: .bold, design: .rounded, relativeTo: .largeTitle)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(amount)))
            .foregroundStyle(amount == 0 ? Color.starhashTertiaryText : Color.starhashPrimaryText)
            .lineLimit(1)
            // "10,000,000" at the largest text sizes still fits one line.
            .minimumScaleFactor(0.3)
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Money.formatWithCurrency(amount))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// The currency in a soft pill just above the keypad, apart from the
/// amount as a payment app shows it: Rwanda's flag while nothing is typed,
/// "RWF" once there is an amount. Only one currency, so nothing to pick.
struct PayCurrencyPill: View {
    /// Nothing typed yet: the flag rather than the code.
    let isEmpty: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isEmpty {
                Text("\u{1F1F7}\u{1F1FC}")
                    .starhashFont(21, relativeTo: .subheadline)
                    .transition(transition)
            } else {
                Text(Money.currency)
                    .starhashFont(15, weight: .semibold, relativeTo: .subheadline)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .transition(transition)
            }
        }
        .padding(.horizontal, 16)
        // One height for both, so the pill does not jump as it switches.
        .frame(minWidth: 72, minHeight: 36)
        .background(Color.starhashPrimaryText.opacity(0.08), in: Capsule())
        .animation(.smooth(duration: 0.25), value: isEmpty)
        // The amount already reads out with its currency.
        .accessibilityHidden(true)
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity)
    }
}

/// The 3 by 4 number pad under the currency, across the full width: 1 to
/// 9, then Clear (a muted "." while there is nothing to clear), 0 and
/// delete ("<"). No keycaps, like a phone's
/// dialler on a plain canvas; a key only shows a soft disc while pressed.
struct PayKeypad: View {
    /// Called with every key; the caller applies it to its `AmountInput`
    /// and says whether anything changed.
    let onKey: (AmountInput.Key) -> Bool
    var canClear: Bool

    /// Bumped on every accepted key, so one light tap plays per press.
    @State private var accepted = 0
    /// Bumped when a key changes nothing (past the ceiling, delete at zero).
    @State private var refused = 0

    private let rows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { digit in
                        key(.digit(digit)) {
                            Text(String(digit))
                                .starhashFont(26, weight: .semibold, relativeTo: .title2)
                        }
                        .accessibilityLabel(String(digit))
                    }
                }
            }
            GridRow {
                key(.clear) {
                    // A "." holds the place, as on a phone's keypad, until
                    // there is something to clear. Amounts are whole
                    // francs, so it is never a decimal point.
                    if canClear {
                        Text("Clear")
                            .starhashFont(17, weight: .medium, relativeTo: .body)
                    } else {
                        Text(".")
                            .starhashFont(30, weight: .semibold, relativeTo: .title2)
                            .foregroundStyle(Color.starhashSecondaryText)
                            // Up from the baseline to sit level with the digits.
                            .offset(y: -6)
                    }
                }
                .disabled(!canClear)
                .accessibilityLabel("Clear")
                .accessibilityHidden(!canClear)
                key(.digit(0)) {
                    Text("0")
                        .starhashFont(26, weight: .semibold, relativeTo: .title2)
                }
                .accessibilityLabel("0")
                key(.delete) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                }
                .accessibilityLabel("Delete")
                // Holding delete clears the lot, as on the system keypad.
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    press(.clear)
                })
            }
        }
        .foregroundStyle(Color.starhashPrimaryText)
        .sensoryFeedback(.impact(weight: .light), trigger: accepted)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.4), trigger: refused)
    }

    private func key(_ key: AmountInput.Key, @ViewBuilder label: () -> some View) -> some View {
        Button {
            press(key)
        } label: {
            label()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
        }
        .buttonStyle(KeypadKeyStyle())
    }

    private func press(_ key: AmountInput.Key) {
        if onKey(key) { accepted += 1 } else { refused += 1 }
    }
}

/// A faint disc behind the key while it is held, and a slight shrink.
private struct KeypadKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle()
                    .fill(Color.starhashInk.opacity(configuration.isPressed ? 0.08 : 0))
                    .frame(width: 76, height: 76)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
