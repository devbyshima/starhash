import SwiftUI

/// Onboarding's photo step, after the number: the owner's photo, shown to
/// whoever scans their code. A tap on the circle picks one from the
/// library; Continue moves on with or without it, as the number step does,
/// and Profile can add or change it later.
///
/// Laid out as the number step, so nothing jumps between them: the photo in
/// its pulse rings, the words low, Continue 10 points over the bottom, and
/// the glow at the bottom edge.
struct OnboardingPhotoPage: View {
    let onDone: () -> Void

    private var tint: Color { OnboardingPalette.tint }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ZStack {
                OnboardingPulseRings(tint: tint)
                ProfilePhotoPicker(size: 140)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Text("Your photo")
                    .starhashFont(22, weight: .bold, relativeTo: .title2)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                Text("Friends who scan your code see it\nbeside your number, so they know it's you.")
                    .font(.starhash(.callout))
                    .foregroundStyle(Color.starhashSecondaryText)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, 22)

            Button("Continue", action: onDone)
                .buttonStyle(.starhashPrimaryGlowing)
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onboardingGlow(tint)
    }
}
