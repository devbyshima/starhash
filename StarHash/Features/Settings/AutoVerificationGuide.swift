import StarHashKit
import SwiftUI
import UIKit

/// Auto-verify setup, a page pushed from Settings (and onboarding's last screens), in three steps,
/// each shown with a picture of what Shortcuts looks like, one thing to
/// do, and a Continue (or Done) that appears only once it is done:
///
/// 1. Add Shortcut: opens Shortcuts on the shared StarHash SMS shortcut.
/// 2. Turn on the automation: opens Shortcuts, where the StarHash SMS
///    automation (when a message containing RWF arrives, which every
///    M-Money and AirtelMoney message does, run immediately) is switched
///    on in the Automation tab. iOS offers no link to that tab, so the
///    step says where to go and nothing else.
/// 3. Check it works: runs the shortcut through Shortcuts with a sample
///    message and comes straight back (x-callback-url). That proves the
///    shortcut, and turns auto-verify on; the automation is proven only by
///    a real message through it, so the step then waits for one, and until
///    one comes nothing is failed for want of a message (`AutoVerify`'s
///    Waiting).
struct AutoVerificationGuide: View {
    /// In onboarding: the close button on the right, which skips the
    /// setup. Pushed from Settings there is none.
    var onClose: (() -> Void)?
    /// Back from the first step, when leaving is not just going back a
    /// screen (in onboarding, where it returns to onboarding's page).
    var onLeave: (() -> Void)?
    /// Done, when finishing is not just going back a screen (in
    /// onboarding, where it ends onboarding).
    var onDone: (() -> Void)?

    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(AutoVerify.self) private var autoVerify
    @Environment(Owner.self) private var owner
    private var ownWallets: OwnerWallets { owner.wallets }

    @State private var step = SettingsLaunch.guideOutcome == nil ? SettingsLaunch.guideStep : Self.checkStep
    /// Whether the step's action (Add Shortcut, Open Shortcuts) has been
    /// tapped, which brings up Continue.
    @State private var didAct = false
    /// When the shortcut had last run as Verify Shortcut was tapped
    /// (`.distantPast` for never); nil before it is tapped.
    @State private var verifyStartedAt: Date?
    @State private var verification: Verification = Self.launchVerification
    /// The scroll view's visible height: from the progress bar to the
    /// buttons.
    @State private var viewportHeight: CGFloat = 0
    /// The title and the steps' card, as tall as this step's words make them.
    @State private var textHeight: CGFloat = 0

    /// The step laid out to fill the room between the progress bar and the
    /// buttons: the words take what they need, the phone takes the rest
    /// (within its bounds), and the gaps stay even, sharing whatever the
    /// phone cannot use. With large text the phone is at its smallest and
    /// the step scrolls.
    private var layout: GuideLayout {
        let gaps = GuideLayout.top + GuideLayout.middle + GuideLayout.bottom
        let free = viewportHeight - textHeight - gaps
        let phone = min(max(free, GuideLayout.minPhone), GuideLayout.maxPhone)
        let extra = max(0, free - phone) / 3
        return GuideLayout(
            phone: phone,
            top: GuideLayout.top + extra,
            middle: GuideLayout.middle + extra,
            bottom: GuideLayout.bottom + extra
        )
    }

    private static var launchVerification: Verification {
        switch SettingsLaunch.guideOutcome {
        case "guideFailed": .failed
        case "guideWaiting": .awaitingMessage
        case "guideVerified": .verified
        default: .idle
        }
    }

    /// The check: not run, running, the shortcut ran but no real message
    /// has come through the automation yet, one has, or the shortcut did
    /// not run.
    private enum Verification { case idle, waiting, awaitingMessage, verified, failed }

    static let stepCount = 3
    private static let checkStep = 2

