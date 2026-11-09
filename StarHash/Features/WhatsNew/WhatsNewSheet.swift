import StarHashKit
import SwiftUI

/// What's New, once, after an update (`WhatsNewLaunch`): a first page
/// listing the release's news, then a page for each feature, its video on
/// a card (black in light mode, white in dark, the app in the video in the
/// appearance the person is in) over its name and a few
/// lines, with the page dots and Next (Done on the last page) under them
/// all. The sheet fits the page showing: on the list, just as tall as the
/// list; on a feature, as tall as the card and the longest feature's words,
/// growing from one to the other as the pages turn. Measured from Cift's,
/// in StarHash's type, colours and sheet glass.
struct WhatsNewSheet: View {
    let announcement: Release.Announcement
    /// The window's width and the bottom of its safe area, which set the
    /// sheet's height: the cards are square, as wide as the sheet.
    let window: WhatsNewWindow

    @Environment(\.dismiss) private var dismiss
    @State private var page: Int
    /// The tallest feature's words, and the list's title and rows, as laid
    /// out at the sheet's width: the sheet is made tall enough for the page
    /// showing and no taller.
    @State private var textHeight = WhatsNewMetrics.textEstimate
    @State private var summaryHeight = WhatsNewMetrics.summaryEstimate
    /// The height showing, one of the two `detents`: the sheet moves
    /// between them on the system's spring as the page changes, by Next or
    /// a swipe alike.
    @State private var detent: PresentationDetent

    init(announcement: Release.Announcement, window: WhatsNewWindow, startPage: Int = 0) {
        self.announcement = announcement
        self.window = window
        let first = min(max(startPage, 0), announcement.pages.count)
        _page = State(initialValue: first)
        _detent = State(initialValue: first == 0
            ? .height(WhatsNewMetrics.summarySheetHeight(in: window, summaryHeight: WhatsNewMetrics.summaryEstimate))
            : .height(WhatsNewMetrics.featureSheetHeight(in: window, textHeight: WhatsNewMetrics.textEstimate)))
    }

    private var pageCount: Int { announcement.pages.count + 1 }
    private var isLastPage: Bool { page == pageCount - 1 }

    /// The list's height, and the features'.
    private var summaryDetent: PresentationDetent {
        .height(WhatsNewMetrics.summarySheetHeight(in: window, summaryHeight: summaryHeight))
    }

    private var featureDetent: PresentationDetent {
        .height(WhatsNewMetrics.featureSheetHeight(in: window, textHeight: textHeight))
    }

