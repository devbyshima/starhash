import StarHashKit
import SwiftUI

/// The first-run flow, in Beam's onboarding style (and Sorty's, which ports
/// it): screens on the plain app background, each with a glow of the tint
/// rising from the bottom edge. Calls `onFinish` after the last one.
///
///   0. `OnboardingReel`, the looping feature reel: pulse rings behind a
///      bouncing symbol, the selling points pushing in beneath it.
///   1. `OnboardingWalletPage`, which wallet pays (MTN MoMo or Airtel Money).
///   2. `OnboardingPermission`, an iPhone mock playing the Contacts prompt,
///      asked for at the moment the screen explains why.
///   3. The same for Nearby's location prompt. After Contacts, since Nearby
///      leaves contacts out.
///   4. Auto-verify, with a message being confirmed on the mock; Set Up
///      runs the setup over onboarding. MTN only (the SMS reader knows only
///      MTN's messages), and last, since setting it up leaves for Shortcuts.
///
/// A screen whose setting is already on (a replay) offers Continue alone.
/// The tint is StarHash's blue throughout; the wallets show as their logos.
struct OnboardingView: View {
    let onFinish: () -> Void

    @AppStorage(PreferenceKey.wallet) private var wallet = ""
    @AppStorage(PreferenceKey.nearbyLocation) private var nearbyLocation = false
    @AppStorage(PreferenceKey.autoVerifySetUp) private var autoVerifySetUp = false
    @State private var stage = OnboardingLaunch.initialStage
    @State private var setsUpAutoVerify = false

    enum Stage: Int {
        case reel, wallet, contacts, nearby, autoVerify
    }

    /// Every screen there can be, for the debug launch's range.
    static let stageCount = 5

    /// The screens for this person: auto-verify only with MTN.
    private var stages: [Stage] {
        var all: [Stage] = [.reel, .wallet, .contacts, .nearby]
        if wallet != Recipient.Network.airtel.rawValue { all.append(.autoVerify) }
        return all
    }

    private var current: Stage { stages[min(stage, stages.count - 1)] }

    private static let phases: [OnboardingReel.Phase] = [
        .init(symbol: "number", title: "No more USSD menus",
              description: "Type an amount, pick who gets it,\nand StarHash dials the code for you."),
        .init(symbol: "storefront.fill", title: "Pay anyone",
              description: "Any MTN or Airtel number, or a merchant\ncode. StarHash knows which is which."),
        .init(symbol: "list.bullet.rectangle.fill", title: "Every payment, logged",
              description: "Activity keeps each payment by day,\nwith a chart and search."),
        .init(symbol: "lock.shield.fill", title: "Private by design",
              description: "No account and no server. Your PIN only\never goes into your wallet's own prompt."),
    ]

    private var tint: Color { OnboardingPalette.tint }

    var body: some View {
        ZStack {
            Color.starhashBackground.ignoresSafeArea()
            switch current {
            case .reel:
                OnboardingReel(phases: Self.phases, tint: tint, onContinue: advance)
                    .transition(.opacity)
            case .wallet:
                OnboardingWalletPage(onDone: advance)
                    .transition(.opacity)
            case .contacts:
                OnboardingPermission(config: contacts)
                    .transition(.opacity)
            case .nearby:
                OnboardingPermission(config: nearby)
                    .id(Stage.nearby)
                    .transition(.opacity)
            case .autoVerify:
                OnboardingPermission(config: autoVerify)
                    .id(Stage.autoVerify)
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: stage)
        // The setup in full, over onboarding; onboarding ends as it closes,
        // set up or not (Settings can switch it on later).
        .fullScreenCover(isPresented: $setsUpAutoVerify, onDismiss: onFinish) {
            AutoVerifySetupCover()
        }
    }

    private var contacts: OnboardingPermission.Config {
        .init(
            initialDelay: 0.4,
            title: "Pay your contacts\nin a tap",
            description: "Pick who to pay from your contacts.\nThey stay on your iPhone.",
            primaryTitle: "Continue",
            primaryAction: {
                Task {
                    await SettingsContactsAccess.request()
                    advance()
                }
            },
            secondaryTitle: "Maybe Later",
            secondaryAction: advance
        )
    }

    /// Where you pay, remembered on the phone. Precise location only: an
    /// approximate grant (or a refusal) leaves Nearby off and moves on,
    /// with no alert in the middle of onboarding.
    private var nearby: OnboardingPermission.Config {
        .init(
            initialDelay: 0.4,
            title: "Suggest who you\npaid here",
            description: "Paid a shop here before? StarHash lists it\nfirst next time. This stays on your iPhone.",
            alertButtons: 3,
            tappedButton: 2,
            primaryTitle: nearbyLocation ? "Continue" : "Turn On",
            primaryAction: {
                guard !nearbyLocation else { return advance() }
                Task {
                    let allowed = await SettingsLocationAccess.shared.request()
                    if allowed, PaymentLocation.isAuthorized { nearbyLocation = true }
                    advance()
                }
            },
            secondaryTitle: nearbyLocation ? nil : "Not Now",
            secondaryAction: advance
        )
    }

    private var autoVerify: OnboardingPermission.Config {
        .init(
            mock: .message,
            initialDelay: 0.4,
            title: "Confirm payments\nautomatically",
            description: "Add one shortcut and each M\u{2011}Money message\nconfirms its payment, with the fee.",
            primaryTitle: autoVerifySetUp ? "Continue" : "Set Up",
            primaryAction: {
                if autoVerifySetUp { onFinish() } else { setsUpAutoVerify = true }
            },
            secondaryTitle: autoVerifySetUp ? nil : "Maybe Later",
            secondaryAction: onFinish
        )
    }

    private func advance() {
        guard stage < stages.count - 1 else { return onFinish() }
        withAnimation(.smooth(duration: 0.45)) { stage += 1 }
    }
}

// MARK: - Shared pieces

enum OnboardingMetrics {
    /// The side margin of the words and buttons, Beam's.
    static let horizontalPadding: CGFloat = 30
    /// The symbol and its rings, as Beam draws them.
    static let iconSize: CGFloat = 100
}

/// Colours used only by onboarding.
enum OnboardingPalette {
    /// The flow's tint, the accent, whichever wallet is chosen.
    static let tint = Color.starhashInk

