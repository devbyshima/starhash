import StarHashKit
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// Pay's effects, after the reference "SIP, send money": a white bubble that
// swells under a key while it is held and melts into a frosted blob of ink
// as the finger lifts (`KeyBubble`, `PayInkLayer`); the same bubble in Pay
// with light streaming through the button while it is held
// (`PayPressOverlay`); and on choosing who to pay, a wave up the screen
// that carries it into the next one (`SendRipple`). Shaders in
// PayEffects.metal.

/// Compiles Pay's shaders ahead of their first use, which would otherwise
/// hold a frame or two while they compile: the first key press, the first
/// hold of Pay, the first wave.
enum PayShaders {
    static func prepare() async {
        try? await ShaderLibrary.PayInk(
            .floatArray([0, 0, 0, 0]), .color(.white), .float2(CGPoint.zero),
            .float(1), .float(1), .float(1), .float(0)
        ).compile(as: .colorEffect)
        try? await ShaderLibrary.PayButtonSheen(
            .float2(CGPoint.zero), .float(0), .float(0), .float(0)
        ).compile(as: .colorEffect)
        try? await ShaderLibrary.PaySendWave(
            .float2(CGPoint.zero), .float2(CGPoint.zero), .float(1), .float(0),
            .float(0), .float(0), .color(.white), .float(0)
        ).compile(as: .layerEffect)
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
            // Whiter than the page, as in the reference; only a haze on
            // black, where white would glare.
            let dark = colorScheme == .dark
            let whiteStrength: Float = dark ? 0.14 : 1
            let tintStrength: Float = dark ? 0.42 : 0.45
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
/// Gone the moment the finger lifts, when the ink (or the wave) takes over
/// where it was.
struct KeyBubble: View {
    let isPressed: Bool
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color.white)
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

// MARK: Send wave

/// Plays the wave up the screen as someone is chosen to pay, in a window of
/// its own above the app: the screen as it was washing over with the accent ahead of the
/// front, the next screen coming up through it, then white mist behind the
/// front clearing onto the live screen underneath. Snapshots rather than
/// the live views because a Metal layer effect cannot draw Liquid Glass or
/// UIKit-backed views, and a window of its own so the second snapshot shows
/// the new screen and not the wave over it.
///
/// Both screens are captured before the wave starts, the old one held
/// still over the app meanwhile: putting the new screen in costs a moment,
/// which would otherwise freeze the wave partway and then jump it on.
@MainActor
final class SendRipple {
    static let shared = SendRipple()

    /// How long the wave takes once it starts.
    static let duration: TimeInterval = 1.25

    private var window: UIWindow?
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var touches: TouchDownRecorder?

    var isPlaying: Bool { window != nil }

    /// Where the last finger came down in the app's window, in its points,
    /// for the wave to start from; nil until `trackTouches()` has run and a
    /// finger has.
    var lastTouch: CGPoint? { touches?.location }

    /// Starts noting where fingers come down in the app's window. Once is
    /// enough; later calls do nothing.
    func trackTouches() {
        guard touches == nil, let window = Self.keyWindow else { return }
        let recorder = TouchDownRecorder(target: nil, action: nil)
        window.addGestureRecognizer(recorder)
        touches = recorder
    }

    /// Returns once the wave has finished, at once if none is playing, for
    /// what would stall it if it ran now, such as raising the keyboard.
    func settled() async {
        guard isPlaying else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// `origin` is in window points, where the finger lifted; without one,
    /// the bottom middle of the screen. `swap` puts the next screen in
    /// place, without its own animation.
    func play(from origin: CGPoint?, tint: Color, dark: Bool, swap: @escaping @MainActor () -> Void) {
        guard window == nil,
              let main = Self.keyWindow,
              let scene = main.windowScene,
              let before = Self.snapshot(of: main, afterUpdates: false)
        else {
            swap()
            return
        }
        let origin = origin ?? CGPoint(x: main.bounds.midX, y: main.bounds.maxY - 80)
        let model = SendRippleModel(before: before, origin: origin)
        let host = UIHostingController(rootView: SendRippleView(model: model, tint: tint, dark: dark))
        host.view.backgroundColor = .clear
        let overlay = UIWindow(windowScene: scene)
        // Above the app, under the keyboard, which can come up through it.
        overlay.windowLevel = .normal + 1
        overlay.isUserInteractionEnabled = false
        overlay.rootViewController = host
        overlay.isHidden = false
        window = overlay

        Task { @MainActor in
            // A frame for the still to be up before the screen under it
            // changes.
            try? await Task.sleep(for: .milliseconds(20))
            swap()
            // And one for the new screen to lay out before it is captured.
            try? await Task.sleep(for: .milliseconds(40))
            model.after = Self.snapshot(of: main, afterUpdates: true)
            model.start = .now
            try? await Task.sleep(for: .seconds(Self.duration))
            overlay.isHidden = true
            self.window = nil
            let waiting = self.waiting
            self.waiting = []
            waiting.forEach { $0.resume() }
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    private static func snapshot(of window: UIWindow, afterUpdates: Bool) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: afterUpdates)
        }
    }
}

@MainActor
@Observable
private final class SendRippleModel {
    let before: UIImage
    let origin: CGPoint
    /// So no two waves have the same rings.
    let seed = Float.random(in: 0..<100)
    /// When the wave started; until then the old screen is held still.
    var start: Date?
    var after: UIImage?

    init(before: UIImage, origin: CGPoint) {
        self.before = before
        self.origin = origin
    }
}

private struct SendRippleView: View {
    let model: SendRippleModel
    let tint: Color
    let dark: Bool

    var body: some View {
        let size = model.before.size
        TimelineView(.animation) { context in
            let time = model.start.map { context.date.timeIntervalSince($0) } ?? 0
            ZStack {
                if let after = model.after {
                    screen(after)
                }
                screen(model.before)
                    .opacity(beforeOpacity(time))
            }
            .frame(width: size.width, height: size.height)
            .layerEffect(
                ShaderLibrary.PaySendWave(
                    .float2(model.origin),
                    .float2(size),
                    .float(reach(in: size)),
                    .float(time),
                    // Without the new screen, never clear onto the old one.
                    .float(model.after == nil ? 1000 : 0.38),
                    .float(model.seed),
                    .color(tint),
                    .float(dark ? 1 : 0)
                ),
                maxSampleOffset: CGSize(width: 24, height: 24)
            )
        }
        .ignoresSafeArea()
    }

    private func screen(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: image.size.width, height: image.size.height)
    }

    /// The old screen dissolves into the new one under the wash, as the
    /// front climbs.
    private func beforeOpacity(_ time: TimeInterval) -> Double {
        guard model.after != nil else { return 1 }
        return max(0, min(1, 1 - (time - 0.3) / 0.15))
    }

    /// How far the front goes: from the button to the farthest corner, and
    /// its band's width past that, so it leaves the screen entirely.
    private func reach(in size: CGSize) -> CGFloat {
        let corners = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
        let farthest = corners.map { hypot($0.x - model.origin.x, $0.y - model.origin.y) }.max() ?? 0
        return farthest + 60
    }
}

/// Notes where each finger comes down anywhere in a window, without taking
/// part in any gesture: it fails at once, and cancels and delays nothing.
private final class TouchDownRecorder: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private(set) var location: CGPoint?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        location = touches.first?.location(in: view)
        state = .failed
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
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
