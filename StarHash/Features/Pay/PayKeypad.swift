import StarHashKit
import SwiftUI

/// Pay's amount: the number alone, very large and bold, the digits rolling
/// as they change. Zero is drawn grey, so an empty amount reads as a
/// placeholder rather than a value. The currency is its own pill, above
/// the keypad (`PayCurrencyPill`).
struct PayAmountDisplay: View {
    let amount: Int
    /// Bumped each time Pay is tapped with nothing typed: the amount shakes
    /// from side to side, as the reference's does.
    var shakes = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The shake's tap, played on its widest swing, and the wait for it.
    @State private var beats = 0
    @State private var beat: Task<Void, Never>?

    var body: some View {
        // A copy the keyframes' closure can take with it.
        let reduceMotion = reduceMotion
        Text(Money.format(amount))
            .starhashFont(96, weight: .bold, design: .rounded, relativeTo: .largeTitle, tracking: 0)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(amount)))
            .foregroundStyle(amount == 0 ? Color.payPlaceholderText : Color.payPrimaryText)
            .lineLimit(1)
            // "10,000,000" at the largest text sizes still fits one line.
            .minimumScaleFactor(0.3)
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .keyframeAnimator(initialValue: Shake(), trigger: shakes) { content, shake in
                // With Reduce Motion it dims and comes back instead.
                content
                    .offset(x: reduceMotion ? 0 : shake.x)
                    .opacity(reduceMotion ? 1 - shake.dim : 1)
            } keyframes: { _ in
                KeyframeTrack(\.x) {
                    for x in Shake.offsets {
                        CubicKeyframe(x, duration: 1.0 / 60)
                    }
                }
                KeyframeTrack(\.dim) {
                    CubicKeyframe(0.6, duration: 0.08)
                    CubicKeyframe(0, duration: 0.28)
                }
            }
            // The second beat of the heartbeat (Pay's press is the first):
            // a softer tap as the amount swings widest, so the two beats
            // span the shake. Another tap before it lands starts over.
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.4), trigger: beats)
            .onChange(of: shakes) {
                beat?.cancel()
                beat = Task {
                    try? await Task.sleep(for: Shake.widestSwing)
                    if !Task.isCancelled { beats += 1 }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Money.formatWithCurrency(amount))
            .accessibilityAddTraits(.updatesFrequently)
    }

    private struct Shake {
        var x: CGFloat = 0
        var dim: Double = 0

        /// Where the amount is, in points, every 60th of a second of the
        /// shake: measured frame by frame from the reference recording (the
        /// mean of its three shakes, at 3 pixels to the point). Three
        /// swings that widen, then a quick ring down, 0.37s in all.
        static let offsets: [CGFloat] = [
            0.87, 5.61, 11.45, 12.80, 3.12, -10.03, -15.85, -4.94, 10.90, 17.62, 9.69,
            0.16, -4.56, -3.85, -0.42, 0.86, 0.99, 0.16, -0.26, -0.32, -0.18, 0,
        ]

        /// When the shake reaches its widest swing, the third: frame n of
        /// `offsets` lands (n + 1) 60ths of a second in.
        static let widestSwing: Duration = {
            let frame = offsets.indices.max { abs(offsets[$0]) < abs(offsets[$1]) } ?? 0
            return .seconds(Double(frame + 1) / 60)
        }()
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
                    // Full strength: on the pill's wash the quieter tone
                    // falls under 4.5:1.
                    .foregroundStyle(Color.payPrimaryText)
                    .transition(transition)
            }
        }
        .padding(.horizontal, 16)
        // One height for both, so the pill does not jump as it switches.
        .frame(minWidth: 72, minHeight: 36)
        .background(Color.payWash, in: Capsule())
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
/// delete ("<"). No keycaps, like a phone's dialler on a plain canvas.
///
/// A held key's digit dims, with nothing drawn around it; as it lifts the
/// digit flashes back in the accent (not with Reduce Motion).
struct PayKeypad: View {
    /// Called with every key; the caller applies it to its `AmountInput`
    /// and says whether anything changed.
    let onKey: (AmountInput.Key) -> Bool
    var canClear: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Bumped on every accepted key, so one light tap plays per press.
    @State private var accepted = 0
    /// Bumped when a key changes nothing (past the ceiling, delete at zero).
    @State private var refused = 0
    /// The key whose digit is still in the accent after its press.
    @State private var tintedKey: AmountInput.Key?

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
                            .foregroundStyle(Color.paySecondaryText)
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
        .foregroundStyle(Color.payPrimaryText)
        .sensoryFeedback(.impact(weight: .light), trigger: accepted)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.4), trigger: refused)
    }

    private func key(_ key: AmountInput.Key, @ViewBuilder label: () -> some View) -> some View {
        Button {
            press(key)
        } label: {
            label()
                // The flash is the accent a little faded, as in the reference.
                .foregroundStyle(tintedKey == key ? AnyShapeStyle(Color.payKeypadFlash.opacity(0.75)) : AnyShapeStyle(Color.payPrimaryText))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
        }
        .buttonStyle(KeypadKeyStyle())
    }

    private func press(_ key: AmountInput.Key) {
        if onKey(key) { accepted += 1 } else { refused += 1 }
        guard !reduceMotion else { return }
        // The digit flashes back in the accent, then to its own colour.
        tintedKey = key
        withAnimation(.easeOut(duration: 0.08).delay(0.04)) { tintedKey = nil }
    }
}

/// A held key: its digit dims, with no disc or bubble around it.
private struct KeypadKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.35 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
