import StarHashKit
import SwiftUI

/// The first-run flow, in Beam's onboarding style (and Sorty's, which ports
/// it): screens on the plain app background, each with a glow of the tint
/// rising from the bottom edge. Calls `onFinish` after the last one.
///
///   0. `OnboardingReel`, the looping feature reel: pulse rings behind a
///      bouncing symbol, the selling points pushing in beneath it.
///   1. `OnboardingWalletPage`, which wallet pays (MTN MoMo or Airtel Money).
///   1½. `OnboardingNumberPage`, the owner's name and number, for their own
///      QR code (Maybe Later skips it).
///   1¾. `OnboardingPhotoPage`, the owner's photo, shown to whoever scans
///      their code. Continue moves on with or without one.
///   2. `OnboardingPermission`, an iPhone mock playing the Contacts prompt,
///      asked for at the moment the screen explains why.
///   3. The same for Nearby's location prompt. After Contacts, since Nearby
///      leaves contacts out.
///   4. The same for notifications' prompt: reminders and summaries.
///   5. Auto-verify, with a message being confirmed on the mock; Set Up
///      goes on to the setup itself, Maybe Later finishes. Last, since
///      setting it up leaves for Shortcuts.
///   6. The setup: `AutoVerificationGuide`'s steps (add the shortcut, make
///      the automation, check it works) as onboarding's own last screens,
///      offered every time, a replay included, so the shortcut and the
///      automation can always be set up from here.
///
/// The screen reached is saved as it changes, so a flow left unfinished
/// opens again where it was left; finishing clears it. The tint is the
/// accent throughout; the wallets show as their logos.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(Owner.self) private var owner
    @AppStorage(PreferenceKey.nearbyLocation) private var nearbyLocation = false
    @AppStorage(PreferenceKey.onboardingStage) private var savedStage = 0
    @AppStorage(PreferenceKey.hasSeenDeveloperNote) private var hasSeenDeveloperNote = false
    @State private var stage = OnboardingLaunch.initialStage ?? UserDefaults.standard.integer(forKey: PreferenceKey.onboardingStage)

    enum Stage: Int {
        case reel, wallet, number, photo, contacts, nearby, notifications, autoVerify, setup
    }

    /// Every screen there can be, for the debug launch's range.
    static let stageCount = 9

    /// The screens, in order. Both wallets' messages can be read, so
    /// everyone sees auto-verify and its setup.
    private var stages: [Stage] { [.reel, .wallet, .number, .photo, .contacts, .nearby, .notifications, .autoVerify, .setup] }

    /// The wallet picked on the wallet screen, MTN MoMo until then.
    private var chosenWallet: Recipient.Network { owner.wallet }

    private var current: Stage { stages[min(stage, stages.count - 1)] }

    private static let phases: [OnboardingReel.Phase] = [
        .init(symbol: "number", title: "No more USSD menus",
              description: "Type an amount, pick who gets it,\nand StarHash dials the code for you."),
        .init(symbol: "storefront.fill", title: "Pay anyone",
              description: "Any MTN or Airtel number, or a merchant\ncode. StarHash knows which is which."),
        .init(symbol: "clock.fill", title: "Every payment, logged",
              description: "Transactions keeps each payment by day,\nwith a chart and search."),
        .init(symbol: "lock.shield.fill", title: "Private by design",
              description: "No account and no tracking. Your PIN only\never goes into your wallet's own prompt."),
    ]

    private var tint: Color { OnboardingPalette.tint }

    var body: some View {
        ZStack {
            Color.starhashBackground.ignoresSafeArea()
            switch current {
            case .reel:
                OnboardingReel(phases: Self.phases, tint: tint, onContinue: advance)
                    .transition(.blurOutUp)
            case .wallet:
                OnboardingWalletPage(onDone: advance)
                    .transition(.blurOutUp)
            case .number:
                OnboardingNumberPage(onDone: advance)
                    .transition(.blurOutUp)
            case .photo:
                OnboardingPhotoPage(onDone: advance)
                    .transition(.blurOutUp)
            case .contacts:
                OnboardingPermission(config: contacts)
                    .transition(.blurOutUp)
            case .nearby:
                OnboardingPermission(config: nearby)
                    .id(Stage.nearby)
                    .transition(.blurOutUp)
            case .notifications:
                OnboardingPermission(config: notifications)
                    .id(Stage.notifications)
                    .transition(.blurOutUp)
            case .autoVerify:
                OnboardingPermission(config: autoVerify)
                    .id(Stage.autoVerify)
                    .transition(.blurOutUp)
            case .setup:
                // The setup in full, in its own navigation bar: back steps
                // back through it and then to the screen before, close
                // skips it. Done or closed, onboarding ends, set up or not
                // (Settings can switch it on later).
                NavigationStack {
                    AutoVerificationGuide(onClose: finish, onLeave: goBack, onDone: finish)
                }
                .transition(.blurOutUp)
            }
        }
        .onChange(of: stage, initial: true) { _, stage in savedStage = stage }
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
            }
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
            primaryTitle: "Continue",
            primaryAction: {
                guard !nearbyLocation else { return advance() }
                Task {
                    let allowed = await SettingsLocationAccess.shared.request()
                    if allowed, PaymentLocation.isAuthorized { nearbyLocation = true }
                    advance()
                }
            }
        )
    }

    /// Reminders and summaries. Asks iOS, then moves on whatever the
    /// answer; which ones come is chosen later on the Notifications page.
    private var notifications: OnboardingPermission.Config {
        .init(
            initialDelay: 0.4,
            title: "Stay on top of\nyour payments",
            description: "A reminder when a payment is still pending,\nand your week and month summed up.",
            primaryTitle: "Continue",
            primaryAction: {
                Task {
                    await StarHashNotifications.shared.requestAuthorization()
                    advance()
                }
            }
        )
    }

    private var autoVerify: OnboardingPermission.Config {
        .init(
            mock: .message,
            initialDelay: 0.4,
            title: "Confirm payments\nautomatically",
            description: String(starhash: "Add one shortcut and each \(chosenWallet.messagesName) message\nconfirms its payment, with the fee."),
            primaryTitle: "Set Up",
            primaryAction: advance,
            secondaryTitle: "Maybe Later",
            secondaryAction: finish
        )
    }

    /// Done: the next launch starts on the tabs, and a later replay from
    /// the first screen. Shima's note is owed again, so it opens over Pay
    /// (`RootView`), and again on the next launch if the app is quit first.
    private func finish() {
        savedStage = 0
        hasSeenDeveloperNote = false
        // The two weeks before the note asking for a rating start now.
        ReviewNote.startClockIfNeeded()
        onFinish()
    }

    private func advance() {
        guard stage < stages.count - 1 else { return finish() }
        withAnimation(.smooth(duration: 0.45)) { stage += 1 }
    }

    private func goBack() {
        guard stage > 0 else { return }
        withAnimation(.smooth(duration: 0.45)) { stage -= 1 }
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
    /// The flow's tint, the accent's fill (the deep green on light mode's
    /// green page, the green on dark mode's), whichever wallet is chosen.
    static let tint = Color.brandFill

    /// The iPhone mock on the permission screen: its frame and the filled
    /// shapes standing in for the screen's content.
    static let mockBezel = Color(light: .init(white: 0.62), dark: .init(white: 0.42))
    static let mockEdge = Color(light: .black, dark: .init(white: 10 / 255))
    static let mockFill = Color(light: .black.opacity(0.15), dark: .white.opacity(0.15))
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

/// `-onboardingPage 0...8` (DEBUG, with `-resetOnboarding`) starts on that
/// screen: the reel, the wallet, the number, the photo, Contacts, Nearby,
/// notifications, auto-verify, its setup. Without it, onboarding starts
/// where it was left.
@MainActor
enum OnboardingLaunch {
    static var initialStage: Int? {
        #if DEBUG
        guard let stage = DebugLaunch.value(after: "-onboardingPage").flatMap(Int.init) else { return nil }
        return min(max(stage, 0), OnboardingView.stageCount - 1)
        #else
        return nil
        #endif
    }
}
