import CoreImage
import SwiftUI
import UIKit

/// The **Distortion Wave**, after the owner's reference (a distortion
/// waves effect library), on the confirmation sheets: as a sheet confirms
/// something, a ring of light in the outcome's colour opens from its icon,
/// its edge moving as a liquid's, blurring what it crosses and leaving the
/// new state behind it, lights the sheet's edges as it reaches them, and
/// fades from them. (The recipient screen had a wave of its own; the owner
/// took it away.)
///
/// A Metal layer effect cannot draw Liquid Glass or UIKit-backed views, so
/// it plays over snapshots of the sheet before and after, in a window above
/// the app's, which lets the second snapshot show the new state and not the
/// wave over it. Both states are captured before the wave starts, the old
/// one held still meanwhile, so the change never freezes the wave partway.
/// Callers skip it under Reduce Motion. The shader is in
/// Shaders/DistortionWave.metal.
@MainActor
final class DistortionWave {
    static let shared = DistortionWave()

    private var window: UIWindow?
    private var waiting: [CheckedContinuation<Void, Never>] = []

    var isPlaying: Bool { window != nil }

    /// Returns once the wave has finished, at once if none is playing.
    func settled() async {
        guard isPlaying else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// The wave in `tint`, over the sheet showing, from `iconFromTop`
    /// points below its top edge in its middle, where its icon is; `swap`
    /// puts its outcome in place without an animation of its own.
    func playOnSheet(tint: Color, iconFromTop: CGFloat, dark: Bool, swap: @escaping @MainActor () -> Void) {
        guard window == nil,
              let main = Self.keyWindow,
              let scene = main.windowScene,
              let sheet = Self.sheet(in: main),
              let before = Self.snapshot(of: main, region: sheet.frame, afterUpdates: false)
        else {
            swap()
            return
        }
        let region = sheet.frame
        let model = DistortionWaveModel(
            tint: tint,
            before: before,
            soft: Self.softened(before, before) ?? before,
            origin: CGPoint(x: region.width / 2, y: iconFromTop),
            corner: sheet.corner
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
            // A frame for the still to be up before the sheet under it
            // changes, and one for the new state to lay out.
            try? await Task.sleep(for: .milliseconds(20))
            swap()
            try? await Task.sleep(for: .milliseconds(40))
            let after = Self.snapshot(of: main, region: region, afterUpdates: true) ?? before
            model.soft = Self.softened(before, after) ?? model.soft
            model.after = after
            model.start = .now
            try? await Task.sleep(for: .seconds(DistortionWaveTiming.duration))
            overlay.isHidden = true
            self.window = nil
            let waiting = self.waiting
            self.waiting = []
            waiting.forEach { $0.resume() }
        }
    }

    /// Compiles the shader ahead of the first wave, which would otherwise
    /// hold a frame or two.
    static func prepare() async {
        let blank = Shader.Argument.image(Image(uiImage: UIImage()))
        let numbers = [Shader.Argument](repeating: .float(0), count: 7)
        do {
            try await Shader(
                function: ShaderLibrary.SheetWave,
                arguments: [.float2(CGSize.zero), .float2(CGPoint.zero)] + numbers + [.float(0), .color(.clear), blank, blank, blank]
            ).compile(as: .colorEffect)
        } catch {
            #if DEBUG
            print("DistortionWave shader:", error)
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

    /// Both snapshots out of focus, as the ring blurs what it crosses, side
    /// by side in one image (SwiftUI hands a shader three images at most):
    /// blurred at a quarter of their size, which is quick and blurs further.
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

/// When each part of the wave happens, in seconds from its start: measured
/// from the reference frame by frame.
enum DistortionWaveTiming {
    /// The ripple round the icon before the ring opens, rising then gone.
    static let pre = 0...0.16
    /// The ring, from the icon to past the sheet's far edge.
    static let sweep = 0.06...0.56
    /// The new state behind the ring.
    static let reveal = 0.06...0.56
    /// How out of focus what the ring crosses is: rising, then settling.
    static let hazeIn = 0.06...0.2
    static let hazeOut = 0.5...0.75
    /// The edges' glow: rising, then fading.
    static let edgeIn = 0.3...0.5
    static let edgeOut = 0.62...1.35
    static let duration = 1.4

    /// 0 before `range`, 1 after, smooth between.
    static func ramp(_ time: Double, _ range: ClosedRange<Double>) -> Double {
        let p = min(max((time - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
        return p * p * (3 - 2 * p)
    }
}

@MainActor
@Observable
private final class DistortionWaveModel {
    let tint: Color
    let before: UIImage
    let origin: CGPoint
    let corner: CGFloat
    /// When the wave started; until then the old state is held still.
    var start: Date?
    var after: UIImage?
    /// Both states out of focus, side by side.
    var soft: UIImage

    init(tint: Color, before: UIImage, soft: UIImage, origin: CGPoint, corner: CGFloat) {
        self.tint = tint
        self.before = before
        self.soft = soft
        self.origin = origin
        self.corner = corner
    }
}

private struct DistortionWaveView: View {
    let model: DistortionWaveModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let size = model.before.size
        TimelineView(.animation) { context in
            let time = model.start.map { context.date.timeIntervalSince($0) } ?? 0
            let started = model.after != nil
            let ramp = { (range: ClosedRange<Double>) in started ? DistortionWaveTiming.ramp(time, range) : 0 }
            let pre = started ? sin(.pi * min(max(time / DistortionWaveTiming.pre.upperBound, 0), 1)) : 0
            let arguments: [Shader.Argument] = [
                .float2(size),
                .float2(model.origin),
                .float(reach(in: size) * front(ramp(DistortionWaveTiming.sweep))),
                .float(time),
                .float(pre),
                .float(ramp(DistortionWaveTiming.reveal)),
                .float(ramp(DistortionWaveTiming.hazeIn) * (1 - ramp(DistortionWaveTiming.hazeOut))),
                .float(ramp(DistortionWaveTiming.edgeIn) * (1 - ramp(DistortionWaveTiming.edgeOut))),
                .float(colorScheme == .dark ? 1 : 0),
                .float(model.corner),
                .color(model.tint),
                .image(Image(uiImage: model.before)),
                .image(Image(uiImage: model.after ?? model.before)),
                .image(Image(uiImage: model.soft)),
            ]
            Rectangle()
                .frame(width: size.width, height: size.height)
                .colorEffect(Shader(function: ShaderLibrary.SheetWave, arguments: arguments))
        }
        .ignoresSafeArea()
    }

    /// The ring's share of its way: quick to open, easing out past the far
    /// edge.
    private func front(_ p: Double) -> CGFloat {
        CGFloat(1 - pow(1 - p, 1.6))
    }

    /// From the icon to the farthest corner, and the ring's width past it,
    /// so it leaves entirely.
    private func reach(in size: CGSize) -> CGFloat {
        let corners = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
        let farthest = corners.map { hypot($0.x - model.origin.x, $0.y - model.origin.y) }.max() ?? 0
        return farthest + 120
    }
}
