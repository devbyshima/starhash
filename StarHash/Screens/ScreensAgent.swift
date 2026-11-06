import SwiftUI
import UIKit

#if DEBUG
import SceneKit

/// How Screens wants the screens drawn: light or dark, and at which text size. Screens
/// writes it to look.json beside the pictures.
struct ScreensLook: Codable {
    var appearance = "light"
    var textSize = "default"

    static func read(near folder: URL) -> ScreensLook {
        for dir in [folder, folder.deletingLastPathComponent()] {
            if let data = try? Data(contentsOf: dir.appendingPathComponent("look.json")),
               let look = try? JSONDecoder().decode(ScreensLook.self, from: data) { return look }
        }
        return ScreensLook()
    }

    @MainActor
    func apply(to window: UIWindow) {
        window.overrideUserInterfaceStyle = appearance == "dark" ? .dark : .light
        window.traitOverrides.preferredContentSizeCategory = category
    }

    private var category: UIContentSizeCategory {
        switch textSize {
        case "small": .small
        case "large": .extraLarge
        case "xl": .extraExtraLarge
        case "xxl": .extraExtraExtraLarge
        case "accessibility": .accessibilityLarge
        default: .large
        }
    }
}

/// One screen the catalog can stand up on its own, in one of its states.
struct ScreensEntry {
    let id: String
    let title: String
    let flow: String
    var states: [String] = ["default"]
    let make: (_ state: String) -> SwiftUI.AnyView
}

/// Debug-only bridge to the Screens Mac app. Never runs unless `SCREENS_OUT` is set.
///
/// - Export mode: the app renders every catalog entry at device size, writes a PNG and
///   the element tree of each, then `manifest.json`, and exits.
/// - Serve mode (`SCREENS_SERVE=1`): the app stays up. Each time the Mac app writes
///   `reload.json` naming a freshly built copy of this app's code, it loads that copy and
///   renders from it, which skips installing and relaunching the app.
@MainActor
enum ScreensAgent {
    static let outDir: URL? = ProcessInfo.processInfo.environment["SCREENS_OUT"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }

    /// The tokens each window's screen reported, while it's being captured.
    private static var specsByWindow: [ObjectIdentifier: ScreensSpecs] = [:]

    static func exportAndExit(_ entries: [ScreensEntry]) async {
        guard let outDir else { return }
        let env = ProcessInfo.processInfo.environment
        let first = Set((env["SCREENS_FIRST"] ?? "").split(separator: ",").map(String.init))
        await export(entries, to: outDir, first: first, seq: 0)
        exit(0)
    }

    static func export(_ entries: [ScreensEntry], to outDir: URL, first: Set<String>, seq: Int) async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let started = Date()
        var marks: [String: Int] = [:]
        func mark(_ name: String) { marks[name] = Int(Date().timeIntervalSince(started) * 1000) }
        let readyMS = Int(started.timeIntervalSince(processStart()) * 1000)
        enableAccessibilityTree()
        let bounds = scene.screen.bounds
        let scale = scene.screen.scale
        let waitMS = Int(ProcessInfo.processInfo.environment["SCREENS_WAIT_MS"] ?? "") ?? 600
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        var screens: [ManifestScreen] = []

