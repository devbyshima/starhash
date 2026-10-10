import SwiftUI

/// The faces a profile can wear, picked on "Pick your vibe": flat white
/// faces with features cut in the blue, on a ring a step lighter than the
/// page. Kept by raw value (`PreferenceKey.profileAvatar`).
enum AvatarFace: String, CaseIterable, Identifiable {
    case wink, grin, smile, happy
    case cool, surprised, content, sleepy
    case dizzy, dead, confounded, angry
    case starStruck, love, neutral, sad

    var id: Self { self }

    /// The face a profile shows before one is picked.
    static let standard = AvatarFace.wink

    /// What VoiceOver says for it.
    var title: String {
        switch self {
        case .wink: String(localized: "Winking")
        case .grin: String(localized: "Grinning")
        case .smile: String(localized: "Smiling")
        case .happy: String(localized: "Happy")
        case .cool: String(localized: "Cool")
        case .surprised: String(localized: "Surprised")
        case .content: String(localized: "Content")
        case .sleepy: String(localized: "Sleepy")
        case .dizzy: String(localized: "Dizzy")
        case .dead: String(localized: "Worn out")
        case .confounded: String(localized: "Confounded")
        case .angry: String(localized: "Angry")
        case .starStruck: String(localized: "Star-struck")
        case .love: String(localized: "In love")
        case .neutral: String(localized: "Neutral")
        case .sad: String(localized: "Sad")
        }
    }
}

/// A face on its ring, `size` across: the ring, the white face inside it,
/// and the features drawn in the blue.
struct AvatarView: View {
    let face: AvatarFace
    var size: CGFloat = 120

    @Environment(\.self) private var environment

