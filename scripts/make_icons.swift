// Draws StarHash's icons, one puffy style for every icon in the app, and
// writes each as a custom SF Symbol into StarHash/Resources/Icons.xcassets:
//
//   swift scripts/make_icons.swift [--preview sheet.png [--only heart,check]]
//
// Every icon is drawn on the same 18 by 18 grid, about 2.5 of room to the
// edges, in one colour. Closed shapes are filled and traced with a 1.5
// round-joined stroke (`puff`), which puffs them out a little and rounds
// every corner, so star tips, arrow heads and bolt points come out as
// small curves; open glyphs (checks, crosses, chevrons, rings, lines) are a
// thin 1.6 round stroke (`line`). A `cut` part takes its shape out of what
// is drawn so far: the check in a filled circle, the gap round a slash.
// Simple: one or two forms per icon, nothing that vanishes at 14pt.
//
// A symbol needs filled outlines, so the strokes are outlined and every
// part merged into one shape with Core Graphics. On the symbol template's
// medium scale the grid's 13 point drawing area is 100 units tall at
// 100pt and its sides keep a point of the grid's room, as SF Symbols' own
// glyphs sit, so an icon sizes and aligns with the font as an SF Symbol
// does. --preview draws the whole set on one sheet, large and at
// its real size, to check them side by side. Run `xcodegen generate` after
// adding an icon so the targets see it, and give it its SF Symbol names in
// `StarIcon` (StarHash/Design/Icons.swift).

import AppKit
import CoreGraphics
import Foundation

// MARK: The style

enum Style {
    /// Filled, then traced with a round-joined stroke of this width.
    case puff(CGFloat)
    /// A round-capped, round-joined stroke of this width, unfilled.
    case line(CGFloat)
    /// Filled exactly, no trace: the dots knocked out of a shape.
    case fill
}

