import StarHashKit
import SwiftUI

/// Onboarding's question about the owner's wallet: MTN MoMo or Airtel
/// Money. It decides the codes StarHash dials and what Pay shows. (Their
/// number is asked for next, for their own QR code only: dialling never
/// needs it, since the call goes out from the SIM in the phone.)
///
/// Laid out as Beam's "find your Mac" step, so it reads as one of the reel's
/// family: the symbol in its pulse rings in the middle, the words low, the
/// choices (each with its carrier's logo) and Continue under them, and the
/// glow at the bottom edge. As a carrier is picked its logo takes the
/// symbol's place and the rings pulse round it: both the near black in
/// light mode, as the accent is on the blue, and the carrier's own colours
/// in dark. The choices keep their logos' colours in both.
///
/// Also shown on its own, to an install that finished onboarding before
/// this page existed.
struct OnboardingWalletPage: View {
    let onDone: () -> Void

    @AppStorage(PreferenceKey.wallet) private var wallet = ""
    @State private var choice: Recipient.Network?
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color { OnboardingPalette.tint }
    /// The rings: the accent until a carrier is chosen, then its ring colour.
    private var ringTint: Color { choice?.ringColor ?? tint }
    /// The chosen logo in the near black on the light page, matching its
    /// rings; nil keeps the carrier's colours on the dark one.
    private var logoInk: Color? { colorScheme == .light ? .white : nil }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ZStack {
                OnboardingPulseRings(tint: ringTint)
                    .animation(.smooth(duration: 0.4), value: choice)
                // The chosen carrier's logo in the rings; a SIM until then.
                Group {
                    if let choice {
                        WalletLogo(wallet: choice, height: 56, ink: logoInk)
                    } else {
                        Image(systemName: "simcard.fill")
                            .font(.system(size: 72, weight: .medium))
                            .foregroundStyle(tint.gradient)
                    }
                }
                .id(choice)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .frame(height: OnboardingMetrics.iconSize)
                .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Text("Your carrier")
                    .starhashFont(22, weight: .bold, relativeTo: .title2)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                Text("Which carrier do you pay with? StarHash\ndials its codes for you.")
                    .font(.starhash(.callout))
                    .foregroundStyle(Color.starhashSecondaryText)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, 22)

            VStack(spacing: 12) {
                ForEach(Recipient.Network.allCases, id: \.self) { network in
                    option(network)
                }
                Button("Continue", action: save)
                    .buttonStyle(.starhashPrimaryGlowing)
                    .disabled(choice == nil)
                    .padding(.top, 8)
            }
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onboardingGlow(tint)
        .animation(.smooth(duration: 0.3), value: choice)
        .onAppear {
            if choice == nil { choice = Recipient.Network(rawValue: wallet) }
        }
    }

    /// A glass capsule the height of the button below it, as Beam's
    /// secondary buttons are, ringed in the blue once chosen.
    private func option(_ network: Recipient.Network) -> some View {
        let isChosen = choice == network
        return Button {
            choice = network
        } label: {
            HStack(spacing: 12) {
                WalletLogo(wallet: network, height: 18)
                    .frame(width: 44)
                Text(network.walletName)
                    .font(.starhash(.headline))
                    .foregroundStyle(Color.starhashPrimaryText)
                Spacer(minLength: 8)
                Text(network.prefixList)
                    .font(.starhash(.footnote))
                    .foregroundStyle(Color.starhashSecondaryText)
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isChosen ? Color.starhashAccentText : Color.starhashSecondaryText)
                    .contentTransition(.symbolEffect(.replace))
            }
            .lineLimit(1)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: StarHashMetrics.primaryButtonHeight)
            .contentShape(Capsule())
            .starhashGlass(interactive: true)
            .overlay(Capsule().strokeBorder(Color.starhashAccentGraphic, lineWidth: 2).opacity(isChosen ? 1 : 0))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(network.walletName), \(network.prefixes)")
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func save() {
        guard let choice else { return }
        wallet = choice.rawValue
        onDone()
    }
}

extension Recipient.Network {
    /// The rings round the chosen logo on onboarding's carrier step: the
    /// near black in light mode, as the logo in them, and the carrier's own
    /// colour in dark. Everywhere else the carrier's colour lives only in
    /// its logo.
    var ringColor: Color {
        switch self {
        case .mtn: Color(light: .white, dark: .starhashMTN)
        case .airtel: Color(light: .white, dark: .starhashAirtel)
        }
    }

    /// A monogram, rather than the network's own logo.
    var symbol: String {
        switch self {
        case .mtn: "m.circle.fill"
        case .airtel: "a.circle.fill"
        }
    }

    /// Which numbers are on it, to tell the two apart at a glance.
    var prefixes: String {
        switch self {
        case .mtn: "Numbers starting 078 or 079"
        case .airtel: "Numbers starting 072 or 073"
        }
    }

    /// The same, short: "078 · 079".
    var prefixList: String {
        switch self {
        case .mtn: "078 \u{00B7} 079"
        case .airtel: "072 \u{00B7} 073"
        }
    }
}
