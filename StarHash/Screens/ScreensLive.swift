#if DEBUG
import SwiftUI
import UIKit

/// Debug-only live view for the Screens Mac app. Shows one catalog screen, writes it to
/// `live.jpg` every frame, and acts on the taps, scrolls and typing the Mac app appends
/// to `live.cmd` as JSON lines. Started by the serve loop, or at launch with
/// `SCREENS_LIVE` set to a catalog id. A tap that leads to another screen
/// (`ScreensLive.go`) shows that one and says so in `live.at`.
@MainActor
final class ScreensLive: NSObject {
    static var shared: ScreensLive?

    /// Where a tap leads, for Clair's live view: call it from the catalog's sample closures,
    /// `onOpen: { ScreensLive.go("detail") }`, with the ids `leadsTo` names. The live view
    /// then goes to that screen as the app would. Anywhere else it does nothing.
    nonisolated static func go(_ id: String, state: String = "default") {
        Task { @MainActor in shared?.show(id, state: state, back: false) }
    }

    private let window: UIWindow
    private let outDir: URL
    private var link: CADisplayLink?
    private var commandOffset: UInt64 = 0
    private var frames = 0
    private var frameStarted = Date()
    private var drawSeconds = 0.0
    /// Set while a frame is being encoded; only touched on the main thread.
    private final class Busy: @unchecked Sendable { var value = false }
    private let encoding = Busy()
    private let encoder = DispatchQueue(label: "screens.live.encode")

    static func start(_ entry: ScreensEntry, state: String = "default", outDir: URL? = nil) {
        stop()
        guard let outDir = outDir ?? ScreensAgent.outDir,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        ScreensAgent.enableAccessibilityTree()
        let window = UIWindow(windowScene: scene)
        ScreensLook.read(near: outDir).apply(to: window)
        window.rootViewController = UIHostingController(rootView: entry.make(state))
        window.makeKeyAndVisible()
        let live = ScreensLive(window: window, outDir: outDir, at: (entry.id, state))
        shared = live
        live.run()
    }

    static func stop() {
        guard let live = shared else { return }
        live.link?.invalidate()
        live.window.isHidden = true
        live.window.rootViewController = nil
        shared = nil
    }

    /// The screen showing, and how many times a tap has gone to another.
    private var current: (id: String, state: String)
    private var moves = 0

    private init(window: UIWindow, outDir: URL, at current: (id: String, state: String)) {
        self.window = window
        self.outDir = outDir
        self.current = current
    }

