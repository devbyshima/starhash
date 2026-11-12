import CoreImage
import SwiftUI
import UIKit

/// The **Distortion Wave**, after the owner's reference (a distortion
/// waves effect library, its two kinds of wave), in a window of its own
/// over snapshots of the screen before and after a change.
///
/// - The screen's: as someone is picked on the recipient screen, the words
///   near the bottom shimmer and split, then a bubble rises from behind the
///   bottom bar and sweeps up and off the screen, deep green inside under a
///   mint rim (the sheet's green, at the owner's ask), bending what it is
///   about to cross. Pay comes through it out of focus and settles, and a
///   glow runs round the screen's edges and fades. The live tab bar is left
///   uncovered, so it floats over the wave.
/// - The sheet's: as a sheet confirms something, a ring of light in the
///   outcome's colour opens from its icon, blurring what it crosses and
///   leaving the new state behind it, lights the sheet's edges as it
///   reaches them, and fades from them.
///
/// A Metal layer effect cannot draw Liquid Glass or UIKit-backed views, so
/// both play over snapshots, in a window above the app's, which lets the
/// second snapshot show the new state and not the wave over it. Both states
/// are captured before the wave starts, the old one held still meanwhile,
/// so the change never freezes the wave partway. Callers skip it under
/// Reduce Motion, and wait on `settled()` before anything that would stall
/// it, such as the call prompt. The shaders are in
/// Shaders/DistortionWave.metal.
@MainActor
final class DistortionWave {
    static let shared = DistortionWave()

    enum Kind {
        /// The whole screen, from just above its bottom bar.
        case screen
        /// A sheet, from its icon, in its outcome's colour.
        case sheet(tint: Color)
    }

    private var window: UIWindow?
    private var waiting: [CheckedContinuation<Void, Never>] = []

    var isPlaying: Bool { window != nil }

