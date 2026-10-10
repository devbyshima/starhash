import CoreImage.CIFilterBuiltins
import SceneKit
import SwiftUI
import UIKit

/// The owner's code as a little voxel tree, after the owner's reference (a
/// 3D QR code by reactiive): the code's modules laid out as tiles on a
/// board, with a tree standing on them whose crown is a block of columns,
/// one per module. Until it is tapped the board turns slowly on its axis,
/// counterclockwise. Tapping it swings the camera from above the corner to
/// straight overhead as the board turns on to square, where every column's
/// top is its module's colour, so the tree flattens into the code itself,
/// upright and ready to scan; another tap stands it back up, turning again.
///
/// Two colours and the tree: the tree is the accent's greens, and the rest
/// of the code is the near black on white in light mode and white on the
/// near black in dark, as a code printed in the page's own ink.
///
/// The code is drawn on its own with nothing behind it: no card, no words.
struct QRTreeView: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsCode = false
    @State private var scene: QRTreeScene?

    /// What the scene is built from: a new code or the other appearance
    /// builds it again.
    private struct Build: Equatable {
        let text: String
        let dark: Bool
    }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let scene {
                    QRTreeSceneView(scene: scene, showsCode: showsCode, animated: !reduceMotion)
                        .transition(.opacity)
                }
            }
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        .sensoryFeedback(.impact(weight: .medium), trigger: showsCode)
        .task(id: Build(text: text, dark: colorScheme == .dark)) {
            scene = QRTreeScene(text: text, dark: colorScheme == .dark)
        }
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Your StarHash QR code"))
        .accessibilityHint(showsCode ? String(localized: "Shows it as a tree") : String(localized: "Shows it as a QR code"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, toggle)
        #if DEBUG
        // -qrCode: the code straight away, for screenshots and scanning;
        // -qrTap <seconds>: a tap after that long, to record the swing.
        .onAppear {
            if DebugLaunch.arguments.contains("-qrCode") { showsCode = true }
        }
        .task {
            guard let delay = DebugLaunch.value(after: "-qrTap").flatMap(Double.init) else { return }
            try? await Task.sleep(for: .seconds(delay))
            toggle()
        }
        #endif
    }

    private func toggle() {
        showsCode.toggle()
    }
}

/// The scene in a SceneKit view, clear over the page.
private struct QRTreeSceneView: UIViewRepresentable {
    let scene: QRTreeScene
    let showsCode: Bool
    let animated: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: nil)
        view.scene = scene.scene
        view.pointOfView = scene.cameraNode
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.isUserInteractionEnabled = false
        // Playing, so the board's turning draws every frame; 60 a second is
        // plenty for something this slow.
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        scene.show(code: showsCode, animated: animated)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        if view.scene !== scene.scene {
            view.scene = scene.scene
            view.pointOfView = scene.cameraNode
            view.isPlaying = true
        }
        scene.show(code: showsCode, animated: animated)
    }
}

/// The board, the tree and the camera rig. One geometry for all of it,
/// with one material per colour, so the whole tree is a handful of draw
/// calls however many modules the code has.
@MainActor
final class QRTreeScene {
    let scene = SCNScene()
    let cameraNode = SCNNode()

    private let yaw = SCNNode()
    private let pitch = SCNNode()
    /// The board and the tree, which turn while it stands as a tree.
    private let spinner = SCNNode()
    private let camera = SCNCamera()
    private let shadow = SCNNode()
    private var isShowingCode: Bool?

    /// The camera's two poses: over the code's bottom left corner, looking
    /// down at the tree, and straight overhead, where the board reads as
    /// the code. The tree's pose turns the board a quarter turn's half, so
    /// the swing is one easy turn and tilt, as the reference's.
    private struct Pose {
        var yaw: Float
        var pitch: Float
        var scale: Double
    }

    private var treePose = Pose(yaw: -.pi / 4, pitch: -0.6155, scale: 1)
    private var codePose = Pose(yaw: 0, pitch: -.pi / 2, scale: 1)

    private let palette: Palette

    init?(text: String, dark: Bool) {
        guard let modules = QRModules(text: text) else { return nil }
        palette = dark ? .dark : .light
        build(modules)
    }

