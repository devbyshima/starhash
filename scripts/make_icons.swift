// Writes StarHash's icons into StarHash/Resources/Icons.xcassets as custom
// SF Symbols, from Keyline Icons (https://keylineicons.com, MIT):
//
//   swift scripts/make_icons.swift [--preview sheet.png [--only heart,check]]
//   swift scripts/make_icons.swift --vendor <path to a keyline-icons clone>
//
// Every icon is one of Keyline's, drawn on its 24 grid with 2pt round
// strokes. The filled form is Keyline's `fill` style, the outline form
// (`<name>Outline`, for `ActionRow` and the like) its `stroke` style. The
// SVGs StarHash uses are kept in scripts/keyline-icons with Keyline's
// licence; --vendor copies them in again from a clone of
// github.com/keyline-icons/keyline-icons, after adding an icon below.
//
// A symbol needs filled outlines, so each Keyline path is filled (by its
// own fill rule) or its stroke outlined, and every part merged into one
// shape with Core Graphics. Keyline's 24 grid is set on the 18 grid the
// template writer below has always used, its 2 to 22 drawing area on 2.5
// to 15.5, so an icon sizes and aligns with the font as an SF Symbol does.
// --preview draws the whole set on one sheet, large and at its real size,
// to check them side by side. Run `xcodegen generate` after adding an icon
// so the targets see it, and give it its SF Symbol names in `StarIcon`
// (StarHash/Design/Icons.swift).

import AppKit
import CoreGraphics
import Foundation

// MARK: The set

/// Which of Keyline's styles a form is drawn from.
enum KeylineStyle: String {
    case fill, stroke
}

struct Icon {
    /// The asset's name, `StarIcon`'s case.
    let name: String
    /// Keyline's name for the drawing.
    let keyline: String
    var filled: KeylineStyle = .fill
    var outline: KeylineStyle = .stroke
}

