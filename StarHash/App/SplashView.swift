import SwiftUI

/// The launch splash, after GO Club's launch, measured frame by frame from a
/// screen recording of it: one stroke in the mark's colour sets off from the
/// top of the page and sweeps round the centre, faster and faster, its tail
/// trailing behind like a pen at speed. As it passes the foot a dot opens
/// where the star's heart will be, and where the stroke lands, on the upper
/// right arm, the arms snap out of the dot one after another, on round the
/// way the stroke was going, the triangle last. The mark arrives a quarter
/// too big and eases down to its size, then the splash fades into the app.
/// All on the page's flat colour, which the system's launch screen already
/// shows, so the two run on as one. Reduce Motion shows the mark still and
/// briefly.
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.self) private var environment
    @State private var clock = SplashClock()

    var body: some View {
        let colour = Color.starhashMarkGlyph.color(in: environment)
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let time = reduceMotion ? SplashMotion.still : clock.time(at: timeline.date)
            Canvas { context, size in
                SplashFrame(time: time, centre: CGPoint(x: size.width / 2, y: size.height / 2), colour: colour)
                    .draw(in: &context)
            }
            // Hands over on the splash's own clock, so a slow first frame
            // never cuts the stroke short.
            .onChange(of: !reduceMotion && time >= SplashMotion.finish) { _, done in
                if done { onFinish() }
            }
        }
        .background(Color.starhashBackground)
        .ignoresSafeArea()
        .onAppear {
            guard reduceMotion else { return }
            Task {
                try? await Task.sleep(for: .seconds(0.4))
                onFinish()
            }
        }
        .accessibilityElement()
        .accessibilityLabel("StarHash")
    }
}

/// The splash's clock, started by the first frame drawn rather than when the
/// view is made: on a cold launch the first frame can come a good half second
/// after, which would otherwise be the stroke's whole sweep, unseen.
@MainActor
private final class SplashClock {
    private var start: Date?

    /// Debug builds' `-splashSlow <n>` (with `-splash`) plays it n times
    /// slower, so a recording on a busy simulator still catches every step.
    private let pace: Double = {
        #if DEBUG
        if let value = DebugLaunch.value(after: "-splashSlow"), let slow = Double(value), slow > 0 {
            return 1 / slow
        }
        #endif
        return 1
    }()

    func time(at date: Date) -> Double {
        if start == nil { start = date }
        return date.timeIntervalSince(start ?? date) * pace
    }
}

/// The splash's timing and sizes, measured from GO Club's launch on an
/// iPhone 17 Pro (402 points wide) and fitted to the mark.
private enum SplashMotion {
    /// The mark's square, at rest.
    static let markSize: CGFloat = 168
    /// The circle the stroke sweeps, and the stroke's width.
    static let orbitRadius: CGFloat = 118
    static let strokeWidth: CGFloat = 22
    /// Seconds from the top of the page to the landing, and the power of
    /// the ease in: slow off the mark, then near 1,500 degrees a second as
    /// it lands, as GO's does.
    static let orbit: Double = 0.46
    static let easeIn: Double = 2.3
    /// How far behind its head the stroke's tail runs, in seconds, so the
    /// stroke stretches as it speeds up and shrinks into the arm it lands on.
    static let trail: Double = 0.07
    /// The stroke's length at the start, in degrees, while it fades in, and
    /// the longest it stretches, GO's at full speed.
    static let firstLength: Double = 6
    static let longest: Double = 55
    static let fadeIn: Double = 0.04
    /// How fast the arms follow on round from the landing, in degrees a
    /// second: all five out within a twentieth of a second.
    static let sweep: Double = 6000
    /// The mark arrives this much too big and eases down to its size on
    /// this time constant, with no bounce back, as GO's logo settles.
    static let overshoot: Double = 0.24
    static let settle: Double = 0.21
    /// When the splash hands over to the app.
    static let finish: Double = 1.35
    /// A time long after everything has settled, for Reduce Motion.
    static let still: Double = 60
}

/// The mark cut up for the splash, in the artwork's units: the heart the
/// arms grow from, and each arm as a fan from it, so the five together are
/// exactly the star.
private enum SplashGeometry {
    /// Where the five arms meet, a little above the square's centre.
    static let heart = CGPoint(x: 404, y: 384)
    /// The dot the arms snap out of, clear of the star's inner corners.
    static let dotRadius: CGFloat = 96