        let look = ScreensLook.read(near: outDir)
        func standUp(_ entry: ScreensEntry, _ state: String) -> UIWindow {
            let window = UIWindow(windowScene: scene)
            window.frame = bounds
            look.apply(to: window)
            window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue - 1)
            let specs = ScreensSpecs()
            specsByWindow[ObjectIdentifier(window)] = specs
            window.rootViewController = UIHostingController(rootView: ScreensSpecReader(specs: specs, content: entry.make(state)))
            window.isHidden = false
            window.layoutIfNeeded()
            return window
        }
        func capture(_ entry: ScreensEntry, _ state: String, _ window: UIWindow) {
            let isFirst = first.contains(entry.id)
            let shotStarted = Date()
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = true
            let uncover = coverSceneKitViews(in: window)
            let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { _ in
                window.drawHierarchy(in: bounds, afterScreenUpdates: true)
            }
            uncover()
            if isFirst { mark("first.drawn") }
            let file = "\(entry.id)@\(state).png"
            let png = image.pngData()
            if isFirst { mark("first.encoded") }
            try? png?.write(to: outDir.appendingPathComponent(file), options: .atomic)
            if isFirst { mark("first.written") }
            screens.append(ManifestScreen(
                id: entry.id, title: entry.title, flow: entry.flow, state: state, image: file,
                captureMS: Int(Date().timeIntervalSince(shotStarted) * 1000),
                elements: elements(in: window),
                specs: specsByWindow[ObjectIdentifier(window)]?.values ?? []))
            specsByWindow[ObjectIdentifier(window)] = nil
            window.isHidden = true
            window.rootViewController = nil
        }

        // The screens just edited go first, one frame after layout, so the canvas
        // shows the change before the rest catch up.
        let pairs = entries.flatMap { entry in entry.states.map { (entry, $0) } }
        for (entry, state) in pairs where first.contains(entry.id) {
            let window = standUp(entry, state)
            mark("first.stoodUp")
            try? await Task.sleep(for: .milliseconds(16))
            mark("first.slept")
            capture(entry, state, window)
            mark("first.elements")
        }
        let firstMS = Int(Date().timeIntervalSince(started) * 1000)

        // The rest stand up together, so their images load during one shared wait.
        let rest = pairs.filter { !first.contains($0.0.id) }.map { ($0.0, $0.1, standUp($0.0, $0.1)) }
        try? await Task.sleep(for: .milliseconds(waitMS))
        for (entry, state, window) in rest {
            // A sheet still sliding in would be caught halfway, or not at all.
            for _ in 0..<50 where isPresenting(window) { try? await Task.sleep(for: .milliseconds(20)) }
            capture(entry, state, window)
        }
        let order = Dictionary(uniqueKeysWithValues: pairs.enumerated().map { ("\($1.0.id)@\($1.1)", $0) })
        screens.sort { order["\($0.id)@\($0.state)", default: 0] < order["\($1.id)@\($1.state)", default: 0] }

        let manifest = Manifest(
            width: bounds.width, height: bounds.height, scale: scale, seq: seq,
            appearance: look.appearance, textSize: look.textSize,
            processStartToReadyMS: readyMS, firstMS: firstMS, marks: marks,
            renderMS: Int(Date().timeIntervalSince(started) * 1000),
            screens: screens)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(manifest).write(to: outDir.appendingPathComponent("manifest.json"), options: .atomic)
    }

    private static func processStart() -> Date {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return Date() }
        let t = info.kp_proc.p_starttime
        return Date(timeIntervalSince1970: Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000)
    }

    /// Whether a sheet or other presentation in the window is still on its way in.
    static func isPresenting(_ window: UIWindow) -> Bool {
        var controller = window.rootViewController
        while let current = controller {
            if current.transitionCoordinator != nil || current.isBeingPresented { return true }
            controller = current.presentedViewController
        }
        return false
    }

    // MARK: - SceneKit

    /// SceneKit draws with Metal, outside UIKit's own drawing, so a picture of the window
    /// leaves its views blank. Each one is drawn on its own and laid over itself while the
    /// picture is taken. Returns what takes the covers off again.
    static func coverSceneKitViews(in root: UIView) -> () -> Void {
        var scenes: [SCNView] = []
        func visit(_ view: UIView) {
            if let scene = view as? SCNView, !scene.isHidden, scene.bounds.width > 0, scene.bounds.height > 0 {
                scenes.append(scene)
            }
            view.subviews.forEach(visit)
        }
        visit(root)
        let covers = scenes.map { scene in
            let cover = UIImageView(image: scene.snapshot())
            cover.frame = scene.bounds
            scene.addSubview(cover)
            return cover
        }
        return { covers.forEach { $0.removeFromSuperview() } }
    }

    static func hasSceneKitViews(in root: UIView) -> Bool {
        root is SCNView || root.subviews.contains { hasSceneKitViews(in: $0) }
    }

    // MARK: - Elements

    /// SwiftUI only builds its accessibility tree while an assistive technology or UI
    /// automation is on. This turns automation on for this process, the way in-process
    /// test tools like KIF do. A private symbol, so it lives in DEBUG builds only.
    static func enableAccessibilityTree() {
        guard let handle = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let symbol = dlsym(handle, "_AXSSetAutomationEnabled") else { return }
        typealias SetEnabled = @convention(c) (Int32) -> Void
        unsafeBitCast(symbol, to: SetEnabled.self)(1)
    }

    /// Leaf accessibility elements under a view, with frames in screen points.
    static func elements(in root: UIView) -> [ManifestElement] {
        var out: [ManifestElement] = []
        var seen = Set<ObjectIdentifier>()
        func visit(_ object: NSObject) {
            guard seen.insert(ObjectIdentifier(object)).inserted else { return }
            if let view = object as? UIView, view.isHidden || view.alpha < 0.01 { return }
            if object.isAccessibilityElement {
                let f = object.accessibilityFrame
                guard f.width > 0, f.height > 0 else { return }
                out.append(ManifestElement(
                    label: object.accessibilityLabel ?? "",
                    value: object.accessibilityValue,
                    identifier: (object as? any UIAccessibilityIdentification)?.accessibilityIdentifier,
                    traits: traitNames(object.accessibilityTraits),
                    x: f.minX, y: f.minY, width: f.width, height: f.height))
                return
            }
            // SwiftUI lists some children as accessibility elements and keeps others,
            // like scroll content, only as subviews, so follow both.
            if let children = object.accessibilityElements as? [NSObject] {
                children.forEach(visit)
            } else {
                let count = object.accessibilityElementCount()
                if count != NSNotFound, count > 0 {
                    for index in 0..<count {
                        if let child = object.accessibilityElement(at: index) as? NSObject { visit(child) }
                    }
                }
            }
            if let view = object as? UIView { view.subviews.forEach(visit) }
        }
        visit(root)
        return out
    }

    private static func traitNames(_ traits: UIAccessibilityTraits) -> [String] {
        let names: [(UIAccessibilityTraits, String)] = [
            (.button, "button"), (.link, "link"), (.header, "header"), (.searchField, "searchField"),
            (.image, "image"), (.selected, "selected"), (.staticText, "text"), (.adjustable, "adjustable"),
            (.tabBar, "tabBar"), (.notEnabled, "disabled"), (.toggleButton, "toggle"),
        ]
        return names.filter { traits.contains($0.0) }.map(\.1)
    }
}

