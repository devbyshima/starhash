import SwiftUI

/// The six-page first-run flow, in Keaser's onboarding look: page dots at
/// the top, a picture in the middle, a big title and grey subtitle, and an
/// ink capsule at the bottom. Calls `onFinish` after the last page.
///
/// Pages advance only with the button (no swiping), so every picture's
/// entrance plays from the start and the Contacts question is asked at the
/// moment its page explains why.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = OnboardingLaunch.initialPage

    static let pageCount = 6

    var body: some View {
        ZStack {
            OnboardingPalette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                OnboardingPageIndicator(count: Self.pageCount, current: page)
                    .padding(.top, 16)
                ZStack {
                    currentPage
                        .id(page)
                        .transition(reduceMotion ? .opacity : .push(from: .trailing))
                }
                .padding(.top, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch page {
        case 0:
            OnboardingPage(
                title: "Welcome to StarHash",
                subtitle: "No more USSD hassles. Type an amount, pick who, and StarHash dials the code.",
                button: "Continue",
                illustrationHeight: 330,
                pictureHeight: 250,
                action: advance
            ) {
                SamplePaymentsIllustration()
            } accessory: {
                StarHashMark(size: 104)
                    .frame(width: 130, height: 130)
                    .padding(.bottom, 12)
                    // The title right below already says "StarHash".
                    .accessibilityHidden(true)
            }
        case 1:
            OnboardingNumberPage(onDone: advance)
        case 2:
            OnboardingPage(
                title: "Pay Anyone",
                subtitle: "Send to any MTN number, or pay a MoMo Pay merchant code. StarHash knows which is which.",
                button: "Continue",
                action: advance
            ) {
                PayAnyoneIllustration()
            }
        case 3:
            OnboardingPage(
                title: "Your Contacts,\nOne Tap Away",
                subtitle: "Pick who to pay from your contacts. They stay on your iPhone.",
                button: "Continue",
                action: {
                    Task {
                        await SettingsContactsAccess.request()
                        advance()
                    }
                }
            ) {
                ContactsIllustration()
            }
        case 4:
            OnboardingPage(
                title: "Every Payment,\nLogged",
                subtitle: "Activity keeps each payment by day. Set up auto-verify in Settings and MTN's SMS confirms every one.",
                button: "Continue",
                action: advance
            ) {
                ActivityIllustration()
            }
        default:
            OnboardingPage(
                title: "You're All Set",
                subtitle: "Type an amount to make your first payment. Your PIN is still only ever typed into MTN's own prompt.",
                button: "Get Started",
                action: onFinish
            ) {
                ReadyIllustration()
            }
        }
    }

    private func advance() {
        guard page < Self.pageCount - 1 else { return onFinish() }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .smooth(duration: 0.5)) { page += 1 }
    }
}

// MARK: - Page layout

/// One onboarding page: a picture in a fixed band at the top, the title and
/// subtitle at the bottom, and the button pinned below them.
///
/// Everything but the button scrolls, so at large text sizes the page grows
/// into a scrolling column instead of pushing the button off screen. At the
/// default size the column exactly fills the screen and nothing moves.
private struct OnboardingPage<Illustration: View, Accessory: View>: View {
    let title: String
    let subtitle: String
    let button: String
    /// The band the picture is centred in. A fixed band (rather than the
    /// space left over) keeps pictures at the same height whether the title
    /// takes one line or two.
    var illustrationHeight: CGFloat = 480
    /// The least the picture needs; the band never shrinks below it.
    var pictureHeight: CGFloat = 320
    let action: () -> Void
    @ViewBuilder var illustration: Illustration
    @ViewBuilder var accessory: Accessory

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { viewport in
                ScrollView {
                    VStack(spacing: 0) {
                        band
                        accessory
                        texts
                    }
                    .padding(.bottom, 28)
                    .frame(minHeight: viewport.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            Button(button, action: action)
                .buttonStyle(.starhashPrimary)
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.bottom, 8)
        }
    }

    /// The picture keeps its default-size look at every text size; at
    /// accessibility sizes the whole picture is drawn smaller to leave the
    /// screen to the words.
    private var band: some View {
        let scale = OnboardingMetrics.pictureScale(for: dynamicTypeSize)
        let minimum = pictureHeight * scale
        return illustration
            .dynamicTypeSize(.large)
            .scaleEffect(scale)
            .frame(maxWidth: .infinity, minHeight: minimum, maxHeight: scale < 1 ? minimum : illustrationHeight)
            .frame(maxHeight: .infinity, alignment: .center)
    }

    private var texts: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.starhashTitle)
                .foregroundStyle(Color.starhashPrimaryText)
                .lineSpacing(1.5)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(Color.starhashSecondaryText)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, OnboardingMetrics.horizontalPadding)
    }
}

extension OnboardingPage where Accessory == EmptyView {
    init(
        title: String,
        subtitle: String,
        button: String,
        illustrationHeight: CGFloat = 480,
        pictureHeight: CGFloat = 320,
        action: @escaping () -> Void,
        @ViewBuilder illustration: () -> Illustration
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            button: button,
            illustrationHeight: illustrationHeight,
            pictureHeight: pictureHeight,
            action: action,
            illustration: illustration,
            accessory: { EmptyView() }
        )
    }
}

/// One dot per page; the current page is a wider ink capsule.
private struct OnboardingPageIndicator: View {
    let count: Int
    let current: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.starhashInk : OnboardingPalette.inactiveDot)
                    .frame(width: index == current ? 24 : 6, height: 6)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

enum OnboardingMetrics {
    static let horizontalPadding: CGFloat = 28

    /// At accessibility text sizes the pictures shrink so the title,
    /// subtitle and button keep most of the screen.
    static func pictureScale(for size: DynamicTypeSize) -> CGFloat {
        size.isAccessibilitySize ? 0.6 : 1
    }
}

/// Shades used only by onboarding, after Keaser's: a lifted black page in
/// dark mode (so the sample rows can sink into it), the app's pale grey in
/// light mode.
enum OnboardingPalette {
    static let background = Color(light: .init(white: 245 / 255), dark: .init(white: 25 / 255))
    static let inactiveDot = Color(light: .black.opacity(0.25), dark: .white.opacity(0.36))
    /// Sample rows: black pills sunk into the page in dark mode, white
    /// cards on the grey page in light mode.
    static let pill = Color(light: .white, dark: .black)
    static let pillRimTop = Color(light: .black.opacity(0.03), dark: .white.opacity(0.03))
    static let pillRimBottom = Color(light: .black.opacity(0.08), dark: .white.opacity(0.12))
    /// Icon tiles and monograms on the sample rows.
    static let tile = Color(light: .init(white: 238 / 255), dark: .init(white: 0.2))
}

// MARK: - Launch arguments

/// `-onboardingPage 0...5` (DEBUG, with `-resetOnboarding`) starts on that
/// page.
@MainActor
enum OnboardingLaunch {
    static var initialPage: Int {
        #if DEBUG
        let page = DebugLaunch.value(after: "-onboardingPage").flatMap(Int.init) ?? 0
        return min(max(page, 0), OnboardingView.pageCount - 1)
        #else
        return 0
        #endif
    }
}
