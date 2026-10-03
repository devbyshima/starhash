import SwiftUI

/// The StarHash mark: the star over its small triangle, bare, with no tile
/// behind it. Light: near black, the dark page's colour, since a blue star
/// would vanish on the blue page. Dark: the blue. Drawn from the icon's own
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
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 816
        let origin = CGPoint(x: rect.midX - 408 * s, y: rect.midY - 408 * s)
        func p(_ point: (CGFloat, CGFloat)) -> CGPoint {
            CGPoint(x: origin.x + point.0 * s, y: origin.y + point.1 * s)
        }

        let star: [(CGFloat, CGFloat)] = [
            (285.5, 88.1), (521.5, 88.1), (480.8, 302.1), (645.7, 166.1),
            (759.1, 364.8), (547, 441.5), (764.3, 516.7), (645.7, 710.3),
            (404.8, 495.3), (160.5, 710.3), (43.4, 516.8), (260, 441.5),
            (45, 364.8), (160.8, 166.1), (325.5, 302.1),
        ]
        let triangle: [(CGFloat, CGFloat)] = [(404.4, 563.8), (564.8, 729.4), (242.3, 729.4)]

        var path = Path()
        path.addLines(star.map(p))
        path.closeSubpath()
        path.addLines(triangle.map(p))
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
