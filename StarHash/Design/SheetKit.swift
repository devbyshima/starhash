import StarHashKit
import SwiftUI

// Every bottom sheet in StarHash is built in Beam's sheet language, from
// these pieces only: a centred large bold title with at most a glass
// button on its right (no close button; a sheet is swiped away), solid
// cards whose rows are split by solid hairlines, small uppercase section
// labels, 50pt buttons, and Beam's type scale, all on clear Liquid Glass
// with the grabber showing. The accent is the text colour: near black, or
// near white in dark mode. Sheets that explain one thing are hero sheets
// instead (HeroSheet.swift): a small caption and a close button on top.

// MARK: Type

extension Font {
    /// Beam's type scale, in Space Grotesk, for sheets: `size` at the default
    /// text size, scaling like `style`.
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
    /// iOS 26, a material. A hero sheet hides the grabber: its close button
    /// says how to leave.
    @ViewBuilder
    func sheetGlass(detents: Set<PresentationDetent> = [.medium, .large], dragIndicator: Visibility = .visible) -> some View {
        if #available(iOS 26.0, *) {
            self
                // White in light mode: its text is a container's.
                .starhashContainerSurface()
                .presentationBackground {
                    // Light: solid white. Dark: toward the page colour, where
                    // a lifted grey failed its grey text.
                    Color.clear
                        .glassEffect(.regular.tint(.sheetGlassTint), in: Rectangle())
                        .ignoresSafeArea()
                }
                .presentationDetents(detents)
                .presentationDragIndicator(dragIndicator)
        } else {
            self
                .starhashContainerSurface()
                .presentationBackground(Color.sheetGlassTint)
                .presentationDetents(detents)
                .presentationDragIndicator(dragIndicator)
        }
    }

    /// The same sheet, with the detent showing in `selection`: setting it
    /// moves the sheet to that height on the system's own spring, where a
    /// new set of detents would jump there.
    @ViewBuilder
    func sheetGlass(detents: Set<PresentationDetent>, selection: Binding<PresentationDetent>) -> some View {
        if #available(iOS 26.0, *) {
            self
                .starhashContainerSurface()
                .presentationBackground {
                    Color.clear
                        .glassEffect(.regular.tint(.sheetGlassTint), in: Rectangle())
                        .ignoresSafeArea()
                }
                .presentationDetents(detents, selection: selection)
                .presentationDragIndicator(.visible)
        } else {
            self
                .starhashContainerSurface()
                .presentationBackground(Color.sheetGlassTint)
                .presentationDetents(detents, selection: selection)
                .presentationDragIndicator(.visible)
        }
    }

    /// The solid card a sheet's rows sit on. A page using the same pieces
    /// passes its own card colour, since its background is the sheet's.
    func sheetCard(radius: CGFloat = 22, fill: Color = .sheetSurface) -> some View {
        starhashContainer(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
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
            Text(catalog: title)
                .font(.sheetLargeTitle)
                .tracking(StarHashTracking.display(32))
                .foregroundStyle(Color.sheetBrandText)
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

/// A sheet that scrolls, its title collapsing after the owner's reference
/// (Apple Pay's sheet). At rest the title is `SheetHeader`'s, the same size
/// in the same place, at the top of the scroll. As it scrolls up, the title
/// blurs and fades as it goes, and once it has all but gone, it comes back
/// small at the top, sharpening out of a blur, in a bar that what scrolls
/// on runs under through the system's soft scroll edge, a progressive blur
/// with no tint (iOS 26; before it, a fade of the sheet's material).
/// Scrolling back down plays it backwards. Every part follows the scroll,
/// so a drag half way leaves it half way.
///
/// The header's glass buttons (`leading`, `trailing`), as `SheetHeader`'s,
/// stay pinned at the top over the scroll: level with the big title at
/// rest, rising with it into the bar, the small title between them. A
/// sheet sized to what it shows passes `contentHeight`, which reports the
/// title and content's whole height for its `.height` detent; it then
/// scrolls only when that is more than the screen, at the largest text
/// sizes, and never bounces while it fits.
struct CollapsingSheetScroll<Leading: View, Trailing: View, Content: View>: View {
    let title: String
    /// The small title's two lines, as the reference sets them: a grey
    /// caption over the main line in bold ("Request" over "5,000 RWF").
    /// Without them, the big title again, small.
    let smallCaption: String?
    let smallTitle: String?
    let contentHeight: Binding<CGFloat>?
    let leading: Leading
    let trailing: Trailing
    let content: Content

    /// How far the scroll has moved from its top.
    @State private var offset: CGFloat = 0
    /// The big title's height, with its padding.
    @State private var titleHeight: CGFloat = 66

    init(
        title: String,
        smallCaption: String? = nil,
        smallTitle: String? = nil,
        contentHeight: Binding<CGFloat>? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.smallCaption = smallCaption
        self.smallTitle = smallTitle
        self.contentHeight = contentHeight
        self.leading = leading()
        self.trailing = trailing()
        self.content = content()
    }

    /// The bar the small title sits in, and the blur under it.
    private static var barHeight: CGFloat { 60 }
    /// The big title's padding above and below, `SheetHeader`'s.
    private static var titleTop: CGFloat { 18 }
    private static var titleBottom: CGFloat { 8 }

    private var hasButtons: Bool { Leading.self != EmptyView.self || Trailing.self != EmptyView.self }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                bigTitle
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = max($0, 1) }
                content
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight?.wrappedValue = $0 }
        }
        .scrollBounceBehavior(contentHeight == nil ? .automatic : .basedOnSize)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, now in
            offset = now
        }
        .starhashSoftEdge()
        // Over the scroll, taking no room, so the big title sits where
        // `SheetHeader`'s does; at rest there is nothing in it.
        .overlay(alignment: .top) { smallTitleBar }
        .overlay(alignment: .top) { if hasButtons { buttons } }
        // Solid, as What's New and the notes are: through clear glass the
        // blur under the bar would take in the page behind the sheet and
        // lighten; on the sheet's own fill it blurs only what scrolls.
        .background(Color.noteSheetBackground.ignoresSafeArea())
        .starhashContainerSurface()
    }

    /// The header's buttons, centred on the big title's line at rest and
    /// on the bar's once it has gone, so the small title sits between them.
    private var buttons: some View {
        let atRest = Self.titleTop + (titleHeight - Self.titleTop - Self.titleBottom) / 2
        let centre = atRest + (Self.barHeight / 2 - atRest) * gone
        return HStack {
            leading
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 20)
        // Centred in a band twice `centre` tall, laid from the top.
        .frame(height: centre * 2)
    }

    /// 0 at rest to 1 once the big title has scrolled away.
    private var gone: CGFloat { Self.clamp(offset / titleHeight) }

    /// The small title: nothing until the big one is two thirds gone, all
    /// of it a little after it has.
    private var small: CGFloat { Self.clamp((offset - titleHeight * 0.66) / (titleHeight * 0.5)) }

    /// The blur under the bar: in as the big title starts under it, full
    /// by the time the small title arrives, so nothing sharp is ever
    /// behind the small title.
    private var backdrop: CGFloat { Self.clamp((offset - titleHeight * 0.25) / (titleHeight * 0.55)) }

    /// Clamped to 0...1 and eased in and out (smoothstep), so each fade
    /// starts and settles softly rather than at a constant rate.
    private static func clamp(_ value: CGFloat) -> CGFloat {
        let x = min(max(value, 0), 1)
        return x * x * (3 - 2 * x)
    }

    /// `SheetHeader`'s title, laid out as it lays it out.
    private var bigTitle: some View {
        Text(catalog: title)
            .font(.sheetLargeTitle)
            .tracking(StarHashTracking.display(32))
            .foregroundStyle(Color.sheetBrandText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 52)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, Self.titleTop)
            .padding(.bottom, Self.titleBottom)
            .opacity(1 - gone)
            .blur(radius: gone * 8)
            .accessibilityAddTraits(.isHeader)
    }

    /// The title, small, at the top once the big one has gone, over a fade
    /// of the sheet's material that the scroll runs under, blurring into it
    /// as the Soft Edge does under a bar.
    private var smallTitleBar: some View {
        VStack(spacing: 1) {
            if let smallCaption {
                Text(catalog: smallCaption)
                    .font(.sheetFootnote)
                    .foregroundStyle(Color.sheetSecondaryText)
            }
            Text(catalog: smallTitle ?? title)
                .font(.sheet(16, .bold, relativeTo: .headline))
                .foregroundStyle(Color.sheetBrandText)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        // Clear of the buttons when there are any.
        .padding(.horizontal, hasButtons ? 70 : 60)
        .opacity(small)
        .blur(radius: (1 - small) * 6)
        .offset(y: (1 - small) * 4)
        .frame(maxWidth: .infinity)
        .frame(height: Self.barHeight)
        .background(alignment: .top) { progressiveBlur }
        .allowsHitTesting(false)
        // VoiceOver reads the big title, which stays in the scroll.
        .accessibilityHidden(true)
    }

    /// What scrolls under the bar blurs more the higher it goes, and is
    /// otherwise left as it is, no tint and no veil: two clear blurs, the
    /// stronger held to the top, each fading out downwards.
    private var progressiveBlur: some View {
        ZStack {
            ClearBlur()
                .mask(Self.fade(solidTo: 0.35, clearAt: 1))
            ClearBlur()
                .mask(Self.fade(solidTo: 0.2, clearAt: 0.6))
        }
        .frame(height: Self.barHeight + 28)
        .padding(.top, -12)
        .opacity(backdrop)
    }

    private static func fade(solidTo solid: CGFloat, clearAt clear: CGFloat) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: solid),
            .init(color: .clear, location: clear),
        ], startPoint: .top, endPoint: .bottom)
    }
}

