import StoreKit
import SwiftUI

/// Shima's note, in two versions, laid out as a letter: a round picture,
/// "A note from Shima", the note left aligned, the signature, and a button
/// with "Write to Shima" under it.
///
/// - `welcome`, the last onboarding screen (and Settings, About StarHash,
///   Developer Note): why StarHash exists, free, open source and private,
///   and enjoy it. No rating ask.
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
        ]
        }
    }
}

/// The note's content, shared by onboarding's last screen and the sheets.
struct DeveloperNoteContent: View {
    let kind: DeveloperNoteKind
    let primaryTitle: String
    let primaryAction: () -> Void
    /// Onboarding's buttons glow, as its others do.
    var glows = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DeveloperAvatar()
                        .padding(.bottom, 18)
                    Text("A note from Shima")
                        .starhashFont(28, weight: .bold, relativeTo: .title)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 16)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(kind.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(.starhash(.body))
                                .foregroundStyle(Color.starhashPrimaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    // A signature, so a script face: iOS's own Snell
                    // Roundhand, the one text not set in Space Grotesk.
                    Text("Shima")
                        .font(.custom("SnellRoundhand-Bold", size: 44, relativeTo: .largeTitle))
                        .foregroundStyle(Color.starhashPrimaryText)
                        .padding(.top, 20)
                        .accessibilityLabel("Signed, Shima")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 4) {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(glows ? .starhashPrimaryGlowing : .starhashPrimary)
                Button {
                    openURL(DeveloperNoteLinks.write)
                } label: {
                    Text("Write to Shima")
                        .font(.starhash(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.starhashSecondaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens a new message to Shima on GitHub")
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 8)
        }
        .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
    }
}

/// The round picture at the top: the StarHash star on a white disc, until a
/// photo of Shima takes its place.
private struct DeveloperAvatar: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 60, height: 60)
            .overlay {
                StarHashMarkShape()
                    .fill(Color.brandBlue)
                    .padding(13)
            }
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            .accessibilityHidden(true)
    }
}

enum DeveloperNoteLinks {
    /// A new issue on StarHash's public repo: writing to Shima without an
    /// email address in the app's open code.
    static let write = URL(string: "https://github.com/devbyshima/starhash/issues/new")!
}

/// The welcome note as a sheet, from Settings, About StarHash, Developer
/// Note: a close button on the right, and Done.
struct DeveloperNoteSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NoteSheetFrame(onClose: { dismiss() }) {
            DeveloperNoteContent(kind: .welcome, primaryTitle: "Done") { dismiss() }
        }
    }
}

/// The two-week note, with its one ask: Rate StarHash brings up the App
/// Store's own rating prompt.
struct ReviewNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NoteSheetFrame(onClose: { dismiss() }) {
            DeveloperNoteContent(kind: .review, primaryTitle: "Rate StarHash") {
                dismiss()
                Task {
                    // Once the sheet has gone, so the prompt is not under it.
                    try? await Task.sleep(for: .milliseconds(500))
                    requestReview()
                }
            }
        }
    }
}

/// A full-height sheet with the round close button at its top right, as
/// the reference draws it.
private struct NoteSheetFrame<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                StarHashCircleButton("xmark", label: "Close", action: onClose)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass(detents: [.large])
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

/// `-note` (DEBUG only) shows the welcome note over the app;
/// `-reviewNote` the two-week one.
enum DeveloperNoteLaunch {
    @MainActor static var forcesNote: Bool {
        #if DEBUG
        DebugLaunch.arguments.contains("-note")
        #else
        false
        #endif
    }
}
