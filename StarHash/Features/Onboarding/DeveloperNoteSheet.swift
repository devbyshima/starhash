import SwiftUI

/// A note from the developer, in Beam's sheet language (its About sheet):
/// the title, the StarHash mark over a short heading, and the note in a
/// card, with a TL;DR switch for the one-paragraph version and Continue at
/// the bottom. Shown once over the app right after onboarding, and again
/// from Settings, StarHash, Developer Note. Dismissing it (Continue or a
/// swipe) marks it seen; RootView owns that flag.
struct DeveloperNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsSummary = DeveloperNoteLaunch.showsSummary

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader("Developer Note")
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        StarHashMark(size: 72)
                            .accessibilityHidden(true)
                        Text("Welcome to StarHash 🎉")
                            .font(.sheet(21, .bold, relativeTo: .title2))
                            .foregroundStyle(Color.starhashPrimaryText)
                            .multilineTextAlignment(.center)
                        Text("A quick note from the developer")
                            .font(.sheetCaption)
                            .foregroundStyle(Color.sheetSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(showsSummary ? "TL;DR" : "The note")
                                .font(.sheetHeadline)
                                .foregroundStyle(Color.starhashPrimaryText)
                                .contentTransition(.opacity)
                            Spacer(minLength: 8)
                            Button {
                                withAnimation(.smooth(duration: 0.4)) { showsSummary.toggle() }
                            } label: {
                                Text(showsSummary ? "Full note" : "TL;DR")
                                    .font(.sheet(11, .bold, relativeTo: .caption))
                                    .tracking(0.5)
                                    .foregroundStyle(Color.sheetSecondaryText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.starhashPrimaryText.opacity(0.08)))
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
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
                    .padding(16)
                    .sheetCard()
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .starhashReadableScrollContent()

            Button("Continue") { dismiss() }
                .buttonStyle(.sheetPrimary)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
                .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass(detents: [.large])
    }

    private var textTransition: AnyTransition {
        reduceMotion ? .opacity : AnyTransition(.blurReplace)
    }
}

/// Paragraphs with a line between them, in Beam's About text style.
private struct NoteText: View {
    let paragraphs: [LocalizedStringKey]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.sheetSubheadline)
        .foregroundStyle(Color.sheetSecondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The note's copy. Markdown bold marks a path in the app.
private enum DeveloperNote {
    static var paragraphs: [LocalizedStringKey] { [
        "Hi there 👋, a quick note from the developer.",
        "Thank you for giving StarHash a try. It's brand new, so your first impressions mean a lot.",
        "StarHash makes MoMo quicker. Type an amount, pick who gets it, and it dials the USSD code for you. Your PIN only ever goes into your wallet's own prompt, and StarHash never moves money by itself.",
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
