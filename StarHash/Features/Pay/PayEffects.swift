import StarHashKit
import SwiftUI

// Pay's effects, after the reference "SIP, send money": a white bubble that
// swells under a key while it is held and melts into a frosted blob of ink
// as the finger lifts (`KeyBubble`, `PayInkLayer`), and the same bubble in
// Pay with light streaming through the button while it is held
// (`PayPressOverlay`). Shaders in PayEffects.metal. The wave that once
// carried Pay into the next screen is kept as the Send Ripple
// (Design/SendRipple.swift).

/// Compiles Pay's shaders ahead of their first use, which would otherwise
/// hold a frame or two while they compile: the first key press and the
/// first hold of Pay.
enum PayShaders {
    static func prepare() async {
        try? await ShaderLibrary.PayInk(
            .floatArray([0, 0, 0, 0]), .color(.white), .float2(CGPoint.zero),
            .float(1), .float(1), .float(1), .float(0), .float(0)
        ).compile(as: .colorEffect)
        try? await ShaderLibrary.PayButtonSheen(
            .float2(CGPoint.zero), .float(0), .float(0), .float(0)
        ).compile(as: .colorEffect)
    }
}

// MARK: Keypad ink

/// One press's blob of ink: where, when the finger lifted, and a random
/// seed so no two blobs share a shape.
struct InkDrop: Identifiable, Equatable {
    let id = UUID()
    let point: CGPoint
    let start: Date
    let seed = Float.random(in: 0..<1000)

    /// How long a blob lasts before it has thinned to nothing.
    static let lifetime: TimeInterval = 7
}

/// The ink behind the keypad, drawn by the `PayInk` shader while any blob
/// is alive and not at all otherwise. Points are in this layer's space;
/// `radius` is the key bubble's, which each blob starts as.
struct PayInkLayer: View {
    let drops: [InkDrop]
    let tint: Color
    let radius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if drops.isEmpty {
            Color.clear
        } else {
            // Whiter than the page, as in the reference. On black, a faint
            // light under a glowing accent instead (see the shader).
            let dark = colorScheme == .dark
            let whiteStrength: Float = dark ? 0.09 : 1
            let tintStrength: Float = dark ? 0.78 : 0.45
            let tint = tint
            let radius = Float(radius)
            TimelineView(.animation) { context in
                let values = values(at: context.date)
                // A steady clock for the drift, so it never jumps as blobs
                // come and go.
                let clock = Float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600))
                Rectangle()
                    .visualEffect { content, proxy in
                        content.colorEffect(ShaderLibrary.PayInk(
                            .floatArray(values),
                            .color(tint),
                            .float2(proxy.size),
                            .float(radius),
                            .float(whiteStrength),
                            .float(tintStrength),
                            .float(dark ? 1 : 0),
                            .float(clock)
                        ))
                    }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func values(at now: Date) -> [Float] {
        drops.flatMap { drop in
            [Float(drop.point.x), Float(drop.point.y), Float(now.timeIntervalSince(drop.start)), drop.seed]
        }
    }
}

/// The white bubble over a held key or Pay, hiding what is under it: there
/// at once at full size, giving under the finger, then filling out again.
/// Gone the moment the finger lifts, when the ink takes over where it was.
struct KeyBubble: View {
    let isPressed: Bool
    let size: CGFloat
    /// White on the light page and on Pay; a soft grey on black, where a
    /// white disc would glare.
    var fill: Color = .white

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
            .keyframeAnimator(initialValue: 1.0, trigger: isPressed) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0.78, duration: 0.09)
                    SpringKeyframe(0.97, duration: 0.3, spring: .bouncy)
                }
            }
            .opacity(isPressed ? 1 : 0)
            .animation(.easeOut(duration: isPressed ? 0.03 : 0.05), value: isPressed)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: Pay button press

/// Pay while held, as in the reference: the white bubble under the finger,
/// a little taller than the button and following it along, and lighter
/// streaks flowing through the button's colour.
struct PayPressOverlay: View {
    let location: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let pressed = location != nil
            let size = proxy.size
            // The bubble's centre stays clear of the button's round ends.
            let x = min(max(location?.x ?? size.width / 2, size.height / 2), size.width - size.height / 2)
            ZStack {
                if pressed {
                    TimelineView(.animation) { context in
                        Capsule()
                            .colorEffect(ShaderLibrary.PayButtonSheen(
                                .float2(size),
                                .float(x),
                                .float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600)),
                                .float(0.42)
                            ))
                    }
                    .transition(.opacity)
                }
                KeyBubble(isPressed: pressed, size: size.height * 1.18)
                    .position(x: x, y: size.height / 2)
            }
            .animation(.easeOut(duration: 0.15), value: pressed)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
