import StarHashKit
import SwiftUI

// Every bottom sheet in StarHash is built in Beam's sheet language, from
// these pieces only: a centred large bold title with at most a glass
// button on its right (no close button; a sheet is swiped away), solid
// cards whose rows are split by dotted lines, small uppercase section
// labels, 50pt buttons, and Beam's type scale, all on clear Liquid Glass
// with the grabber showing. The accent is StarHash's blue where Beam uses
// its green.

// MARK: Type

extension Font {
    /// Beam's type scale, in Space Grotesk, for sheets: `size` at the
    /// default text size, scaling like `style`.
    static func sheet(_ size: CGFloat, _ weight: Font.Weight = .medium, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(starhashFamily, size: size, relativeTo: style).weight(weight)
    }

    static var sheetLargeTitle: Font { sheet(32, .bold, relativeTo: .largeTitle) }
    static var sheetTitle2: Font { sheet(21, .semibold, relativeTo: .title2) }
    static var sheetTitle3: Font { sheet(19, .semibold, relativeTo: .title3) }
    static var sheetHeadline: Font { sheet(16, .semibold, relativeTo: .headline) }
    static var sheetBody: Font { sheet(16, relativeTo: .body) }
    static var sheetCallout: Font { sheet(15, relativeTo: .callout) }
    static var sheetSubheadline: Font { sheet(14, .medium, relativeTo: .subheadline) }
    static var sheetFootnote: Font { sheet(12, relativeTo: .footnote) }
    static var sheetCaption: Font { sheet(11, .medium, relativeTo: .caption) }
    static var sheetCaption2: Font { sheet(10, .medium, relativeTo: .caption2) }
}

// MARK: Presentation

extension View {
    /// A bottom sheet on clear Liquid Glass (the page behind shows through,
    /// refracted, at every height), with the grabber and `detents`. Before
    /// iOS 26, a material.
    @ViewBuilder
    func sheetGlass(detents: Set<PresentationDetent> = [.medium, .large]) -> some View {
        if #available(iOS 26.0, *) {
            self
                .presentationBackground {
                    // Light: solid white. Dark: toward the page colour, where
                    // a lifted grey failed its grey text.
                    Color.clear
                        .glassEffect(.regular.tint(.sheetGlassTint), in: Rectangle())
                        .ignoresSafeArea()
                }
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
        } else {
            self
                .presentationBackground(Color.sheetGlassTint)
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
        }
    }

    /// The solid card a sheet's rows sit on. A page using the same pieces
    /// passes its own card colour, since its background is the sheet's.
    func sheetCard(radius: CGFloat = 22, fill: Color = .sheetSurface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Reports this view's height, so a sheet can size its detent to its
    /// content (`.height(height + 8)`, Beam's margin).
    func sheetHeight(_ height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.wrappedValue = $0 }
    }
}

// MARK: Header

/// A sheet's title row: the title centred, large and bold, with an
/// optional glass button pinned to the right.
struct SheetHeader<Trailing: View>: View {
    private let title: String
    private let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.sheetLargeTitle)
                .tracking(StarHashTracking.display(32))
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // Clear of the button on the right, and centred anyway.
                .padding(.horizontal, 52)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
}

extension SheetHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// The round glass button in a sheet's header, the label of a menu or a
/// button: a `.title3` glyph in a 32pt frame, Beam's.
struct SheetGlassGlyph: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(Color.starhashPrimaryText)
            .frame(width: 32, height: 32)
            .padding(6)
            .contentShape(Circle())
            .starhashGlass(in: Circle(), interactive: true)
    }
}

// MARK: Rows

/// A dotted line between a card's rows.
struct SheetDivider: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0.5))
            }
            // GO Club's dashes: 3pt on, 3pt off.
            .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .butt, dash: [3, 3]))
            .foregroundStyle(Color.sheetDivider)
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}

/// A label on the left and its value on the right, grey.
struct SheetInfoRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.sheetBody)
                .foregroundStyle(Color.starhashPrimaryText)
            Spacer(minLength: 12)
            trailing
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

extension SheetInfoRow where Trailing == SheetValueText {
    init(_ label: String, _ value: String) {
        self.init(label: label) { SheetValueText(text: value) }
    }
}

/// A row's value, as `SheetInfoRow` draws it.
struct SheetValueText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.sheetBody)
            .foregroundStyle(Color.sheetSecondaryText)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
    }
}

/// A small uppercase label over a card.
struct SheetSectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.sheet(11, .semibold, relativeTo: .caption))
            .tracking(0.8)
            .foregroundStyle(Color.sheetSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A symbol in a softly tinted circle, leading a card's heading row.
struct SheetIconCircle: View {
    let symbol: String
    var tint: Color = .starhashPrimaryText

    var body: some View {
        Image(systemName: symbol)
            .font(.sheetBody)
            .foregroundStyle(tint)
            .frame(width: 38, height: 38)
            .background(Circle().fill(Color.sheetChip))
            .accessibilityHidden(true)
    }
}

// MARK: Buttons

/// A sheet's button, Beam's: 50pt, a 16pt semibold label, a gradient fill
/// with no glow. `.sheetPrimary` is the accent, the
/// blue with near-black text; `.sheetFilled` is the
/// near-black (near-white in dark mode) fill for a choice that is not the
/// accent.
struct SheetButtonStyle: ButtonStyle {
    enum Fill {
        case accent
        case filled
    }

    var fill: Fill

    func makeBody(configuration: Configuration) -> some View {
        SheetButtonBody(configuration: configuration, fill: fill)
    }
}

private struct SheetButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let fill: SheetButtonStyle.Fill

    @Environment(\.isEnabled) private var isEnabled

    private var colors: (fill: Color, label: Color) {
        switch fill {
        case .filled:
            return (.sheetFilledButton, .sheetFilledLabel)
        case .accent:
            return (.starhashInk, .starhashOnInk)
        }
    }

    var body: some View {
        let colors = colors
        configuration.label
            .font(.sheetHeadline)
            .foregroundStyle(isEnabled ? colors.label : Color.sheetDisabledLabel)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background((isEnabled ? colors.fill : Color.sheetChip).gradient, in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SheetButtonStyle {
    static var sheetPrimary: SheetButtonStyle { SheetButtonStyle(fill: .accent) }
    static var sheetFilled: SheetButtonStyle { SheetButtonStyle(fill: .filled) }
}

/// The quiet choice under a sheet's button: grey text, or red for a
/// destructive one ("Turn Off", "Delete Transaction").
struct SheetTextButton: View {
    let title: String
    var role: ButtonRole?
    /// Straight on the blue page (the transaction page) rather than a
    /// white sheet: the red deepens to read on the blue.
    var onPage = false
    let action: () -> Void

    init(_ title: String, role: ButtonRole? = nil, onPage: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.onPage = onPage
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                // Bold when destructive: the vivid red on a white sheet,
                // the deeper one on the blue page.
                .font(.sheet(14, role == .destructive ? .bold : .semibold, relativeTo: .subheadline))
                .foregroundStyle(role == .destructive ? (onPage ? Color.starhashDestructiveOnPage : Color.starhashDestructive) : Color.sheetSecondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