/// StarHash's icons and the Keyline drawing for each. Where Keyline has no
/// drawing of the very thing (parking, a fuel pump, a ticket, a first aid
/// case, a hash in a square), the nearest it has.
let icons: [Icon] = [
    Icon(name: "airplane", keyline: "plane"),
    Icon(name: "antenna", keyline: "broadcast"),
    // The half-filled circle is the point, in both forms.
    Icon(name: "appearance", keyline: "circle-half", outline: .fill),
    Icon(name: "arrowDownLeft", keyline: "arrow-down-left"),
    Icon(name: "arrowUpRight", keyline: "arrow-up-right"),
    Icon(name: "bag", keyline: "shopping-bag"),
    Icon(name: "bank", keyline: "landmark"),
    Icon(name: "battery", keyline: "battery-medium"),
    Icon(name: "bell", keyline: "bell"),
    Icon(name: "bellBadge", keyline: "bell-dot"),
    Icon(name: "bellSlash", keyline: "bell-off"),
    Icon(name: "bolt", keyline: "zap"),
    Icon(name: "box", keyline: "package"),
    Icon(name: "bus", keyline: "bus"),
    Icon(name: "calendar", keyline: "calendar"),
    Icon(name: "camera", keyline: "camera"),
    Icon(name: "car", keyline: "car"),
    Icon(name: "card", keyline: "credit-card"),
    Icon(name: "cart", keyline: "shopping-cart"),
    Icon(name: "cash", keyline: "banknote"),
    Icon(name: "chartBar", keyline: "chart-column"),
    Icon(name: "chartLine", keyline: "chart-line-up"),
    Icon(name: "chat", keyline: "messages-square"),
    Icon(name: "check", keyline: "check"),
    Icon(name: "checkCircle", keyline: "circle-check"),
    Icon(name: "chevronLeft", keyline: "chevron-left"),
    Icon(name: "chevronRight", keyline: "chevron-right"),
    Icon(name: "chevronUpDown", keyline: "chevrons-up-down"),
    // An empty choice beside a ticked one: the ring, in both forms.
    Icon(name: "circle", keyline: "circle", filled: .stroke),
    Icon(name: "clock", keyline: "clock"),
    Icon(name: "close", keyline: "x"),
    Icon(name: "closeCircle", keyline: "circle-x"),
    Icon(name: "code", keyline: "code-xml"),
    Icon(name: "cup", keyline: "coffee"),
    Icon(name: "document", keyline: "file-text"),
    Icon(name: "download", keyline: "download"),
    Icon(name: "drop", keyline: "droplet"),
    Icon(name: "envelope", keyline: "mail-open"),
    Icon(name: "eye", keyline: "eye"),
    Icon(name: "faceID", keyline: "scan-face"),
    Icon(name: "film", keyline: "film"),
    Icon(name: "flag", keyline: "flag"),
    Icon(name: "food", keyline: "utensils"),
    Icon(name: "fuel", keyline: "ev-charger"),
    Icon(name: "game", keyline: "gamepad"),
    Icon(name: "gear", keyline: "settings"),
    Icon(name: "gift", keyline: "gift"),
    Icon(name: "globe", keyline: "globe"),
    Icon(name: "graduation", keyline: "graduation-cap"),
    Icon(name: "hash", keyline: "hash"),
    Icon(name: "health", keyline: "briefcase-medical"),
    Icon(name: "heart", keyline: "heart"),
    Icon(name: "hashSquare", keyline: "hash"),
    Icon(name: "history", keyline: "history"),
    Icon(name: "hourglass", keyline: "hourglass"),
    Icon(name: "house", keyline: "house"),
    Icon(name: "info", keyline: "info"),
    Icon(name: "lightbulb", keyline: "lightbulb"),
    Icon(name: "location", keyline: "navigation"),
    Icon(name: "lock", keyline: "lock"),
    Icon(name: "messageCheck", keyline: "message-check"),
    Icon(name: "messageQuestion", keyline: "message-question"),
    Icon(name: "more", keyline: "circle-more-horizontal"),
    Icon(name: "parking", keyline: "car-front"),
    Icon(name: "pencil", keyline: "pen"),
    Icon(name: "people", keyline: "users"),
    Icon(name: "person", keyline: "user"),
    Icon(name: "personAlert", keyline: "user-x"),
    Icon(name: "personCircle", keyline: "circle-user"),
    Icon(name: "phone", keyline: "phone"),
    Icon(name: "pin", keyline: "pin"),
    Icon(name: "play", keyline: "circle-play"),
    Icon(name: "plus", keyline: "plus"),
    Icon(name: "qrCode", keyline: "qr-code"),
    Icon(name: "received", keyline: "circle-arrow-down"),
    Icon(name: "reset", keyline: "rotate-ccw"),
    Icon(name: "seal", keyline: "badge-check"),
    Icon(name: "search", keyline: "search"),
    Icon(name: "sendBack", keyline: "circle-arrow-u-turn-left"),
    Icon(name: "shieldAlert", keyline: "shield-alert"),
    Icon(name: "shieldLock", keyline: "shield-lock"),
    Icon(name: "share", keyline: "upload"),
    Icon(name: "simCard", keyline: "card-sim"),
    Icon(name: "sound", keyline: "volume"),
    Icon(name: "sparkles", keyline: "sparkles"),
    Icon(name: "star", keyline: "star"),
    Icon(name: "store", keyline: "store"),
    Icon(name: "sunset", keyline: "sunset"),
    Icon(name: "swap", keyline: "arrow-left-right"),
    Icon(name: "ticket", keyline: "coupon"),
    // The torch's button shows what a tap does: off with a slash through.
    Icon(name: "torch", keyline: "flashlight-off"),
    Icon(name: "torchOn", keyline: "flashlight"),
    Icon(name: "touchID", keyline: "fingerprint-pattern"),
    Icon(name: "trash", keyline: "bin"),
    Icon(name: "tray", keyline: "inbox"),
    Icon(name: "tv", keyline: "tv"),
    Icon(name: "unpin", keyline: "pin-off"),
    Icon(name: "wifi", keyline: "wifi"),
]