    /// The iPhone mock on the permission screen: its frame and the filled
    /// shapes standing in for the screen's content.
    static let mockBezel = Color(light: .init(white: 0.62), dark: .init(white: 0.42))
    static let mockEdge = Color(light: .black, dark: .init(white: 10 / 255))
    static let mockFill = Color(light: .black.opacity(0.15), dark: .white.opacity(0.15))
    static let mockTap = Color(white: 0.5).opacity(0.8)
}

/// Three rings growing out from behind the symbol, staggered so one is
/// always leaving as another arrives. Beam's.
///
/// In an overlay on a clear view on purpose: a ring grows to twelve times
/// its size, and a laid-out view that wide would size everything above it.
/// An overlay never reports a size to its parent.
struct OnboardingPulseRings: View {
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.clear
            .overlay {
                if !reduceMotion {
                    ZStack {
                        ring(delay: 0, wait: 1)
                        ring(delay: 0.5, wait: 0.5)
                        ring(delay: 1, wait: 0)
                    }
                }
            }
            .accessibilityHidden(true)
    }

    /// Each ring's cycle is 3s, the reel's phase: its delay, 2s growing,
    /// then its wait.
    private func ring(delay: CGFloat, wait: CGFloat) -> some View {
        let size = OnboardingMetrics.iconSize / 2
        return KeyframeAnimator(initialValue: Pulse(), repeating: true) { pulse in
            Circle()
                .stroke(tint.opacity(0.6), lineWidth: 1.3)
                .frame(width: size * pulse.scale, height: size * pulse.scale)
                // Thins as it grows, as well as fading on its own keyframe.
                .opacity((pulse.scale - 1) / 3)
                .opacity(pulse.opacity)
        } keyframes: { _ in
            MoveKeyframe(Pulse())
            LinearKeyframe(Pulse(), duration: delay)
            LinearKeyframe(Pulse(scale: 12, opacity: 0), duration: 2)
            LinearKeyframe(Pulse(scale: 12, opacity: 0), duration: wait)
        }
    }

    private struct Pulse: Animatable {
        var scale: CGFloat = 1
        var opacity: CGFloat = 1

        var animatableData: AnimatablePair<CGFloat, CGFloat> {
            get { AnimatablePair(scale, opacity) }
            set {
                scale = newValue.first
                opacity = newValue.second
            }
        }
    }
}

extension View {
    /// Beam's glow: a big circle of the tint sunk below the bottom edge and
    /// blurred, so the colour rises from under the button.
    func onboardingGlow(_ tint: Color) -> some View {
        background {
            Circle()
                .fill(tint.gradient)
                .visualEffect { content, proxy in
                    content.offset(y: proxy.size.height * 1.07)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .blur(radius: 90)
                .animation(.smooth(duration: 0.5), value: tint)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Launch arguments

/// `-onboardingPage 0...4` (DEBUG, with `-resetOnboarding`) starts on that
/// screen: the reel, the wallet, Contacts, Nearby, auto-verify.
@MainActor
enum OnboardingLaunch {
    static var initialStage: Int {
        #if DEBUG
        let stage = DebugLaunch.value(after: "-onboardingPage").flatMap(Int.init) ?? 0
        return min(max(stage, 0), OnboardingView.stageCount - 1)
        #else
        return 0
        #endif
    }
}

/// Auto-verify's setup as onboarding shows it: the same guide Settings
/// pushes, in its own navigation bar with a close button. Done or closed,
/// it goes, and onboarding ends with it.
private struct AutoVerifySetupCover: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AutoVerificationGuide()
                .starhashCloseButton { dismiss() }
        }
    }
}
