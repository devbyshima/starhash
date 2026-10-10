import StarHashKit
import SwiftUI

/// Onboarding's number step, after the wallet: the owner's name and wallet
/// number, for the QR code others scan to pay them (Settings' Profile keeps
/// them after). Dialling never needs the number, since the call goes out
/// from the SIM in the phone, so it can wait: Maybe Later moves on without
/// it.
///
/// Laid out as the wallet step: a symbol in its pulse rings, the words low,
/// the fields and Continue under them, and the glow at the bottom edge.
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
                Image(systemName: hasNumber ? "qrcode" : "person.crop.circle.fill")
                    .font(.system(size: 72, weight: .medium))
                    .foregroundStyle(tint.gradient)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(height: OnboardingMetrics.iconSize)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Text("Your number")
                    .starhashFont(22, weight: .bold, relativeTo: .title2)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                Text("It goes in your own QR code, so friends\nscan it to pay you. It stays on your iPhone.")
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
                    .disabled(!hasNumber)
                    .padding(.top, 8)
                Button(action: onDone) {
                    Text("Maybe Later")
                        .font(.starhash(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.starhashSecondaryText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.hapticPlain)
                .opacity(hasNumber ? 0 : 1)
                .disabled(hasNumber)
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