    /// The one the page showing needs.
    private var wantedDetent: PresentationDetent {
        page == 0 ? summaryDetent : featureDetent
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                WhatsNewSummaryPage(highlights: announcement.highlights)
                    .tag(0)
                ForEach(Array(announcement.pages.enumerated()), id: \.offset) { index, feature in
                    WhatsNewFeaturePage(feature: feature, isShowing: page == index + 1)
                        .tag(index + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            WhatsNewPageDots(count: pageCount, current: page)
                .padding(.vertical, WhatsNewMetrics.dotsMargin)
                .layoutPriority(1)

            Button {
                if isLastPage {
                    dismiss()
                } else {
                    // The sheet grows on the same spring as the page turns.
                    withAnimation(.smooth) { page += 1 }
                }
            } label: {
                Text(isLastPage ? "Done" : "Next")
                    .contentTransition(.opacity)
            }
            .buttonStyle(PrimaryButtonStyle(height: WhatsNewMetrics.buttonHeight))
            .animation(.smooth(duration: 0.2), value: isLastPage)
            .padding(.horizontal, WhatsNewMetrics.buttonInset)
            // The pages give way, never the button.
            .layoutPriority(1)
        }
        .padding(.bottom, WhatsNewMetrics.bottomMargin)
        // The list, and every feature's words, unseen, at the pages' width:
        // the list sets the sheet's height on the first page and the
        // tallest words on the rest, so no page keeps empty room.
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                WhatsNewSummaryContent(highlights: announcement.highlights)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { summaryHeight = $0 }
                ZStack(alignment: .top) {
                    ForEach(Array(announcement.pages.enumerated()), id: \.offset) { _, feature in
                        WhatsNewFeatureText(feature: feature)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
            }
            .hidden()
            .accessibilityHidden(true)
        }
        // Every measure is from the sheet's own edges, as Cift's: the paged
        // view lays its pages out over the sheet's safe area anyway, so the
        // rest follows it there.
        .ignoresSafeArea()
        // Solid, as the notes' sheets: the page behind would show through
        // clear glass and blur Pay's buttons into the corners.
        .background(Color.noteSheetBackground.ignoresSafeArea())
        .starhashContainerSurface()
        .sheetGlass(detents: [summaryDetent, featureDetent], selection: $detent)
        // The page, or a measure coming in, picks the height; a drag to
        // the other one is sent back, since it would cut the page off.
        .onChange(of: wantedDetent, initial: true) { _, wanted in
            if detent != wanted { detent = wanted }
        }
        .onChange(of: detent) { _, now in
            if now != wantedDetent { detent = wantedDetent }
        }
        .presentationDragIndicator(.hidden)
    }
}

/// The window the sheet opens in: its width and the height of its safe
/// area's foot (the home indicator's strip).
struct WhatsNewWindow: Equatable {
    var width: CGFloat = 0
    var bottomInset: CGFloat = 0
}

/// Cift's What's New, measured on an iPhone 17 Pro. iOS 26 lays a sheet this
/// short out at the window's full width and shrinks it to 95.7% to float it
/// 8pt in from the edges, so these are the points before that shrink: the
/// screenshot's measures divided by 0.957. An iOS 18 sheet draws them as
/// they are, edge to edge.
enum WhatsNewMetrics {
    /// The video card's distance from the sheet's top and sides.
    static let cardInset: CGFloat = 16
    static let cardRadius: CGFloat = 24
    /// From the card's foot to a feature's title, and from its last line to
    /// the foot of the pages. Between them the words take what they need:
    /// the tallest feature's, measured (`WhatsNewFeatureText`).
    static let textTop: CGFloat = 24
    static let textBottom: CGFloat = 8
    /// A title and three lines, until the measure comes in.
    static let textEstimate: CGFloat = 97
    /// The list's title and four rows, until the measure comes in.
    static let summaryEstimate: CGFloat = 390
    /// From the list's last row to the foot of the pages.
    static let summaryBottom: CGFloat = 12
    /// Above and below the dots.
    static let dotsMargin: CGFloat = 16.9
    static let dotSize: CGFloat = 6.85
    static let dotSpacing: CGFloat = 6.4
    /// Cift's button, a little taller than the app's own 58.
    static let buttonHeight: CGFloat = 62.5
    static let buttonInset: CGFloat = 27.8
    /// Under the button, from the sheet's foot.
    static let bottomMargin: CGFloat = 33
    /// Text on the first page sits this far in, and the features' text
    /// within this of the sheet's sides.
    static let summaryInset: CGFloat = 27.7
    static let featureInset: CGFloat = 30.5

    /// On a feature: tall enough for a square card the window's width, the
    /// tallest feature's words, the dots and the button, and no taller. A
    /// detent leaves out the safe area's foot, which the sheet adds.
    static func featureSheetHeight(in window: WhatsNewWindow, textHeight: CGFloat) -> CGFloat {
        let card = window.width - cardInset * 2
        return cardInset + card + textTop + textHeight + textBottom + footer(in: window)
    }

    /// On the list: its title and rows, the dots and the button.
    static func summarySheetHeight(in window: WhatsNewWindow, summaryHeight: CGFloat) -> CGFloat {
        summaryHeight + summaryBottom + footer(in: window)
    }

    /// The dots, the button and the room under it, less the safe area's
    /// foot, which the sheet adds.
    private static func footer(in window: WhatsNewWindow) -> CGFloat {
        dotsMargin * 2 + dotSize + buttonHeight + bottomMargin - window.bottomInset
    }
}

// MARK: - Pages

/// The first page's title and a row for each piece of news, its symbol in
/// a column of its own, centred on the title's line: on the page, and
/// unseen on the sheet to measure the list, which the sheet fits on this
/// page.
private struct WhatsNewSummaryContent: View {
    let highlights: [Release.Highlight]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("What's New in StarHash")
                .starhashFont(31, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color.sheetBrandText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 28.2) {
                ForEach(Array(highlights.prefix(4).enumerated()), id: \.offset) { _, highlight in
                    WhatsNewSummaryRow(highlight: highlight)
                }
            }
        }
        .padding(.top, 26)
        .padding(.horizontal, WhatsNewMetrics.summaryInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The first page: the list, from the top. The sheet is as tall as it, so
/// nothing is left under it; while the sheet grows to a feature's height
/// as the pages turn, the room opens below. A large text size scrolls it.
private struct WhatsNewSummaryPage: View {
    let highlights: [Release.Highlight]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                WhatsNewSummaryContent(highlights: highlights)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }
}

private struct WhatsNewSummaryRow: View {
    let highlight: Release.Highlight

