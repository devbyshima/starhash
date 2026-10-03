import SwiftUI

/// Onboarding's first screen, a port of Beam's `LoopOnBoarding`: a symbol
/// bouncing in time with three pulse rings, and the selling points pushing
/// up into place beneath it, one every 3 seconds, round and round until
/// Continue.
///
/// The symbol stays put and swaps in place while only the words move: it is
/// mid-bounce when the phase changes, and sliding it away would cut the
/// bounce short.
struct OnboardingReel: View {
    struct Phase: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let description: String
    }

    let phases: [Phase]
    let tint: Color
    let onContinue: () -> Void

    /// How long each phase holds. The bounce keyframes below are cut to fit
    /// it exactly (1.75s of movement, then 1.25s still), as are the rings.
    private let phaseDuration: TimeInterval = 3
    /// Room under the words for the button and its margin.
    private let buttonRoom: CGFloat = StarHashMetrics.primaryButtonHeight + 25

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date.now

    var body: some View {
        ZStack {
            TimelineView(.periodic(from: startDate, by: phaseDuration)) { context in
                let elapsed = startDate.distance(to: context.date)
                let index = max(0, Int(elapsed / phaseDuration)) % max(phases.count, 1)

                ZStack {
                    glyph(phases[index].symbol)
                        .padding(.bottom, 130)

                    ZStack {
                        ForEach(phases.indices, id: \.self) { phase in
                            if phase == index {
                                words(phases[phase])
                                    .transition(reduceMotion
                                        ? .opacity
                                        : .asymmetric(insertion: .push(from: .bottom), removal: .push(from: .bottom))
                                            .combined(with: AnyTransition(.blurReplace)))
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, buttonRoom)
                    .animation(reduceMotion ? .easeInOut(duration: 0.4) : .bouncy(duration: 0.8), value: index)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }

            OnboardingPulseRings(tint: tint)
                .padding(.bottom, 130)
        }
        .overlay(alignment: .bottom) {
            Button("Continue", action: onContinue)
                .buttonStyle(.starhashPrimaryGlowing)
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.bottom, 10)
        }
        .onboardingGlow(tint)
    }

    @ViewBuilder
    private func glyph(_ symbol: String) -> some View {
        let size = OnboardingMetrics.iconSize
        let image = Image(systemName: symbol)
            .font(.system(size: size - 20))
            .foregroundStyle(tint.gradient)
            // One phase's symbol becomes the next instead of cutting to it.
            .contentTransition(.symbolEffect(.replace.downUp))
            .frame(width: size, height: size)
            .accessibilityHidden(true)

        if reduceMotion {
            image
        } else {
            image.keyframeAnimator(initialValue: 1.0, repeating: true) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                // Three bounces, landing on the three rings, then still.
                MoveKeyframe(1)
                SpringKeyframe(1, duration: 0.25)
                SpringKeyframe(1.25, duration: 0.25)
                SpringKeyframe(1, duration: 0.25)
                SpringKeyframe(1.25, duration: 0.25)
                SpringKeyframe(1, duration: 0.25)
                SpringKeyframe(1.25, duration: 0.25)
                SpringKeyframe(1, duration: 0.25)
                CubicKeyframe(1, duration: 1.25)
            }
        }
    }

    private func words(_ phase: Phase) -> some View {
        VStack(spacing: 12) {
            Text(phase.title)
                .starhashFont(22, weight: .bold, relativeTo: .title2)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Text(phase.description)
                .font(.starhash(.callout))
                .foregroundStyle(Color.starhashSecondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
        }
        .frame(height: 130)
        .accessibilityElement(children: .combine)
    }
}
