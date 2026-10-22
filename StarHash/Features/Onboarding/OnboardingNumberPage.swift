import StarHashKit
import SwiftUI

/// Onboarding's number step, after the wallet: the owner's name and wallet
/// number, for the QR code others scan to pay them (Settings' Profile keeps
/// them after). Dialling never needs the number, since the call goes out
/// from the SIM in the phone, so it can wait: Continue moves on with or
/// without it.
///
/// Laid out exactly as the wallet step, so nothing jumps between them: a
/// symbol in its pulse rings, the words low, the fields and Continue under
/// them, Continue 10 points over the bottom, and the glow at the bottom
/// edge.
struct OnboardingNumberPage: View {
    let onDone: () -> Void

    @AppStorage(PreferenceKey.profileName) private var name = ""
    @AppStorage(PreferenceKey.profileNumber) private var number = ""
    @FocusState private var typing: Bool

    private var tint: Color { OnboardingPalette.tint }
    private var hasNumber: Bool { Recipient.ownNumber(number) != nil }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ZStack {
                OnboardingPulseRings(tint: tint)
                Image(symbol: hasNumber ? "qrcode" : "person.crop.circle.fill")
                    .font(.system(size: 72, weight: .medium))
                    .foregroundStyle(tint.gradient)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(height: OnboardingMetrics.iconSize)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                // Rising word by word as the screen before leaves.
                RevealText(String(localized: "Your number"), delay: RevealTiming.enterDelay)
                    .starhashFont(22, weight: .bold, relativeTo: .title2)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                RevealText(
                    String(localized: "It goes in your own QR code, so friends\nscan it to pay you. It stays on your iPhone."),
                    startIndex: RevealText.wordCount(String(localized: "Your number")),
                    delay: RevealTiming.enterDelay
                )
                    .font(.starhash(.callout))
                    .foregroundStyle(Color.starhashSecondaryText)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, 22)

            VStack(spacing: 12) {
                ProfileFields(name: $name, number: $number)
                Button("Continue", action: onDone)
                    .buttonStyle(.starhashPrimaryGlowing)
                    .padding(.top, 8)
            }
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onboardingGlow(tint)
        .animation(.smooth(duration: 0.3), value: hasNumber)
        .contentShape(Rectangle())
        .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}
