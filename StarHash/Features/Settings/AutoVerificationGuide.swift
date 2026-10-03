import SwiftUI
import UIKit

/// Auto-verify setup, a page pushed from Settings or Help, in two steps,
/// each shown with a real screenshot of what Shortcuts looks like, one
/// thing to do, and a Continue (or Done) that appears only once it is done:
///
/// 1. Add Shortcut: opens Shortcuts on the shared StarHash SMS shortcut.
///    It comes with its automation built in ("When I get a message
///    containing RWF", which every M-Money message is, run without asking),
///    so there is nothing to build or set up.
/// 2. Verify Shortcut: runs it through Shortcuts with a sample message and
///    comes straight back (x-callback-url). Done appears only when the
///    action actually ran; there is no skipping, and auto-verify stays off
///    until it has.
struct AutoVerificationGuide: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(PreferenceKey.lastVerifiedAt) private var lastVerifiedAt: Double = 0
    @AppStorage(PreferenceKey.autoVerifySetUp) private var autoVerifySetUp = false

    @State private var step = SettingsLaunch.guideStep
    /// Whether Add Shortcut has been tapped, which brings up Continue.
    @State private var didAct = false
    /// `lastVerifiedAt` when Verify Shortcut was tapped; nil before.
    @State private var verifyStartedAt: Double?
    @State private var verification: Verification = .idle

    private enum Verification { case idle, waiting, verified, failed }

    static let stepCount = 2

    var body: some View {
        VStack(spacing: 0) {
            GuideProgress(count: Self.stepCount, current: step)
                .padding(.top, 8)
            ScrollView {
                VStack(spacing: 0) {
                    screenshot
                        .padding(.top, 20)
                    texts
                        .padding(.top, 24)
                    if step == 0 {
                        GuideStepList(steps: [
                            "Tap **Add Shortcut** below.",
                            "In Shortcuts, tap **Add Shortcut**.",
                            "Come back and tap **Continue**.",
                        ])
                        .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .id(step)
                .transition(reduceMotion ? .opacity : .push(from: .trailing))
            }
            .scrollBounceBehavior(.basedOnSize)
            .starhashSoftTopEdge()
            .starhashBottomBar { buttonsBar }
        }
        .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
        .background(Color.starhashBackground.ignoresSafeArea())
        .navigationTitle("Auto-verify")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: lastVerifiedAt) { checkVerification() }
        .onChange(of: router.shortcutCallback) { _, callback in
            guard let callback, verification == .waiting else { return }
            // Shortcuts came back: either the action ran (and wrote
            // lastVerifiedAt), or the shortcut was missing or failed.
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                checkVerification()
                if verification == .waiting, callback.result != .success {
                    withAnimation(.smooth) { verification = .failed }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Back without a callback (the person switched apps by hand).
            guard phase == .active, verification == .waiting else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                checkVerification()
                if verification == .waiting { withAnimation(.smooth) { verification = .failed } }
            }
        }
        .sensoryFeedback(.success, trigger: verification == .verified)
    }

    // MARK: Content

    /// What Shortcuts shows at this step, from a real iPhone: the whole
    /// Add Shortcut screen in a phone frame, its button ringed; then the
    /// automation the shortcut brings, switched on.
    @ViewBuilder
    private var screenshot: some View {
        if step == 0 {
            GuidePhoneScreenshot(
                imageName: "GuideAddShortcut",
                label: "Shortcuts showing StarHash SMS, with the Add Shortcut button at the bottom",
                // The blue Add Shortcut button, as a share of the image.
                highlight: CGRect(x: 0.055, y: 0.895, width: 0.89, height: 0.064)
            )
        } else {
            GuideCardScreenshot(
                imageName: "GuideAutomationOn",
                label: "Shortcuts' Automation tab: When I get a message containing RWF, run StarHash SMS, switched on",
                // The switch, on.
                highlight: CGRect(x: 0.725, y: 0.40, width: 0.185, height: 0.185),
                isVerified: verification == .verified
            )
        }
    }

    private var title: String {
        switch step {
        case 0: "Add StarHash SMS"
        default:
            switch verification {
            case .verified: "You're all set"
            case .failed: "Shortcut didn't run"
            default: "Check it works"
            }
        }
    }

    /// Step 1 has its numbered steps instead.
    private var subtitle: String? {
        switch step {
        case 0:
            nil
        default:
            switch verification {
            case .verified: "Every M\u{2011}Money message now logs itself in Activity. In Shortcuts, Automation shows it switched on, as above."
            case .failed: "Add StarHash SMS first, then try again. In Shortcuts, Automation, make sure it is switched on."
            default: "StarHash sends a test message through the shortcut and comes straight back. Nothing is saved."
            }
        }
    }

    private var texts: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.starhashTitle)
                .foregroundStyle(Color.starhashPrimaryText)
                .accessibilityAddTraits(.isHeader)
                .contentTransition(.opacity)
            if let subtitle {
                Text(subtitle)
                    .font(.starhash(.body))
                    .foregroundStyle(Color.starhashSecondaryText)
                    .contentTransition(.opacity)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.smooth, value: verification)
    }

    // MARK: Buttons

    /// On iOS 26 the system's scroll edge effect fades the content beneath
    /// the bar; before that the bar needs a backing of its own.
    private var buttonsBar: some View {
        buttons.background {
            if #available(iOS 26.0, *) {
                Color.clear
            } else {
                Color.starhashBackground.ignoresSafeArea()
            }
        }
    }

    /// The step's action first; Continue (or Done) comes in under it once
    /// the action is done, and the action steps back to a glass button.
    private var buttons: some View {
        VStack(spacing: 10) {
            if step == 0 {
                Button("Add Shortcut", action: addShortcut)
                    .buttonStyle(GuideButtonStyle(prominent: !didAct))
                if didAct {
                    Button("Continue") { goTo(1) }
                        .buttonStyle(GuideButtonStyle(prominent: true))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else {
                verifyButtons
            }
        }
        .animation(.smooth(duration: 0.3), value: didAct)
        .animation(.smooth(duration: 0.3), value: verification)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var verifyButtons: some View {
        switch verification {
        case .verified:
            Button("Done", action: finish)
                .buttonStyle(GuideButtonStyle(prominent: true))
        case .waiting:
            Button {} label: {
                HStack(spacing: 10) {
                    ProgressView().tint(Color.starhashSecondaryText)
                    Text("Checking")
                }
            }
            .buttonStyle(GuideButtonStyle(prominent: true))
            .disabled(true)
        case .idle, .failed:
            Button(verification == .failed ? "Try Again" : "Verify Shortcut", action: runVerification)
                .buttonStyle(GuideButtonStyle(prominent: true))
            if verification == .failed {
                Button("Add the Shortcut") { goTo(0) }
                    .buttonStyle(GuideButtonStyle(prominent: false))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func addShortcut() {
        StarHashShortcut.install(openURL: openURL)
        didAct = true
    }

    private func finish() {
        autoVerifySetUp = true
        dismiss()
    }

    private func goTo(_ next: Int) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .smooth(duration: 0.45)) {
            step = next
            didAct = false
            verification = .idle
        }
    }

    private func runVerification() {
        verifyStartedAt = lastVerifiedAt
        withAnimation(.smooth) { verification = .waiting }
        if let url = StarHashShortcut.verificationURL { openURL(url) }
    }

    private func checkVerification() {
        guard let start = verifyStartedAt, lastVerifiedAt > start else { return }
        withAnimation(.smooth) { verification = .verified }
    }
}

/// A whole real iPhone screen of Shortcuts, in a slim dark phone frame
/// with rounded corners all round, and the control to tap ringed.
private struct GuidePhoneScreenshot: View {
    let imageName: String
    let label: String
    /// What to tap, as a share of the image (0...1 on both axes).
    let highlight: CGRect

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 290

    var body: some View {
        let screen = RoundedRectangle(cornerRadius: 26, style: .continuous)
        let body = RoundedRectangle(cornerRadius: 31, style: .continuous)
        Image(imageName)
            .resizable()
            .scaledToFit()
            .overlay { GuideHighlight(rect: highlight, cornerFraction: 0.5) }
            .clipShape(screen)
            .padding(5)
            .background(body.fill(Color(white: 0.09)))
            .overlay(body.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
            .frame(height: min(height, 420))
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
    }
}

/// A real screenshot cut to one Shortcuts card, on a rounded card of its
/// own, with what matters ringed, and a green check on the corner once the
/// shortcut is verified.
private struct GuideCardScreenshot: View {
    let imageName: String
    let label: String
    let highlight: CGRect
    var isVerified = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        Image(imageName)
            .resizable()
            .scaledToFit()
            .overlay { GuideHighlight(rect: highlight, cornerFraction: 0.5) }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
            .overlay(alignment: .topTrailing) {
                if isVerified {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.starhashOnIncoming, Color.starhashIncoming)
                        .background(Circle().fill(Color.starhashBackground).padding(2))
                        .offset(x: 10, y: -10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.3), value: isVerified)
            .frame(maxWidth: 420)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
    }
}

/// A soft white ring around the part of a screenshot to look at, breathing
/// gently (still when Reduce Motion is on). The screenshots are always the
/// dark Shortcuts, so the ring is white in both appearances.
private struct GuideHighlight: View {
    /// A share of the screenshot, 0...1 on both axes.
    let rect: CGRect
    /// Corner radius as a share of the ring's height (0.5 is a capsule).
    let cornerFraction: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathes = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width * rect.width
            let h = proxy.size.height * rect.height
            RoundedRectangle(cornerRadius: h * cornerFraction, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 2.5)
                .shadow(color: .white.opacity(0.7), radius: 6)
                .frame(width: w + 10, height: h + 10)
                .scaleEffect(breathes ? 1.04 : 1)
                .opacity(breathes ? 0.75 : 1)
                .position(
                    x: proxy.size.width * rect.midX,
                    y: proxy.size.height * rect.midY
                )
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { breathes = true }
        }
    }
}

/// Numbered steps for the person to follow, in a card: each number in a
/// small ink disc, the text beside it.
private struct GuideStepList: View {
    let steps: [LocalizedStringKey]

    var body: some View {
        StarHashCard(fill: .starhashCard) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 { StarHashRowSeparator(leading: 54) }
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(index + 1)")
                        .starhashFont(14, weight: .bold, relativeTo: .subheadline)
                        .foregroundStyle(Color.starhashOnInk)
                        .frame(width: 24, height: 24)
                        .background(Color.starhashInk, in: Circle())
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                        .accessibilityHidden(true)
                    Text(step)
                        .font(.starhash(.body))
                        .foregroundStyle(Color.starhashPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }
}

/// The full-width capsules of the guide: ink when it is the next thing to
/// tap, glass once it has been done.
private struct GuideButtonStyle: ButtonStyle {
    var prominent: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        if prominent {
            PrimaryButtonStyle().makeBody(configuration: configuration)
        } else {
            configuration.label
                .starhashFont(18, weight: .semibold, relativeTo: .body)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .frame(minHeight: StarHashMetrics.primaryButtonHeight)
                .contentShape(Capsule())
                .starhashGlass(interactive: true)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.snappy(duration: 0.2), value: configuration.isPressed)
        }
    }
}

// MARK: - Pieces

/// One capsule per step: done and current steps in the accent, the rest grey.
private struct GuideProgress: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.starhashAccentGraphic : Color.starhashPrimaryText.opacity(0.15))
                    .frame(height: 5)
            }
        }
        .frame(maxWidth: 220)
        .animation(.smooth(duration: 0.4), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}