    var body: some View {
        VStack(spacing: 0) {
            GuideProgress(count: Self.stepCount, current: step)
                .padding(.top, 8)
            ScrollView {
                // (Spacers do not stretch in a scroll view, so the room is
                // worked out: `layout`.)
                let layout = layout
                VStack(spacing: 0) {
                    screenshot(height: layout.phone)
                        .padding(.top, layout.top)
                    VStack(spacing: 20) {
                        texts
                        stepList
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        textHeight = height
                    }
                    .padding(.top, layout.middle)
                    .padding(.bottom, layout.bottom)
                }
                .padding(.horizontal, 24)
                .animation(.smooth(duration: 0.3), value: layout)
                .id(step)
                .transition(reduceMotion ? .opacity : .push(from: .trailing))
            }
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // The container already stops at the button bar, which
                // the bottom inset also counts.
                geometry.containerSize.height - geometry.contentInsets.top
            } action: { _, height in
                viewportHeight = height
            }
            .starhashSoftEdge()
            .starhashBottomBar { buttonsBar }
        }
        .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
        .background(Color.starhashBackground.ignoresSafeArea())
        .starhashNavigationTitle("Auto-verify")
        // Back on the left steps back through the setup, then leaves it;
        // close on the right, over onboarding only.
        .starhashBackAndClose(back: goBack, close: onClose)
        .onChange(of: autoVerify.shortcutRanAt) { checkVerification() }
        // A real message through the automation, while the step waits.
        .onChange(of: automationProven) {
            guard verification == .awaitingMessage, automationProven else { return }
            withAnimation(.smooth) { verification = .verified }
        }
        .onChange(of: router.shortcutCallback) { _, callback in
            guard let callback, verification == .waiting else { return }
            // Shortcuts came back: either the action ran (and wrote
            // `shortcutRanAt`), or the shortcut was missing or failed.
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

    /// What Shortcuts shows at this step, from a real iPhone, in the
    /// appearance the app is in (the asset catalog holds a light and a dark
    /// picture, StarHash's own icon on both): the whole Add Shortcut screen
    /// in a phone frame, its button ringed; then the Automation tab with
    /// the automation made, and a check on it once a message has come
    /// through.
    @ViewBuilder
    private func screenshot(height: CGFloat) -> some View {
        if step == 0 {
            GuidePhoneScreenshot(
                imageName: "GuideAddShortcut",
                label: "Shortcuts showing StarHash SMS, with the Add Shortcut button at the bottom",
                // The blue Add Shortcut button, as a share of the image,
                // measured from its pixels.
                highlight: CGRect(x: 0.0597, y: 0.8961, width: 0.8806, height: 0.062),
                height: height
            )
        } else {
            GuideAutomationPhone(
                imageName: "GuideAutomationOn",
                label: "Shortcuts' Automation tab: When I get a message containing RWF, run StarHash SMS, switched on",
                // The switch, on.
                highlight: CGRect(x: 0.725, y: 0.40, width: 0.185, height: 0.185),
                isVerified: step == Self.checkStep && verification == .verified,
                height: height
            )
        }
    }

    private var title: String {
        switch step {
        case 0: "Add StarHash SMS"
        case 1: "Turn on the automation"
        default:
            switch verification {
            case .verified: "You're all set"
            case .awaitingMessage: "Waiting for a message"
            case .failed: "Shortcut didn't run"
            default: "Check it works"
            }
        }
    }

    /// Both steps say what to do in a card under the title, as numbered
    /// steps; once verified, what now works, ticked.
    @ViewBuilder
    private var stepList: some View {
        if step == 0 {
            GuideStepList(steps: [
                "Tap **Add Shortcut** below.",
                "In Shortcuts, tap **Add Shortcut**.",
                // A shortcut file names no app for its icon, so Shortcuts
                // shows its wand until StarHash's is chosen by hand.
                "Tap its name at the top, then **Choose Icon** and **StarHash**.",
                "Come back and tap **Continue**.",
            ])
        } else if step == 1 {
            GuideStepList(steps: [
                "Tap **Open Shortcuts** below and go to **Automation**.",
                "Turn on **StarHash SMS**.",
                "Come back and tap **Continue**.",
            ])
        } else {
            Group {
                switch verification {
                case .verified:
                    GuideStepList(steps: [
                        "Every \(ownWallets.messagesName) message confirms its payment.",
                        "Fees and your balance fill in by themselves.",
                        "Turn it off any time in **Settings**.",
                    ], symbol: "checkmark", confirmed: true)
                case .awaitingMessage:
                    GuideStepList(steps: [
                        "The shortcut works. A message through the automation proves the rest.",
                        "Wait for your next \(ownWallets.messagesName) message, or ask someone to text you **RWF**.",
                        "Until one comes, StarHash won't mark payments failed on its own.",
                    ])
                case .failed:
                    GuideStepList(steps: [
                        "In Shortcuts, check **StarHash SMS** was added under that name.",
                        "Run it once there, and allow anything it asks.",
                        "Come back and tap **Try Again**.",
                    ])
                default:
                    GuideStepList(steps: [
                        "Tap **Verify Shortcut** below.",
                        "Shortcuts opens and runs **StarHash SMS** on a test message.",
                        "It comes straight back here. Nothing is saved.",
                    ])
                }
            }
            .id(verification)
            .transition(.opacity)
        }
    }

    private var texts: some View {
        Text(catalog: title)
            .font(.starhashTitle)
            .tracking(StarHashTracking.display(28))
            .foregroundStyle(Color.starhashPrimaryText)
            .accessibilityAddTraits(.isHeader)
            .contentTransition(.opacity)
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

    /// The step's action; once it is done, Continue (or Try Again) joins
    /// it side by side, the action stepping back to a glass button, so the
    /// bar stays one button tall and never covers the steps above it.
    /// Stacked only when a large text size will not fit them in a row.
    private var buttons: some View {
        Group {
            if step == 0 {
                if didAct {
                    pair {
                        Button("Add Again", action: addShortcut)
                            .buttonStyle(GuideButtonStyle(prominent: false))
                    } primary: {
                        Button("Continue") { goTo(1) }
                            .buttonStyle(GuideButtonStyle(prominent: true))
                    }
                } else {
                    Button("Add Shortcut", action: addShortcut)
                        .buttonStyle(GuideButtonStyle(prominent: true))
                }
            } else if step == 1 {
                if didAct {
                    pair {
                        Button("Open Again", action: openShortcuts)
                            .buttonStyle(GuideButtonStyle(prominent: false))
                    } primary: {
                        Button("Continue") { goTo(Self.checkStep) }
                            .buttonStyle(GuideButtonStyle(prominent: true))
                    }
                } else {
                    Button("Open Shortcuts", action: openShortcuts)
                        .buttonStyle(GuideButtonStyle(prominent: true))
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

    /// Two buttons in a row, the quieter one first; in a column at large
    /// text sizes.
    private func pair(@ViewBuilder _ secondary: () -> some View, @ViewBuilder primary: () -> some View) -> some View {
        let secondary = secondary(), primary = primary()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                secondary
                primary
            }
            VStack(spacing: 10) {
                primary
                secondary
            }
        }
    }

    @ViewBuilder
    private var verifyButtons: some View {
        switch verification {
        case .verified, .awaitingMessage:
            // Waiting needs nothing more here: the message can come any
            // time, and Settings says auto-verify is waiting until then.
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
        case .idle:
            Button("Verify Shortcut", action: runVerification)
                .buttonStyle(GuideButtonStyle(prominent: true))
        case .failed:
            pair {
                Button("Add Shortcut") { goTo(0) }
                    .buttonStyle(GuideButtonStyle(prominent: false))
            } primary: {
                Button("Try Again", action: runVerification)
                    .buttonStyle(GuideButtonStyle(prominent: true))
            }
        }
    }

    private func addShortcut() {
        StarHashShortcut.install(openURL: openURL)
        didAct = true
    }

    /// Shortcuts' own screen; iOS has no link to its Automation tab.
    private func openShortcuts() {
        if let url = URL(string: "shortcuts://") { openURL(url) }
        didAct = true
    }

    /// Auto-verify is already on by now (`checkVerification`).
    private func finish() {
        if let onDone { onDone() } else { dismiss() }
    }

    private func goBack() {
        if step > 0 {
            goTo(step - 1)
        } else if let onLeave {
            onLeave()
        } else {
            dismiss()
        }
    }

    private func goTo(_ next: Int) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .smooth(duration: 0.45)) {
            step = next
            didAct = false
            verification = .idle
        }
    }

    private func runVerification() {
        verifyStartedAt = autoVerify.shortcutRanAt ?? .distantPast
        withAnimation(.smooth) { verification = .waiting }
        if let url = StarHashShortcut.verificationURL { openURL(url) }
    }

    /// The shortcut ran: auto-verify goes on, counting from now, and the
    /// step waits for a real message through the automation, unless one
    /// has come already.
    private func checkVerification() {
        guard let start = verifyStartedAt, let ran = autoVerify.shortcutRanAt, ran > start else { return }
        verifyStartedAt = nil
        autoVerify.finishSetUp()
        withAnimation(.smooth) { verification = automationProven ? .verified : .awaitingMessage }
    }

    /// A real message has come through the automation since the setup.
    private var automationProven: Bool {
        switch autoVerify.status() {
        case .active, .looksBroken: true
        case .off, .waiting: false
        }
    }
}

/// How a step is laid out between the progress bar and the buttons: the
/// phone's height and the room above it, between it and the title, and
/// under the steps.
private struct GuideLayout: Equatable {
    var phone: CGFloat
    var top: CGFloat
    var middle: CGFloat
    var bottom: CGFloat

    /// The least room in each gap.
    static let top: CGFloat = 20
    static let middle: CGFloat = 28
    static let bottom: CGFloat = 24
    /// The phone's bounds: small enough to leave the words their room on a
    /// small screen or with large text, never so big it crowds them.
    static let minPhone: CGFloat = 200
    static let maxPhone: CGFloat = 440
}

/// The phone both steps draw, sized from its height: Shortcuts' screen in
/// the proportions of the Add Shortcut screenshot (from the top of its
/// sheet down), its corners as round as that sheet's, so the screenshot's
/// own corners and the frame's are one curve and nothing is cut, and a
/// slim bezel round it on the same curve.
private struct GuidePhone {
    let height: CGFloat

    static let bezel: CGFloat = 5
    /// The screenshot's size in pixels, from the top of the sheet.
    static let screenAspect: CGFloat = 1206.0 / 2436.0
    /// The sheet's continuous corner, as a share of the screen's width:
    /// its curve runs 135 pixels in from 1206.
    static let cornerShare: CGFloat = 0.073

    var screen: CGSize {
        let h = height - 2 * Self.bezel
        return CGSize(width: h * Self.screenAspect, height: h)
    }

    var screenShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: screen.width * Self.cornerShare, style: .continuous)
    }

