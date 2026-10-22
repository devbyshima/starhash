import StarHashKit
import SwiftUI

/// The full-width primary capsule: "Pay", "Continue", "Get Started". After
/// Beam's: a gradient fill, with a soft glow of the same colour under it on
/// onboarding only (`.starhashPrimaryGlowing`); everywhere else it is flat.
/// The accent green with near-black words on every page, Pay's included.
/// The label is 18pt semibold, as measured in the reference.
struct PrimaryButtonStyle: ButtonStyle {
    /// The design height; the paywall's button is taller than the others.
    var height: CGFloat = StarHashMetrics.primaryButtonHeight
    /// On Pay's page, which takes Pay's own tokens (the same colours).
    var onPay = false
    /// The glow under it, kept for onboarding's buttons.
    var glows = false

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, height: height, onPay: onPay, glows: glows)
    }
}

private struct PrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let height: CGFloat
    let onPay: Bool
    let glows: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.self) private var environment

    private var fill: Color {
        guard isEnabled else { return onPay ? .payWash : Color.starhashPrimaryText.color(in: environment).opacity(0.1) }
        return onPay ? .payButtonFill : Color.starhashInk.color(in: environment)
    }

    private var label: Color {
        guard isEnabled else { return onPay ? .paySecondaryText : Color.starhashSecondaryText.color(in: environment) }
        return onPay ? .payButtonLabel : Color.starhashOnInk.color(in: environment)
    }

    var body: some View {
        configuration.label
            .starhashFont(18, weight: .semibold, relativeTo: .body)
            .foregroundStyle(label)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            // The design height, growing only when a large text size makes
            // the label wrap, so the label is never cut off.
            .frame(minHeight: height)
            .background(fill.gradient, in: Capsule())
            // The glow is the button's own colour, so it lifts off the page
            // in either appearance; a disabled button gets none.
            .shadow(color: glows && isEnabled ? fill.opacity(0.35) : .clear, radius: 7, y: 3)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
            .animation(.smooth(duration: 0.2), value: isEnabled)
            .starhashPressHaptic(configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var starhashPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }

    /// For Pay's page.
    static var starhashPrimaryOnPay: PrimaryButtonStyle { PrimaryButtonStyle(onPay: true) }

    /// With the glow under it: onboarding's buttons.
    static var starhashPrimaryGlowing: PrimaryButtonStyle { PrimaryButtonStyle(glows: true) }
}

/// An SF Symbol on a raised tile (the page's pale grey on a white card, a lifted
/// charcoal in dark mode), as in expense rows and the
/// onboarding sample rows.
struct SymbolTile: View {
    let symbol: String
    var size: CGFloat = 40
    var background: Color = .starhashCardRaised

    var body: some View {
        Image(symbol: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(Color.starhashPrimaryText)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// The doodles over the empty states, drawn for StarHash by
/// scripts/make_doodles.py, each with a light and a dark version.
enum EmptyDoodle: String {
    /// A hand holding up a near-blank receipt.
    case transactions = "EmptyTransactions"
    /// A hand holding a calendar page with nothing marked.
    case period = "EmptyPeriod"
    /// A hand holding up a magnifying glass.
    case search = "EmptySearch"
    /// A magnifying glass with a question mark in it.
    case results = "EmptyResults"
    /// A hand holding a phone, a number being typed.
    case matches = "EmptyMatches"
    /// A card with a big # and a + at its corner.
    case codes = "EmptyCodes"
}

/// Every empty state in StarHash, one look: a doodle in the accent and a
/// bold 20pt title under it, centred, with an optional action under them.
/// No line explaining it: the doodle and the title say enough.
struct EmptyStateView<Actions: View>: View {
    let doodle: EmptyDoodle
    let title: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            Image(doodle.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: 168, height: 168)
                .padding(.bottom, 12)
                .accessibilityHidden(true)
            Text(catalog: title)
                .starhashFont(20, weight: .bold)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            actions
                .padding(.top, 30)
        }
        .frame(maxWidth: 260)
        .accessibilityElement(children: .contain)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(doodle: EmptyDoodle, title: String) {
        self.init(doodle: doodle, title: title) { EmptyView() }
    }
}

// MARK: Outlined cards

/// A card drawn as a line, with nothing filled behind it, after the owner's
/// reference for a transaction's details: rows grouped by what they say,
/// a card to each group. Settings' groups are the same, with lines between
/// their rows.
struct OutlinedCardShape: ViewModifier {
    var padding = EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: StarHashMetrics.outlinedCardRadius, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(shape.strokeBorder(Color.starhashOutline, lineWidth: 1))
            .contentShape(shape)
    }
}

extension View {
    /// A card or tile of its own drawn as a line, as the outlined cards are,
    /// over the page's own colour rather than nothing, so it stays solid
    /// when lifted over others (a pinned code being moved).
    func starhashOutlinedTile(in shape: some InsettableShape) -> some View {
        background(Color.starhashBackground, in: shape)
            .overlay(shape.strokeBorder(Color.starhashOutline, lineWidth: 1))
            .starhashContainerSurface()
    }
}

extension View {
    /// This content in an outlined card: `OutlinedCardShape`.
    func starhashOutlinedCard(padding: EdgeInsets = EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)) -> some View {
        modifier(OutlinedCardShape(padding: padding))
    }
}

/// A row of an outlined card: the label on the left in the text colour,
/// the value on the right in the quieter one, as the reference's.
struct DetailRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(catalog: label)
                .starhashFont(17, relativeTo: .body)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            value
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}

extension DetailRow where Value == Text {
    /// A row with words for its value; `numeric` sets them as a number.
    init(_ label: String, _ value: String, numeric: Bool = false) {
        self.label = label
        self.value = Text(catalog: value)
            .font(numeric ? .starhashNumber(17, relativeTo: .body) : .starhash(.body, weight: .medium))
            .foregroundStyle(Color.starhashSecondaryText)
    }
}

/// A list of things to do in one filled card, after the owner's reference:
/// each row its icon, its words and a chevron, a line between rows from
/// where the words start.
struct ActionList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StarHashMetrics.outlinedCardRadius, style: .continuous)
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.starhashSeparator)
                            .frame(height: 1)
                            .padding(.leading, ActionRow.textInset)
                    }
                    row
                }
            }
        }
        .starhashContainer(.starhashCard, in: shape)
    }
}

/// One thing to do in an `ActionList`: its icon, its words and a chevron;
/// red, icon and words, when it deletes.
struct ActionRow: View {
    let title: String
    let symbol: String
    var isDestructive = false
    let action: () -> Void

    /// Where a row's words start, from the card's edge, so the lines
    /// between rows start there too.
    static let textInset: CGFloat = 56

    init(_ title: String, symbol: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Outline, as the reference's list draws its icons.
                Image(symbol: symbol, outline: true)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 24)
                    .padding(.leading, 16)
                    .padding(.trailing, Self.textInset - 16 - 24)
                Text(catalog: title)
                    .starhashFont(17, relativeTo: .body)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if !isDestructive {
                    Image(symbol: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.starhashTertiaryText)
                        .padding(.trailing, 16)
                }
            }
            .foregroundStyle(isDestructive ? AnyShapeStyle(Color.starhashDestructive) : AnyShapeStyle(Color.starhashPrimaryText))
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
    }
}