extension CollapsingSheetScroll where Leading == EmptyView, Trailing == EmptyView {
    /// With no buttons in its header.
    init(
        title: String,
        smallCaption: String? = nil,
        smallTitle: String? = nil,
        contentHeight: Binding<CGFloat>? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            smallCaption: smallCaption,
            smallTitle: smallTitle,
            contentHeight: contentHeight,
            leading: { EmptyView() },
            trailing: { EmptyView() },
            content: content
        )
    }
}

/// A blur and nothing else: the system's blur view with the layers that
/// tint it hidden, and its backdrop left with only its Gaussian blur (no
/// saturation or brightness of its own), so what is behind is blurred and
/// keeps its own colours, as if through clear frosted glass.
struct ClearBlur: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = ClearBlurView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {}

    private final class ClearBlurView: UIVisualEffectView {
        override func layoutSubviews() {
            super.layoutSubviews()
            // The first subview is the backdrop that blurs; the rest tint.
            for tint in subviews.dropFirst() { tint.isHidden = true }
            // The backdrop's filters, by name: keep the blur, drop the
            // saturation and brightness that colour it.
            if let backdrop = subviews.first, let filters = backdrop.layer.filters {
                let blurOnly = filters.filter { ($0 as AnyObject).value(forKey: "name") as? String == "gaussianBlur" }
                if blurOnly.count != filters.count, !blurOnly.isEmpty { backdrop.layer.filters = blurOnly }
            }
        }
    }
}