enum Geometry {
    case path(String)
    case circle(CGFloat, CGFloat, CGFloat)
    case rect(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
}

struct Part {
    var geometry: Geometry
    var style: Style
    var cuts = false
}

func puff(_ d: String, _ width: CGFloat = 1.5) -> Part { Part(geometry: .path(d), style: .puff(width)) }
func puff(circle cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Part { Part(geometry: .circle(cx, cy, r), style: .puff(1.5)) }
func puff(rect x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Part { Part(geometry: .rect(x, y, w, h, r), style: .puff(1.5)) }
func line(_ d: String, _ width: CGFloat = 1.6) -> Part { Part(geometry: .path(d), style: .line(width)) }
func line(circle cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ width: CGFloat = 1.6) -> Part { Part(geometry: .circle(cx, cy, r), style: .line(width)) }
func line(rect x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ width: CGFloat = 1.6) -> Part { Part(geometry: .rect(x, y, w, h, r), style: .line(width)) }
func dot(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Part { Part(geometry: .circle(cx, cy, r), style: .fill) }
func cut(_ part: Part) -> Part { var part = part; part.cuts = true; return part }

// Shapes worked out rather than typed: a puffy star, a badge's scallops,
// a gear's teeth.

func star(_ cx: CGFloat, _ cy: CGFloat, outer: CGFloat, inner: CGFloat, points: Int) -> String {
    var d = ""
    for i in 0..<(points * 2) {
        let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
        let r = i.isMultiple(of: 2) ? outer : inner
        d += (i == 0 ? "M" : "L") + "\(cx + r * cos(angle)) \(cy + r * sin(angle))"
    }
    return d + "Z"
}

func scallops(_ cx: CGFloat, _ cy: CGFloat, valley: CGFloat, peak: CGFloat, bumps: Int) -> String {
    let step = 2 * CGFloat.pi / CGFloat(bumps)
    func point(_ angle: CGFloat, _ r: CGFloat) -> String { "\(cx + r * cos(angle)) \(cy + r * sin(angle))" }
    var d = "M" + point(-.pi / 2 - step / 2, valley)
    for i in 0..<bumps {
        let mid = -CGFloat.pi / 2 + CGFloat(i) * step
        d += "Q" + point(mid, peak) + " " + point(mid + step / 2, valley)
    }
    return d + "Z"
}

func gear(_ cx: CGFloat, _ cy: CGFloat, outer: CGFloat, inner: CGFloat, teeth: Int) -> String {
    let step = 2 * CGFloat.pi / CGFloat(teeth)
    var d = ""
    for i in 0..<teeth {
        let a = -CGFloat.pi / 2 + CGFloat(i) * step
        let corners: [(CGFloat, CGFloat)] = [
            (a - step * 0.36, inner), (a - step * 0.2, outer), (a + step * 0.2, outer), (a + step * 0.36, inner),
        ]
        for (j, corner) in corners.enumerated() {
            d += (i == 0 && j == 0 ? "M" : "L") + "\(cx + corner.1 * cos(corner.0)) \(cy + corner.1 * sin(corner.0))"
        }
    }
    return d + "Z"
}

// MARK: The set

// Shared pieces, so related icons stay alike.
let ring = (cx: CGFloat(9), cy: CGFloat(9), r: CGFloat(5.75))
let bellBody = "M9 3.6c2.3 0 3.9 1.7 3.9 4v2l1 1.2c.4.5.1 1.2-.5 1.2H4.6c-.6 0-.9-.7-.5-1.2l1-1.2v-2c0-2.3 1.6-4 3.9-4z"
let bellClapper = "M7.8 14.1h2.4"
let bubble = "M9 3.6c3.1 0 5.6 2.1 5.6 4.8S12.1 13.2 9 13.2c-.6 0-1.2-.1-1.8-.2l-2.4 1.3c-.4.2-.9-.1-.8-.6l.4-1.9C3.9 10.9 3.4 9.7 3.4 8.4c0-2.7 2.5-4.8 5.6-4.8z"
let shield = "M8.5 3.4c.3-.1.7-.1 1 0l4 1.5c.4.2.7.6.7 1v3.3c0 2.7-1.8 4.6-4.7 5.6-.3.1-.6.1-.9 0-2.9-1-4.7-2.9-4.7-5.6V5.9c0-.4.3-.8.7-1z"
let corners = "M3.6 6.4V5a1.4 1.4 0 011.4-1.4h1.4M11.6 3.6H13a1.4 1.4 0 011.4 1.4v1.4M14.4 11.6V13a1.4 1.4 0 01-1.4 1.4h-1.4M6.4 14.4H5a1.4 1.4 0 01-1.4-1.4v-1.4"
// Most of a ring, open at the upper left, and a puffy head at its top
// pointing back round it.
let circleArrow = "M9 4.7A4.9 4.9 0 1 1 4.4 7.92"
let circleArrowHead = "M9.5 3.3v2.8L6.5 4.7z"
let pinShape = "M6.5 3.4h5c.5 0 .7.5.4.9l-.8 1v2.2l1.8 1.9c.3.3.4.6.4 1v.6H5.7v-.6c0-.4.1-.7.4-1l1.8-1.9V5.3l-.8-1c-.3-.4-.1-.9.4-.9z"
let torch = "M5.8 6.4h6.4v1.2l-1.5 2.2v3.8c0 .6-.5 1.1-1.1 1.1h-1.2c-.6 0-1.1-.5-1.1-1.1V9.8L5.8 7.6z"
let tray = "M3.4 9.6h3l.9 1.5h3.4l.9-1.5h3v3.4c0 .9-.7 1.6-1.6 1.6H5c-.9 0-1.6-.7-1.6-1.6z"
let graduationCap = "M8.4 3.9c.4-.2.8-.2 1.2 0l5.2 2.5c.5.2.5.9 0 1.1L9.6 9.9c-.4.2-.8.2-1.2 0L3.2 7.5c-.5-.2-.5-.9 0-1.1z"
let personHead = (cx: CGFloat(9), cy: CGFloat(5.6), r: CGFloat(2.35))
let personBody = "M4.5 13.6c0-2.2 2-3.6 4.5-3.6s4.5 1.4 4.5 3.6c0 .5-.4.9-.9.9H5.4c-.5 0-.9-.4-.9-.9z"
let box = "M6.6 7.6H5.4a1.2 1.2 0 00-1.2 1.2v4.4a1.2 1.2 0 001.2 1.2h7.2a1.2 1.2 0 001.2-1.2V8.8a1.2 1.2 0 00-1.2-1.2h-1.2"

let icons: [(name: String, parts: [Part])] = [
    // The three the style was given by.
    ("heart", [puff("M9 14.3c-.3 0-.6-.1-.86-.27C5.2 12.1 3.2 10 3.2 7.35A2.95 2.95 0 019 6.05a2.95 2.95 0 015.8 1.3c0 2.65-2 4.75-4.94 6.68-.26.17-.56.27-.86.27z")]),
    ("check", [line("M4.4 9.6l3 3 6.2-6.4")]),
    ("search", [line(circle: 8, 8, 4.8, 1.7), line("M11.6 11.6l2.8 2.8", 1.9)]),

    // Marks and arrows.
    ("plus", [line("M9 4v10M4 9h10")]),
    ("close", [line("M5 5l8 8M13 5l-8 8")]),
    ("chevronLeft", [line("M11 4.5L6.5 9l4.5 4.5")]),
    ("chevronRight", [line("M7 4.5L11.5 9 7 13.5")]),
    ("chevronUpDown", [line("M6 7l3-3 3 3M6 11l3 3 3-3")]),
    ("circle", [line(circle: 9, 9, 5.7)]),
    ("checkCircle", [puff(circle: ring.cx, ring.cy, ring.r), cut(line("M6.3 9.2l1.9 1.9 3.6-3.8"))]),
    ("closeCircle", [puff(circle: ring.cx, ring.cy, ring.r), cut(line("M7 7l4 4M11 7l-4 4"))]),
    ("info", [puff(circle: ring.cx, ring.cy, ring.r), cut(line("M9 8.4v3.6")), cut(dot(9, 6.1, 0.95))]),
    ("more", [puff(circle: ring.cx, ring.cy, ring.r), cut(dot(6.2, 9, 0.95)), cut(dot(9, 9, 0.95)), cut(dot(11.8, 9, 0.95))]),
    ("received", [puff(circle: ring.cx, ring.cy, ring.r), cut(line("M9 5.8v6M6.6 9.4L9 11.8l2.4-2.4"))]),
    ("play", [puff(circle: ring.cx, ring.cy, ring.r), cut(puff("M7.7 6.9v4.2c0 .4.4.6.7.4l3.2-2.1c.3-.2.3-.6 0-.8L8.4 6.5c-.3-.2-.7 0-.7.4z", 0.6))]),
    ("arrowUpRight", [line("M5.6 12.4l6.8-6.8M7.2 5.6h5.2v5.2")]),
    ("arrowDownLeft", [line("M12.4 5.6l-6.8 6.8M10.8 12.4H5.6V7.2")]),
    ("swap", [line("M3.8 6.4h10.4M11.6 3.8l2.6 2.6-2.6 2.6M14.2 11.6H3.8M6.4 9l-2.6 2.6 2.6 2.6")]),
    ("reset", [line(circleArrow), puff(circleArrowHead)]),
    ("history", [line(circleArrow), puff(circleArrowHead), line("M9 7.5v2.2l1.6 1.1")]),
    ("sendBack", [line("M7 4.4L4.4 7 7 9.6M4.6 7h5.4a3.4 3.4 0 010 6.8H8.4")]),
    ("hash", [line("M7.4 3.8L6 14.2M12 3.8l-1.4 10.4M4.2 7.1h10M3.8 10.9h10")]),
    ("code", [line("M6 6.2L3.4 9 6 11.8M12 6.2L14.6 9 12 11.8M10.1 4.8l-2.2 8.4")]),

    // Things to do.
    ("trash", [puff("M5.2 7h7.6l-.5 6.3a1.3 1.3 0 01-1.3 1.2H7a1.3 1.3 0 01-1.3-1.2z"), line("M3.8 4.9h10.4"), line("M7.2 4.6v-.5c0-.5.4-.9.9-.9h1.8c.5 0 .9.4.9.9v.5")]),
    ("pencil", [puff("M12.1 3.7l2.2 2.2-7.7 7.7-3 .7.7-3z"), cut(line("M10.3 5.5l2.2 2.2", 1.2))]),
    ("pin", [puff(pinShape), line("M9 11.2v3.4")]),
    ("unpin", [puff(pinShape), line("M9 11.2v3.4"), cut(line("M3.6 3.6l10.8 10.8", 3.4)), line("M3.6 3.6l10.8 10.8")]),
    ("share", [line(box), line("M9 3.4v7M6.6 5.6L9 3.4l2.4 2.2")]),
    ("download", [line(box), line("M9 3.2v7M6.6 7.8L9 10.2l2.4-2.4")]),
    ("scan", [line(corners), puff(rect: 7.2, 7.2, 3.6, 3.6, 0.6)]),
    ("qrCode", [
        puff(rect: 3.4, 3.4, 3.6, 3.6, 0.7), puff(rect: 11, 3.4, 3.6, 3.6, 0.7), puff(rect: 3.4, 11, 3.6, 3.6, 0.7),
        cut(Part(geometry: .rect(4.55, 4.55, 1.3, 1.3, 0.2), style: .fill)), cut(Part(geometry: .rect(12.15, 4.55, 1.3, 1.3, 0.2), style: .fill)), cut(Part(geometry: .rect(4.55, 12.15, 1.3, 1.3, 0.2), style: .fill)),
        puff(rect: 11.7, 11.7, 1.6, 1.6, 0.4),
    ]),
    ("camera", [puff("M6.8 4.4h4.4l.9 1.5h1.2a1.4 1.4 0 011.4 1.4v4.9a1.4 1.4 0 01-1.4 1.4H4.7a1.4 1.4 0 01-1.4-1.4V7.3a1.4 1.4 0 011.4-1.4h1.2z"), cut(line(circle: 9, 9.6, 2.2, 1.4))]),
    ("torch", [puff(torch), cut(dot(9, 10.6, 0.7))]),
    ("torchOn", [puff(torch), cut(dot(9, 10.6, 0.7)), line("M9 2.9v1.3M5 4.1l.9.9M13 4.1l-.9.9")]),

    // Safety.
    ("lock", [puff(rect: 4.6, 8.2, 8.8, 6.2, 1.5), line("M6.4 8.2V6.4a2.6 2.6 0 015.2 0v1.8")]),
    ("faceID", [line(corners), line("M6.9 7.2v1M11.1 7.2v1"), line("M6.9 11.3c1.2 1 3 1 4.2 0")]),
    ("touchID", [line("M4.2 11.8V9.6a4.8 4.8 0 019.6 0v1"), line("M6.6 14V9.6a2.4 2.4 0 014.8 0v2.6c0 .8-.2 1.5-.5 2"), line("M9 9.6v4.6")]),
    ("eye", [puff("M9 4.8c2.9 0 5 2.2 5.7 4.2-.7 2-2.8 4.2-5.7 4.2S4 11 3.3 9C4 7 6.1 4.8 9 4.8z"), cut(line(circle: 9, 9, 1.9, 1.4))]),
    ("shieldAlert", [puff(shield), cut(line("M9 6.3v3.3", 1.5)), cut(dot(9, 11.7, 0.85))]),
    ("shieldLock", [puff(shield), cut(dot(9, 7.9, 1.25)), cut(line("M9 8.6v2.8", 1.3))]),

    // Notifications and messages.
    ("bell", [puff(bellBody), line(bellClapper)]),
    ("bellBadge", [puff(bellBody), line(bellClapper), cut(dot(13.3, 4.7, 2.9)), puff(circle: 13.3, 4.7, 1.5)]),
    ("bellSlash", [puff(bellBody), line(bellClapper), cut(line("M3.6 3.6l10.8 10.8", 3.4)), line("M3.6 3.6l10.8 10.8")]),
    ("messageCheck", [puff(bubble), cut(line("M6.6 8.5l1.6 1.6 3.2-3.3", 1.5))]),
    ("messageQuestion", [puff(bubble), cut(line("M7.6 7.1c0-.8.6-1.4 1.4-1.4s1.4.6 1.4 1.3c0 .6-.4.9-.9 1.2-.4.2-.5.5-.5.9", 1.4)), cut(dot(9, 10.8, 0.8))]),
    ("chat", [
        puff("M10.3 3.4h1.4c1.6 0 2.9 1.2 2.9 2.7 0 1-.6 1.9-1.4 2.4l.3 1.3c.1.4-.3.6-.6.5L11 9.3h-.7c-1.6 0-2.9-1.3-2.9-2.9s1.3-3 2.9-3z"),
        cut(puff("M6.2 7.2h1.6c1.7 0 3 1.3 3 2.9S9.5 13 7.8 13H7l-1.9 1.1c-.3.2-.7-.1-.6-.5l.3-1.3C3.9 11.8 3.3 11 3.3 10c0-1.6 1.3-2.8 2.9-2.8z", 3.1)),
        puff("M6.2 7.2h1.6c1.7 0 3 1.3 3 2.9S9.5 13 7.8 13H7l-1.9 1.1c-.3.2-.7-.1-.6-.5l.3-1.3C3.9 11.8 3.3 11 3.3 10c0-1.6 1.3-2.8 2.9-2.8z"),
    ]),
    ("envelope", [puff(rect: 3.4, 4.8, 11.2, 8.4, 1.6), cut(line("M4.8 6.6L9 9.6l4.2-3", 1.4))]),
    ("sound", [puff("M3.6 7.2c0-.4.3-.8.8-.8h1.6l2.9-2.5c.4-.3 1-.1 1 .4v9.4c0 .5-.6.7-1 .4L6 11.6H4.4c-.5 0-.8-.4-.8-.8z"), line("M11.6 7.3a2.4 2.4 0 010 3.4M13.3 5.6a4.8 4.8 0 010 6.8")]),

    // People and places.
    ("person", [puff(circle: personHead.cx, personHead.cy, personHead.r), puff(personBody)]),
    ("personCircle", [puff(circle: ring.cx, ring.cy, ring.r), cut(dot(9, 7.3, 2.1)), cut(Part(geometry: .path("M5.5 13.4a4.6 4.6 0 007 0c-.8-1.3-2-2.1-3.5-2.1s-2.7.8-3.5 2.1z"), style: .fill))]),
    ("personAlert", [puff(circle: 7.4, 5.6, 2.3), puff("M3.2 13.6c0-2.2 1.8-3.6 4.2-3.6s4.2 1.4 4.2 3.6c0 .5-.4.9-.9.9H4.1c-.5 0-.9-.4-.9-.9z"), line("M14 4.4v4.8"), puff(circle: 14, 12.4, 0.35)]),
    ("people", [
        puff(circle: 12, 5.6, 1.9), puff("M9.6 13.4c0-1.9 1.2-3.2 2.7-3.2s2.6 1.3 2.6 3.2c0 .4-.3.7-.7.7h-3.9c-.4 0-.7-.3-.7-.7z"),
        cut(puff(circle: 7, 6.2, 2.2)), cut(puff("M3.1 13.4c0-2 1.7-3.3 3.9-3.3s3.9 1.3 3.9 3.3c0 .5-.4.8-.8.8H3.9c-.4 0-.8-.3-.8-.8z", 3.2)),
        puff(circle: 7, 6.2, 2.2), puff("M3.1 13.4c0-2 1.7-3.3 3.9-3.3s3.9 1.3 3.9 3.3c0 .5-.4.8-.8.8H3.9c-.4 0-.8-.3-.8-.8z"),
    ]),
    ("house", [puff("M8.1 3.8a1.4 1.4 0 011.8 0l4.3 3.6c.3.3.5.7.5 1.1v4.7a1.3 1.3 0 01-1.3 1.3h-2.5v-3.2a1.9 1.9 0 00-3.8 0v3.2H4.6a1.3 1.3 0 01-1.3-1.3V8.5c0-.4.2-.8.5-1.1z")]),
    ("store", [puff("M4.6 3.2h8.8l1.2 3c0 1-.8 1.6-1.8 1.6-.9 0-1.6-.6-1.8-1.3-.2.7-.9 1.3-1.8 1.3h-.4c-.9 0-1.6-.6-1.8-1.3-.2.7-.9 1.3-1.8 1.3-1 0-1.8-.6-1.8-1.6z"), puff(rect: 4.6, 9.8, 8.8, 4.8, 1), cut(Part(geometry: .rect(7.6, 11.6, 2.8, 5, 0.7), style: .fill))]),
    ("location", [puff("M13.9 3.6c.4-.2.8.2.6.6l-4.4 10c-.2.5-.9.4-1-.1l-.9-3.6c0-.2-.2-.3-.4-.4l-3.6-.9c-.5-.1-.6-.8-.1-1z")]),
    ("globe", [line(circle: 9, 9, 5.7), line("M9 3.3c-1.6 1.6-2.4 3.6-2.4 5.7s.8 4.1 2.4 5.7c1.6-1.6 2.4-3.6 2.4-5.7S10.6 4.9 9 3.3zM3.5 9h11")]),
    ("bank", [puff("M8.4 3.4c.4-.2.8-.2 1.2 0l4.7 2.5c.5.3.3 1-.3 1H3.9c-.6 0-.8-.7-.3-1z"), line("M5.4 9.1v3.1M9 9.1v3.1M12.6 9.1v3.1"), line("M3.8 14.4h10.4")]),

    // Money.
    ("phone", [puff("M5.4 3.6c.5-.3 1.1-.2 1.5.3l1.3 1.9c.3.5.3 1.1-.1 1.5l-.8.8c.6 1.4 1.8 2.6 3.2 3.2l.8-.8c.4-.4 1-.4 1.5-.1l1.9 1.3c.5.3.6 1 .3 1.5l-.6.9c-.6.9-1.7 1.3-2.7 1-3.4-1-6-3.6-7-7-.3-1 .1-2.1 1-2.7z")]),
    ("cash", [puff(rect: 3.3, 5.4, 11.4, 7.2, 1.4), cut(line(circle: 9, 9, 1.8, 1.4))]),
    ("card", [puff(rect: 3.3, 4.6, 11.4, 8.8, 1.6), cut(line("M2.8 7.6h12.4", 1.4)), cut(line("M5.8 10.9h2.2", 1.3))]),
    ("seal", [puff(scallops(9, 9, valley: 5.0, peak: 6.5, bumps: 10)), cut(line("M6.6 9.2l1.6 1.6 3.2-3.4", 1.5))]),
    ("gift", [puff(rect: 3.5, 6.2, 11, 2.4, 0.8), puff(rect: 4.4, 9.6, 9.2, 4.8, 1.2), cut(line("M9 5.4v9.8", 1.2)), line("M9 6c-.6-1.5-1.6-2.4-2.6-2.3-.9.1-1.1 1.1-.3 1.7.8.5 1.8.6 2.9.6M9 6c.6-1.5 1.6-2.4 2.6-2.3.9.1 1.1 1.1.3 1.7-.8.5-1.8.6-2.9.6")]),
    ("bag", [puff("M4.4 6.8h9.2l-.5 6.5a1.4 1.4 0 01-1.4 1.3H6.3a1.4 1.4 0 01-1.4-1.3z"), line("M6.8 8.2V5.8a2.2 2.2 0 014.4 0v2.4")]),
    ("cart", [puff("M6 5.6h7.8c.4 0 .7.4.6.8l-.8 3.6c-.1.5-.5.8-1 .8H7z"), line("M3.4 3.6h1.4c.4 0 .7.3.8.6l1.5 7c.1.4.4.7.8.7h5.6"), puff(circle: 7.8, 14.1, 0.6), puff(circle: 12.5, 14.1, 0.6)]),
    // An arrow dropping into a tray: kept.
    ("tray", [puff(tray), line("M9 3.4v5.2M6.6 6.2L9 8.6l2.4-2.4")]),
    ("box", [puff("M8.4 3.4c.4-.2.8-.2 1.2 0l4.4 2.2c.4.2.7.6.7 1.1v4.6c0 .5-.3.9-.7 1.1l-4.4 2.2c-.4.2-.8.2-1.2 0L4 12.4c-.4-.2-.7-.6-.7-1.1V6.7c0-.5.3-.9.7-1.1z"), cut(line("M3.8 6.3L9 8.9l5.2-2.6M9 8.9v5.4", 1.2))]),
    ("document", [puff("M5.4 3.3h4.6l3.4 3.4v6.8c0 .7-.5 1.2-1.2 1.2H5.4c-.7 0-1.2-.5-1.2-1.2V4.5c0-.7.5-1.2 1.2-1.2z"), cut(line("M6.8 9.4h4.2M6.8 11.9h2.8", 1.3))]),
    ("simCard", [puff("M6 3.3h4.6l3 3v7.1c0 .7-.6 1.3-1.3 1.3H6c-.7 0-1.3-.6-1.3-1.3V4.6c0-.7.6-1.3 1.3-1.3z"), cut(line(rect: 7, 8.6, 4, 3.6, 0.6, 1.2))]),

    // What codes and payments are for.
    ("bolt", [puff("M10.3 3.3L4.9 10h4l-.9 4.7 5.2-6.9H9.3z")]),
    ("drop", [puff("M9 3.6c.2 0 .4.1.5.3 1.7 2.4 3.8 4.7 3.8 6.5a4.3 4.3 0 01-8.6 0c0-1.8 2.1-4.1 3.8-6.5.1-.2.3-.3.5-.3z")]),
    ("tv", [puff(rect: 3.3, 4, 11.4, 7.8, 1.6), line("M6.4 14.2h5.2")]),
    ("wifi", [line("M5.1 9.1a5.5 5.5 0 017.8 0M6.9 10.9a3 3 0 014.2 0"), line("M3.3 7.3a8 8 0 0111.4 0"), puff(circle: 9, 13.1, 0.55)]),
    ("antenna", [puff(circle: 9, 7.6, 1), line("M9 9.2v5.2"), line("M6.6 5.2a3.4 3.4 0 000 4.8M11.4 5.2a3.4 3.4 0 010 4.8M4.6 3.4a6 6 0 000 8.4M13.4 3.4a6 6 0 010 8.4")]),
    ("food", [line("M5.6 3.4v4.2c0 .9.6 1.5 1.4 1.5M8.4 3.4v4.2c0 .9-.6 1.5-1.4 1.5M7 3.4v11.2"), puff("M12.2 3.6c-1.3.7-1.9 2.5-1.9 4.6 0 .8.4 1.3 1 1.5v4.3a.8.8 0 001.6 0V4c0-.3-.4-.6-.7-.4z")]),
    ("car", [puff("M5.4 5.2c.2-.6.8-1 1.4-1h4.4c.6 0 1.2.4 1.4 1l.9 2.6c.7.4 1.2 1.2 1.2 2v2.3H3.3v-2.3c0-.8.5-1.6 1.2-2z"), puff(rect: 4.3, 12, 1.6, 1.8, 0.5), puff(rect: 12.1, 12, 1.6, 1.8, 0.5), cut(line("M5.8 7.6h6.4", 1.2)), cut(dot(5.9, 10, 0.75)), cut(dot(12.1, 10, 0.75))]),
    ("bus", [puff(rect: 4.4, 3.4, 9.2, 9.6, 2), puff(rect: 5.2, 12.6, 1.6, 1.6, 0.5), puff(rect: 11.2, 12.6, 1.6, 1.6, 0.5), cut(line("M5.9 7.1h6.2", 2.2)), cut(dot(6.8, 10.6, 0.7)), cut(dot(11.2, 10.6, 0.7))]),
    ("airplane", [puff("M9 3.3c.6 0 1 .6 1 1.4v3l4.3 2.5c.2.1.3.3.3.5v.8c0 .3-.3.5-.6.4L10 10.4v2.4l1.3 1c.1.1.2.2.2.4v.4c0 .2-.2.4-.4.3L9 14.3l-2.1.6c-.2.1-.4-.1-.4-.3v-.4c0-.2.1-.3.2-.4l1.3-1v-2.4l-4 1.5c-.3.1-.6-.1-.6-.4v-.8c0-.2.1-.4.3-.5L8 7.7v-3c0-.8.4-1.4 1-1.4z")]),
    ("fuel", [puff("M4 4.6c0-.7.6-1.3 1.3-1.3h4c.7 0 1.3.6 1.3 1.3v9.8H4z"), cut(Part(geometry: .rect(5.4, 4.8, 3.8, 2.6, 0.4), style: .fill)), line("M10.6 7.4h1c.6 0 1 .4 1 1v3.8c0 .5.4.9.9.9s.9-.4.9-.9V6.6l-1.5-1.8")]),
    ("graduation", [puff("M5.8 9.4v2.2c0 1.3 1.4 2.3 3.2 2.3s3.2-1 3.2-2.3V9.4L9.6 10.7c-.4.2-.8.2-1.2 0z"), cut(puff(graduationCap, 3)), puff(graduationCap), line("M14.3 7.2v3.4")]),
    ("health", [puff(rect: 3.3, 5.8, 11.4, 8.4, 1.6), line("M6.9 5.8V5c0-.5.4-.9.9-.9h2.4c.5 0 .9.4.9.9v.8"), cut(line("M9 7.9v4.2M6.9 10h4.2", 1.5))]),
    // A clapperboard, which reads at 14pt where a strip of film does not.
    ("film", [puff(rect: 3.4, 8.2, 11.2, 6, 1.4), puff("M3.7 6.6L3.4 5.3c-.1-.4.2-.8.6-.9l9.4-2c.4-.1.8.2.9.6l.3 1.4z"), cut(line("M2.6 7.5h12.8", 1)), cut(line("M7 3.4l-1.3 2.6M10.4 2.7L9.1 5.3", 1.1))]),
    ("ticket", [puff("M4.6 4.8h8.8c.7 0 1.2.5 1.2 1.2v1.6a1.4 1.4 0 000 2.8v1.6c0 .7-.5 1.2-1.2 1.2H4.6c-.7 0-1.2-.5-1.2-1.2v-1.6a1.4 1.4 0 000-2.8V6c0-.7.5-1.2 1.2-1.2z"), cut(line("M10.8 6.4v.6M10.8 8.7v.6M10.8 11v.6", 1.3))]),
    ("game", [puff("M6 5.6h6c1.7 0 2.8 1.2 3 2.9l.3 3.3c.1 1.1-.7 2-1.8 2-.6 0-1.1-.3-1.5-.7l-1-1.3H7l-1 1.3c-.4.4-.9.7-1.5.7-1.1 0-1.9-.9-1.8-2L3 8.5c.2-1.7 1.3-2.9 3-2.9z"), cut(line("M5.4 8.9h2.2M6.5 7.8V10", 1.2)), cut(dot(11.3, 8.2, 0.65)), cut(dot(12.6, 9.6, 0.65))]),
    ("parking", [puff(rect: 3.6, 3.6, 10.8, 10.8, 2.4), cut(line("M7.4 12.2V5.8h2a1.9 1.9 0 010 3.8h-2"))]),
    ("star", [puff(star(9, 9.5, outer: 5.6, inner: 2.7, points: 5))]),
    ("sparkles", [puff("M8 5.6C8.5 8.2 9.6 9.3 12.2 9.8 9.6 10.3 8.5 11.4 8 14 7.5 11.4 6.4 10.3 3.8 9.8 6.4 9.3 7.5 8.2 8 5.6z"), puff("M12.8 3.4c.2 1.1.8 1.7 1.9 1.9-1.1.2-1.7.8-1.9 1.9-.2-1.1-.8-1.7-1.9-1.9 1.1-.2 1.7-.8 1.9-1.9z")]),

    // The tabs and Settings.
    ("clock", [puff(circle: ring.cx, ring.cy, ring.r), cut(line("M9 5.9V9l2.1 1.4", 1.5))]),
    ("gear", [puff(gear(9, 9, outer: 5.7, inner: 4.3, teeth: 8)), cut(dot(9, 9, 1.9))]),
    ("calendar", [puff(rect: 3.4, 4.6, 11.2, 9.8, 1.8), cut(line("M6.4 3.1v2.6M11.6 3.1v2.6", 3.2)), line("M6.4 3.1v2.6M11.6 3.1v2.6"), cut(line("M3 8h12", 1.2))]),
    ("chartBar", [puff(rect: 4, 9.6, 1.8, 4.8, 0.5), puff(rect: 8.1, 6.4, 1.8, 8, 0.5), puff(rect: 12.2, 3.6, 1.8, 10.8, 0.5)]),
    ("chartLine", [line("M3.6 3.6v10.8h10.8"), line("M6.4 11.2l2.4-2.8 2 1.6 3.4-4.2")]),
    ("hourglass", [line("M5 3.6h8M5 14.4h8"), puff("M6 4.6h6c0 2-1.1 3.4-2.4 4.4 1.3 1 2.4 2.4 2.4 4.4H6c0-2 1.1-3.4 2.4-4.4C7.1 8 6 6.6 6 4.6z")]),
    ("sunset", [puff("M5.6 12.2a3.4 3.4 0 016.8 0z"), line("M3.4 14.4h11.2"), line("M9 4.2v1.6M4.6 6.6l1.1 1.1M13.4 6.6l-1.1 1.1")]),
    ("lightbulb", [puff("M9 3.4a4.2 4.2 0 00-2.6 7.5c.5.4.7.9.7 1.4v.2h3.8v-.2c0-.5.2-1 .7-1.4A4.2 4.2 0 009 3.4z"), line("M7.6 14.6h2.8")]),
    // Ko-fi's cup, with the heart its own mark carries.
    ("cup", [puff("M3.4 6.8h8.2v3.8a3.6 3.6 0 01-3.6 3.6H7a3.6 3.6 0 01-3.6-3.6z"), line("M11.6 7.9h.7a1.85 1.85 0 010 3.7h-.7"), line("M6 3.4v1.4M9 3.4v1.4"), cut(Part(geometry: .path("M7.5 12.2C6.3 11.4 5.7 10.6 5.7 9.8a.9.9 0 011.8 0 .9.9 0 011.8 0c0 .8-.6 1.6-1.8 2.4z"), style: .fill))]),
    ("flag", [puff("M5.2 3.8c1.6-.8 3.2-.8 4.6 0s3 .8 4.4 0v6.2c-1.4.8-3 .8-4.4 0s-3-.8-4.6 0z"), line("M4.6 3.4v11.2")]),
    ("appearance", [line(circle: 9, 9, 5.7), puff("M9 3.3a5.7 5.7 0 000 11.4z")]),
    ("battery", [line(rect: 3.2, 6, 10.4, 6, 1.6), puff(rect: 5.1, 7.9, 3.2, 2.2, 0.4), line("M15.2 8.2v1.6")]),
]

// MARK: Path data

/// SVG path data in the 18 grid, read into a Core Graphics path: every
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

// MARK: Outlines

func geometryPath(_ geometry: Geometry) -> CGPath {
    switch geometry {
    case .path(let d):
        return parsePath(d)
    case .circle(let cx, let cy, let r):
        return CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r), transform: nil)
    case .rect(let x, let y, let w, let h, let r):
        return CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
    }
}

/// What a part covers, as one filled outline.
func region(_ part: Part) -> CGPath {
    let path = geometryPath(part.geometry)
    switch part.style {
    case .fill:
        return path.normalized()
    case .line(let width):
        return path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10).normalized()
    case .puff(let width):
        let trace = path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
        return path.normalized().union(trace)
    }
}

/// An icon's parts, in order, as one filled shape in the 18 grid.
func outline(_ parts: [Part]) -> CGPath {
    var shape: CGPath = CGMutablePath()
    for part in parts {
        let covered = region(part)
        shape = part.cuts ? shape.subtracting(covered) : shape.union(covered)
    }
    return shape
}

// MARK: Symbols

/// Template units per grid unit: the drawing area, 2.5 to 15.5, is 100
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
    <!-- \(name), drawn by scripts/make_icons.swift; edit it there, not here. -->
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

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let catalog = root.appendingPathComponent("StarHash/Resources/Icons.xcassets")
let folder = catalog.appendingPathComponent("Icons")
let manager = FileManager.default
try? manager.removeItem(at: folder)
try! manager.createDirectory(at: folder, withIntermediateDirectories: true)
let info = #""info" : { "author" : "xcode", "version" : 1 }"#
try! "{ \(info) }\n".write(to: catalog.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try! "{ \(info), \"properties\" : { \"provides-namespace\" : true } }\n".write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

var drawn: [(String, CGPath)] = []
for icon in icons {
    let path = outline(icon.parts)
    let set = folder.appendingPathComponent("\(icon.name).symbolset")
    try! manager.createDirectory(at: set, withIntermediateDirectories: true)
    try! symbolSVG(icon.name, path).write(to: set.appendingPathComponent("\(icon.name).svg"), atomically: true, encoding: .utf8)
    let contents = "{ \(info), \"symbols\" : [ { \"filename\" : \"\(icon.name).svg\", \"idiom\" : \"universal\" } ] }\n"
    try! contents.write(to: set.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    drawn.append((icon.name, path))
}

let arguments = CommandLine.arguments
if let flag = arguments.firstIndex(of: "--preview"), flag + 1 < arguments.count {
    // --only a,b,c previews just those.
    var shown = drawn
    if let only = arguments.firstIndex(of: "--only"), only + 1 < arguments.count {
        let names = Set(arguments[only + 1].split(separator: ",").map(String.init))
        shown = drawn.filter { names.contains($0.0) }
    }
    writePreview(shown, to: URL(fileURLWithPath: arguments[flag + 1]))
}
print("\(drawn.count) icons: " + drawn.map(\.0).joined(separator: ", "))