    var body: some View {
        let feature = Color.avatarFeature.color(in: environment)
        // The z sits on the ring: white on the page, the features' blue
        // on a light container's pale ring.
        let zColor = environment.colorScheme == .light && environment.starhashSurface == .container ? feature : Color.avatarFace
        ZStack {
            Circle().fill(Color.avatarRing)
            Canvas { context, canvas in
                let inset = canvas.width * 0.13
                let rect = CGRect(origin: .zero, size: canvas).insetBy(dx: inset, dy: inset)
                context.fill(Path(ellipseIn: rect), with: .color(.avatarFace))
                AvatarFeatures.draw(face, in: rect, ink: feature, context: context)
                if face == .sleepy {
                    let s = canvas.width / 100
                    var z = Path()
                    z.move(to: CGPoint(x: 72 * s, y: 6 * s))
                    z.addLine(to: CGPoint(x: 86 * s, y: 6 * s))
                    z.addLine(to: CGPoint(x: 72 * s, y: 22 * s))
                    z.addLine(to: CGPoint(x: 86 * s, y: 22 * s))
                    context.stroke(z, with: .color(zColor), style: StrokeStyle(lineWidth: 5 * s, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(face.title)
    }
}

/// Each face's eyes and mouth, drawn in a 100 by 100 square laid over the
/// face's circle.
private enum AvatarFeatures {
    static func draw(_ face: AvatarFace, in rect: CGRect, ink color: Color, context: GraphicsContext) {
        let s = rect.width / 100
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        let ink = GraphicsContext.Shading.color(color)
        let line = StrokeStyle(lineWidth: 7.5 * s, lineCap: .round, lineJoin: .round)

        func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 6) {
            context.fill(Path(ellipseIn: CGRect(x: rect.minX + (x - r) * s, y: rect.minY + (y - r) * s, width: 2 * r * s, height: 2 * r * s)), with: ink)
        }
        func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            context.fill(Path(ellipseIn: CGRect(x: rect.minX + (x - w / 2) * s, y: rect.minY + (y - h / 2) * s, width: w * s, height: h * s)), with: ink)
        }
        func stroke(_ build: (inout Path) -> Void) {
            var path = Path()
            build(&path)
            context.stroke(path, with: ink, style: line)
        }
        func curve(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint) {
            stroke { $0.move(to: a); $0.addQuadCurve(to: b, control: control) }
        }
        func smile(width: CGFloat = 18, depth: CGFloat = 16, y: CGFloat = 60) {
            curve(p(50 - width, y), p(50, y + depth), p(50 + width, y))
        }
        func grin() {
            var mouth = Path()
            mouth.move(to: p(28, 56))
            mouth.addLine(to: p(72, 56))
            mouth.addQuadCurve(to: p(28, 56), control: p(50, 92))
            mouth.closeSubpath()
            context.fill(mouth, with: ink)
        }
        func star(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            var path = Path()
            for i in 0..<10 {
                let radius = i.isMultiple(of: 2) ? r : r * 0.45
                let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let point = p(x + cos(angle) * radius, y + sin(angle) * radius)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            context.fill(path, with: ink)
        }
        func heart(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            var path = Path()
            path.move(to: p(x, y + r))
            path.addCurve(to: p(x - r, y - r * 0.2), control1: p(x - r * 0.4, y + r * 0.6), control2: p(x - r, y + r * 0.3))
            path.addArc(center: p(x - r * 0.5, y - r * 0.3), radius: r * 0.5 * s, startAngle: .degrees(170), endAngle: .degrees(-10), clockwise: false)
            path.addArc(center: p(x + r * 0.5, y - r * 0.3), radius: r * 0.5 * s, startAngle: .degrees(190), endAngle: .degrees(10), clockwise: false)
            path.addCurve(to: p(x, y + r), control1: p(x + r, y + r * 0.3), control2: p(x + r * 0.4, y + r * 0.6))
            path.closeSubpath()
            context.fill(path, with: ink)
        }
        func cross(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 6) {
            stroke {
                $0.move(to: p(x - r, y - r)); $0.addLine(to: p(x + r, y + r))
                $0.move(to: p(x + r, y - r)); $0.addLine(to: p(x - r, y + r))
            }
        }

        switch face {
        case .wink:
            stroke { $0.move(to: p(27, 34)); $0.addLine(to: p(40, 41)); $0.addLine(to: p(27, 48)) }
            curve(p(58, 44), p(65, 36), p(72, 44))
            smile()
        case .grin:
            oval(36, 38, 10, 15)
            oval(64, 38, 10, 15)
            grin()
        case .smile:
            dot(36, 42)
            dot(64, 42)
            smile()
        case .happy:
            curve(p(28, 46), p(35, 33), p(42, 46))
            curve(p(58, 46), p(65, 33), p(72, 46))
            smile(width: 20, depth: 18)
        case .cool:
            // Two lenses, rounder at the bottom, and the bridge between.
            for x in [CGFloat(21), 53] {
                let lens = Path(roundedRect: CGRect(x: rect.minX + x * s, y: rect.minY + 33 * s, width: 26 * s, height: 17 * s), cornerRadii: RectangleCornerRadii(topLeading: 4 * s, bottomLeading: 9 * s, bottomTrailing: 9 * s, topTrailing: 4 * s))
                context.fill(lens, with: ink)
            }
            stroke { $0.move(to: p(46, 37)); $0.addLine(to: p(54, 37)) }
            smile(width: 20, depth: 14, y: 62)
        case .surprised:
            oval(36, 38, 10, 14)
            oval(64, 38, 10, 14)
            oval(50, 68, 16, 20)
        case .content:
            curve(p(28, 42), p(35, 50), p(42, 42))
            curve(p(58, 42), p(65, 50), p(72, 42))
            smile(width: 12, depth: 10, y: 63)
        case .sleepy:
            curve(p(28, 46), p(35, 52), p(42, 46))
            curve(p(58, 46), p(65, 52), p(72, 46))
            oval(50, 68, 10, 11)
        case .dizzy:
            for x in [CGFloat(35), 65] {
                stroke { $0.addEllipse(in: CGRect(x: rect.minX + (x - 9) * s, y: rect.minY + 33 * s, width: 18 * s, height: 18 * s)) }
                dot(x, 42, 2.5)
            }
            stroke {
                $0.move(to: p(30, 68))
                $0.addCurve(to: p(50, 68), control1: p(36, 60), control2: p(44, 76))
                $0.addCurve(to: p(70, 68), control1: p(56, 60), control2: p(64, 76))
            }
        case .dead:
            cross(36, 41)
            cross(64, 41)
            oval(50, 68, 13, 15)
        case .confounded:
            stroke { $0.move(to: p(27, 34)); $0.addLine(to: p(40, 41)); $0.addLine(to: p(27, 48)) }
            stroke { $0.move(to: p(73, 34)); $0.addLine(to: p(60, 41)); $0.addLine(to: p(73, 48)) }
            stroke {
                $0.move(to: p(28, 68)); $0.addLine(to: p(35, 61)); $0.addLine(to: p(43, 69))
                $0.addLine(to: p(50, 61)); $0.addLine(to: p(57, 69)); $0.addLine(to: p(65, 61)); $0.addLine(to: p(72, 68))
            }
        case .angry:
            stroke { $0.move(to: p(26, 32)); $0.addLine(to: p(42, 39)) }
            stroke { $0.move(to: p(74, 32)); $0.addLine(to: p(58, 39)) }
            dot(36, 47)
            dot(64, 47)
            curve(p(34, 72), p(50, 58), p(66, 72))
        case .starStruck:
            star(36, 40, 11)
            star(64, 40, 11)
            grin()
        case .love:
            heart(36, 40, 10)
            heart(64, 40, 10)
            smile()
        case .neutral:
            dot(36, 42)
            dot(64, 42)
            stroke { $0.move(to: p(36, 66)); $0.addLine(to: p(64, 66)) }
        case .sad:
            dot(36, 42)
            dot(64, 42)
            curve(p(34, 70), p(50, 58), p(66, 70))
        }
    }
}

/// "Pick your vibe": every face in a grid on a card, the one chosen ringed
/// in the accent, in the app's own sheet (Beam's sheet language, as every
/// sheet). Choosing one keeps it and closes the sheet.
struct AvatarPickerSheet: View {
    @Binding var selection: AvatarFace
    @Environment(\.dismiss) private var dismiss
    @State private var picked = 0
    @State private var height: CGFloat = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(spacing: 14) {
            SheetHeader(String(localized: "Pick your vibe"))
            Text("Choose a face that is you. You can change it any time.")
                .font(.sheetBody)
                .foregroundStyle(Color.sheetSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AvatarFace.allCases) { face in
                    Button {
                        selection = face
                        picked += 1
                        Task {
                            try? await Task.sleep(for: .milliseconds(250))
                            dismiss()
                        }
                    } label: {
                        AvatarView(face: face, size: 64)
                            .padding(4)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.starhashAccentGraphic, lineWidth: 3)
                                    .opacity(selection == face ? 1 : 0)
                            }
                            .frame(maxWidth: .infinity)
                            .scaleEffect(selection == face ? 1.04 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selection)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityAddTraits(selection == face ? .isSelected : [])
                }
            }
            .padding(14)
            .sheetCard()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .sheetHeight($height)
        .sheetGlass(detents: [.height(max(height, 200) + 8)])
        .sensoryFeedback(.selection, trigger: picked)
    }
}

/// The graphic behind the top of Profile, after the reference's rings
/// round its letters: the StarHash mark, with rings spreading out from it
/// in its own shape (the outer edges of ever wider strokes of it, so their
/// corners round off as they grow), faint, off the top right corner.
struct ProfileBackdrop: View {
    @Environment(\.self) private var environment

    var body: some View {
        Canvas { context, size in
            let side: CGFloat = 120
            let mark = StarHashMarkShape().path(in: CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side))
            let ink = GraphicsContext.Shading.color(.profileBackdrop)
            // Widest first, each ring's inside covered by the page so only
            // its outer edge shows.
            let page = Color.starhashBackground
            for ring in (1...6).reversed() {
                let reach = CGFloat(ring) * 24
                let band = mark.strokedPath(StrokeStyle(lineWidth: reach * 2, lineCap: .round, lineJoin: .round))
                context.stroke(band, with: ink, style: StrokeStyle(lineWidth: 4.5))
                context.fill(band, with: .color(page))
            }
            context.fill(mark, with: .color(page))
            context.fill(mark, with: ink)
        }
        .frame(width: 480, height: 440)
        // The mark just inside the top right corner, as the reference's.
        .offset(x: 190, y: -150)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