    /// Returns once the wave has finished, at once if none is playing.
    func settled() async {
        guard isPlaying else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// The screen's wave, rising from the foot of the screen, `swap`
    /// putting the next screen in place without an animation of its own.
    /// `floating` (window points), the tab bar's capsule, is left uncovered,
    /// so the live bar floats over the wave as the reference's button
    /// stays over its bubble, and never vanishes while it plays.
    func play(dark: Bool, keeping floating: CGRect? = nil, swap: @escaping @MainActor () -> Void) {
        guard let main = Self.keyWindow else {
            swap()
            return
        }
        let bounds = main.bounds
        // The reference's bubble rises from low on the screen, wide, a dome
        // more than a ring: from just behind the bottom bar.
        let origin = CGPoint(x: bounds.midX, y: bounds.maxY - bounds.height * 0.09)
        play(.screen, in: main, region: bounds, corner: Self.displayCorner, origin: origin, hole: floating, dark: dark, swap: swap)
    }

    /// The sheet's wave, over the sheet showing, from `iconFromTop` points
    /// below its top edge in its middle, where its icon is; `swap` puts
    /// its outcome in place.
    func playOnSheet(tint: Color, iconFromTop: CGFloat, dark: Bool, swap: @escaping @MainActor () -> Void) {
        guard let main = Self.keyWindow, let sheet = Self.sheet(in: main) else {
            swap()
            return
        }
        let origin = CGPoint(x: sheet.frame.midX, y: sheet.frame.minY + iconFromTop)
        play(.sheet(tint: tint), in: main, region: sheet.frame, corner: sheet.corner, origin: origin, hole: nil, dark: dark, swap: swap)
    }

    private func play(
        _ kind: Kind,
        in main: UIWindow,
        region: CGRect,
        corner: CGFloat,
        origin: CGPoint,
        hole: CGRect?,
        dark: Bool,
        swap: @escaping @MainActor () -> Void
    ) {
        guard window == nil,
              let scene = main.windowScene,
              let before = Self.snapshot(of: main, region: region, afterUpdates: false)
        else {
            swap()
            return
        }
        let model = DistortionWaveModel(
            kind: kind,
            before: before,
            soft: Self.softened(before, before) ?? before,
            origin: CGPoint(x: origin.x - region.minX, y: origin.y - region.minY),
            corner: corner,
            hole: hole.map { $0.offsetBy(dx: -region.minX, dy: -region.minY) }
        )
        let host = UIHostingController(rootView: DistortionWaveView(model: model).environment(\.colorScheme, dark ? .dark : .light))
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []
        let overlay = UIWindow(windowScene: scene)
        overlay.frame = region
        overlay.windowLevel = .normal + 1
        overlay.isUserInteractionEnabled = false
        overlay.backgroundColor = .clear
        overlay.rootViewController = host
        overlay.isHidden = false
        window = overlay

        Task { @MainActor in
            // A frame for the still to be up before the screen under it
            // changes, and one for the new state to lay out.
            try? await Task.sleep(for: .milliseconds(20))
            swap()
            try? await Task.sleep(for: .milliseconds(40))
            let after = Self.snapshot(of: main, region: region, afterUpdates: true) ?? before
            model.soft = Self.softened(before, after) ?? model.soft
            model.after = after
            model.start = .now
            try? await Task.sleep(for: .seconds(DistortionWaveTiming(kind).duration))
            overlay.isHidden = true
            self.window = nil
            let waiting = self.waiting
            self.waiting = []
            waiting.forEach { $0.resume() }
        }
    }

    /// Compiles the shaders ahead of the first wave, which would otherwise
    /// hold a frame or two.
    static func prepare() async {
        let blank = Shader.Argument.image(Image(uiImage: UIImage()))
        let numbers = [Shader.Argument](repeating: .float(0), count: 7)
        do {
            try await Shader(
                function: ShaderLibrary.DistortionWave,
                arguments: [.float2(CGSize.zero), .float2(CGPoint.zero)] + numbers + [.float4(0, 0, 0, 0), .color(.clear), blank, blank, blank]
            ).compile(as: .colorEffect)
            try await Shader(
                function: ShaderLibrary.SheetWave,
                arguments: [.float2(CGSize.zero), .float2(CGPoint.zero)] + numbers + [.float(0), .color(.clear), blank, blank, blank]
            ).compile(as: .colorEffect)
        } catch {
            #if DEBUG
            print("DistortionWave shaders:", error)
            #endif
        }
    }

    // MARK: Snapshots

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    /// The screen's corners, which its edges' glow follows: the iPhone's
    /// display, near enough on every model with rounded corners.
    private static let displayCorner: CGFloat = 55

    /// The sheet on top, in window points, with its corners' radius.
    private static func sheet(in window: UIWindow) -> (frame: CGRect, corner: CGFloat)? {
        var top = window.rootViewController
        while let next = top?.presentedViewController { top = next }
        guard let view = top?.view, top !== window.rootViewController else { return nil }
        // The sheet's rounding is on the view or a container round it.
        var corner: CGFloat = 0
        var current: UIView? = view
        while let candidate = current, candidate !== window, corner == 0 {
            corner = candidate.layer.cornerRadius
            current = candidate.superview
        }
        return (view.convert(view.bounds, to: window), corner > 0 ? corner : 38)
    }

    private static func snapshot(of window: UIWindow, region: CGRect, afterUpdates: Bool) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: region.size, format: format).image { _ in
            window.drawHierarchy(
                in: CGRect(origin: CGPoint(x: -region.minX, y: -region.minY), size: window.bounds.size),
                afterScreenUpdates: afterUpdates
            )
        }
    }

    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// Both snapshots out of focus, as the bubble's frosted inside shows
    /// them, side by side in one image (SwiftUI hands a shader three images
    /// at most): blurred at a quarter of their size, which is quick and
    /// blurs further.
    private static func softened(_ first: UIImage, _ second: UIImage) -> UIImage? {
        func quarter(_ image: UIImage) -> CIImage? {
            guard let cgImage = image.cgImage else { return nil }
            let small = CIImage(cgImage: cgImage).transformed(by: CGAffineTransform(scaleX: 0.25, y: 0.25))
            return small.clampedToExtent().applyingGaussianBlur(sigma: 9).cropped(to: small.extent)
        }
        guard let left = quarter(first), let right = quarter(second) else { return nil }
        let pair = right.transformed(by: CGAffineTransform(translationX: left.extent.width, y: 0)).composited(over: left)
        let extent = CGRect(x: 0, y: 0, width: left.extent.width * 2, height: left.extent.height)
        guard let result = context.createCGImage(pair, from: extent) else { return nil }
        return UIImage(cgImage: result, scale: first.scale * 0.25, orientation: .up)
    }
}

/// When each part of a wave happens, in seconds from its start: measured
/// from the reference frame by frame.
struct DistortionWaveTiming {
    /// The shimmer before the front forms, rising then gone.
    let pre: ClosedRange<Double>
    /// The front, from forming to off the far edge.
    let sweep: ClosedRange<Double>
    /// The new state coming through behind the front.
    let reveal: ClosedRange<Double>
    /// How out of focus what the front has passed is: rising, then
    /// settling once the front has gone.
    let hazeIn: ClosedRange<Double>
    let hazeOut: ClosedRange<Double>
    /// The edges' glow: rising, then fading.
    let edgeIn: ClosedRange<Double>
    let edgeOut: ClosedRange<Double>
    let duration: Double