/// The round glass button in a sheet's header, the label of a menu or a
/// button: a `.title3` glyph in a 32pt frame, Beam's.
struct SheetGlassGlyph: View {
    let symbol: String

    var body: some View {
        Image(symbol: symbol)
            .font(.title3)
            .foregroundStyle(Color.starhashPrimaryText)
            .frame(width: 32, height: 32)
            .padding(6)
            .contentShape(Circle())
            .starhashGlass(in: Circle(), interactive: true, tint: .sheetControlTint)
    }
}

// MARK: Rows

/// A solid hairline between a card's rows.
struct SheetDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.sheetDivider)
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
            Text(catalog: label)
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
        Text(catalog: text)
            .font(.sheetBody)
            .foregroundStyle(Color.sheetSecondaryText)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
    }
}

/// A small uppercase label over a card, in the quieter grey.
struct SheetSectionLabel: View {
    let text: String
    /// On a page rather than a sheet (the transaction page). The same grey
    /// either way; kept so callers can say where they are.
    var onPage = false

    init(_ text: String, onPage: Bool = false) {
        self.text = text
        self.onPage = onPage
    }

    var body: some View {
        // From the catalog, then uppercased as drawn: a `String` handed to
        // `Text` is shown verbatim and would stay English in French and
        // Kinyarwanda.
        Text(catalog: text)
            .textCase(.uppercase)
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
    var tint: Color?

    var body: some View {
        Image(symbol: symbol)
            .font(.sheetBody)
            .foregroundStyle(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(Color.starhashPrimaryText))
            .frame(width: 38, height: 38)
            .background(Circle().fill(Color.sheetChip))
            .accessibilityHidden(true)
    }
}

/// A card of short statements, each led by its icon circle: what turning
/// auto-verify off stops, on its question and on its outcome.
struct SheetIconRows: View {
    let rows: [(symbol: String, text: String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { SheetDivider().padding(.leading, 52) }
                HStack(spacing: 14) {
                    SheetIconCircle(symbol: row.symbol)
                    Text(catalog: row.text)
                        .font(.sheetBody)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
        .sheetCard()
    }
}

// MARK: Buttons

/// A sheet's button, Beam's: 50pt, a 16pt semibold label, a gradient fill
/// with no glow. `.sheetPrimary` is the accent, near
/// black with white text (near white with near black in dark mode);
/// `.sheetFilled` is the same fill, for a choice that is not the accent.
struct SheetButtonStyle: ButtonStyle {
    enum Fill {
        case accent
        case filled
        /// Blood red with white words: every delete button in the app
        /// (`DeleteButton`), whatever page or sheet it is on.
        case destructive
        /// Mark as Confirmed: the accent with the page's colour on it.
        case confirm
    }

    var fill: Fill
    /// False for a button the width of its words, centred (Delete All
    /// Data, alone under Settings' cards).
    var fillsWidth = true

    func makeBody(configuration: Configuration) -> some View {
        SheetButtonBody(configuration: configuration, fill: fill, fillsWidth: fillsWidth)
    }
}

/// Every delete button StarHash draws, one design: the blood red capsule
/// with white words and no icon, as every button with words. Menus, swipes
/// and confirmation alerts stay the system's own.
struct DeleteButton: View {
    let title: String
    var fillsWidth = true
    let action: () -> Void

    init(_ title: String, fillsWidth: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.fillsWidth = fillsWidth
        self.action = action
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(catalog: title)
        }
        .buttonStyle(SheetButtonStyle(fill: .destructive, fillsWidth: fillsWidth))
    }
}

private struct SheetButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let fill: SheetButtonStyle.Fill
    let fillsWidth: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.starhashSurface) private var surface

