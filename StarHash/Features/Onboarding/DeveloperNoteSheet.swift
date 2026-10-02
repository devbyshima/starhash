import SwiftUI

/// A note from the developer, as Keaser's welcome letter: shown once over
/// the app right after onboarding, and again from Settings, StarHash,
/// Developer Note. Dismissing it (Continue, the close button, or a swipe)
/// marks it seen; RootView owns that flag.
struct DeveloperNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsSummary = DeveloperNoteLaunch.showsSummary

    /// How much of the text shows below the button, as in Keaser.
    private static let belowButtonOpacity = 0.17

    /// The home indicator's inset, where the text below the button fades out.
    @State private var bottomSafeArea: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            letter
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .starhashReadableWidth()
                // The text stays fully opaque until it reaches the button,
                // which floats over it without a bar behind it, and shows
                // faintly below it, fading out toward the bottom edge. The
                // mask only uses alpha, so its black is not a colour.
                .mask {
                    ZStack {
                        VStack(spacing: 0) {
                            Color.black.opacity(Self.belowButtonOpacity)
                            LinearGradient(colors: [.black.opacity(Self.belowButtonOpacity), .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: bottomSafeArea)
                        }
                        .ignoresSafeArea(edges: .bottom)
                        VStack(spacing: 0) {
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 24)
                        }
                    }
                }

            StarHashCircleButton("xmark", label: "Close") { dismiss() }
                .padding(16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Continue") { dismiss() }
                .buttonStyle(.starhashPrimary)
                .padding(.horizontal, 28)
                .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomSafeArea = $0 }
        .presentationDetents([.large])
        .starhashSheetChrome()
    }

    private var letter: some View {
        ScrollView {
            VStack(spacing: 0) {
                StarHashMark(size: 104)
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)
                Text("Welcome to\nStarHash 🎉")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.starhashPrimaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 28)
                VStack(alignment: .leading, spacing: 26) {
                    Button {
                        withAnimation(.smooth(duration: 0.4)) { showsSummary.toggle() }
                    } label: {
                        Text(showsSummary ? "Click for the full note" : "Click for TL;DR")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.starhashPrimaryText)
                            .contentTransition(.opacity)
                    }
                    .buttonStyle(.plain)
                    ZStack(alignment: .topLeading) {
                        if showsSummary {
                            NoteText(paragraphs: DeveloperNote.summary)
                                .transition(textTransition)
                        } else {
                            NoteText(paragraphs: DeveloperNote.paragraphs)
                                .transition(textTransition)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 52)
                .padding(.horizontal, 45)
                .padding(.bottom, 40)
            }
            .padding(.top, 70)
        }
        .scrollIndicators(.hidden)
    }

    private var textTransition: AnyTransition {
        reduceMotion ? .opacity : AnyTransition(.blurReplace)
    }
}

/// Paragraphs separated by a blank line, as in a letter.
private struct NoteText: View {
    let paragraphs: [LocalizedStringKey]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.body)
        .foregroundStyle(Color.starhashPrimaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The note's copy. Markdown bold marks a path in the app.
private enum DeveloperNote {
    static var paragraphs: [LocalizedStringKey] { [
        "Hi there 👋, a quick note from the developer.",
        "Thank you for giving StarHash a try. It's brand new, so your first impressions mean a lot.",
        "StarHash makes MoMo quicker. Type an amount, pick who gets it, and it dials the USSD code for you. Your PIN only ever goes into MTN's own prompt, and StarHash never moves money by itself.",
        "There's no sign-in, no server and no tracking. Your payments stay on your iPhone, and with auto-verify your M\u{2011}Money messages confirm each one for you.",
        "StarHash is free and open source. If you have an idea, or something doesn't feel right, you'll find the code on GitHub from **Help > Source code**. Each update is listed in **Settings > What's New**.",
        "I'm glad you're here. Happy paying!",
    ] }

    static var summary: [LocalizedStringKey] { [
        "Type an amount, pick who, and StarHash dials MoMo for you.\nFree, open source and private. Updates: **Settings > What's New**.",
    ] }
}

/// `-note` (DEBUG only) shows the note; `-noteTLDR` opens it on the TL;DR.
enum DeveloperNoteLaunch {
    @MainActor static var showsSummary: Bool {
        #if DEBUG
        DebugLaunch.arguments.contains("-noteTLDR")
        #else
        false
        #endif
    }

    @MainActor static var forcesNote: Bool {
        #if DEBUG
        DebugLaunch.arguments.contains("-note") || DebugLaunch.arguments.contains("-noteTLDR")
        #else
        false
        #endif
    }
}
