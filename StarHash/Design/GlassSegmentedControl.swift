import SwiftUI

/// GO Club's period control, measured from its screen recording (a capsule
/// 41pt tall of short labels 41pt apart, 16pt medium, over a lens 34pt
/// tall), in the same glass as the search button beside it and the tab
/// bar, clear Liquid Glass, with a light lens.
/// It moves as the tab bar does: a spring that overshoots about a tenth and
/// settles, stretching the glass when it overshoots an end. A change plays
/// the system's selection tick. A finger dragged along it carries the lens
/// and chooses wherever it lets go.
struct GlassSegmentedControl<Value: Hashable>: View {
    let options: [Value]
    let selection: Value
    let onSelect: (Value) -> Void
    /// The short label in the control ("W").
    let label: (Value) -> String
    /// What VoiceOver reads for it ("This Week").
    let accessibilityLabel: (Value) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where a finger dragging along the control holds the lens.
    @State private var dragX: CGFloat?

    private typealias Metrics = GlassSegmentedMetrics

    var body: some View {
        let index = options.firstIndex(of: selection) ?? 0
        let lensCenter = dragX.map { min(max($0, center(of: 0)), center(of: options.count - 1)) } ?? center(of: index)

        ZStack(alignment: .topLeading) {
            LensGlass(
                width: width,
                height: Metrics.height,
                sideInset: Metrics.inset,
                lensMinX: lensCenter - Metrics.segment / 2,
                lensMaxX: lensCenter + Metrics.segment / 2
            )

            GlassLens(light: true)
                .frame(width: Metrics.segment, height: Metrics.lensHeight)
                .offset(x: lensCenter - Metrics.segment / 2, y: (Metrics.height - Metrics.lensHeight) / 2)

            HStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    segment(option, isSelected: option == selection)
                }
            }
            .padding(.horizontal, Metrics.inset)
        }
        .frame(width: width, height: Metrics.height, alignment: .topLeading)
        .animation(dragX == nil ? LensMotion.spring(reduceMotion: reduceMotion) : .interactiveSpring(response: 0.18), value: lensCenter)
        .contentShape(Capsule())
        .gesture(choosing)
        .sensoryFeedback(.selection, trigger: selection)
        // Clear glass, as the tab bar's: near-black letters in light mode.
        .starhashContainerSurface()
        .accessibilityElement(children: .contain)
    }

    private var width: CGFloat {
        Metrics.inset * 2 + Metrics.segment * CGFloat(options.count)
    }

    private func center(of index: Int) -> CGFloat {
        Metrics.inset + Metrics.segment * (CGFloat(index) + 0.5)
    }

    private func segment(_ option: Value, isSelected: Bool) -> some View {
        Text(label(option))
            .starhashFont(16, weight: .medium, relativeTo: .callout)
            .foregroundStyle(Color.starhashPrimaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            // Like a toolbar's, the labels stop growing at the largest
            // standard size; the Large Content Viewer shows them bigger.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(width: Metrics.segment, height: Metrics.height)
            .contentShape(Rectangle())
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel(option))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { choose(option) }
            .accessibilityShowsLargeContentViewer {
                Text(accessibilityLabel(option))
            }
    }

    /// A tap chooses the label under it; a drag carries the lens and
    /// chooses wherever the finger lets go.
    private var choosing: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard dragX != nil || abs(value.translation.width) > 6 else { return }
                dragX = value.location.x
            }
            .onEnded { value in
                let raw = Int(((value.location.x - Metrics.inset) / Metrics.segment).rounded(.down))
                dragX = nil
                choose(options[min(max(raw, 0), options.count - 1)])
            }
    }

    /// Another choice; the one showing does nothing.
    private func choose(_ option: Value) {
        guard option != selection else { return }
        onSelect(option)
    }
}

/// The reference's measurements, in points.
enum GlassSegmentedMetrics {
    static let height: CGFloat = 41
    static let segment: CGFloat = 41.33
    static let inset: CGFloat = 3.5
    static let lensHeight: CGFloat = 34
}