    var bodyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: screen.width * Self.cornerShare + Self.bezel, style: .continuous)
    }
}

extension View {
    /// The phone's bezel, rim and shadow round a screen already clipped to
    /// its shape.
    fileprivate func guidePhoneBody(_ phone: GuidePhone) -> some View {
        padding(GuidePhone.bezel)
            .background(phone.bodyShape.fill(Color(white: 0.09)))
            .overlay(phone.bodyShape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
    }
}

/// A whole real iPhone screen of Shortcuts, in a slim dark phone frame
/// with its corners on the screenshot's own curve, and the control to tap
/// ringed inside the screen.
private struct GuidePhoneScreenshot: View {
    let imageName: String
    let label: String
    /// What to tap, as a share of the image (0...1 on both axes).
    let highlight: CGRect
    let height: CGFloat

    var body: some View {
        let phone = GuidePhone(height: height)
        Image(imageName)
            .resizable()
            .frame(width: phone.screen.width, height: phone.screen.height)
            .overlay { GuideHighlight(rect: highlight, cornerFraction: 0.5) }
            .clipShape(phone.screenShape)
            .guidePhoneBody(phone)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
    }
}

/// Step 2's picture, in the same phone as step 1's and the same size, so
/// both steps lay out alike: Shortcuts' Automation tab, light or dark as the
/// app is, with the real screenshot of the StarHash SMS automation on it,
/// its switch ringed, and a check once the shortcut is verified.
private struct GuideAutomationPhone: View {
    let imageName: String
    let label: String
    let highlight: CGRect
    var isVerified = false
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    /// Shortcuts' own colours, not StarHash's: the tab's grouped background,
    /// its title and the cards of the automations under this one.
    private var tabBackground: Color {
        colorScheme == .dark ? Color(white: 0.07) : Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
    }

