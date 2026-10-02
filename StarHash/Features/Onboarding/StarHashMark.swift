import SwiftUI

/// The StarHash mark: a rounded tile with a "#" cut out of it, its centre
/// square left solid. Drawn from the app icon's Mark.svg (a 1024 grid,
/// 230 corner radius, bars 110 wide), so it matches the icon at any size.
///
/// The tile is ink by default: white on the dark canvas, as on the icon,
/// and black in light mode, where a white tile would vanish.
struct StarHashMark: View {
    var size: CGFloat
    var color: Color = .starhashInk

    var body: some View {
        StarHashMarkShape()
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: size, height: size)
            .accessibilityLabel("StarHash")
    }
}

/// The mark's outline in its own square. Even-odd filling cuts the "#"
/// out of the tile and fills its centre back in, as the SVG's opposite
/// windings do.
struct StarHashMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 1024
        let origin = CGPoint(x: rect.midX - 512 * s, y: rect.midY - 512 * s)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * s, y: origin.y + y * s)
        }

        var path = Path()
        path.addRoundedRect(
            in: CGRect(origin: origin, size: CGSize(width: 1024 * s, height: 1024 * s)),
            cornerSize: CGSize(width: 230 * s, height: 230 * s),
            style: .circular
        )

        // The "#" outline, clockwise from the top of its left bar.
        let hash: [(CGFloat, CGFloat)] = [
            (340, 230), (450, 230), (450, 340), (574, 340), (574, 230), (684, 230),
            (684, 340), (794, 340), (794, 450), (684, 450), (684, 574), (794, 574),
            (794, 684), (684, 684), (684, 794), (574, 794), (574, 684), (450, 684),
            (450, 794), (340, 794), (340, 684), (230, 684), (230, 574), (340, 574),
            (340, 450), (230, 450), (230, 340), (340, 340),
        ]
        path.addLines(hash.map { p($0.0, $0.1) })
        path.closeSubpath()

        // The square in the middle of the "#".
        path.addRect(CGRect(origin: p(450, 450), size: CGSize(width: 124 * s, height: 124 * s)))
        return path
    }
}

#Preview {
    HStack(spacing: 24) {
        StarHashMark(size: 120)
        StarHashMark(size: 40)
    }
    .padding()
    .background(Color.starhashBackground)
}