    /// Goes to another screen of the catalog with a push (from the left going back), and
    /// writes where it went to `live.at` for Clair: its trail, its Back, and the arrow.
    private func show(_ id: String, state: String, back: Bool) {
        guard let entry = ScreensCatalog.entries.first(where: { $0.id == id }) else { return }
        let from = current.id
        current = (id, state)
        firstResponder()?.resignFirstResponder()
        // The screen leaving stays a real view while it slides (a layer transition or a
        // snapshot would draw black in the frames), and goes when the push ends.
        let leaving = window.rootViewController
        window.rootViewController = UIHostingController(rootView: entry.make(state))
        if let old = leaving?.view, let new = window.rootViewController?.view {
            let width = window.bounds.width
            if back { window.addSubview(old) } else { window.insertSubview(old, belowSubview: new) }
            new.transform = CGAffineTransform(translationX: back ? -width * 0.3 : width, y: 0)
            UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut]) {
                new.transform = .identity
                old.transform = CGAffineTransform(translationX: back ? width : -width * 0.3, y: 0)
            } completion: { _ in
                old.removeFromSuperview()
                _ = leaving
            }
        }
        moves += 1
        let at: [String: Any] = ["move": moves, "id": id, "state": state, "from": from, "back": back]
        if let data = try? JSONSerialization.data(withJSONObject: at) {
            try? data.write(to: outDir.appendingPathComponent("live.at"), options: .atomic)
        }
    }

    private func run() {
        let cmd = outDir.appendingPathComponent("live.cmd")
        FileManager.default.createFile(atPath: cmd.path, contents: Data())
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick() {
        readCommands()
        writeFrame()
    }

    // MARK: - Frames

    /// Drawing has to happen on the main thread; encoding and writing don't, so they run
    /// beside it, and a frame is skipped while the last one is still being written.
    private func writeFrame() {
        guard !encoding.value else { return }
        let bounds = window.bounds
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.5
        format.opaque = true
        let drawStarted = Date()
        // A SceneKit view needs its cover drawn in, which takes a fresh screen update.
        let hasScenes = ScreensAgent.hasSceneKitViews(in: window)
        let uncover = hasScenes ? ScreensAgent.coverSceneKitViews(in: window) : {}
        // Every visible window of the scene, bottom to top, so the app's own overlays show
        // over the screen. Not the text effects window a text field leaves behind: it
        // draws as solid black over everything (on iOS 27 the keyboard isn't in it, or in
        // any of the app's windows, so it can't be drawn here; typing still reaches it).
        let windows = (window.windowScene?.windows ?? [window])
            .filter { !$0.isHidden && $0.alpha > 0 && ($0 === window || $0.windowLevel > window.windowLevel) }
            .filter { NSStringFromClass(type(of: $0)) != "UITextEffectsWindow" }
            .sorted { $0.windowLevel < $1.windowLevel }
        func render(fresh: Bool) -> UIImage {
            UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
                for each in windows {
                    each.drawHierarchy(in: each.frame, afterScreenUpdates: fresh || (hasScenes && each === window))
                }
            }
        }
        var image = render(fresh: drawsFresh)
        // A Simulator whose display isn't showing the app (asleep, locked) gives a blank
        // snapshot: then every frame is drawn afresh, as the pictures are.
        if !drawsFresh, Self.isBlank(image) {
            drawsFresh = true
            image = render(fresh: true)
        }
        uncover()
        drawSeconds += Date().timeIntervalSince(drawStarted)
        encoding.value = true
        let url = outDir.appendingPathComponent("live.jpg")
        let busy = encoding
        let frame = image
        encoder.async {
            if let data = frame.jpegData(compressionQuality: 0.75) { try? data.write(to: url, options: .atomic) }
            DispatchQueue.main.async { busy.value = false }
        }
        frames += 1
        if frames % 30 == 0 {
            let fps = 30 / Date().timeIntervalSince(frameStarted)
            frameStarted = Date()
            let drawMS = drawSeconds / 30 * 1000
            drawSeconds = 0
            try? String(format: "%.1f (draw %.0f ms)", fps, drawMS).write(
                to: outDir.appendingPathComponent("live.fps"), atomically: true, encoding: .utf8)
        }
    }

    /// Frames drawn afresh rather than snapshot from the display (see writeFrame).
    private var drawsFresh = false

    /// Whether a frame came out blank: nothing but black, read from an 8 × 8 copy of it.
    private static func isBlank(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        var pixels = [UInt8](repeating: 0, count: 8 * 8 * 4)
        guard let context = CGContext(data: &pixels, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: 8, height: 8))
        return pixels.enumerated().allSatisfy { index, value in index % 4 == 3 || value < 6 }
    }

    // MARK: - Commands

    private struct Command: Decodable {
        var tap: [Double]?
        var down: [Double]?     // x, y: a finger touches the screen
        var move: [Double]?     // x, y: it moves
        var up: [Double]?       // x, y: it lifts
        var scroll: [Double]?   // x, y, dx, dy
        var type: String?
        var key: String?        // "return", "delete"
        var open: String?       // "id" or "id@state": Clair's Back
        var back: Bool?
        var sent: Double?       // Mac clock, for latency
    }

    private func readCommands() {
        guard let handle = try? FileHandle(forReadingFrom: outDir.appendingPathComponent("live.cmd")) else { return }
        defer { try? handle.close() }
        try? handle.seek(toOffset: commandOffset)
        guard let data = try? handle.readToEnd(), !data.isEmpty,
              let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return }
        let complete = data[data.startIndex...lastNewline]
        commandOffset += UInt64(complete.count)
        for line in complete.split(separator: UInt8(ascii: "\n")) {
            guard let command = try? JSONDecoder().decode(Command.self, from: Data(line)) else { continue }
            perform(command)
        }
    }

    /// Where the finger went down, for falling back to a tap when real touches can't be made.
    private var downAt: CGPoint?

    private func perform(_ command: Command) {
        if let p = command.tap, p.count == 2 { tap(CGPoint(x: p[0], y: p[1])) }
        if let p = command.down, p.count == 2 {
            let point = CGPoint(x: p[0], y: p[1])
            downAt = point
            if ScreensTouches.send(.began, at: point, in: window) { downAt = nil }
        }
        if let p = command.move, p.count == 2, downAt == nil {
            _ = ScreensTouches.send(.moved, at: CGPoint(x: p[0], y: p[1]), in: window)
        }
        if let p = command.up, p.count == 2 {
            let point = CGPoint(x: p[0], y: p[1])
            if let start = downAt {
                // No real touches here: a click still taps, through accessibility.
                if hypot(point.x - start.x, point.y - start.y) < 8 { tap(point) }
                downAt = nil
            } else {
                _ = ScreensTouches.send(.ended, at: point, in: window)
            }
        }
        if let s = command.scroll, s.count == 4 { scroll(at: CGPoint(x: s[0], y: s[1]), by: CGVector(dx: s[2], dy: s[3])) }
        if let open = command.open {
            let parts = open.split(separator: "@", maxSplits: 1).map(String.init)
            if let id = parts.first { show(id, state: parts.count > 1 ? parts[1] : "default", back: command.back ?? false) }
        }
        if let text = command.type { (firstResponder() as? any UIKeyInput)?.insertText(text) }
        switch command.key {
        case "return": (firstResponder() as? any UIKeyInput)?.insertText("\n")
        case "delete": (firstResponder() as? any UIKeyInput)?.deleteBackward()
        default: break
        }
        if let sent = command.sent {
            let ms = Int((Date().timeIntervalSince1970 - sent) * 1000)
            try? "\(ms)".write(to: outDir.appendingPathComponent("live.lag"), atomically: true, encoding: .utf8)
        }
    }

    /// Public APIs can't synthesize a real touch, so a tap goes to what a touch there
    /// would have reached: a text input gets focus, a UIKit control gets its action,
    /// and anything else gets activated through accessibility, as VoiceOver would.
    private func tap(_ point: CGPoint) {
        let hit = window.hitTest(point, with: nil)
        let chain = sequence(first: hit, next: { $0?.superview }).compactMap { $0 }
        if let input = chain.first(where: { $0 is UITextField || $0 is UITextView }) {
            input.becomeFirstResponder()
            return
        }
        if let toggle = chain.first(where: { $0 is UISwitch }) as? UISwitch {
            toggle.setOn(!toggle.isOn, animated: true)
            toggle.sendActions(for: .valueChanged)
            return
        }
        if let control = chain.first(where: { $0 is UIControl }) as? UIControl, !(control is UITextField) {
            control.sendActions(for: .touchUpInside)
            return
        }
        firstResponder()?.resignFirstResponder()
        let target = activatable(in: window)
            .filter { $0.accessibilityFrame.contains(point) }
            .min { area($0.accessibilityFrame) < area($1.accessibilityFrame) }
        _ = target?.accessibilityActivate()
    }

    private func scroll(at point: CGPoint, by delta: CGVector) {
        let hit = window.hitTest(point, with: nil)
        guard let scrollView = sequence(first: hit, next: { $0?.superview })
            .compactMap({ $0 as? UIScrollView }).first(where: { $0.isScrollEnabled }) else { return }
        var offset = scrollView.contentOffset
        let inset = scrollView.adjustedContentInset
        offset.x = min(max(offset.x - delta.dx, -inset.left),
                       max(-inset.left, scrollView.contentSize.width - scrollView.bounds.width + inset.right))
        offset.y = min(max(offset.y - delta.dy, -inset.top),
                       max(-inset.top, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom))
        scrollView.setContentOffset(offset, animated: false)
    }

    private func area(_ r: CGRect) -> CGFloat { r.width * r.height }

    private func activatable(in root: UIView) -> [NSObject] {
        var out: [NSObject] = []
        var seen = Set<ObjectIdentifier>()
        func visit(_ object: NSObject) {
            guard seen.insert(ObjectIdentifier(object)).inserted else { return }
            if object.isAccessibilityElement { out.append(object); return }
            if let children = object.accessibilityElements as? [NSObject] { children.forEach(visit) }
            if let view = object as? UIView { view.subviews.forEach(visit) }
        }
        visit(root)
        return out
    }

    private func firstResponder() -> UIResponder? {
        func find(_ view: UIView) -> UIResponder? {
            if view.isFirstResponder { return view }
            for sub in view.subviews { if let r = find(sub) { return r } }
            return nil
        }
        return find(window)
    }
}

