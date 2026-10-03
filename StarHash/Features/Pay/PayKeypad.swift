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
            .foregroundStyle(amount == 0 ? Color.payPlaceholderText : Color.payPrimaryText)
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
/// As in the reference "SIP, send money": a held key swells into a white
/// bubble over its digit; as it lifts the digit flashes back in the accent
/// and the bubble melts into a frosted blob that runs down behind the pad,
/// a puff of the accent at its top, lingering for seconds
/// (`PayEffects.swift`). With Reduce Motion, a faint disc behind a held key
/// instead.
struct PayKeypad: View {
    /// Called with every key; the caller applies it to its `AmountInput`
    /// and says whether anything changed.
    let onKey: (AmountInput.Key) -> Bool
    var canClear: Bool
    /// The accent the ink puffs and the digits flash in.
    var tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Bumped on every accepted key, so one light tap plays per press.
    @State private var accepted = 0
    /// Bumped when a key changes nothing (past the ceiling, delete at zero).
    @State private var refused = 0
    /// The ink of recent presses, in the ink layer's space.
    @State private var drops: [InkDrop] = []
    /// The key whose digit is still in the accent after its press.
    @State private var tintedKey: AmountInput.Key?
    @State private var size: CGSize = .zero

    /// How far the ink may spread past the pad's edges.
    private let bleed: CGFloat = 90

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
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .background {
            PayInkLayer(drops: drops, tint: tint, radius: bubbleSize / 2)
                .padding(-bleed)
        }
        // Clears the ink once the last blob has thinned away, so the
        // shader stops drawing.
        .task(id: drops.last?.id) {
            guard !drops.isEmpty else { return }
            try? await Task.sleep(for: .seconds(InkDrop.lifetime))
            drops.removeAll { Date.now.timeIntervalSince($0.start) >= InkDrop.lifetime }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: accepted)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.4), trigger: refused)
        #if DEBUG
        .task {
            guard PayDebug.pressesKeys else { return }
            try? await Task.sleep(for: .seconds(1.5))
            for digit in [8, 5, 3, 7] {
                press(.digit(digit))
                try? await Task.sleep(for: .seconds(0.9))
            }
        }
        #endif
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
        .buttonStyle(KeypadKeyStyle(
            bubbleSize: bubbleSize,
            // The grey the shader's blob starts from on black.
            bubbleFill: .payKeyBubble,
            reduceMotion: reduceMotion
        ))
    }

    /// Nearly a row tall, as in the reference.
    private var bubbleSize: CGFloat {
        guard size.height > 0 else { return 64 }
        return min(size.height / 4 * 0.92, 76)
    }

    private func press(_ key: AmountInput.Key) {
        if onKey(key) { accepted += 1 } else { refused += 1 }
        guard !reduceMotion, size != .zero else { return }
        // The bubble melts into ink as the key lifts; a dozen blobs at a
        // time is plenty, and keeps the shader's work small.
        let now = Date.now
        drops.removeAll { now.timeIntervalSince($0.start) >= InkDrop.lifetime }
        drops.append(InkDrop(point: center(of: key), start: now))
        if drops.count > 12 { drops.removeFirst(drops.count - 12) }
        // The digit flashes back in the accent, then straight to ink.
        tintedKey = key
        withAnimation(.easeOut(duration: 0.08).delay(0.04)) { tintedKey = nil }
    }

    /// A key's centre in the ink layer's space: the pad is a 3 by 4 grid of
    /// equal cells, and the layer reaches `bleed` past its edges.
    private func center(of key: AmountInput.Key) -> CGPoint {
        let (row, column): (Int, Int) = switch key {
        case .digit(0): (3, 1)
        case .digit(let digit): ((digit - 1) / 3, (digit - 1) % 3)
        case .clear: (3, 0)
        case .delete: (3, 2)
        }
        let cell = CGSize(width: size.width / 3, height: size.height / 4)
        return CGPoint(
            x: bleed + (CGFloat(column) + 0.5) * cell.width,
            y: bleed + (CGFloat(row) + 0.5) * cell.height
        )
    }
}

/// A held key: the white bubble swelling over its digit, which hides under
/// it. With Reduce Motion, a faint disc behind the digit and a slight
/// shrink instead.
private struct KeypadKeyStyle: ButtonStyle {
    let bubbleSize: CGFloat
    let bubbleFill: Color
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        if reduceMotion {
            configuration.label
                .background {
                    Circle()
                        .fill(Color.payWash.opacity(configuration.isPressed ? 1 : 0))
                        .frame(width: 76, height: 76)
                }
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .animation(.snappy(duration: 0.15), value: configuration.isPressed)
        } else {
            configuration.label
                .opacity(configuration.isPressed ? 0 : 1)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .overlay {
                    KeyBubble(isPressed: configuration.isPressed, size: bubbleSize, fill: bubbleFill)
                }
        }
    }
}
