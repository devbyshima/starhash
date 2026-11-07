import StoreKit
import SwiftUI

/// Shima's note, in two versions, laid out as a letter: a round photo,
/// "A note from Shima", the note left aligned, the signature, and a button
/// with "Write to Shima" under it (and, from Settings, "Buy Shima a coffee"
/// beside it).
///
/// - `welcome`, over Pay as onboarding ends (and Settings, About StarHash,
///   Developer Note): why StarHash exists, free, source-available and private,
///   and enjoy it. No rating ask, and after onboarding no Write to Shima.
/// - `review`, once, after two weeks of use (`ReviewNote`): some of the
///   same, then the one ask: if you love it, rate it.
enum DeveloperNoteKind {
    case welcome
    case review

    var paragraphs: [LocalizedStringKey] {
        switch self {
        case .welcome: [
            "Hi, I'm Shima, and I made StarHash.",
            "I built it because I was tired of how hard USSD makes paying. Typing codes and digging through menus for the things you do every day felt wrong, so StarHash does them in a few taps.",
            "It's free, its source code is public, and it's private: no account, no tracking. Your payments stay on your iPhone.",
            "I hope it makes paying a little easier. Enjoy it.",
        ]
        case .review: [
            "You've been using StarHash for two weeks now. Thank you.",
            "I made it on my own, because USSD made paying harder than it should be.",
            "StarHash is free, with public source code, no ads, no account, and your payments never leave your iPhone. There is nothing to buy.",
            "So if you love it, a rating on the App Store is all I ask. It helps someone else find an easier way to pay.",
            "If something is off, write to me first. I answer you myself.",
        ]
        }
    }
}