// MARK: Path data

/// SVG path data, read into a Core Graphics path: every
/// command, absolute and relative, arcs included.
func parsePath(_ d: String) -> CGMutablePath {
    let path = CGMutablePath()
    var tokens: [String] = []
    var number = ""
    func flush() { if !number.isEmpty { tokens.append(number); number = "" } }
    for ch in d {
        if ch.isLetter && ch != "e" && ch != "E" {
            flush(); tokens.append(String(ch))
        } else if ch == "-" {
            if let last = number.last, last == "e" || last == "E" { number.append(ch) } else { flush(); number.append(ch) }
        } else if ch == "." {
            if number.contains(".") && !number.contains("e") { flush() }
            number.append(ch)
        } else if ch == "," || ch == " " || ch == "\n" {
            flush()
        } else {
            number.append(ch)
        }
    }
    flush()

    var index = 0
    var command = "M"
    var current = CGPoint.zero
    var start = CGPoint.zero
    var lastControl: CGPoint?
    var lastCommand = ""
    func next() -> CGFloat {
        defer { index += 1 }
        return CGFloat(Double(tokens[index])!)
    }
    // An arc's two flags are single digits, often run into what follows
    // ("011.4" is 0, 1, 1.4).
    func nextFlag() -> Bool {
        let token = tokens[index]
        if token.count > 1 { tokens[index] = String(token.dropFirst()) } else { index += 1 }
        return token.first == "1"
    }
    while index < tokens.count {
        if let first = tokens[index].first, first.isLetter {
            command = tokens[index]; index += 1
        } else if command == "M" { command = "L" } else if command == "m" { command = "l" }
        let relative = command == command.lowercased() && command != "z"
        let base = relative ? current : .zero
        switch command.uppercased() {
        case "M":
            current = CGPoint(x: base.x + next(), y: base.y + next())
            path.move(to: current); start = current; lastControl = nil
        case "L":
            current = CGPoint(x: base.x + next(), y: base.y + next())
            path.addLine(to: current); lastControl = nil
        case "H":
            current = CGPoint(x: base.x + next(), y: current.y)
            path.addLine(to: current); lastControl = nil
        case "V":
            current = CGPoint(x: current.x, y: (relative ? current.y : 0) + next())
            path.addLine(to: current); lastControl = nil
        case "C":
            let c1 = CGPoint(x: base.x + next(), y: base.y + next())
            let c2 = CGPoint(x: base.x + next(), y: base.y + next())
            current = CGPoint(x: base.x + next(), y: base.y + next())
            path.addCurve(to: current, control1: c1, control2: c2); lastControl = c2
        case "S":
            let c1 = (lastControl != nil && "CS".contains(lastCommand.uppercased()))
                ? CGPoint(x: 2 * current.x - lastControl!.x, y: 2 * current.y - lastControl!.y) : current
            let c2 = CGPoint(x: base.x + next(), y: base.y + next())
            current = CGPoint(x: base.x + next(), y: base.y + next())
            path.addCurve(to: current, control1: c1, control2: c2); lastControl = c2
        case "Q":
            let c = CGPoint(x: base.x + next(), y: base.y + next())
            current = CGPoint(x: base.x + next(), y: base.y + next())
            path.addQuadCurve(to: current, control: c); lastControl = c
        case "T":
            let c = (lastControl != nil && "QT".contains(lastCommand.uppercased()))
                ? CGPoint(x: 2 * current.x - lastControl!.x, y: 2 * current.y - lastControl!.y) : current
            current = CGPoint(x: base.x + next(), y: base.y + next())
            path.addQuadCurve(to: current, control: c); lastControl = c
        case "A":
            let rx = next(), ry = next(), rotation = next(), large = nextFlag(), sweep = nextFlag()
            let end = CGPoint(x: base.x + next(), y: base.y + next())
            addArc(to: path, from: current, to: end, rx: rx, ry: ry, rotation: rotation, large: large, sweep: sweep)
            current = end; lastControl = nil
        case "Z":
            path.closeSubpath(); current = start; lastControl = nil
        default:
            fatalError("Unknown path command \(command) in \(d)")
        }
        lastCommand = command
    }
    return path
}