    private var colors: (fill: Color, label: Color) {
        switch fill {
        case .filled:
            return (.sheetFilledButton, .sheetFilledLabel)
        case .accent:
            return (Color.starhashInk.color(scheme: colorScheme, surface: surface), Color.starhashOnInk.color(scheme: colorScheme, surface: surface))
        case .destructive:
            return (.starhashDestructiveButton, .starhashOnDestructive)
        case .confirm:
            return (.confirmButton, .onConfirmButton)
        }
    }

    /// The accent's fills (Filled, the accent, Verify) are lit as every
    /// primary button is; the red keeps its own gradient, and a disabled
    /// button is flat.
    private func surface(_ colors: (fill: Color, label: Color)) -> AnyShapeStyle {
        guard isEnabled else { return AnyShapeStyle(Color.sheetChip) }
        return fill == .destructive ? AnyShapeStyle(colors.fill.gradient) : AnyShapeStyle(.starhashAccentLit)
    }

    var body: some View {
        let colors = colors
        configuration.label
            .font(.sheetHeadline)
            .foregroundStyle(isEnabled ? colors.label : Color.sheetDisabledLabel)
            .multilineTextAlignment(.center)
            .padding(.horizontal, fillsWidth ? 16 : 32)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: 50)
            .background(surface(colors), in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
            .starhashPressHaptic(configuration.isPressed)
    }
}

extension ButtonStyle where Self == SheetButtonStyle {
    static var sheetPrimary: SheetButtonStyle { SheetButtonStyle(fill: .accent) }
    static var sheetFilled: SheetButtonStyle { SheetButtonStyle(fill: .filled) }
    static var sheetDestructive: SheetButtonStyle { SheetButtonStyle(fill: .destructive) }
    static var sheetConfirm: SheetButtonStyle { SheetButtonStyle(fill: .confirm) }
}

/// The quiet choice under a sheet's button: the accent's text colour ("Mark
/// as Failed"), or red for a destructive one ("Turn Off").
struct SheetTextButton: View {
    let title: String
    var role: ButtonRole?
    /// Straight on the page (the transaction page) rather than a sheet.
    /// The same colours either way; kept so callers can say where they are.
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
            Text(catalog: title)
                // Bold when destructive.
                .font(.sheet(14, role == .destructive ? .bold : .semibold, relativeTo: .subheadline))
                .foregroundStyle(role == .destructive
                    ? AnyShapeStyle(Color.starhashDestructive)
                    : AnyShapeStyle(Color.starhashAccentText))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
    }
}