/// The note's content, shared by the sheets: the letter and its buttons as
/// one block from the top of the sheet, which fits its height to them
/// (`height`), so there is no empty band above or below; a long Dynamic
/// Type size scrolls instead. The photo shares its row with the sheet's
/// close cross.
struct DeveloperNoteContent: View {
    let kind: DeveloperNoteKind
    let primaryTitle: String
    let primaryAction: () -> Void
    /// The note onboarding ends on stops at its button.
    var showsWriteLink = true
    /// Settings' note also offers Ko-fi. Never the note onboarding ends on,
    /// nor the two-week one, whose one ask is the rating.
    var showsSupportLink = false
    /// The letter's whole height, for the sheet's detent.
    var height: Binding<CGFloat> = .constant(0)

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            letter
                .frame(maxWidth: .infinity)
                .sheetHeight(height)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
    }

    private var hasLinks: Bool { showsWriteLink || showsSupportLink }

    private var letter: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeveloperAvatar()
                .padding(.bottom, NoteLayout.avatarGap)
            Text("A note from Shima")
                .starhashFont(29, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color.noteBrandText)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, NoteLayout.titleGap)
            VStack(alignment: .leading, spacing: NoteLayout.paragraphGap) {
                ForEach(Array(kind.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .starhashFont(16.5, relativeTo: .body)
                        .lineSpacing(NoteLayout.lineSpacing)
                        .foregroundStyle(Color.noteBrandText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // A signature, so a script face: iOS's own Snell Roundhand, the
            // one text not set in Space Grotesk.
            Text("Shima")
                .font(.custom("SnellRoundhand", size: 50, relativeTo: .largeTitle))
                .foregroundStyle(Color.noteBrandText)
                .padding(.top, NoteLayout.signatureGap)
                .accessibilityLabel("Signed, Shima")

            VStack(spacing: 0) {
                Button(LocalizedStringKey(primaryTitle), action: primaryAction)
                    .buttonStyle(NoteButtonStyle())
                // Side by side, so the note keeps the one row of links the
                // reference has; stacked when a large text size won't fit.
                if hasLinks {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 0) { links }
                        VStack(spacing: 0) { links }
                    }
                }
            }
            .padding(.top, NoteLayout.buttonGap)
        }
        .padding(.horizontal, NoteLayout.sideMargin)
        .padding(.top, NoteLayout.topMargin)
        // The links' rows carry their own room under them.
        .padding(.bottom, hasLinks ? 4 : NoteLayout.bottomMargin)
    }

    @ViewBuilder private var links: some View {
        if showsWriteLink {
            link("Write to Shima", to: DeveloperNoteLinks.write, hint: "Opens a new message to Shima on GitHub")
        }
        if showsSupportLink {
            link("Buy Shima a coffee", to: SettingsLinks.koFi, hint: "Opens Shima's Ko-fi page")
        }
    }

    private func link(_ title: LocalizedStringKey, to url: URL, hint: LocalizedStringKey) -> some View {
        Button {
            openURL(url)
        } label: {
            Text(title)
                .starhashFont(14, relativeTo: .subheadline)
                .foregroundStyle(Color.noteBrandSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityHint(hint)
    }
}

/// The round picture at the top: Shima's photo, whole, in the circle the
/// reference has its maker in.
private struct DeveloperAvatar: View {
    var body: some View {
        Image("DeveloperPhoto")
            .resizable()
            .scaledToFill()
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay { Circle().strokeBorder(Color.noteBrandText.opacity(0.15), lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

/// The note's spacing: the same breath between every part of the letter,
/// a little more round the title and the button, and the photo's centre
/// level with the close cross's.
private enum NoteLayout {
    static let sideMargin: CGFloat = 28
    static let topMargin: CGFloat = 24
    static let bottomMargin: CGFloat = 24
    static let avatarGap: CGFloat = 22
    static let titleGap: CGFloat = 18
    static let paragraphGap: CGFloat = 16
    static let lineSpacing: CGFloat = 5
    static let signatureGap: CGFloat = 16
    static let buttonGap: CGFloat = 28
    /// The close cross's top: its 44pt circle centred on the 60pt photo.
    static let closeTop: CGFloat = topMargin + 8
}

enum DeveloperNoteLinks {
    /// A new issue on StarHash's public repo: writing to Shima without an
    /// email address in the app's open code.
    static let write = URL(string: "https://github.com/devbyshima/starhash/issues/new")!

    /// StarHash's App Store id, from its App Store Connect record (App
    /// Information, Apple ID). Nil until the record exists.
    static let appStoreID: String? = nil

    /// The App Store's Write a Review page for StarHash, once the id is set.
    static var writeReview: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}

/// The welcome note. As onboarding ends it opens over Pay, ends on Start
/// Using StarHash, and closes to Pay; from Settings, About StarHash,
/// Developer Note, it ends on Done with Write to Shima and Buy Shima a
/// coffee under it.
struct DeveloperNoteSheet: View {
    var afterOnboarding = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NoteSheetFrame(onClose: { dismiss() }) { height in
            DeveloperNoteContent(
                kind: .welcome,
                primaryTitle: afterOnboarding ? "Start Using StarHash" : "Done",
                primaryAction: { dismiss() },
                showsWriteLink: !afterOnboarding,
                showsSupportLink: !afterOnboarding,
                height: height
            )
        }
    }
}

/// The two-week note, with its one ask: Rate on the App Store opens the App
/// Store's Write a Review page. iOS may skip its own rating prompt (it
/// limits how often it shows, and never shows it in TestFlight), so the
/// prompt is only the stand-in until the App Store id is known.
struct ReviewNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NoteSheetFrame(onClose: { dismiss() }) { height in
            DeveloperNoteContent(kind: .review, primaryTitle: "Rate on the App Store", primaryAction: {
                dismiss()
                Task {
                    // Once the sheet has gone, so the prompt is not under it.
                    try? await Task.sleep(for: .milliseconds(500))
                    if let page = DeveloperNoteLinks.writeReview {
                        openURL(page)
                    } else {
                        requestReview()
                    }
                }
            }, height: height)
        }
    }
}

/// A sheet as tall as its letter, with a bare close cross at its top right,
/// level with the photo, and no grabber, as the reference draws it.
private struct NoteSheetFrame<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: (Binding<CGFloat>) -> Content
    @Environment(\.colorScheme) private var colorScheme
    @State private var height: CGFloat = 0

    var body: some View {
        content($height)
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    SheetGlassGlyph(symbol: "xmark")
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel("Close")
                .padding(.trailing, 18)
                .padding(.top, NoteLayout.closeTop)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The page turned over, so the note stands apart from the page it
            // opens over: near black in light mode, near white in dark, its
            // glass and words the other appearance's on it.
            .background(Color.noteBrandBackground.ignoresSafeArea())
            .environment(\.colorScheme, colorScheme == .dark ? .light : .dark)
            .starhashContainerSurface()
            .sheetGlass(detents: [height > 0 ? .height(height + 8) : .large])
            .presentationBackground(Color.noteBrandPresentation)
            .presentationDragIndicator(.hidden)
    }
}

/// The note's button: the note's words colour with its page colour on it,
/// the other way round from the page, at a sheet button's size.
private struct NoteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sheet(17, .semibold, relativeTo: .headline))
            .foregroundStyle(Color.noteBrandButtonLabel)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.noteBrandButton, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
            .starhashPressHaptic(configuration.isPressed, weight: .medium)
    }
}

/// When the two-week note is due: two weeks after StarHash was first set
/// up, once.
@MainActor
enum ReviewNote {
    static let delay: TimeInterval = 14 * 24 * 3600

    /// Marks the start of the two weeks, if not already marked (an install
    /// from before this note starts counting from now).
    static func startClockIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.double(forKey: PreferenceKey.firstUsedAt) == 0 {
            defaults.set(Date.now.timeIntervalSince1970, forKey: PreferenceKey.firstUsedAt)
        }
    }

    static func isDue(now: Date = .now) -> Bool {
        #if DEBUG
        if DebugLaunch.arguments.contains("-reviewNote") { return true }
        #endif
        let defaults = UserDefaults.standard
        let start = defaults.double(forKey: PreferenceKey.firstUsedAt)
        guard start > 0, !defaults.bool(forKey: PreferenceKey.hasSeenReviewNote) else { return false }
        return now.timeIntervalSince1970 - start >= delay
    }
}

/// `-note` (DEBUG only) shows the welcome note over Pay, as onboarding
/// ends; `-reviewNote` the two-week one.
enum DeveloperNoteLaunch {
    @MainActor static var forcesNote: Bool {
        #if DEBUG
        DebugLaunch.arguments.contains("-note")
        #else
        false
        #endif
    }
}