    private var tabTitle: Color {
        colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.85)
    }

    private func otherAutomation(_ index: Int) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07 - Double(index) * 0.02)
            : Color.white.opacity(0.9 - Double(index) * 0.3)
    }

    var body: some View {
        let phone = GuidePhone(height: height)
        let screenSize = phone.screen
        ZStack(alignment: .top) {
            tabBackground
            VStack(alignment: .leading, spacing: screenSize.height * 0.03) {
                // Shortcuts' large title, drawn as the screenshots are.
                RoundedRectangle(cornerRadius: 2)
                    .fill(tabTitle)
                    .frame(width: screenSize.width * 0.5, height: screenSize.height * 0.028)
                    .padding(.top, screenSize.height * 0.11)
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .overlay { GuideHighlight(rect: highlight, cornerFraction: 0.5) }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if isVerified {
                            // The tick is cut out of the circle, so the
                            // colour drawn on it sits behind, inside the rim.
                            Image(symbol: "checkmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.starhashConfirmed)
                                .background(Circle().fill(Color.starhashOnConfirmed).padding(5))
                                .background(Circle().fill(tabBackground).padding(2.5))
                                .offset(x: 6, y: -8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                // The automations under it, faded: the tab is a list.
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(otherAutomation(index))
                        .frame(height: screenSize.height * 0.1)
                }
            }
            .padding(.horizontal, screenSize.width * 0.06)
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .clipShape(phone.screenShape)
        .guidePhoneBody(phone)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: isVerified)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isImage)
    }
}

