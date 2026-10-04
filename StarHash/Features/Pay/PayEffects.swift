import SwiftUI

// Pay's effect, after the reference "SIP, send money": light streaming
// through Pay while it is held (`PayPressOverlay`), with nothing drawn under
// the finger. Shader in PayEffects.metal. The wave that once carried Pay
// into the next screen is kept as the Send Ripple (Design/SendRipple.swift).

/// Compiles Pay's shader ahead of its first use, the first hold of Pay,
/// which would otherwise hold a frame or two while it compiles.
enum PayShaders {
    static func prepare() async {
        try? await ShaderLibrary.PayButtonSheen(
            .float2(CGPoint.zero), .float(0), .float(0)
        ).compile(as: .colorEffect)
    }
}

// MARK: Pay button press

/// Pay while held, as in the reference: lighter streaks flowing through
/// the button's colour.
struct PayPressOverlay: View {
    let isPressed: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if isPressed {
                    TimelineView(.animation) { context in
                        Capsule()
                            .colorEffect(ShaderLibrary.PayButtonSheen(
                                .float2(size),
                                .float(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600)),
                                .float(0.42)
                            ))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: isPressed)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