struct Manifest: Encodable {
    let width: Double
    let height: Double
    let scale: Double
    let seq: Int
    let appearance: String
    let textSize: String
    let processStartToReadyMS: Int
    let firstMS: Int
    let marks: [String: Int]
    let renderMS: Int
    let screens: [ManifestScreen]
}

struct ManifestScreen: Encodable {
    let id: String
    let title: String
    let flow: String
    let state: String
    let image: String
    let captureMS: Int
    let elements: [ManifestElement]
    let specs: [ManifestSpec]
}

/// Collects what `.screensSpec` reports for one screen.
final class ScreensSpecs {
    var values: [ManifestSpec] = []
}

/// Hosts a screen and reads the tokens its elements report, in the window's points.
struct ScreensSpecReader<Content: SwiftUI.View>: SwiftUI.View {
    let specs: ScreensSpecs
    let content: Content

    var body: some SwiftUI.View {
        content.overlayPreferenceValue(ScreensSpecKey.self) { reported in
            SwiftUI.GeometryReader { proxy in
                let values = reported.map { item in
                    let frame = proxy[item.anchor]
                    return ManifestSpec(tokens: item.tokens, x: frame.minX, y: frame.minY,
                                        width: frame.width, height: frame.height)
                }
                SwiftUI.Color.clear
                    .onAppear { specs.values = values }
                    .onChange(of: values.count) { specs.values = values }
            }
            .ignoresSafeArea()
        }
    }
}