    /// Swings to the code or back to the tree.
    func show(code: Bool, animated: Bool) {
        guard isShowingCode != code else { return }
        let first = isShowingCode == nil
        isShowingCode = code
        let pose = code ? codePose : treePose
        let duration = animated && !first ? 0.9 : 0
        if code {
            settle(over: duration)
        } else if animated {
            spin()
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(controlPoints: 0.65, 0, 0.25, 1)
        yaw.eulerAngles.y = pose.yaw
        pitch.eulerAngles.x = pose.pitch
        camera.orthographicScale = pose.scale
        shadow.opacity = code ? 0 : 1
        SCNTransaction.commit()
    }

    // MARK: Turning

    private static let spinKey = "spin"
    /// One full turn, in seconds: slow enough to read as the tree turning
    /// on its own, not as a loading spinner.
    private static let turn: TimeInterval = 14

    /// Turns the board counterclockwise, seen from above, round and round.
    private func spin() {
        spinner.removeAction(forKey: Self.spinKey)
        let turn = SCNAction.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: Self.turn)
        spinner.runAction(.repeatForever(turn), forKey: Self.spinKey)
    }

    /// Stops the turning by carrying on, the same way, to the next whole
    /// turn, so the code lands upright as the camera arrives overhead.
    private func settle(over duration: TimeInterval) {
        let angle = Double(spinner.presentation.eulerAngles.y)
        spinner.removeAction(forKey: Self.spinKey)
        let remaining = angle <= 0 ? -angle : 2 * .pi - angle
        guard duration > 0, remaining > 0.001 else {
            spinner.eulerAngles.y = 0
            return
        }
        let finish = SCNAction.rotateBy(x: 0, y: CGFloat(remaining), z: 0, duration: duration)
        finish.timingMode = .easeOut
        // Exactly square at the end, whatever the sums left over.
        spinner.runAction(.sequence([finish, .rotateTo(x: 0, y: 0, z: 0, duration: 0)]), forKey: Self.spinKey)
    }

    // MARK: Building

    private func build(_ modules: QRModules) {
        let border = 2
        let count = modules.count
        let side = count + border * 2
        let half = Float(side) / 2

        // The crown: a ball over the middle of the board, about two thirds
        // of the code across, held up on a trunk a fifth of the code tall.
        let radius = Float(count) * 0.32
        let trunk = Float(count) * 0.2
        let crownCentre = trunk + radius * 0.78
        var mesh = VoxelMesh()

        for row in 0..<side {
            for column in 0..<side {
                let x = Float(column) - half
                let z = Float(row) - half
                let qrRow = row - border, qrColumn = column - border
                let inCode = (0..<count).contains(qrRow) && (0..<count).contains(qrColumn)
                let dark = inCode && modules.isDark(row: qrRow, column: qrColumn)
                let finder = inCode && modules.isFinder(row: qrRow, column: qrColumn)
                let noise = Self.noise(row, column)

                // The ground: every module a tile, the code's light ones
                // low and the dark ones raised, the finders a step more,
                // in the page's two colours.
                if dark {
                    let height: Float = finder ? 1.3 : 1.0
                    let top = finder ? palette.finder : palette.ink[noise % palette.ink.count]
                    mesh.box(x: x, z: z, bottom: 0, top: height, colours: .init(top: top, left: palette.inkSide, right: palette.inkShade))
                } else {
                    let top = palette.ground[noise % palette.ground.count]
                    mesh.box(x: x, z: z, bottom: 0, top: 0.6, colours: .init(top: top, left: palette.groundSide, right: palette.groundShade))
                }

                // The crown, over the code's middle: a column on every
                // module under it, its top the module's colour, so straight
                // down it reads as the code. The light ones sit a step or
                // two lower, pale as blossom; the sides are all leaves.
                let dx = x + 0.5, dz = z + 0.5
                let distance = (dx * dx + dz * dz).squareRoot()
                guard inCode, !finder, distance < radius else { continue }
                let reach = (radius * radius - distance * distance).squareRoot()
                var top = (crownCentre + reach * 0.95 + Float(noise % 3) * 0.5).rounded()
                let bottom = max(trunk, (crownCentre - reach * 0.75).rounded())
                if !dark { top -= Float(1 + noise % 2) }
                guard top > bottom + 0.5 else { continue }
                let colours = dark
                    ? VoxelMesh.Colours(top: palette.leaves[noise % palette.leaves.count], left: palette.leafSide, right: palette.leafShade)
                    : VoxelMesh.Colours(top: palette.blossom[noise % palette.blossom.count], left: palette.leafSide, right: palette.leafShade)
                mesh.box(x: x, z: z, bottom: bottom, top: top, colours: colours)
            }
        }

        // The trunk, two modules square, from the ground into the crown.
        let trunkTop = crownCentre
        for (dx, dz) in [(-1, -1), (0, -1), (-1, 0), (0, 0)] {
            mesh.box(x: Float(dx), z: Float(dz), bottom: 0.6, top: trunkTop, colours: .init(top: palette.bark, left: palette.bark, right: palette.barkShade))
        }

        let board = SCNNode(geometry: mesh.geometry())
        spinner.addChildNode(board)
        scene.rootNode.addChildNode(spinner)

        // A soft shadow under the board while it stands as a tree.
        let plane = SCNPlane(width: CGFloat(side) * 1.5, height: CGFloat(side) * 1.5)
        let material = SCNMaterial()
        material.diffuse.contents = Self.shadowImage(strength: palette.shadow)
        material.lightingModel = .constant
        material.writesToDepthBuffer = false
        material.blendMode = .alpha
        plane.materials = [material]
        shadow.geometry = plane
        shadow.eulerAngles.x = -.pi / 2
        shadow.position = SCNVector3(0, -Float(side) * 0.32, 0)
        shadow.renderingOrder = -1
        scene.rootNode.addChildNode(shadow)

        // The camera on a two-jointed arm round a point above the board.
        // Orthographic, so overhead every tile is the same size and the
        // code is square.
        let crownTop = crownCentre + radius * 0.95 + 1
        let tilt = Float(0.6155)
        let boardHalf = half * Float(2).squareRoot()
        let lowest = -boardHalf * sin(tilt) - Float(side) * 0.32 * cos(tilt) * 0.4
        let highest = max(boardHalf * sin(tilt), crownTop * cos(tilt))
        let target = SCNNode()
        target.position = SCNVector3(0, (lowest + highest) / 2 / cos(tilt), 0)
        scene.rootNode.addChildNode(target)
        target.addChildNode(yaw)
        yaw.addChildNode(pitch)
        pitch.addChildNode(cameraNode)
        camera.usesOrthographicProjection = true
        camera.zNear = 0.1
        camera.zFar = Double(side) * 10
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, Float(side) * 3)
        treePose.scale = Double(max(boardHalf, (highest - lowest) / 2) * 1.04)
        codePose.scale = Double(half) * 1.005
    }

    /// The same small number for a module every time, so the tree looks
    /// the same on every launch.
    private static func noise(_ row: Int, _ column: Int) -> Int {
        var value = UInt32(truncatingIfNeeded: row &* 73_856_093 ^ column &* 19_349_663)
        value ^= value >> 13
        value = value &* 0x5BD1_E995
        value ^= value >> 15
        return Int(value % 1024)
    }

    /// A round black fade, for the shadow.
    private static func shadowImage(strength: CGFloat) -> UIImage {
        let size = CGSize(width: 128, height: 128)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colours = [UIColor.black.withAlphaComponent(strength).cgColor, UIColor.black.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0, 1]) else { return }
            let centre = CGPoint(x: 64, y: 64)
            context.cgContext.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 64, options: [])
        }
    }
}

