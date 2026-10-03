import SwiftUI

// The tab bar's Liquid Glass, shared with the period control so the two
// look and move alike: clear glass that stretches to take in its lens when
// the lens overshoots an end, and the grey lens itself.

/// Clear glass `width` by `height`, stretched to take in a lens from
/// `lensMinX` to `lensMaxX` wherever it is: at rest the lens sits
/// `sideInset` inside, and overshooting an end it pulls the edge out with
/// it. Animatable, so the outline follows the lens frame by frame.
struct LensGlass: View, Animatable {
    var width: CGFloat
    var height: CGFloat
    var sideInset: CGFloat
    var lensMinX: CGFloat
    var lensMaxX: CGFloat
    /// Clear by default, as the tab bar's and the period control's; nil
    /// takes the page's tint.
    var tint: Color? = .clear

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(width, AnimatablePair(lensMinX, lensMaxX)) }
        set {
            width = newValue.first
            lensMinX = newValue.second.first
            lensMaxX = newValue.second.second
        }
    }

    var body: some View {
        let minX = min(0, lensMinX - sideInset)
        let maxX = max(width, lensMaxX + sideInset)
        Color.clear
            .frame(width: maxX - minX, height: height)
            .starhashGlass(in: Capsule(), tint: tint)
            .offset(x: minX)
            .allowsHitTesting(false)
    }
}

/// The lens under the choice showing: the palette's grey, faint, with the
/// light top edge and dark sides glass has (the tab bar's); or, `light`, a
/// white one with a bright rim, as the system's selection reads on tinted
/// glass (the period control's).
struct GlassLens: View {
    var light = false

    var body: some View {
        if light {
            Capsule()
                .fill(Color.segmentedLens)
                .overlay(Capsule().strokeBorder(Color.segmentedLensEdge, lineWidth: 0.75))
                .accessibilityHidden(true)
        } else {
            greyLens
        }
    }

    private var greyLens: some View {
        Capsule()
            .fill(Color.tabBarLens)
            .overlay {
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [.tabBarLensEdgeLight, .tabBarLensEdgeDark, .tabBarLensEdgeDark, .tabBarLensEdgeLight.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
            }
            .accessibilityHidden(true)
    }
}

/// The lens's spring, the tab bar's (measured from GO Club's): about a
/// tenth past the mark, back a touch, and still in under half a second. A
/// plain ease with Reduce Motion.
enum LensMotion {
    static func spring(reduceMotion: Bool) -> Animation {
        reduceMotion ? .smooth(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.61)
    }
}