    /// Each arm, in the star's order (top, upper right, lower right, lower
    /// left, upper left): the heart, the inner corner before it, its two
    /// outer corners and the inner corner after it. The fans all turn the
    /// same way, so filled as one path they join without a seam.
    static let arms: [[CGPoint]] = (0..<5).map { arm in
        let star = StarHashMarkShape.star
        let before = star[(arm * 3 + star.count - 1) % star.count]
        return [heart, before, star[arm * 3], star[arm * 3 + 1], star[arm * 3 + 2]]
    }

    /// The middle of each arm's outer edge, its tip.
    static let tips: [CGPoint] = (0..<5).map { arm in
        let star = StarHashMarkShape.star
        return CGPoint(x: (star[arm * 3].x + star[arm * 3 + 1].x) / 2, y: (star[arm * 3].y + star[arm * 3 + 1].y) / 2)
    }

    /// Each arm's direction from the heart, in degrees anticlockwise from
    /// the right, as the stroke turns.
    static let armAngles: [Double] = tips.map { tip in
        let degrees = atan2(Double(heart.y - tip.y), Double(tip.x - heart.x)) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// The stroke lands on the upper right arm, the last it meets coming
    /// round from the top.
    static let landingArm = 1

    static let triangleCentre = CGPoint(
        x: StarHashMarkShape.triangle.map(\.x).reduce(0, +) / 3,
        y: StarHashMarkShape.triangle.map(\.y).reduce(0, +) / 3
    )
}

/// One frame of the splash, worked out from the clock alone, so it plays the
/// same at any frame rate and Reduce Motion can ask for the last.
private struct SplashFrame {
    let time: Double
    let centre: CGPoint
    let colour: Color

    private typealias Motion = SplashMotion
    private typealias Geometry = SplashGeometry

    /// Points per unit of the artwork.
    private var unit: CGFloat { Motion.markSize / StarHashMarkShape.side }

    /// The heart on screen, the centre of the orbit and of every scale.
    private var pivot: CGPoint {
        CGPoint(
            x: centre.x + (Geometry.heart.x - StarHashMarkShape.side / 2) * unit,
            y: centre.y + (Geometry.heart.y - StarHashMarkShape.side / 2) * unit
        )
    }

    private var landingAngle: Double { Geometry.armAngles[Geometry.landingArm] + 360 }
    private var travel: Double { landingAngle - 90 }

    func draw(in context: inout GraphicsContext) {
        drawStroke(in: &context)
        drawMark(in: &context)
    }

    // MARK: The stroke

    /// The stroke's head at `time`, in degrees anticlockwise from the
    /// right, starting at the top.
    private func angle(at time: Double) -> Double {
        let progress = min(max(time / Motion.orbit, 0), 1)
        return 90 + travel * pow(progress, Motion.easeIn)
    }

    /// The orbit's radius at an angle: it drifts in a little as it goes, as
    /// GO's does, then dives in over the last stretch to the tip of the arm
    /// it lands on, where that arm will be at its largest.
    private func radius(at angle: Double) -> CGFloat {
        let progress = pow(min(max((angle - 90) / travel, 0), 1), 1 / Motion.easeIn)
        let drift = Motion.orbitRadius * (1 - 0.07 * progress)
        let tip = Geometry.tips[Geometry.landingArm]
        let reach = hypot(tip.x - Geometry.heart.x, tip.y - Geometry.heart.y) * unit * (1 + Motion.overshoot)
        return drift + (reach - drift) * smoothstep((progress - 0.72) / 0.28)
    }