/// Real touches, made the way the system makes them: a digitizer event handed to UIKit,
/// which turns it into touches, so every gesture (drags, sliders, long presses, swipes)
/// works as on a phone. Private API, in debug builds only, as touch-testing tools use it.
@MainActor
enum ScreensTouches {
    enum Phase { case began, moved, ended }

    private typealias CreateHand = @convention(c) (CFAllocator?, UInt64, UInt32, UInt32, UInt32, UInt32, UInt32,
                                                   Double, Double, Double, Double, Double, UInt8, UInt8, UInt32) -> Unmanaged<CFTypeRef>?
    private typealias CreateFinger = @convention(c) (CFAllocator?, UInt64, UInt32, UInt32, UInt32,
                                                     Double, Double, Double, Double, Double, UInt8, UInt8, UInt32) -> Unmanaged<CFTypeRef>?
    private typealias Append = @convention(c) (CFTypeRef, CFTypeRef, UInt32) -> Void
    private typealias SetInteger = @convention(c) (CFTypeRef, UInt32, Int) -> Void
    private typealias SetFloat = @convention(c) (CFTypeRef, UInt32, Double) -> Void
    private typealias SetSender = @convention(c) (CFTypeRef, UInt64) -> Void
    private typealias SetDigitizerInfo = @convention(c) (CFTypeRef, UInt32, UInt8, UInt8, CFString?, Double, Float) -> Void

