import Charts
import StarHashKit
import SwiftUI
import UIKit

/// The card at the top of Activity: what was sent in the chosen period,
/// what came in and what MTN charged, and an ink bar chart of how the
/// spending was spread over the period.
struct ActivitySummaryCard: View {
    let period: ActivityPeriod
    let totals: ActivitySummary.Totals
    let buckets: [ActivitySummary.Bucket]
    let calendar: Calendar

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(period.spentCaption)
                    .starhashFont(17, relativeTo: .body)
                    .foregroundStyle(Color.starhashSecondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Money.format(totals.spent))
                        .starhashFont(40, weight: .bold, relativeTo: .largeTitle)
                        .foregroundStyle(Color.starhashPrimaryText)
                        // The digits roll to a new total (another period, a
                        // new payment), or fade with Reduce Motion.
                        .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(totals.spent)))
                    Text(Money.currency)
                        .starhashFont(20, weight: .semibold, relativeTo: .title3)
                        .foregroundStyle(Color.starhashSecondaryText)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 8.5)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Money.formatWithCurrency(totals.spent))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { receivedLine; feesLine }
                    VStack(alignment: .leading, spacing: 2) { receivedLine; feesLine }
                }
                .padding(.top, 6)
            }
            .accessibilityElement(children: .combine)
            ActivitySpendingChart(buckets: buckets, period: period, calendar: calendar)
                .frame(height: 200)
                .padding(.top, 32)
        }
        .padding(.top, 22.5)
        .padding(.bottom, 27)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.starhashCard, in: RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous))
    }

    private var receivedLine: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.left")
                .font(.starhash(.footnote, weight: .bold))
                .accessibilityHidden(true)
            Text("Received \(Money.format(totals.received))")
        }
        .starhashFont(15, weight: .medium, relativeTo: .subheadline)
        .foregroundStyle(totals.received > 0 ? Color.starhashIncoming : Color.starhashSecondaryText)
        .lineLimit(1)
    }

    private var feesLine: some View {
        Text("MTN fees \(Money.format(totals.fees))")
            .starhashFont(15, relativeTo: .subheadline)
            .foregroundStyle(Color.starhashSecondaryText)
            .lineLimit(1)
    }
}

/// Ink bars with rounded tops over hairline grid lines, compact amounts on
/// the trailing edge, as Keaser's Home chart. VoiceOver reads each bar as
/// its day, month or hours and the amount sent.
///
/// Pressing and holding a bar raises a small glass callout over it with its
/// period and amount; sliding the finger carries the callout from bar to
/// bar until the finger lifts.
struct ActivitySpendingChart: View {
    let buckets: [ActivitySummary.Bucket]
    let period: ActivityPeriod
    let calendar: Calendar

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The width of the bar area, measured once the chart is laid out.
    @State private var plotWidth: CGFloat = 0
    /// The bar under a pressing finger, if any.
    @State private var selectedIndex: Int?
    @State private var calloutSize = CGSize(width: 86, height: 46)

    /// The chart has a fixed height and unwrapped labels, so its text stops
    /// growing here; VoiceOver reads the bar values.
    private static let largestTextSize = DynamicTypeSize.xxxLarge
    private static let barWidthRatio = 0.7