    init(_ kind: DistortionWave.Kind) {
        switch kind {
        case .screen:
            pre = 0...0.28
            sweep = 0.16...0.78
            reveal = 0.4...0.68
            hazeIn = 0.18...0.36
            hazeOut = 0.64...0.86
            edgeIn = 0.56...0.74
            edgeOut = 0.98...1.6
            duration = 1.65
        case .sheet:
            pre = 0...0.16
            sweep = 0.06...0.56
            reveal = 0.06...0.56
            hazeIn = 0.06...0.2
            hazeOut = 0.5...0.75
            edgeIn = 0.3...0.5
            edgeOut = 0.62...1.35
            duration = 1.4
        }
    }

    /// 0 before `range`, 1 after, smooth between.
    static func ramp(_ time: Double, _ range: ClosedRange<Double>) -> Double {
        let p = min(max((time - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
        return p * p * (3 - 2 * p)
    }
}

@MainActor
@Observable
private final class DistortionWaveModel {
    let kind: DistortionWave.Kind
    let before: UIImage
    let origin: CGPoint
    let corner: CGFloat
    /// Left uncovered, the live view under it showing: the tab bar.
    let hole: CGRect?
    /// When the wave started; until then the old state is held still.
    var start: Date?
    var after: UIImage?
    /// Both states out of focus, side by side.
    var soft: UIImage

    init(kind: DistortionWave.Kind, before: UIImage, soft: UIImage, origin: CGPoint, corner: CGFloat, hole: CGRect?) {
        self.kind = kind
        self.before = before
        self.soft = soft
        self.origin = origin
        self.corner = corner
        self.hole = hole
    }
}

private struct DistortionWaveView: View {
    let model: DistortionWaveModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let size = model.before.size
        let timing = DistortionWaveTiming(model.kind)
        TimelineView(.animation) { context in
            let time = model.start.map { context.date.timeIntervalSince($0) } ?? 0
            let started = model.after != nil
            let ramp = { (range: ClosedRange<Double>) in started ? DistortionWaveTiming.ramp(time, range) : 0 }
            let pre = started ? sin(.pi * min(max(time / timing.pre.upperBound, 0), 1)) : 0
            let numbers: [Shader.Argument] = [
                .float(reach(in: size) * front(ramp(timing.sweep))),
                .float(time),
                .float(pre),
                .float(ramp(timing.reveal)),
                .float(ramp(timing.hazeIn) * (1 - ramp(timing.hazeOut))),
                .float(ramp(timing.edgeIn) * (1 - ramp(timing.edgeOut))),
                .float(colorScheme == .dark ? 1 : 0),
            ]
            let images: [Shader.Argument] = [
                .image(Image(uiImage: model.before)),
                .image(Image(uiImage: model.after ?? model.before)),
                .image(Image(uiImage: model.soft)),
            ]
            let place: [Shader.Argument] = [.float2(size), .float2(model.origin)]
            Rectangle()
                .frame(width: size.width, height: size.height)
                .colorEffect(shader(place + numbers, images))
        }
        .ignoresSafeArea()
    }

    private func shader(_ numbers: [Shader.Argument], _ images: [Shader.Argument]) -> Shader {
        switch model.kind {
        case .screen:
            let hole = model.hole ?? .zero
            let keep = Shader.Argument.float4(Float(hole.minX), Float(hole.minY), Float(hole.width), Float(hole.height))
            return Shader(function: ShaderLibrary.DistortionWave, arguments: numbers + [keep, .color(.waveConfirmed)] + images)
        case .sheet(let tint):
            return Shader(function: ShaderLibrary.SheetWave, arguments: numbers + [.float(model.corner), .color(tint)] + images)
        }
    }

    /// The front's share of its way: quick to form, steady across the
    /// screen and easing out past the far edge, as the reference's bubble.
    private func front(_ p: Double) -> CGFloat {
        CGFloat(1 - pow(1 - p, 1.6))
    }

    /// From the origin to the farthest corner, and the rim's width past it,
    /// so the front leaves entirely.
    private func reach(in size: CGSize) -> CGFloat {
        let corners = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
        let farthest = corners.map { hypot($0.x - model.origin.x, $0.y - model.origin.y) }.max() ?? 0
        return farthest + 120
    }
}
