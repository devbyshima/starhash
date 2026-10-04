import StarHashKit
import SwiftUI

/// The full-width primary capsule: "Pay", "Continue", "Get Started". After
/// Beam's: a gradient fill, with a soft glow of the same colour under it on
/// onboarding only (`.starhashPrimaryGlowing`); everywhere else it is flat.
/// The blue with near-black text on every page but light mode's Pay,
/// whose page is the blue already: there it turns over, near black with
/// blue text, as the palette pairs them. The label is 18pt semibold, as
/// measured in the reference.
struct PrimaryButtonStyle: ButtonStyle {
    /// The design height; the paywall's button is taller than the others.
    var height: CGFloat = StarHashMetrics.primaryButtonHeight
    /// On Pay's page, which is the blue in light mode.
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

    private var fill: Color {
        guard isEnabled else { return onPay ? .payWash : Color.starhashPrimaryText.opacity(0.1) }
        return onPay ? .payButtonFill : .starhashInk
    }

    private var label: Color {
        guard isEnabled else { return onPay ? .paySecondaryText : .starhashSecondaryText }
        return onPay ? .payButtonLabel : .starhashOnInk
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

    /// For Pay's page, the blue in light mode.
    static var starhashPrimaryOnPay: PrimaryButtonStyle { PrimaryButtonStyle(onPay: true) }

    /// With the glow under it: onboarding's buttons.
    static var starhashPrimaryGlowing: PrimaryButtonStyle { PrimaryButtonStyle(glows: true) }
}

/// An SF Symbol on a raised tile (pale grey on a white card, a lifted
/// charcoal in dark mode), as in expense rows and the
/// onboarding sample rows.
struct SymbolTile: View {
    let symbol: String
    var size: CGFloat = 40
    var background: Color = .starhashCardRaised

    var body: some View {
        Image(systemName: symbol)
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

/// Every empty state in StarHash, one look: a doodle, a bold title and a
/// line under it, all 20pt and centred, after the reference's Home ("No
/// Account", "No Expenses"), with an optional action under them.
struct EmptyStateView<Actions: View>: View {
    let doodle: EmptyDoodle
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            Image(doodle.rawValue)
                .resizable()
                .scaledToFit()
                .frame(width: 168, height: 168)
                .padding(.bottom, 12)
                .accessibilityHidden(true)
            Text(title)
                .starhashFont(20, weight: .bold)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .starhashFont(20)
                .foregroundStyle(Color.starhashSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 3)
                .fixedSize(horizontal: false, vertical: true)
            actions
                .padding(.top, 30)
        }
        .frame(maxWidth: 260)
        .accessibilityElement(children: .contain)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(doodle: EmptyDoodle, title: String, message: String) {
        self.init(doodle: doodle, title: title, message: message) { EmptyView() }
    }
}
