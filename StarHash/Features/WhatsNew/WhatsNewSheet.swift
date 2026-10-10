import StarHashKit
import SwiftUI

/// What's New, once, after an update (`WhatsNewLaunch`): a first page
/// listing the release's news, then a page for each feature, its video on
/// a white card over its name and a few lines, with the page dots and
/// Next (Done on the last page) under them all. Measured from Cift's,
/// in StarHash's type, colours and sheet glass.
struct WhatsNewSheet: View {
    let announcement: Release.Announcement
    /// The window's width and the bottom of its safe area, which set the
    /// sheet's height: the cards are square, as wide as the sheet.
    let window: WhatsNewWindow

    @Environment(\.dismiss) private var dismiss
    @State private var page: Int

    init(announcement: Release.Announcement, window: WhatsNewWindow, startPage: Int = 0) {
        self.announcement = announcement
        self.window = window
        _page = State(initialValue: min(max(startPage, 0), announcement.pages.count))
    }

    private var pageCount: Int { announcement.pages.count + 1 }
    private var isLastPage: Bool { page == pageCount - 1 }

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
        // Every measure is from the sheet's own edges, as Cift's: the paged
        // view lays its pages out over the sheet's safe area anyway, so the
        // rest follows it there.
        .ignoresSafeArea()
        // Solid, as the notes' sheets: the page behind would show through
        // clear glass and blur Pay's buttons into the corners.
        .background(Color.noteSheetBackground.ignoresSafeArea())
        .starhashContainerSurface()
        .sheetGlass(detents: [.height(WhatsNewMetrics.sheetHeight(in: window))])
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
    /// From the card's foot to the foot of the pages, room for a title and
    /// three lines.
    static let textArea: CGFloat = 171.6
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

    /// Tall enough for a square card the window's width, its text, the dots
    /// and the button: 667pt on an iPhone 17 Pro once shrunk, as Cift's. A
    /// detent leaves out the safe area's foot, which the sheet adds.
    static func sheetHeight(in window: WhatsNewWindow) -> CGFloat {
        let card = window.width - cardInset * 2
        return cardInset + card + textArea
            + dotsMargin * 2 + dotSize
            + buttonHeight + bottomMargin - window.bottomInset
    }
}

// MARK: - Pages

/// The first page: "What's New in StarHash" and a row for each piece of
/// news, its symbol in a column of its own, centred on the title's line.
/// The rows sit in the middle of the room under the title; a large text
/// size scrolls them.
private struct WhatsNewSummaryPage: View {
    let highlights: [Release.Highlight]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("What's New in StarHash")
                        .starhashFont(31, weight: .bold, relativeTo: .title)
                        .foregroundStyle(Color.sheetBrandText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 26)
                    Spacer(minLength: 24)
                    VStack(alignment: .leading, spacing: 28.2) {
                        ForEach(Array(highlights.prefix(4).enumerated()), id: \.offset) { _, highlight in
                            WhatsNewSummaryRow(highlight: highlight)
                        }
                    }
                    Spacer(minLength: 24)
                    // The rows sit a touch above the middle, as Cift's.
                    Color.clear.frame(height: 4)
                }
                .padding(.horizontal, WhatsNewMetrics.summaryInset)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .leading)
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
            Image(systemName: highlight.symbol)
                .font(.system(size: symbolSize, weight: .regular))
                .foregroundStyle(Color.sheetBrandText)
                .frame(width: symbolColumn, height: titleLine)
                .padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(catalog: highlight.title)
                    .starhashFont(18, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(Color.starhashPrimaryText)
                Text(highlight.detail)
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

/// A feature: its video on a white card, square and as wide as the sheet
/// allows, then its name and a few lines on it. The words are one block,
/// as wide as their longest line and centred, as Cift sets them.
private struct WhatsNewFeaturePage: View {
    let feature: Release.Page
    /// The page is the one showing, so its video plays.
    let isShowing: Bool

    @Environment(\.colorScheme) private var colorScheme
    /// Settings' Auto-Play Video Previews: off, a video waits for a tap.
    @State private var autoplays = UIAccessibility.isVideoAutoplayEnabled
    @State private var tappedToPlay = false

    var body: some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width - WhatsNewMetrics.cardInset * 2, 0)
            VStack(spacing: 0) {
                card
                    .frame(width: side, height: side)
                    .padding(.top, WhatsNewMetrics.cardInset)
                ScrollView {
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
                    .padding(.top, 27.7)
                    .frame(maxWidth: .infinity)
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
        return ZStack {
            Color.white
            if let url = Bundle.main.url(forResource: feature.video, withExtension: "mp4") {
                WhatsNewVideo(url: url, isPlaying: isShowing && (autoplays || tappedToPlay))
                    .onTapGesture { if !autoplays { tappedToPlay.toggle() } }
            } else {
                // No video yet: the feature's symbol, so the page still
                // reads.
                Image(systemName: feature.symbol)
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(Color.brandNight)
            }
        }
        .clipShape(shape)
        // On light mode's white sheet the white card needs a lift to show
        // its edge; on the dark sheet it stands out alone.
        .shadow(color: .black.opacity(colorScheme == .light ? 0.08 : 0), radius: 14, y: 3)
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
