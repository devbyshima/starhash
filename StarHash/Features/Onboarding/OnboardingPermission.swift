import SwiftUI

/// A permission primer, a port of Beam's `PermissionOnBoarding`: an iPhone
/// drawn in outline with a system alert popping up on it, over and over, and
/// the words and buttons on a soft panel at the bottom. No button on the
/// alert is picked out: pointing at one would steer the choice. The real prompt comes after Continue. The
/// `.message` mock plays an M-Money message arriving and its payment being
/// ticked off instead, for auto-verify.
struct OnboardingPermission: View {
    enum Mock {
        case alert
        case message
    }

    struct Config {
        var mock: Mock = .alert
        /// Before the alert first appears, so the screen settles first.
        var initialDelay: Double = 0
        var title: String
        var description: String
        /// How many buttons the drawn alert has.
        var alertButtons = 2
        var primaryTitle: String
        var primaryAction: () -> Void
        /// A quieter second choice under the button (auto-verify's Maybe
        /// Later). Never on a screen before a system prompt: Apple allows
        /// those one button, Continue, and no way past the prompt.
        var secondaryTitle: String?
        var secondaryAction: (() -> Void)?
    }

    let config: Config

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAlert = false

    var body: some View {
        ZStack(alignment: .bottom) {
            iPhone
                .accessibilityHidden(true)

            VStack(spacing: 15) {
                Text(config.title)
                    .starhashFont(28, weight: .bold, relativeTo: .title)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)

                Text(config.description)
                    .font(.starhash(.footnote))
                    .foregroundStyle(Color.starhashSecondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 10)

                Button(config.primaryTitle, action: config.primaryAction)
                    .buttonStyle(.starhashPrimaryGlowing)
                    .padding(.horizontal, 15)

                if let title = config.secondaryTitle, let action = config.secondaryAction {
                    Button(action: action) {
                        Text(title)
                            .font(.starhash(.subheadline, weight: .semibold))
                            .foregroundStyle(Color.starhashSecondaryText)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.hapticPlain)
                }
            }
            // A lone button sits where Continue does on the other
            // onboarding screens, 10 points over the bottom; with a second
            // choice under it, the two are centred in the panel.
            .frame(height: 270, alignment: hasSecondary ? .center : .bottom)
            .padding([.horizontal, .top], 15)
            .padding(.bottom, hasSecondary ? 15 : 10)
            .frame(maxWidth: .infinity)
            // The phone fades into the page under the words.
            .background {
                Rectangle()
                    .fill(Color.starhashBackground)
                    .blur(radius: 25)
                    .padding(-50)
                    .ignoresSafeArea()
            }
        }
        .padding(.top, 20)
        .task {
            guard !showsAlert else { return }
            try? await Task.sleep(for: .seconds(config.initialDelay))
            showsAlert = true
        }
    }

    private var hasSecondary: Bool { config.secondaryTitle != nil && config.secondaryAction != nil }

    // MARK: The iPhone

    /// Drawn at an iPhone's size (402 by 874 points) and scaled down to fit
    /// the room above the panel.
    private var iPhone: some View {
        Color.clear
            .overlay(alignment: .top) {
                let radius: CGFloat = 55
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(OnboardingPalette.mockFill)
                        .overlay(alignment: .top) { statusBar }
                        .overlay(alignment: .top) {
                            // The Dynamic Island.
                            Capsule()
                                .fill(OnboardingPalette.mockEdge)
                                .frame(width: 120, height: 37)
                                .offset(y: 15)
                        }

                    // The bezel.
                    ZStack {
                        RoundedRectangle(cornerRadius: radius + 7)
                            .stroke(OnboardingPalette.mockBezel, lineWidth: 12)
                        RoundedRectangle(cornerRadius: radius + 7)
                            .stroke(OnboardingPalette.mockEdge, lineWidth: 4)
                        RoundedRectangle(cornerRadius: radius + 3)
                            .stroke(OnboardingPalette.mockEdge, lineWidth: 6)
                            .padding(4)
                    }
                    .padding(-7)

                    if showsAlert {
                        switch config.mock {
                        case .alert: alert
                        case .message: message
                        }
                    }
                }
                .frame(width: 402, height: 874)
            }
            .visualEffect { content, proxy in
                let design = CGSize(width: 402, height: 874)
                let ratio = min(proxy.size.width / design.width, proxy.size.height / design.height)
                return content.scaleEffect(ratio, anchor: .top)
            }
            .padding(.top, 10)
            .padding(.bottom, 270)
            .frame(maxHeight: .infinity, alignment: .top)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Text("9:41")
                .padding(.leading, 24)
            Spacer(minLength: 0)
            Group {
                Image(systemName: "wifi")
                Image(systemName: "battery.50percent")
            }
            .offset(y: -2)
        }
        // The iPhone's own status bar, so the system's font, not the app's.
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(Color.starhashPrimaryText)
        .frame(height: 37)
        .padding(.horizontal, 35)
        .offset(y: 18)
    }

    // MARK: The alert

    /// Pops in, stays a moment and fades, every 3.4s.
    @ViewBuilder
    private var alert: some View {
        if reduceMotion {
            alertCard
        } else {
            KeyframeAnimator(initialValue: Frame(), repeating: true) { frame in
                alertCard
                    .opacity(frame.opacity)
                    .scaleEffect(frame.scale)
            } keyframes: { _ in
                SpringKeyframe(Frame(opacity: 1, scale: 1), duration: 0.7, spring: .smooth(duration: 0.5, extraBounce: 0))
                SpringKeyframe(Frame(opacity: 1, scale: 1), duration: 0.7, spring: .smooth(duration: 0.4, extraBounce: 0))
                SpringKeyframe(Frame(), duration: 2, spring: .smooth(duration: 0.4, extraBounce: 0))
            }
        }
    }

    /// A system alert in outline: a title, two lines of text and the
    /// buttons.
    private var alertCard: some View {
        let fill = OnboardingPalette.mockFill
        return VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 5)
                .fill(fill)
                .frame(width: 120, height: 20)
                .padding(.bottom, 12)
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .frame(height: 15)
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .frame(height: 15)
                .padding(.trailing, 50)
                .padding(.bottom, 30)

            let layout = config.alertButtons > 2 ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                ForEach(1...config.alertButtons, id: \.self) { _ in
                    Capsule()
                        .fill(fill)
                        .frame(height: 45)
                }
            }
        }
        .frame(width: 280)
        .padding(20)
        .starhashGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    // MARK: The message

    /// A message banner drops in from the top, then a tick lands on it, and
    /// it lifts away, every 3.4s: an M-Money message confirming a payment.
    @ViewBuilder
    private var message: some View {
        if reduceMotion {
            messageCard(Frame(opacity: 1, scale: 1, tapOpacity: 1))
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 84)
        } else {
            KeyframeAnimator(initialValue: Frame(), repeating: true) { frame in
                messageCard(frame)
                    .opacity(frame.opacity)
                    .offset(y: (frame.scale - 1) * -400)
            } keyframes: { _ in
                SpringKeyframe(Frame(opacity: 1, scale: 1), duration: 0.7, spring: .smooth(duration: 0.5, extraBounce: 0.1))
                SpringKeyframe(Frame(opacity: 1, scale: 1, tapOpacity: 1, tapScale: 1.2), duration: 0.35, spring: .bouncy(duration: 0.35))
                SpringKeyframe(Frame(opacity: 1, scale: 1, tapOpacity: 1), duration: 1.4, spring: .smooth(duration: 0.3))
                SpringKeyframe(Frame(), duration: 0.95, spring: .smooth(duration: 0.4, extraBounce: 0))
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 84)
        }
    }

    /// A notification in outline: an app tile, two lines of text, and the
    /// tick that says the payment it confirms is logged.
    private func messageCard(_ frame: Frame) -> some View {
        let fill = OnboardingPalette.mockFill
        return HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(fill)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(fill)
                    .frame(width: 110, height: 16)
                RoundedRectangle(cornerRadius: 3)
                    .fill(fill)
                    .frame(height: 13)
                RoundedRectangle(cornerRadius: 3)
                    .fill(fill)
                    .frame(height: 13)
                    .padding(.trailing, 60)
            }
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.starhashIncoming)
                .opacity(frame.tapOpacity)
                .scaleEffect(frame.tapScale)
        }
        .frame(width: 320)
        .padding(18)
        .starhashGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private struct Frame: Animatable {
        var opacity: CGFloat = 0
        var scale: CGFloat = 1.1
        var tapOpacity: CGFloat = 0
        var tapScale: CGFloat = 1

        var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
            get { AnimatablePair(AnimatablePair(opacity, scale), AnimatablePair(tapOpacity, tapScale)) }
            set {
                opacity = newValue.first.first
                scale = newValue.first.second
                tapOpacity = newValue.second.first
                tapScale = newValue.second.second
            }
        }
    }
}
