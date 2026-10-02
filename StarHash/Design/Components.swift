import StarHashKit
import SwiftUI

/// The full-width primary capsule: "Pay", "Continue", "Get Started". After
/// Beam's: a gradient in the main wallet's colour (MTN yellow or Airtel
/// red) with a soft glow of the same colour under it, and ink until a
/// wallet is chosen. The label is 18pt semibold, as measured in the
/// reference.
struct PrimaryButtonStyle: ButtonStyle {
    /// Where the fill comes from.
    enum Tint {
        /// The main wallet's colour, or ink while none is chosen.
        case mainWallet
        /// This wallet's colour, or ink for nil (onboarding's wallet page,
        /// before the choice is saved).
        case wallet(Recipient.Network?)
    }

    /// The design height; the paywall's button is taller than the others.
    var height: CGFloat = StarHashMetrics.primaryButtonHeight
    var tint: Tint = .mainWallet

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, height: height, tint: tint)
    }
}

private struct PrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let height: CGFloat
    let tint: PrimaryButtonStyle.Tint

    @AppStorage(PreferenceKey.wallet) private var mainWallet = ""
    @Environment(\.isEnabled) private var isEnabled

    private var wallet: Recipient.Network? {
        switch tint {
        case .mainWallet: Recipient.Network(rawValue: mainWallet)
        case .wallet(let wallet): wallet
        }
    }

    private var fill: Color {
        guard isEnabled else { return Color.starhashInk.opacity(0.14) }
        return wallet?.buttonFill ?? .starhashInk
    }

    private var label: Color {
        guard isEnabled else { return .starhashSecondaryText }
        return wallet?.buttonLabel ?? .starhashOnInk
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
            // in either appearance; ink and disabled buttons get none.
            .shadow(color: isEnabled && wallet != nil ? fill.opacity(0.35) : .clear, radius: 7, y: 3)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
            .animation(.smooth(duration: 0.25), value: wallet)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var starhashPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }

    /// In `wallet`'s colour rather than the main wallet's.
    static func starhashPrimary(wallet: Recipient.Network?) -> PrimaryButtonStyle {
        PrimaryButtonStyle(tint: .wallet(wallet))
    }
}

extension Recipient.Network {
    /// The primary button's fill and label on this wallet.
    var buttonFill: Color {
        switch self {
        case .mtn: .starhashMTN
        case .airtel: .starhashAirtel
        }
    }

    var buttonLabel: Color {
        switch self {
        case .mtn: .starhashOnMTN
        case .airtel: .starhashOnAirtel
        }
    }
}

/// An SF Symbol on a rounded dark tile, as in expense rows and the
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

/// Centred symbol, title, message and optional action for empty screens.
/// `.large` is Home's version ("No Account", "No Expenses"): a bigger grey
/// symbol and 20pt text, measured from the reference.
struct EmptyStateView<Actions: View>: View {
    enum Style { case regular, large }

    let symbol: String
    let title: String
    let message: String
    var style: Style = .regular
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: symbol)
                .starhashFont(style == .large ? 40 : 28)
                .foregroundStyle(style == .large ? Color.starhashMutedIcon : Color.starhashPrimaryText)
                .padding(.bottom, style == .large ? 21 : 14)
                .accessibilityHidden(true)
            Text(title)
                .starhashFont(style == .large ? 20 : 17, weight: .bold)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
            Text(message)
                .starhashFont(style == .large ? 20 : 15)
                .foregroundStyle(Color.starhashSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, style == .large ? 3 : 4)
                .fixedSize(horizontal: false, vertical: true)
            actions
                .padding(.top, style == .large ? 30 : 16)
        }
        .frame(maxWidth: style == .large ? 260 : 280)
        .accessibilityElement(children: .contain)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(symbol: String, title: String, message: String, style: Style = .regular) {
        self.init(symbol: symbol, title: title, message: message, style: style) { EmptyView() }
    }
}