/// The tree's colours, one set per appearance. Straight down only the tops
/// show, so every top is clearly one of the code's two colours: in light
/// mode the dark modules are the near black (and the tree's deeper greens)
/// and the light ones white (and pale blossom); in dark mode the code turns
/// over, its dark modules white (and the bright greens) on the near black
/// (and the deepest greens). A scanner tells them apart either way. The
/// sides, which only the tree's pose shows, are free to be the accent.
private struct Palette {
    var ground: [UIColor]
    var groundSide: UIColor
    var groundShade: UIColor
    var ink: [UIColor]
    var inkSide: UIColor
    var inkShade: UIColor
    var finder: UIColor
    var leaves: [UIColor]
    var blossom: [UIColor]
    var leafSide = UIColor(rgb: 0x00D957)
    var leafShade = UIColor(rgb: 0x00A945)
    var bark = UIColor(rgb: 0x6B4429)
    var barkShade = UIColor(rgb: 0x4E301C)
    var shadow: CGFloat

    static let light = Palette(
        ground: [UIColor(rgb: 0xFFFFFF)],
        groundSide: UIColor(rgb: 0xE2E2E2),
        groundShade: UIColor(rgb: 0xCACACA),
        ink: [UIColor(rgb: 0x171717), UIColor(rgb: 0x202020)],
        inkSide: UIColor(rgb: 0x2E2E2E),
        inkShade: UIColor(rgb: 0x0B0B0B),
        finder: UIColor(rgb: 0x171717),
        leaves: [UIColor(rgb: 0x00C451), UIColor(rgb: 0x00B84B), UIColor(rgb: 0x00A845)],
        blossom: [UIColor(rgb: 0xE9FAEF), UIColor(rgb: 0xDDF6E6)],
        shadow: 0.16
    )