    private func drawStroke(in context: inout GraphicsContext) {
        guard time < Motion.orbit + Motion.trail else { return }
        let head = angle(at: time)
        // Once landed, the tail catches up twice as fast, so the arm
        // swallows the stroke as it grows rather than after.
        let landed = max(time - Motion.orbit, 0)
        var tail = max(angle(at: time - Motion.trail + landed), head - Motion.longest)
        // A short stroke from the first frame, not a point that grows.
        if time < Motion.orbit {
            tail = min(tail, head - Motion.firstLength)
        }
        guard head - tail > 0.2 else { return }

        var path = Path()
        let steps = 24
        for step in 0...steps {
            let degrees = tail + (head - tail) * Double(step) / Double(steps)
            let radians = degrees * .pi / 180
            let r = radius(at: degrees)
            let point = CGPoint(x: pivot.x + r * cos(radians), y: pivot.y - r * sin(radians))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        let opacity = min(1, time / Motion.fadeIn)
        context.stroke(
            path,
            with: .color(colour.opacity(opacity)),
            style: StrokeStyle(lineWidth: Motion.strokeWidth, lineCap: .butt, lineJoin: .round)
        )
    }

    // MARK: The mark

    /// The whole mark's scale: a quarter over as it lands, easing down.
    private var markScale: CGFloat {
        let peak = Motion.orbit + 0.06
        let over = time < peak ? 1 : exp(-(time - peak) / Motion.settle)
        return 1 + Motion.overshoot * over
    }

    /// A point of the artwork on screen, grown by `growth` about `origin`
    /// first.
    private func place(_ point: CGPoint, growth: CGFloat = 1, about origin: CGPoint = Geometry.heart) -> CGPoint {
        let grown = CGPoint(x: origin.x + (point.x - origin.x) * growth, y: origin.y + (point.y - origin.y) * growth)
        let scale = unit * markScale
        return CGPoint(
            x: pivot.x + (grown.x - Geometry.heart.x) * scale,
            y: pivot.y + (grown.y - Geometry.heart.y) * scale
        )
    }

    private func drawMark(in context: inout GraphicsContext) {
        // The dot opens as the stroke passes the foot of the page.
        let dotTime = Motion.orbit * pow((270 - 90) / travel, 1 / Motion.easeIn)
        let dot = springStep(time - dotTime, response: 0.2, damping: 0.72)
        if dot > 0.001 {
            let radius = Geometry.dotRadius * dot * unit * markScale
            context.fill(
                Path(ellipseIn: CGRect(x: pivot.x - radius, y: pivot.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(colour)
            )
        }

        // The arms, from the one the stroke lands on, on round anticlockwise.
        var arms = Path()
        let landing = Geometry.armAngles[Geometry.landingArm]
        for (arm, fan) in Geometry.arms.enumerated() {
            var turn = Geometry.armAngles[arm] - landing
            if turn < 0 { turn += 360 }
            let growth = springStep(time - Motion.orbit - turn / Motion.sweep, response: 0.17, damping: 0.72)
            guard growth > 0.001 else { continue }
            arms.addLines(fan.map { place($0, growth: growth) })
            arms.closeSubpath()
        }
        context.fill(arms, with: .color(colour))

        // The triangle, as the last arm settles.
        let triangle = springStep(time - Motion.orbit - 0.06, response: 0.22, damping: 0.62)
        if triangle > 0.001 {
            var path = Path()
            path.addLines(StarHashMarkShape.triangle.map { place($0, growth: triangle, about: Geometry.triangleCentre) })
            path.closeSubpath()
            context.fill(path, with: .color(colour))
        }
    }
}

/// A damped spring's step from 0 to 1, `time` seconds after it starts:
/// SwiftUI's `.spring(response:dampingFraction:)`, worked out by hand so a
/// frame can be drawn from the clock alone.
private func springStep(_ time: Double, response: Double, damping: Double) -> CGFloat {
    guard time > 0 else { return 0 }
    let omega = 2 * .pi / response
    let decay = exp(-damping * omega * time)
    let ringing = omega * sqrt(1 - damping * damping)
    return 1 - decay * (cos(ringing * time) + damping * omega / ringing * sin(ringing * time))
}

/// 0 below 0, 1 above 1, and an S curve between.
private func smoothstep(_ x: Double) -> CGFloat {
    let t = min(max(x, 0), 1)
    return t * t * (3 - 2 * t)
}

/// Shows the splash over the app on a cold launch, then fades it into the
/// app. The welcome and rating notes wait for it (`splashActive`), so they
/// never open over it. Debug launches that set up a screen skip it, so a
/// screenshot sees the screen; `-splash` shows it anyway.
struct SplashGate<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var showsSplash = SplashGate.showsAtLaunch

    var body: some View {
        ZStack {
            content
                .environment(\.splashActive, showsSplash)
            if showsSplash {
                SplashView {
                    withAnimation(.smooth(duration: 0.35)) { showsSplash = false }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }

    private static var showsAtLaunch: Bool {
        #if DEBUG
        let arguments = DebugLaunch.arguments
        if arguments.contains("-splash") { return true }
        return !arguments.contains { $0.hasPrefix("-") && $0 != "-splash" && !$0.hasPrefix("-NS") && !$0.hasPrefix("-Apple") && !$0.hasPrefix("-UI") }
        #else
        return true
        #endif
    }
}

extension EnvironmentValues {
    /// True while the launch splash is on screen.
    @Entry var splashActive = false
}