    var body: some View {
        let narrow = usesNarrowLabels
        let ticks = ActivitySummary.axisTicks(for: buckets.map(\.total).max() ?? 0)
        let top = Double(ticks.last ?? 1)
        Chart {
            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("Period", key(bucket.index)),
                    // A fixed 0...1 domain: Charts lays its axis labels out
                    // with invalid frames while an animated change moves
                    // the domain, as switching periods does.
                    y: .value("Sent", Double(bucket.total) / top),
                    width: .ratio(Self.barWidthRatio)
                )
                // The pressed bar keeps the full blue; the rest step back.
                .foregroundStyle(Color.starhashAccentGraphic.opacity(selectedIndex == nil || selectedIndex == bucket.index ? 1 : 0.5))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: barRadius, topTrailingRadius: barRadius, style: .continuous))
                .accessibilityLabel(ActivitySummary.spokenName(of: bucket, period: period, calendar: calendar))
                .accessibilityValue(Money.formatWithCurrency(bucket.total))
            }
        }
        .chartXAxis {
            AxisMarks(values: buckets.filter(\.showsLabel).map { key($0.index) }) { value in
                AxisValueLabel(centered: true, verticalSpacing: 4) {
                    // Charts may ask for a label under every category,
                    // whatever `values` lists, so each label checks itself.
                    if let key = value.as(String.self), let bucket = bucket(for: key), bucket.showsLabel {
                        Text(narrow ? bucket.narrowLabel : bucket.label)
                            .font(.starhash(.caption2))
                            .foregroundStyle(Color.starhashSecondaryText)
                            .fixedSize()
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: ticks.map { Double($0) / top }) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 2 / 3))
                    .foregroundStyle(Color.starhashPrimaryText.opacity(0.14))
                AxisValueLabel {
                    if let position = value.as(Double.self) {
                        Text(Money.compact(Int((position * top).rounded())))
                            .font(.starhash(.caption2))
                            .foregroundStyle(Color.starhashSecondaryText)
                    }
                }
            }
        }
        .chartYScale(domain: 0...1)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let plot = proxy.plotFrame.map { geometry[$0] } ?? .zero
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(ActivityPressAndScrubGesture { location in
                        select(at: location, in: plot, proxy: proxy)
                    })
                    .onChange(of: proxy.plotSize.width, initial: true) { _, width in plotWidth = width }
                    .accessibilityHidden(true)
                    .overlay(alignment: .topLeading) {
                        callout(proxy: proxy, plot: plot, chartWidth: geometry.size.width, top: top)
                    }
            }
        }
        .dynamicTypeSize(...Self.largestTextSize)
        .animation(.smooth(duration: 0.35), value: buckets)
        .sensoryFeedback(trigger: selectedIndex) { _, new in new == nil ? nil : .selection }
        .onChange(of: buckets.map(\.interval)) { _, _ in selectedIndex = nil }
        #if DEBUG
        .task {
            // `-activityChartSelection last` (or a bar index) shows the
            // callout without a long press, for screenshots.
            guard let value = DebugLaunch.value(after: "-activityChartSelection") else { return }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            selectedIndex = value == "last" ? buckets.last(where: { $0.total > 0 })?.index : Int(value)
        }
        #endif
    }

    /// The pressed bar's callout, centred over the bar just above its top,
    /// kept inside the chart. It grows out of the bar as it appears.
    @ViewBuilder
    private func callout(proxy: ChartProxy, plot: CGRect, chartWidth: CGFloat, top: Double) -> some View {
        if let selected = selectedBucket,
           let x = proxy.position(forX: key(selected.index)),
           let y = proxy.position(forY: Double(selected.total) / top) {
            let barCenter = plot.minX + x
            let barTop = plot.minY + y
            let leading = min(max(barCenter - calloutSize.width / 2, 0), max(chartWidth - calloutSize.width, 0))
            let bottom = max(barTop - 6, calloutSize.height)
            ActivityChartCallout(
                title: ActivitySummary.calloutTitle(of: selected, period: period, calendar: calendar),
                amount: Money.formatWithCurrency(selected.total),
                rollsDigits: !reduceMotion
            )
            .onGeometryChange(for: CGSize.self) { $0.size } action: { calloutSize = $0 }
            .offset(x: leading, y: bottom - calloutSize.height)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.6, anchor: .bottom)))
            .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: selected.index)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var selectedBucket: ActivitySummary.Bucket? {
        selectedIndex.flatMap { index in buckets.first { $0.index == index } }
    }

    /// Picks the bar under `location`, clamped to the plot so a finger that
    /// drifts past either end keeps the end bar; nil clears the selection.
    private func select(at location: CGPoint?, in plot: CGRect, proxy: ChartProxy) {
        guard let location, plot.width > 0 else {
            withAnimation(.easeOut(duration: 0.2)) { selectedIndex = nil }
            return
        }
        let x = min(max(location.x - plot.minX, 0), plot.width - 1)
        guard let key = proxy.value(atX: x, as: String.self), let bucket = bucket(for: key),
              bucket.index != selectedIndex
        else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.28)) {
            selectedIndex = bucket.index
        }
    }

    /// Charts treats strings as categories, which keeps every bar in its own
    /// slot even when labels repeat.
    private func key(_ index: Int) -> String { "b\(index)" }

    private func bucket(for key: String) -> ActivitySummary.Bucket? {
        Int(key.dropFirst()).flatMap { index in buckets.first { $0.index == index } }
    }

    /// Twelve months fit as "Jan Feb Mar" at the default text size but
    /// collide at larger ones, so they drop to "J F M" when the measured
    /// labels would touch.
    private var usesNarrowLabels: Bool {
        guard !buckets.isEmpty, plotWidth > 0 else { return false }
        let size = min(dynamicTypeSize, Self.largestTextSize)
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        let font = UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: traits)
        func width(_ text: String) -> CGFloat { (text as NSString).size(withAttributes: [.font: font]).width }
        let slot = plotWidth / CGFloat(buckets.count)
        let labelled = buckets.filter(\.showsLabel)
        return !zip(labelled, labelled.dropFirst()).allSatisfy { left, right in
            (width(left.label) + width(right.label)) / 2 + 4 <= CGFloat(right.index - left.index) * slot
        }
    }

    /// Narrow bars (a month of days) get smaller corners so they stay bars.
    private var barRadius: CGFloat {
        switch buckets.count {
        case ...7: 8
        case ...12: 5
        default: 2.5
        }
    }
}

/// The small glass tag a long press raises over a bar: the period in grey
/// over the amount, on Liquid Glass tinted with a breath of ink.
private struct ActivityChartCallout: View {
    let title: String
    let amount: String
    let rollsDigits: Bool

    private static let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .starhashFont(11, relativeTo: .caption2)
                .foregroundStyle(Color.starhashSecondaryText)
            Text(amount)
                .starhashFont(15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Color.starhashPrimaryText)
                .contentTransition(rollsDigits ? .numericText() : .opacity)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .starhashGlass(in: Self.shape, tint: Color.starhashInk.opacity(0.1))
    }
}

/// A long press that keeps reporting where the finger is as it slides, and
/// nil once it lifts or is cancelled. UIKit's recogniser only takes over
/// after the press, so a swipe that starts on the chart still scrolls.
private struct ActivityPressAndScrubGesture: UIGestureRecognizerRepresentable {
    let onChange: (CGPoint?) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.3
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: onChange(context.converter.localLocation)
        default: onChange(nil)
        }
    }
}