    static let dark = Palette(
        ground: [UIColor(rgb: 0x171717)],
        groundSide: UIColor(rgb: 0x2E2E2E),
        groundShade: UIColor(rgb: 0x242424),
        ink: [UIColor(rgb: 0xF4F4F4), UIColor(rgb: 0xE8E8E8)],
        inkSide: UIColor(rgb: 0xBDBDBD),
        inkShade: UIColor(rgb: 0x8E8E8E),
        finder: UIColor(rgb: 0xF4F4F4),
        leaves: [UIColor(rgb: 0x00D957), UIColor(rgb: 0x00C451)],
        blossom: [UIColor(rgb: 0x0B2E1A), UIColor(rgb: 0x0E3A21)],
        shadow: 0.5
    )
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Boxes as one geometry, the faces grouped by colour into one element
/// each, lit by their colours alone: the tops their own, the sides the
/// shades the camera's corner sees, as a voxel drawing is shaded.
private struct VoxelMesh {
    struct Colours {
        var top: UIColor
        /// The side facing the camera's left, and the one facing its right.
        var left: UIColor
        var right: UIColor
    }

    private var positions: [SCNVector3] = []
    private var groups: [UIColor: [UInt32]] = [:]

    /// A box one module square from `bottom` to `top`, its bottom face left
    /// out, which nothing ever sees.
    mutating func box(x: Float, z: Float, bottom: Float, top: Float, colours: Colours) {
        let x1 = x + 1, z1 = z + 1
        // Top.
        quad([.init(x, top, z), .init(x, top, z1), .init(x1, top, z1), .init(x1, top, z)], colour: colours.top)
        // The camera sits off the -x, +z corner: -x is its left face, +z
        // its right. The other two only show mid-swing, if at all.
        quad([.init(x, bottom, z), .init(x, bottom, z1), .init(x, top, z1), .init(x, top, z)], colour: colours.left)
        quad([.init(x, bottom, z1), .init(x1, bottom, z1), .init(x1, top, z1), .init(x, top, z1)], colour: colours.right)
        quad([.init(x1, bottom, z1), .init(x1, bottom, z), .init(x1, top, z), .init(x1, top, z1)], colour: colours.right)
        quad([.init(x1, bottom, z), .init(x, bottom, z), .init(x, top, z), .init(x1, top, z)], colour: colours.left)
    }

    /// Four corners counterclockwise seen from outside.
    private mutating func quad(_ corners: [SCNVector3], colour: UIColor) {
        let start = UInt32(positions.count)
        positions.append(contentsOf: corners)
        groups[colour, default: []].append(contentsOf: [start, start + 1, start + 2, start, start + 2, start + 3])
    }

    func geometry() -> SCNGeometry {
        let ordered = groups.sorted { $0.value.count > $1.value.count }
        let elements = ordered.map { SCNGeometryElement(indices: $0.value, primitiveType: .triangles) }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: positions)], elements: elements)
        geometry.materials = ordered.map { colour, _ in
            let material = SCNMaterial()
            material.diffuse.contents = colour
            material.lightingModel = .constant
            material.isDoubleSided = false
            return material
        }
        return geometry
    }
}

/// A QR code's modules, read from Core Image's generator: a square of dark
/// and light, without the quiet zone round it.
private struct QRModules {
    let count: Int
    private let dark: [Bool]

    init?(text: String) {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        // Q, a quarter of the code to spare: room for the crown's shading
        // to blur an edge here and there.
        filter.correctionLevel = "Q"
        guard let output = filter.outputImage,
              let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 255, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        // The generator leaves a margin; keep only the code.
        var rows: [Int] = [], columns: [Int] = []
        for row in 0..<height {
            for column in 0..<width where pixels[row * width + column] < 128 {
                rows.append(row)
                columns.append(column)
            }
        }
        guard let top = rows.min(), let bottom = rows.max(), let left = columns.min(), let right = columns.max() else { return nil }
        let count = min(bottom - top, right - left) + 1
        var dark = [Bool](repeating: false, count: count * count)
        for row in 0..<count {
            for column in 0..<count {
                dark[row * count + column] = pixels[(top + row) * width + left + column] < 128
            }
        }
        self.count = count
        self.dark = dark
    }

    func isDark(row: Int, column: Int) -> Bool {
        dark[row * count + column]
    }

    /// One of the three big squares in the corners, with the light ring
    /// round each.
    func isFinder(row: Int, column: Int) -> Bool {
        let near = 0..<8, far = (count - 8)..<count
        return (near.contains(row) && near.contains(column))
            || (near.contains(row) && far.contains(column))
            || (far.contains(row) && near.contains(column))
    }
}