    private struct API {
        let hand: CreateHand
        let finger: CreateFinger
        let append: Append
        let setInteger: SetInteger
        let setFloat: SetFloat
        let setSender: SetSender
        let digitizerInfo: SetDigitizerInfo
    }

    private static let api: API? = {
        _ = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_NOW)
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil } // RTLD_DEFAULT
            return unsafeBitCast(pointer, to: type)
        }
        guard UIApplication.shared.responds(to: NSSelectorFromString("_enqueueHIDEvent:")),
              let hand = symbol("IOHIDEventCreateDigitizerEvent", as: CreateHand.self),
              let finger = symbol("IOHIDEventCreateDigitizerFingerEvent", as: CreateFinger.self),
              let append = symbol("IOHIDEventAppendEvent", as: Append.self),
              let setInteger = symbol("IOHIDEventSetIntegerValue", as: SetInteger.self),
              let setFloat = symbol("IOHIDEventSetFloatValue", as: SetFloat.self),
              let setSender = symbol("IOHIDEventSetSenderID", as: SetSender.self),
              let info = symbol("BKSHIDEventSetDigitizerInfo", as: SetDigitizerInfo.self) else { return nil }
        return API(hand: hand, finger: finger, append: append, setInteger: setInteger, setFloat: setFloat,
                   setSender: setSender, digitizerInfo: info)
    }()

    // IOHIDEvent digitizer fields: (type 11) << 16 + field.
    private static let field: (Int) -> UInt32 = { UInt32((11 << 16) + $0) }
    private static let majorRadius = field(20), minorRadius = field(21), displayIntegrated = field(25)
    private static let range: UInt32 = 1, touch: UInt32 = 2, position: UInt32 = 4

    /// Sends one finger's touch at a point in the window. False when this system can't.
    static func send(_ phase: Phase, at point: CGPoint, in window: UIWindow) -> Bool {
        guard let api, let context = window.value(forKey: "_contextId") as? UInt32 else { return false }
        let screen = window.convert(point, to: window.screen.coordinateSpace)
        let time = mach_absolute_time()
        let mask = phase == .moved ? position : range | touch
        let down: UInt8 = phase == .ended ? 0 : 1
        guard let hand = api.hand(kCFAllocatorDefault, time, 3, 0, 0, mask, 0, 0, 0, 0, 0, 0, down, down, 0)?
            .takeRetainedValue(),
              let finger = api.finger(kCFAllocatorDefault, time, 1, 2, mask, screen.x, screen.y, 0,
                                      Double(down), 0, down, down, 0)?.takeRetainedValue() else { return false }
        api.setInteger(hand, displayIntegrated, 1)
        api.setInteger(finger, displayIntegrated, 1)
        api.setFloat(finger, majorRadius, 5)
        api.setFloat(finger, minorRadius, 5)
        api.append(hand, finger, 0)
        api.setSender(hand, 0x0000_0001_2345_6789)
        api.digitizerInfo(hand, context, 0, 0, nil, 0, 0)
        UIApplication.shared.perform(NSSelectorFromString("_enqueueHIDEvent:"), with: hand)
        return true
    }
}

struct ScreensLiveHost: SwiftUI.View {
    let entry: ScreensEntry
    var body: some SwiftUI.View {
        SwiftUI.Color.black.task {
            ScreensAgent.allowCamera()
            ScreensLive.start(entry)
        }
    }
}
#endif
