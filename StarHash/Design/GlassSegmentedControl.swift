import SwiftUI

/// GO Club's period control, measured from its screen recording: a glass
/// capsule 41pt tall of short labels 41pt apart (16pt medium), with a
/// lighter lens 34pt tall under the one chosen. A finger down swells the
/// capsule to 1.07, brightens its glass and stretches the lens a little;
/// on release it settles back with a slight undershoot. The lens glides to
/// a new choice on a spring that does not overshoot, settling in about
/// 0.4s, and a finger dragged along the control carries it, choosing
/// wherever it lets go.
struct GlassSegmentedControl<Value: Hashable>: View {
    let options: [Value]
    let selection: Value
    let onSelect: (Value) -> Void
    /// The short label in the control ("W").
    let label: (Value) -> String
    /// What VoiceOver reads for it ("This Week").
    let accessibilityLabel: (Value) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var isPressed = false
    /// Where a finger dragging along the control holds the lens.
    @State private var dragX: CGFloat?

    private typealias Metrics = GlassSegmentedMetrics

    var body: some View {
        let index = options.firstIndex(of: selection) ?? 0
        let lensCenter = dragX.map { min(max($0, center(of: 0)), center(of: options.count - 1)) } ?? center(of: index)

        ZStack(alignment: .topLeading) {
            // The glass brightens under a finger, as the reference's does.
            Capsule()
                .fill(Color.segmentedPressedGlow)
                .opacity(isPressed ? 1 : 0)

            Capsule()
                .fill(Color.segmentedLens)
                .overlay(Capsule().strokeBorder(Color.segmentedLensEdge, lineWidth: 0.75))
                .frame(width: Metrics.segment * (isPressed ? 1.13 : 1), height: Metrics.lensHeight)
                .position(x: lensCenter, y: Metrics.height / 2)
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                ForEach(options, id: \.self) { option in
                    segment(option, isSelected: option == selection)
                }
            }
            .padding(.horizontal, Metrics.inset)
        }
        .frame(width: width, height: Metrics.height)
        .animation(dragX == nil ? lensSpring : .interactiveSpring(response: 0.18), value: lensCenter)
        .contentShape(Capsule())
        // The page's glass, as the buttons beside it have; untinted, it
        // would turn a bright cyan on the blue.
        .starhashGlass(in: Capsule())
        .gesture(choosing)
        .scaleEffect(isPressed ? 1.07 : 1)
        .animation(reduceMotion ? .smooth(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.62), value: isPressed)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
    }

    private var width: CGFloat {
        Metrics.inset * 2 + Metrics.segment * CGFloat(options.count)
    }

    private func center(of index: Int) -> CGFloat {
        Metrics.inset + Metrics.segment * (CGFloat(index) + 0.5)
    }

    /// The reference's: straight there and settled, no bounce.
    private var lensSpring: Animation {
        reduceMotion ? .smooth(duration: 0.2) : .spring(response: 0.32, dampingFraction: 1)
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
            .accessibilityAction { onSelect(option) }
            .accessibilityShowsLargeContentViewer {
                Text(accessibilityLabel(option))
            }
    }

    private var choosing: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, pressed, _ in pressed = true }
            .onChanged { value in
                guard dragX != nil || abs(value.translation.width) > 6 else { return }
                dragX = value.location.x
            }
            .onEnded { value in
                let raw = Int(((value.location.x - Metrics.inset) / Metrics.segment).rounded(.down))
                let chosen = options[min(max(raw, 0), options.count - 1)]
                dragX = nil
                if chosen != selection { onSelect(chosen) }
            }
    }
}

/// The reference's measurements, in points.
enum GlassSegmentedMetrics {
    static let height: CGFloat = 41
    static let segment: CGFloat = 41.33
    static let inset: CGFloat = 3.5
    static let lensHeight: CGFloat = 34
}
