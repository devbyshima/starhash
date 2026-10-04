import StoreKit
import SwiftUI

/// Shima's note, in two versions, laid out as a letter: a round photo,
/// "A note from Shima", the note left aligned, the signature, and a button
/// with "Write to Shima" under it.
///
/// - `welcome`, over Pay as onboarding ends (and Settings, About StarHash,
///   Developer Note): why StarHash exists, free, open source and private,
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
            "It's free and open source, and it's private: no account, no server, no tracking. Everything stays on your iPhone.",
            "I hope it makes paying a little easier. Enjoy it.",
        ]
        case .review: [
            "You've been using StarHash for two weeks now. Thank you.",
            "I made it on my own, because USSD made paying harder than it should be.",
            "StarHash is free and open source, with no ads, no account and nothing sent off your iPhone. There is nothing to buy.",
            "So if you love it, a rating on the App Store is all I ask. It helps someone else find an easier way to pay.",
            "If something is off, write to me first. I answer you myself.",
        ]
        }
    }
}

/// The note's content, shared by the sheets. The letter and its buttons
/// are one block, centred on the page, as the reference sets them; a long
/// Dynamic Type size scrolls instead.
struct DeveloperNoteContent: View {
    let kind: DeveloperNoteKind
    let primaryTitle: String
    let primaryAction: () -> Void
    /// The note onboarding ends on stops at its button.
    var showsWriteLink = true

    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                letter
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
    }

    private var letter: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeveloperAvatar()
                .padding(.bottom, 16)
            Text("A note from Shima")
                .starhashFont(29, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color.starhashPrimaryText)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 18)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(kind.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .starhashFont(16.5, relativeTo: .body)
                        .lineSpacing(3)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // A signature, so a script face: iOS's own Snell Roundhand, the
            // one text not set in Space Grotesk.
            Text("Shima")
                .font(.custom("SnellRoundhand", size: 50, relativeTo: .largeTitle))
                .foregroundStyle(Color.starhashPrimaryText)
                .padding(.top, 14)
                .accessibilityLabel("Signed, Shima")

            VStack(spacing: 0) {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.sheetPrimary)
                if showsWriteLink {
                    Button {
                        openURL(DeveloperNoteLinks.write)
                    } label: {
                        Text("Write to Shima")
                            .starhashFont(14, relativeTo: .subheadline)
                            .foregroundStyle(Color.starhashSecondaryText)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.hapticPlain)
                    .accessibilityHint("Opens a new message to Shima on GitHub")
                }
            }
            .padding(.top, 30)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
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
            .overlay { Circle().strokeBorder(Color.starhashPrimaryText.opacity(0.1), lineWidth: 1) }
            .accessibilityHidden(true)
    }
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
/// Developer Note, it ends on Done with Write to Shima under it.
struct DeveloperNoteSheet: View {
    var afterOnboarding = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NoteSheetFrame(onClose: { dismiss() }) {
            DeveloperNoteContent(
                kind: .welcome,
                primaryTitle: afterOnboarding ? "Start Using StarHash" : "Done",
                primaryAction: { dismiss() },
                showsWriteLink: !afterOnboarding
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
        NoteSheetFrame(onClose: { dismiss() }) {
            DeveloperNoteContent(kind: .review, primaryTitle: "Rate on the App Store") {
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
            }
        }
    }
}

/// A full-height sheet with a bare close cross at its top right and no
/// grabber, as the reference draws it.
private struct NoteSheetFrame<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    SheetGlassGlyph(symbol: "xmark")
                }
                .buttonStyle(.hapticPlain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.noteSheetBackground.ignoresSafeArea())
        .sheetGlass(detents: [.large])
        .presentationDragIndicator(.hidden)
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