/// A soft ring around the part of a screenshot to look at, breathing
/// gently (still when Reduce Motion is on): white on dark mode's Shortcuts,
/// the near black on light mode's, with a fainter glow there, since a dark
/// glow on white reads as a shadow.
private struct GuideHighlight: View {
    /// A share of the screenshot, 0...1 on both axes.
    let rect: CGRect
    /// Corner radius as a share of the ring's height (0.5 is a capsule).
    let cornerFraction: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var breathes = false

    private var ring: Color { colorScheme == .dark ? .brandPaper : .brandInk }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width * rect.width
            let h = proxy.size.height * rect.height
            // Snug round the control, so it stays inside the screen's
            // rounded corners, breathing included.
            RoundedRectangle(cornerRadius: (h + 6) * cornerFraction, style: .continuous)
                .strokeBorder(ring, lineWidth: 2.5)
                .shadow(color: ring.opacity(colorScheme == .dark ? 0.7 : 0.35), radius: 6)
                .frame(width: w + 6, height: h + 6)
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

/// Numbered steps for the person to follow, in StarHash's outlined card
/// (Settings' and a transaction's, which Ijwi's cards follow too): a line
/// round them on the page's own colour, solid lines between them from
/// where the words start. Each number in a small ink disc, the text beside
/// it. With `symbol`, every disc shows that symbol instead (a tick for
/// what now works).
private struct GuideStepList: View {
    let steps: [LocalizedStringKey]
    var symbol: String?
    /// Ticked in the confirmed green: what works now the check passed.
    var confirmed = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 { StarHashRowSeparator(leading: 54, trailing: 16) }
                // The disc in the middle of its step, however many lines
                // the step runs to.
                HStack(alignment: .center, spacing: 14) {
                    Group {
                        if let symbol {
                            Image(symbol: symbol)
                                .font(.system(size: 12, weight: .heavy))
                        } else {
                            Text("\(index + 1)")
                                .starhashFont(14, weight: .bold, relativeTo: .subheadline)
                        }
                    }
                        .foregroundStyle(confirmed ? AnyShapeStyle(Color.starhashOnConfirmed) : AnyShapeStyle(Color.starhashOnInk))
                        .frame(width: 24, height: 24)
                        .background(confirmed ? AnyShapeStyle(Color.starhashConfirmed) : AnyShapeStyle(Color.starhashInk), in: Circle())
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
        .starhashOutlinedCard(padding: EdgeInsets())
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
                    .fill(index <= current ? AnyShapeStyle(Color.starhashAccentGraphic) : AnyShapeStyle(Color.starhashPrimaryText.opacity(0.15)))
                    .frame(height: 5)
            }
        }
        .frame(maxWidth: 220)
        .animation(.smooth(duration: 0.4), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}
