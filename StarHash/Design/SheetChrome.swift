import SwiftUI

// The pieces pages and cards in StarHash are built from (sheets use
// SheetKit). Feature folders use these rather than their own copies, so a
// round glass button or a hairline looks and behaves the same everywhere.

/// A round glass icon button: close, back, add, confirm.
///
/// `xmark` is drawn grey and medium weight, like the reference; every other
/// glyph is ink-coloured and semibold.
///
/// On iOS 26 and later the glyph is at the large symbol scale, as the
/// system draws toolbar buttons and as the reference's round header buttons
/// measure (the close glyph 52 pixels across, where the medium scale gave
/// 41). Earlier systems keep the medium scale.
struct StarHashCircleButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    init(_ symbol: String, label: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            StarHashCircleGlyph(symbol: symbol)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        // A checkmark glyph would otherwise make VoiceOver say "selected".
        .accessibilityRemoveTraits(.isSelected)
    }
}

/// The look of `StarHashCircleButton`, for controls that bring their own
/// action, such as a `ShareLink`.
struct StarHashCircleGlyph: View {
    let symbol: String

    private var isClose: Bool { symbol == "xmark" }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: isClose ? .medium : .semibold))
            .starhashHeaderGlyphScale()
            .foregroundStyle(isClose ? Color.starhashCloseGlyph : Color.starhashPrimaryText)
            .starhashCircleButton()
    }
}

/// A card holding rows. Rows inside are separated with
/// `StarHashRowSeparator`.
struct StarHashCard<Content: View>: View {
    var fill: Color = .starhashCard
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .starhashSurface(.card)
            .background(fill, in: RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
    }
}

/// The hairline between rows of a card, starting where the row text starts.
/// With `overlapsRows` it is drawn across the boundary between the rows
/// instead of adding its own height between them. `thickness`, when given,
/// replaces the usual one in both appearances.
struct StarHashRowSeparator: View {
    var leading: CGFloat = 16
    var trailing: CGFloat = 16
    var overlapsRows = false
    var thickness: CGFloat?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Measured from the reference: a hairline on black, a full point on
        // white, where half a point at 10% black all but vanishes.
        let thickness: CGFloat = thickness ?? (colorScheme == .light ? 1 : 0.5)
        Rectangle()
            .fill(Color.starhashSeparator)
            .frame(height: thickness)
            .padding(.vertical, overlapsRows ? -thickness / 2 : 0)
            .padding(.leading, leading)
            .padding(.trailing, trailing)
            .accessibilityHidden(true)
    }
}

/// A tappable card row that highlights while pressed, like a list cell.
struct HighlightRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.starhashPrimaryText.opacity(configuration.isPressed ? 0.06 : 0))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// The small ink capsule ("Add Account", "Upgrade"). Drawn at `height`
/// but always at least 44pt tall to tap.
struct StarHashCapsuleButtonStyle: ButtonStyle {
    var height: CGFloat = 36
    var horizontalPadding: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.starhash(.body, weight: .semibold))
            .foregroundStyle(Color.starhashOnInk)
            .multilineTextAlignment(.center)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 6)
            .frame(minHeight: height)
            // A capsule at the design height; a rounded card, not a clipped
            // pill, when a large text size wraps the label.
            .background(RoundedRectangle(cornerRadius: height / 2, style: .continuous).fill(Color.starhashInk))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == StarHashCapsuleButtonStyle {
    static func starhashCapsule(height: CGFloat, horizontalPadding: CGFloat = 12) -> StarHashCapsuleButtonStyle {
        StarHashCapsuleButtonStyle(height: height, horizontalPadding: horizontalPadding)
    }
}

/// How round header buttons size their glyphs. From iOS 26, where the
/// system's own toolbar buttons use the large symbol scale, the reference's
/// custom ones match them.
private enum HeaderGlyph {
    static var usesToolbarSize: Bool {
        if #available(iOS 26.0, *) { true } else { false }
    }
}

private extension View {
    /// The large symbol scale on iOS 26 and later; unchanged before.
    @ViewBuilder
    func starhashHeaderGlyphScale() -> some View {
        if HeaderGlyph.usesToolbarSize {
            imageScale(.large)
        } else {
            self
        }
    }
}

/// A slight shrink while pressed, for controls that draw their own shape.
struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