/// Design tokens an element named with `.screensSpec`, and where it is.
struct ManifestSpec: Encodable {
    let tokens: [String]
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct ManifestElement: Encodable {
    let label: String
    let value: String?
    let identifier: String?
    let traits: [String]
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

/// Shown instead of the app while the agent exports.
struct ScreensAgentHost: SwiftUI.View {
    let entries: [ScreensEntry]
    var body: some SwiftUI.View {
        SwiftUI.Color.black.task { await ScreensAgent.exportAndExit(entries) }
    }
}
#endif

#if DEBUG
/// The entry point a freshly built copy of this app's code is called through in serve
/// mode. It renders that copy's own catalog, so the pictures show the new code.
@_cdecl("screens_export")
nonisolated public func screensExport(_ out: UnsafePointer<CChar>, _ first: UnsafePointer<CChar>, _ seq: Int64) {
    let outDir = URL(fileURLWithPath: String(cString: out), isDirectory: true)
    let firstIDs = Set(String(cString: first).split(separator: ",").map(String.init))
    let seq = Int(seq)
    _ = MainActor.assumeIsolated {
        Task { await ScreensAgent.export(ScreensCatalog.entries, to: outDir, first: firstIDs, seq: seq) }
    }
}

@_cdecl("screens_live")
nonisolated public func screensLive(_ out: UnsafePointer<CChar>, _ id: UnsafePointer<CChar>) {
    let dir = URL(fileURLWithPath: String(cString: out), isDirectory: true)
    // "id" or "id@state".
    let parts = String(cString: id).split(separator: "@", maxSplits: 1).map(String.init)
    MainActor.assumeIsolated {
        guard let first = parts.first, let entry = ScreensCatalog.entries.first(where: { $0.id == first }) else {
            return ScreensLive.stop()
        }
        ScreensLive.start(entry, state: parts.count > 1 ? parts[1] : "default", outDir: dir)
    }
}

@_cdecl("screens_live_stop")
nonisolated public func screensLiveStop() {
    MainActor.assumeIsolated { ScreensLive.stop() }
}

@MainActor
enum ScreensServer {
    private typealias Export = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, Int64) -> Void
    private typealias Live = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Void
    private typealias Stop = @convention(c) () -> Void

    /// The newest copy of the app's code: its export, live and stop entry points.
    private struct Image {
        let export: Export
        let live: Live
        let stop: Stop
    }

    private struct Request: Decodable {
        let seq: Int
        var image: String?
        var first: String?
        var id: String?
    }

    private static var image = Image(export: screensExport, live: screensLive, stop: screensLiveStop)
    private static var reloadSeen = -1
    private static var renderSeen = -1
    private static var liveSeen = -1
    private static var liveID = ""
    private static var timer: Timer?

    static func start() {
        guard let outDir = ScreensAgent.outDir else { return }
        // Render once from the code the app launched with, which also warms it up.
        outDir.path.withCString { image.export($0, "", 0) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            MainActor.assumeIsolated {
                reloadIfAsked(outDir)
                renderIfAsked(outDir)
                goLiveIfAsked(outDir)
            }
        }
    }

    private static func request(_ url: URL, newerThan seen: Int) -> Request? {
        guard let data = try? Data(contentsOf: url),
              let request = try? JSONDecoder().decode(Request.self, from: data),
              request.seq != seen else { return nil }
        return request
    }

    private static func reloadIfAsked(_ outDir: URL) {
        guard let reload = request(outDir.appendingPathComponent("reload.json"), newerThan: reloadSeen),
              let path = reload.image else { return }
        reloadSeen = reload.seq
        guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL),
              let export = dlsym(handle, "screens_export"),
              let live = dlsym(handle, "screens_live"),
              let stop = dlsym(handle, "screens_live_stop") else {
            let error = dlerror().map { String(cString: $0) } ?? "unknown"
            try? error.write(to: outDir.appendingPathComponent("reload.error"), atomically: true, encoding: .utf8)
            return
        }
        if !liveID.isEmpty { image.stop() }
        image = Image(export: unsafeBitCast(export, to: Export.self),
                      live: unsafeBitCast(live, to: Live.self),
                      stop: unsafeBitCast(stop, to: Stop.self))
        outDir.path.withCString { out in (reload.first ?? "").withCString { image.export(out, $0, Int64(reload.seq)) } }
        if !liveID.isEmpty { startLive(outDir) }
    }