/// An SVG arc as Bézier curves, by the spec's endpoint-to-centre
/// conversion, radii scaled up when they cannot span the two points.
func addArc(to path: CGMutablePath, from p0: CGPoint, to p1: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat, rotation: CGFloat, large: Bool, sweep: Bool) {
    guard p0 != p1 else { return }
    var rx = abs(rxIn), ry = abs(ryIn)
    guard rx > 0, ry > 0 else { path.addLine(to: p1); return }
    let phi = rotation * .pi / 180
    let cosPhi = cos(phi), sinPhi = sin(phi)
    let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
    let x1 = cosPhi * dx + sinPhi * dy, y1 = -sinPhi * dx + cosPhi * dy
    let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
    if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
    let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
    var factor = sqrt(max(0, numerator / denominator))
    if large == sweep { factor = -factor }
    let cx1 = factor * rx * y1 / ry, cy1 = -factor * ry * x1 / rx
    let cx = cosPhi * cx1 - sinPhi * cy1 + (p0.x + p1.x) / 2
    let cy = sinPhi * cx1 + cosPhi * cy1 + (p0.y + p1.y) / 2
    func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
        let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a
    }
    let theta1 = angle(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
    var delta = angle((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
    if !sweep && delta > 0 { delta -= 2 * .pi }
    if sweep && delta < 0 { delta += 2 * .pi }
    let segments = Int(ceil(abs(delta) / (.pi / 2)))
    let step = delta / CGFloat(segments)
    let k = 4 / 3 * tan(step / 4)
    func point(_ t: CGFloat) -> CGPoint {
        let x = rx * cos(t), y = ry * sin(t)
        return CGPoint(x: cosPhi * x - sinPhi * y + cx, y: sinPhi * x + cosPhi * y + cy)
    }
    func derivative(_ t: CGFloat) -> CGPoint {
        let x = -rx * sin(t), y = ry * cos(t)
        return CGPoint(x: cosPhi * x - sinPhi * y, y: sinPhi * x + cosPhi * y)
    }
    for i in 0..<segments {
        let t0 = theta1 + CGFloat(i) * step, t1 = t0 + step
        let a = point(t0), b = point(t1), da = derivative(t0), db = derivative(t1)
        path.addCurve(
            to: i == segments - 1 ? p1 : b,
            control1: CGPoint(x: a.x + k * da.x, y: a.y + k * da.y),
            control2: CGPoint(x: b.x - k * db.x, y: b.y - k * db.y)
        )
    }
}


// MARK: Keyline's SVGs

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let vendored = root.appendingPathComponent("scripts/keyline-icons")

/// A drawing's SVG in a style. Keyline leaves out the fill file of a glyph
/// with nothing to fill (an arrow, a chevron), and so does StarHash: those
/// take the stroke drawing, as Keyline's own filled sets do.
func svgFile(_ keyline: String, _ style: KeylineStyle) -> URL {
    let file = vendored.appendingPathComponent("\(style.rawValue)/\(keyline).svg")
    if style == .fill, !FileManager.default.fileExists(atPath: file.path) {
        return svgFile(keyline, .stroke)
    }
    return file
}

/// A tag's attributes by name.
func attributes(_ tag: String) -> [String: String] {
    let pattern = try! NSRegularExpression(pattern: #"([a-zA-Z-]+)="([^"]*)""#)
    var result: [String: String] = [:]
    for match in pattern.matches(in: tag, range: NSRange(tag.startIndex..., in: tag)) {
        result[String(tag[Range(match.range(at: 1), in: tag)!])] = String(tag[Range(match.range(at: 2), in: tag)!])
    }
    return result
}

/// Keyline's 24 grid on the 18 grid: its 2 to 22 drawing area on 2.5 to
/// 15.5, round the same middle.
let keylineToGrid: CGAffineTransform = {
    let k: CGFloat = 13 / 20
    return CGAffineTransform(a: k, b: 0, c: 0, d: k, tx: 9 - 12 * k, ty: 9 - 12 * k)
}()

/// One of Keyline's SVGs as one filled shape in the 18 grid: each path
/// filled by its fill rule where it is filled, its stroke outlined where it
/// is stroked (round caps and joins, as all of Keyline's are), all merged.
func keylineShape(_ keyline: String, _ style: KeylineStyle) -> CGPath {
    let url = svgFile(keyline, style)
    guard let svg = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("No \(style.rawValue)/\(keyline).svg in scripts/keyline-icons: run --vendor with a keyline-icons clone")
    }
    let tags = try! NSRegularExpression(pattern: #"<(svg|path)\b[^>]*>"#)
    var defaults: [String: String] = [:]
    var shape: CGPath = CGMutablePath()
    for match in tags.matches(in: svg, range: NSRange(svg.startIndex..., in: svg)) {
        let tag = String(svg[Range(match.range, in: svg)!])
        let own = attributes(tag)
        if tag.hasPrefix("<svg") { defaults = own; continue }
        func value(_ name: String) -> String? { own[name] ?? defaults[name] }
        guard let d = own["d"] else { continue }
        let path = parsePath(d)
        if (value("fill") ?? "black") != "none" {
            let rule: CGPathFillRule = value("fill-rule") == "evenodd" ? .evenOdd : .winding
            shape = shape.union(path.normalized(using: rule))
        }
        if let stroke = value("stroke"), stroke != "none" {
            let width = CGFloat(Double(value("stroke-width") ?? "1") ?? 1)
            let outline = path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
            shape = shape.union(outline.normalized())
        }
    }
    var transform = keylineToGrid
    return shape.copy(using: &transform) ?? shape
}

/// Copies the SVGs `icons` uses, and Keyline's licence, from a clone of
/// keyline-icons into scripts/keyline-icons, replacing what was there.
func vendor(from clone: URL) {
    let manager = FileManager.default
    try? manager.removeItem(at: vendored)
    for style in [KeylineStyle.fill, .stroke] {
        try! manager.createDirectory(at: vendored.appendingPathComponent(style.rawValue), withIntermediateDirectories: true)
    }
    let needed = Set(icons.flatMap { ["\($0.filled.rawValue)/\($0.keyline)", "\($0.outline.rawValue)/\($0.keyline)"] })
    var copied = 0
    for file in needed.sorted() {
        let source = clone.appendingPathComponent("icons/\(file).svg")
        // A fill file Keyline does not draw falls back to the stroke one.
        guard manager.fileExists(atPath: source.path) || !file.hasPrefix("fill/") else { continue }
        try! manager.copyItem(at: source, to: vendored.appendingPathComponent("\(file).svg"))
        copied += 1
    }
    try! manager.copyItem(at: clone.appendingPathComponent("LICENSE"), to: vendored.appendingPathComponent("LICENSE"))
    print("Copied \(copied) SVGs and the licence into scripts/keyline-icons")
}

// MARK: Symbols

/// Template units per grid unit: the drawing area, 2.5 to 15.5 (Keyline's 2 to 22), is 100
/// units, about as tall as SF Symbols' filled glyphs at 100pt.
let scale: CGFloat = 100 / 13
/// The grid's left and right edges as the symbol's margins: a point of
/// room each side of the drawing area.
let marginLeft: CGFloat = 1.5
let marginRight: CGFloat = 16.5
/// The medium scale's baseline in the template, its cap height, and where
/// the left margin goes.
let baselineM: CGFloat = 1126
let capHeight: CGFloat = 70.459
let originX: CGFloat = 1400

func number(_ value: CGFloat) -> String {
    let rounded = (value * 100).rounded() / 100
    return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.2f", rounded)
}

/// The outline as path data in the template's Regular-M group: the grid's
/// middle on the middle of the cap height, as SF Symbols centre on it.
func templatePathData(_ path: CGPath, size: CGFloat = 1) -> String {
    func convert(_ p: CGPoint) -> String {
        number((p.x - marginLeft) * scale * size) + " " + number((p.y - 9) * scale * size - capHeight / 2)
    }
    var d = ""
    path.applyWithBlock { element in
        let e = element.pointee
        switch e.type {
        case .moveToPoint: d += "M" + convert(e.points[0])
        case .addLineToPoint: d += "L" + convert(e.points[0])
        case .addQuadCurveToPoint: d += "Q" + convert(e.points[0]) + " " + convert(e.points[1])
        case .addCurveToPoint: d += "C" + convert(e.points[0]) + " " + convert(e.points[1]) + " " + convert(e.points[2])
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

/// The three symbol scales, each on its own baseline in the template, at
/// SF Symbols' sizes: small 0.783 and large 1.29 of medium. A view or a
/// toolbar asking for the small or large scale (the round header buttons
/// do) finds a drawing; with medium alone it drew nothing.
let symbolScales: [(name: String, baseline: CGFloat, size: CGFloat)] = [("S", 696, 0.783), ("M", baselineM, 1), ("L", 1556, 1.29)]

func symbolSVG(_ name: String, _ path: CGPath) -> String {
    let margins = symbolScales.map { variant in
        let right = originX + (marginRight - marginLeft) * scale * variant.size
        return """
          <line id="left-margin-Regular-\(variant.name)" style="fill:none;stroke:#00AEEF;stroke-width:0.5;" x1="\(number(originX))" x2="\(number(originX))" y1="\(number(variant.baseline - 96))" y2="\(number(variant.baseline + 24))"/>
          <line id="right-margin-Regular-\(variant.name)" style="fill:none;stroke:#00AEEF;stroke-width:0.5;" x1="\(number(right))" x2="\(number(right))" y1="\(number(variant.baseline - 96))" y2="\(number(variant.baseline + 24))"/>
        """
    }.joined(separator: "\n")
    let groups = symbolScales.map { variant in
        """
          <g id="Regular-\(variant.name)" transform="matrix(1 0 0 1 \(number(originX)) \(number(variant.baseline)))">
           <path d="\(templatePathData(path, size: variant.size))"/>
          </g>
        """
    }.joined(separator: "\n")
    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
    <!-- \(name), Keyline Icons converted by scripts/make_icons.swift; edit it there, not here. -->
    <svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="3300" height="2200">
     <g id="Notes">
      <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
      <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 3036 1933)" text-anchor="end">Template v.2.0</text>
     </g>
     <g id="Guides">
      <line id="Baseline-S" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="696" y2="696"/>
      <line id="Capline-S" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="625.541" y2="625.541"/>
      <line id="Baseline-M" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="1126" y2="1126"/>
      <line id="Capline-M" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="1055.54" y2="1055.54"/>
      <line id="Baseline-L" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="1556" y2="1556"/>
      <line id="Capline-L" style="fill:none;stroke:#27AAE1;stroke-width:0.5;" x1="263" x2="3036" y1="1485.54" y2="1485.54"/>
    \(margins)
     </g>
     <g id="Symbols">
    \(groups)
     </g>
    </svg>

    """
}

// MARK: Preview

/// Every icon on one sheet: large, then at 18pt and 14pt, with its name.
func writePreview(_ outlines: [(String, CGPath)], to url: URL) {
    let columns = 8, cell = 150, rows = (outlines.count + columns - 1) / columns
    let width = columns * cell, height = rows * cell
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocusFlipped(true)
    let context = NSGraphicsContext.current!.cgContext
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    for (i, (name, path)) in outlines.enumerated() {
        let x = CGFloat(i % columns * cell), y = CGFloat(i / columns * cell)
        context.setFillColor(CGColor(gray: 0.95, alpha: 1))
        context.fill(CGRect(x: x + 33, y: y + 6, width: 84, height: 84))
        for (size, origin) in [(CGFloat(84), CGPoint(x: x + 33, y: y + 6)), (18, CGPoint(x: x + 45, y: y + 98)), (14, CGPoint(x: x + 90, y: y + 100))] {
            context.saveGState()
            context.translateBy(x: origin.x, y: origin.y)
            context.scaleBy(x: size / 18, y: size / 18)
            context.addPath(path)
            context.setFillColor(CGColor(gray: 0.09, alpha: 1))
            context.fillPath()
            context.restoreGState()
        }
        let label = NSAttributedString(string: name, attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.darkGray])
        label.draw(at: NSPoint(x: x + (CGFloat(cell) - label.size().width) / 2, y: y + 124))
    }
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try! bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

// MARK: Run

let arguments = CommandLine.arguments
if let flag = arguments.firstIndex(of: "--vendor"), flag + 1 < arguments.count {
    vendor(from: URL(fileURLWithPath: (arguments[flag + 1] as NSString).expandingTildeInPath))
}

let catalog = root.appendingPathComponent("StarHash/Resources/Icons.xcassets")
let folder = catalog.appendingPathComponent("Icons")
let manager = FileManager.default
try? manager.removeItem(at: folder)
try! manager.createDirectory(at: folder, withIntermediateDirectories: true)
let info = #""info" : { "author" : "xcode", "version" : 1 }"#
try! "{ \(info) }\n".write(to: catalog.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try! "{ \(info), \"properties\" : { \"provides-namespace\" : true } }\n".write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

func writeSymbol(_ name: String, _ path: CGPath) {
    let set = folder.appendingPathComponent("\(name).symbolset")
    try! manager.createDirectory(at: set, withIntermediateDirectories: true)
    try! symbolSVG(name, path).write(to: set.appendingPathComponent("\(name).svg"), atomically: true, encoding: .utf8)
    let contents = "{ \(info), \"symbols\" : [ { \"filename\" : \"\(name).svg\", \"idiom\" : \"universal\" } ] }\n"
    try! contents.write(to: set.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

// Each icon's filled form, and its outline form beside it as `<name>Outline`.
var drawn: [(String, CGPath)] = []
var outlines: [(String, CGPath)] = []
for icon in icons {
    let filled = keylineShape(icon.keyline, icon.filled)
    writeSymbol(icon.name, filled)
    drawn.append((icon.name, filled))
    let outline = keylineShape(icon.keyline, icon.outline)
    writeSymbol(icon.name + "Outline", outline)
    outlines.append((icon.name + "Outline", outline))
}

if let flag = arguments.firstIndex(of: "--preview"), flag + 1 < arguments.count {
    // --only a,b,c previews just those.
    // Each filled form, then its outline form.
    var shown = zip(drawn, outlines).flatMap { [$0, $1] }
    if let only = arguments.firstIndex(of: "--only"), only + 1 < arguments.count {
        let names = Set(arguments[only + 1].split(separator: ",").map(String.init))
        shown = shown.filter { names.contains($0.0.hasSuffix("Outline") ? String($0.0.dropLast("Outline".count)) : $0.0) }
    }
    writePreview(shown, to: URL(fileURLWithPath: arguments[flag + 1]))
}
print("\(drawn.count) icons: " + drawn.map(\.0).joined(separator: ", "))
