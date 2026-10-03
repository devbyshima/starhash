import SwiftUI

/// The header's round glass buttons, the same as the wallet switcher on
/// Pay.
struct SwapGlassButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            // Keyed by the symbol, so a change (close to back and back again)
            // swaps one glyph for the other: the old one shrinks, blurs and
            // fades as the new one grows into focus.
            ZStack {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.starhashPrimaryText)
                    .id(symbol)
                    .transition(reduceMotion ? .opacity : .glyphSwap)
            }
            .starhashCircleButton()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A glyph coming in from small, soft and clear, or going out the same way.
private struct GlyphSwap: ViewModifier {
    var progress: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 - 0.45 * progress)
            .blur(radius: 5 * progress)
            .opacity(1 - progress)
    }
}

private extension AnyTransition {
    static var glyphSwap: AnyTransition {
        .modifier(active: GlyphSwap(progress: 1), identity: GlyphSwap(progress: 0))
    }
}