    /// Draws every screen again from the code already loaded, after the look changed.
    private static func renderIfAsked(_ outDir: URL) {
        guard let render = request(outDir.appendingPathComponent("render.json"), newerThan: renderSeen) else { return }
        renderSeen = render.seq
        outDir.path.withCString { out in (render.first ?? "").withCString { image.export(out, $0, Int64(render.seq)) } }
        if !liveID.isEmpty { startLive(outDir) }
    }

    private static func goLiveIfAsked(_ outDir: URL) {
        guard let live = request(outDir.appendingPathComponent("live.json"), newerThan: liveSeen) else { return }
        liveSeen = live.seq
        liveID = live.id ?? ""
        if liveID.isEmpty { image.stop() } else { startLive(outDir) }
    }

    private static func startLive(_ outDir: URL) {
        let dir = outDir.appendingPathComponent("live").path
        dir.withCString { out in liveID.withCString { image.live(out, $0) } }
    }
}

struct ScreensServerHost: SwiftUI.View {
    var body: some SwiftUI.View {
        SwiftUI.Color.black.task { ScreensServer.start() }
    }
}
#endif

extension SwiftUI.View {
    /// Shows Screens' renderer instead of the app when Screens launched it. Put it on
    /// the top view of the app's WindowGroup. In release builds it does nothing.
    @SwiftUI.ViewBuilder
    public func screensHost() -> some SwiftUI.View {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let id = environment["SCREENS_LIVE"], let entry = ScreensCatalog.entries.first(where: { $0.id == id }) {
            ScreensLiveHost(entry: entry)
        } else if environment["SCREENS_SERVE"] == "1" {
            ScreensServerHost()
        } else if environment["SCREENS_OUT"] != nil {
            ScreensAgentHost(entries: ScreensCatalog.entries)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

/// What `.screensSpec` reports: the tokens and where the element is.
public struct ScreensSpecItem: @unchecked Sendable {
    let tokens: [String]
    let anchor: SwiftUI.Anchor<CGRect>
}

public struct ScreensSpecKey: SwiftUI.PreferenceKey {
    public static let defaultValue: [ScreensSpecItem] = []
    public static func reduce(value: inout [ScreensSpecItem], nextValue: () -> [ScreensSpecItem]) {
        value.append(contentsOf: nextValue())
    }
}

extension SwiftUI.View {
    /// Names the design tokens behind this element (a font, a colour, a spacing) for
    /// Screens' spec sheets: `.screensSpec("Title", "ink.primary")`. Design-system
    /// components call it once, inside. In release builds it does nothing.
    public func screensSpec(_ tokens: String...) -> some SwiftUI.View {
        #if DEBUG
        anchorPreference(key: ScreensSpecKey.self, value: .bounds) { [ScreensSpecItem(tokens: tokens, anchor: $0)] }
        #else
        self
        #endif
    }
}
