import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// The **Send Ripple**, kept for later. Pay used it as someone was chosen to
// pay, after the reference "SIP, send money": a wave up the screen from
// where the finger lifted, washing the old screen with the accent and
// clearing through white mist onto the next one. Nothing plays it now.
//
// To bring it back on a screen: call `SendRipple.shared.trackTouches()` as
// the screen the finger lifts on appears, then swap screens inside
//
//     SendRipple.shared.play(from: SendRipple.shared.lastTouch, tint: .brandBlue, dark: colorScheme == .dark) {
//         var transaction = Transaction()
//         transaction.disablesAnimations = true
//         withTransaction(transaction) { /* the next screen */ }
//     }
//
// skipping it under Reduce Motion, and wait on `settled()` before anything
// that would stall it (raising the keyboard, the call prompt). Call
// `SendRipple.prepare()` early so its first run does not stutter. The
// shader is in Shaders/SendRipple.metal.

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
                ShaderLibrary.SendRipple(
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

extension SendRipple {
    /// Compiles the shader ahead of the first wave, which would otherwise
    /// hold a frame or two.
    static func prepare() async {
        try? await ShaderLibrary.SendRipple(
            .float2(CGPoint.zero), .float2(CGPoint.zero), .float(1), .float(0),
            .float(0), .float(0), .color(.white), .float(0)
        ).compile(as: .layerEffect)
    }
}