    /// The title's line (Space Grotesk 18), which the symbol centres on,
    /// a little low, as Cift's sit.
    @ScaledMetric(relativeTo: .headline) private var titleLine: CGFloat = 23
    @ScaledMetric(relativeTo: .headline) private var symbolSize: CGFloat = 23.5
    @ScaledMetric(relativeTo: .headline) private var symbolColumn: CGFloat = 40.2

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(symbol: highlight.symbol)
                .font(.system(size: symbolSize, weight: .regular))
                .foregroundStyle(Color.sheetBrandText)
                .frame(width: symbolColumn, height: titleLine)
                .padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(catalog: highlight.title)
                    .starhashFont(18, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(Color.starhashPrimaryText)
                Text(catalog: highlight.detail)
                    .starhashFont(15, relativeTo: .subheadline)
                    // Cift's 20pt from line to line.
                    .lineSpacing(0.9)
                    .foregroundStyle(Color.sheetSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A feature's name and a few lines on it, one block as wide as its
/// longest line and centred, as Cift sets them: on its page, and unseen
/// on the sheet to measure the room the words need.
private struct WhatsNewFeatureText: View {
    let feature: Release.Page

    var body: some View {
        VStack(alignment: .leading, spacing: 6.6) {
            Text(catalog: feature.title)
                .starhashFont(20, weight: .bold, relativeTo: .title3)
                .foregroundStyle(Color.sheetBrandText)
                .accessibilityAddTraits(.isHeader)
            Text(catalog: feature.detail)
                .starhashFont(17, relativeTo: .body)
                // Cift's 21.9pt from line to line.
                .lineSpacing(0.2)
                .foregroundStyle(Color.starhashPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, WhatsNewMetrics.featureInset)
        .frame(maxWidth: .infinity)
    }
}

/// A feature: its video on a card, square and as wide as the sheet allows,
/// then its words. The card is the sheet turned over, black in light mode
/// and white in dark, so it stands apart from the sheet either way, and
/// plays the video made on its colour, which was recorded in that card's
/// appearance: StarHash in the phone looks as it does around it.
private struct WhatsNewFeaturePage: View {
    let feature: Release.Page
    /// The page is the one showing, so its video plays.
    let isShowing: Bool

    @Environment(\.colorScheme) private var colorScheme
    /// Settings' Auto-Play Video Previews: off, a video waits for a tap.
    @State private var autoplays = UIAccessibility.isVideoAutoplayEnabled
    @State private var tappedToPlay = false

    private var onBlack: Bool { colorScheme == .light }

    var body: some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width - WhatsNewMetrics.cardInset * 2, 0)
            VStack(spacing: 0) {
                card
                    .frame(width: side, height: side)
                    .padding(.top, WhatsNewMetrics.cardInset)
                // Scrolls only when the words outgrow the room the sheet
                // measured for them (a larger text size since).
                ScrollView {
                    WhatsNewFeatureText(feature: feature)
                        .padding(.top, WhatsNewMetrics.textTop)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.videoAutoplayStatusDidChangeNotification)) { _ in
            autoplays = UIAccessibility.isVideoAutoplayEnabled
        }
        .onChange(of: isShowing) { if !isShowing { tappedToPlay = false } }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: WhatsNewMetrics.cardRadius, style: .continuous)
        // The video made on the card's colour and recorded in this
        // appearance (`<Name>OnBlack`, light mode's, on black; `<Name>`, dark
        // mode's, on white), or the one on white when there is no other.
        let video = (onBlack ? Bundle.main.url(forResource: feature.video + "OnBlack", withExtension: "mp4") : nil)
            ?? Bundle.main.url(forResource: feature.video, withExtension: "mp4")
        let onBlackVideo = onBlack && video?.lastPathComponent.hasSuffix("OnBlack.mp4") == true
        return ZStack {
            onBlackVideo || (onBlack && video == nil) ? Color.black : Color.white
            if let video {
                WhatsNewVideo(url: video, isPlaying: isShowing && (autoplays || tappedToPlay))
                    // A new video when the appearance changes.
                    .id(video)
                    .onTapGesture { if !autoplays { tappedToPlay.toggle() } }
            } else {
                // No video yet: the feature's symbol, so the page still
                // reads.
                Image(symbol: feature.symbol)
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(onBlack ? Color.brandPaper : Color.brandInk)
            }
        }
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

/// The page dots: the current page a short bar, the rest dots, in the
/// text colour faded, as Cift's.
private struct WhatsNewPageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: WhatsNewMetrics.dotSpacing) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(Color.starhashPrimaryText.opacity(index == current ? 0.35 : 0.19))
                    .frame(width: index == current ? WhatsNewMetrics.dotSize * 2 : WhatsNewMetrics.dotSize, height: WhatsNewMetrics.dotSize)
            }
        }
        .animation(.smooth(duration: 0.3), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}
