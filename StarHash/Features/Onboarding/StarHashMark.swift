import SwiftUI

/// The StarHash mark: the star over its small triangle, bare, with no tile
/// behind it. Light: white on the blue page, since a blue star would vanish
/// there, and the blue on white. Dark: the blue. Drawn from the icon's own
/// artwork (`AppIcon.icon/Assets/Document.svg`), so it matches the icon at
/// any size.
struct StarHashMark: View {
    var size: CGFloat

    var body: some View {
        StarHashMarkShape()
            .fill(Color.starhashMarkGlyph)
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel("StarHash")
    }
}

/// The star and the triangle beneath it, from the icon's 816 by 816
/// artwork, centred in the rect at its largest square.
struct StarHashMarkShape: Shape {
    /// The artwork's square.
    static let side: CGFloat = 816

    /// The star, clockwise from the top arm's left corner: each arm's two
    /// outer corners, then the inner corner before the next arm.
    static let star: [CGPoint] = [
        CGPoint(x: 285.5, y: 88.1), CGPoint(x: 521.5, y: 88.1), CGPoint(x: 480.8, y: 302.1),
        CGPoint(x: 645.7, y: 166.1), CGPoint(x: 759.1, y: 364.8), CGPoint(x: 547, y: 441.5),
        CGPoint(x: 764.3, y: 516.7), CGPoint(x: 645.7, y: 710.3), CGPoint(x: 404.8, y: 495.3),
        CGPoint(x: 160.5, y: 710.3), CGPoint(x: 43.4, y: 516.8), CGPoint(x: 260, y: 441.5),
        CGPoint(x: 45, y: 364.8), CGPoint(x: 160.8, y: 166.1), CGPoint(x: 325.5, y: 302.1),
    ]
    static let triangle: [CGPoint] = [
        CGPoint(x: 404.4, y: 563.8), CGPoint(x: 564.8, y: 729.4), CGPoint(x: 242.3, y: 729.4),
    ]

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / Self.side
        let origin = CGPoint(x: rect.midX - Self.side / 2 * s, y: rect.midY - Self.side / 2 * s)
        func p(_ point: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + point.x * s, y: origin.y + point.y * s)
        }

        var path = Path()
        path.addLines(Self.star.map(p))
        path.closeSubpath()
        path.addLines(Self.triangle.map(p))
        path.closeSubpath()
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
