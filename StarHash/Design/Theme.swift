import SwiftUI
import UIKit

/// StarHash follows the system appearance in the owner's palette: a white
/// page with #F2F3F6 cards in light mode, a #171717 page with #3A3A3A cards
/// in dark, and the green #00D957 as the accent and the brand, plus
/// variations of them where contrast needs one. Text is the near black on
/// the white page and the pale grey on the near black. The green is 1.9:1
/// on white, too faint for words, so it fills (buttons, switches, the
/// chart, the mark) with near-black words on it (9.4:1), and green words in
/// light mode are a deeper shade of it (`brandAccentDeep`, 4.6:1 or more on
/// the page and its cards). On the near black the green itself reads as
/// text (9.4:1 on the page, 6:1 on a card).
///
/// The page and its cards share their text colours in either appearance,
/// so the `SurfaceColor` tokens resolve the same on both; they keep the
/// page and container split for any colour that ever needs it. Each colour
/// resolves per appearance, so nothing else needs to know which mode is on.
extension Color {
    // MARK: The palette, exactly as given

    /// The accent and brand colour, #00D957.
    static let brandAccent = Color(red: 0, green: 217 / 255, blue: 87 / 255)
    /// Light mode's page, #FFFFFF, and its foreground, #F2F3F6: cards,
    /// fields, every container.
    static let brandWhite = Color.white
    static let brandMist = Color(red: 242 / 255, green: 243 / 255, blue: 246 / 255)
    /// Dark mode's page, #171717, and its foreground, #3A3A3A.
    static let brandNight = Color(white: 23 / 255)
    static let brandCharcoal = Color(white: 58 / 255)
    /// Text on the near black and the grey of light mode's quieter words.
    static let brandPaper = Color(white: 244 / 255)
    static let brandGrey = Color(white: 97 / 255)

    /// The status hues: yellow for a payment still pending, red for money
    /// out, a failed payment and anything that deletes. Money in and a
    /// confirmed payment are the accent.
    static let brandYellow = Color(red: 242 / 255, green: 187 / 255, blue: 7 / 255)
    static let brandRed = Color(red: 243 / 255, green: 98 / 255, blue: 9 / 255)

    /// The accent deepened for words and thin marks on white and on the
    /// light cards: 5.1:1 on the page, 4.6:1 on #F2F3F6.
    static let brandAccentDeep = Color(red: 0, green: 127 / 255, blue: 55 / 255)

    // MARK: Pages

    /// Screen background: white, or the near black.
    static let starhashBackground = Color(light: .brandWhite, dark: .brandNight)
    /// Pay's background, the same as every page's.
    static let starhashPayBackground = Color.starhashBackground
    /// Cards, list rows, the chart panel, fields: the owner's foreground,
    /// #F2F3F6 on white and #3A3A3A on the near black.
    static let starhashCard = Color(light: .brandMist, dark: .brandCharcoal)
    /// Controls sitting on a card (icon tiles, date pill, text fields):
    /// white on the light card, a step lighter than the dark one.
    static let starhashCardRaised = Color(light: .brandWhite, dark: .init(white: 76 / 255))
    /// Hairlines between rows.
    static let starhashSeparator = Color(light: .brandNight.opacity(0.1), dark: .brandPaper.opacity(0.14))
    /// Hairlines between the rows of a settings list.
    static let starhashListSeparator = Color(light: .brandNight.opacity(0.1), dark: .brandPaper.opacity(0.12))

    // MARK: Text

    /// The near black on white and on the light cards (17:1), the pale
    /// grey on the near black and on its cards (16:1, 9.5:1).
    static let starhashPrimaryText = SurfaceColor(light: .brandNight, dark: .brandPaper)
    /// The quieter text. Light: the palette's grey (6.2:1 on white, 5.6:1
    /// on #F2F3F6). Dark: a grey lifted from it, which is under 3:1 on the
    /// near black (7.4:1 on the page, 4.7:1 on #3A3A3A).
    static let starhashSecondaryText = SurfaceColor(light: .brandGrey, dark: .init(white: 166 / 255))
    /// Placeholders and muted marks, 3:1 or more on the page and on cards.
    static let starhashTertiaryText = SurfaceColor(light: .init(white: 0.52), dark: .init(white: 138 / 255))
    /// Section titles and small print.
    static let starhashCaptionText = Color.starhashSecondaryText
    /// Money going out and destructive actions as words and arrows: on
    /// white a deeper shade of the red (4.7:1), since the red is 3.2:1
    /// there; on the dark cards a lighter one (4.9:1), since the red is
    /// 3.5:1 on #3A3A3A.
    static let starhashDestructive = Color(
        light: .init(red: 201 / 255, green: 74 / 255, blue: 0),
        dark: .init(red: 1, green: 138 / 255, blue: 76 / 255)
    )
    /// Buy's call buttons, the one glass left on Buy: Liquid Glass tinted
    /// the accent, with a near-black phone on it (9.4:1).
    static let callGlassTint = Color.brandAccent.opacity(0.92)
    static let callSolidFill = Color.clear
    static let callGlyph = Color.brandNight
    /// The period control's lens on the clear glass: a faint veil of the
    /// text colour, as the system's own selection reads on white.
    static let segmentedLens = Color(light: .brandNight.opacity(0.07), dark: .white.opacity(0.14))
    static let segmentedLensEdge = Color(light: .brandNight.opacity(0.08), dark: .white.opacity(0.18))
    /// A payment still waiting for its SMS: the yellow, filled behind a
    /// pending badge with near-black words on it (10:1), in either
    /// appearance.
    static let starhashUrgent = Color.brandYellow
    static let starhashOnUrgent = Color.brandNight
    /// The yellow as words (Pending on a transaction's page): itself on the
    /// near black (10:1), a deep amber on white (5.3:1), where the yellow is
    /// 1.8:1.
    static let starhashUrgentText = Color(light: .init(red: 138 / 255, green: 101 / 255, blue: 0), dark: .brandYellow)
    /// A delete button's fill (Delete All Data, Delete Transaction): the
    /// red, in either appearance, with near-black words on it (5.6:1;
    /// white is 3.2:1).
    static let starhashDestructiveButton = Color.brandRed
    static let starhashOnDestructive = Color.brandNight
    /// Red as text straight on the page, the same as on a card.
    static let starhashDestructiveOnPage = Color.starhashDestructive
    /// Money coming in and a confirmed payment: the accent. Its deeper
    /// shade on white and the light cards (5.1:1, 4.6:1), the accent itself
    /// on the near black and its cards (9.4:1, 6:1).
    static let starhashIncoming = SurfaceColor(light: .brandAccentDeep, dark: .brandAccent)
    /// Drawn on `starhashIncoming` as a fill (the verified tick): white on
    /// the deep green (5.1:1), the near black on the accent (9.4:1).
    static let starhashOnIncoming = SurfaceColor(light: .white, dark: .brandNight)

    // MARK: Text on Pay

    /// Pay's text, the same as every page's.
    static let payPrimaryText = Color(light: .brandNight, dark: .brandPaper)
    static let paySecondaryText = Color(light: .brandGrey, dark: .init(white: 166 / 255))
    /// The amount's zero, a placeholder: 3:1, as large text needs.
    static let payPlaceholderText = Color(light: .init(white: 0.52), dark: .init(white: 138 / 255))
    /// Pay's primary button: the accent with near-black words (9.4:1), as
    /// every primary button.
    static let payButtonFill = Color.brandAccent
    static let payButtonLabel = Color.brandNight
    /// Glass on Pay: clear, as on every page now the page is white.
    static let payGlassTint = Color.clear
    /// The pressed digit's flash as it lifts: the accent.
    static let payKeypadFlash = Color.brandAccent
    /// Glass on any page: clear.
    static let starhashGlassTint = Color.clear
    /// Pills and recipient tiles on Pay, and the primary button there
    /// when disabled: the cards' foreground.
    static let payWash = Color(light: .brandMist, dark: .brandCharcoal)

    // MARK: The accent

    /// The accent as a fill: primary buttons, chart bars, a filled check.
    static let starhashInk = SurfaceColor(light: .brandAccent, dark: .brandAccent)
    /// Text and glyphs drawn on `starhashInk`: the near black (9.4:1).
    static let starhashOnInk = SurfaceColor(light: .brandNight, dark: .brandNight)
    /// The accent as text or a thin mark (a chosen check): the deeper
    /// green on white, the accent on the near black.
    static let starhashAccentText = SurfaceColor(light: .brandAccentDeep, dark: .brandAccent)
    /// The accent as a graphic that has to stand out (a selection ring,
    /// progress): the accent itself.
    static let starhashAccentGraphic = SurfaceColor(light: .brandAccent, dark: .brandAccent)
    /// A switched-on toggle: the accent, its white knob on it.
    static let starhashSwitchOn = Color.brandAccent

    /// The StarHash mark's star, drawn bare: the accent.
    static let starhashMarkGlyph = SurfaceColor(light: .brandAccent, dark: .brandAccent)

    /// Letters a search matched: the deeper green on a pale wash of the
    /// accent, and the accent on the near black.
    static let pickerMatch = SurfaceColor(light: .brandAccentDeep, dark: .brandAccent)
    static let pickerMatchBackground = Color(light: .brandAccent.opacity(0.16), dark: .clear)

    /// Sheets: the solid surface cards sit on (the foreground, as every
    /// card), the grey of secondary text, and the fill of a filled button
    /// that is not the accent.
    static let sheetSurface = Color(light: .brandMist, dark: .brandCharcoal)
    static let sheetSecondaryText = Color.starhashSecondaryText
    /// Small fills inside a sheet (icon circles, a monogram tile, a pill, a
    /// disabled button): a step deeper than the cards.
    static let sheetChip = Color(light: .init(red: 228 / 255, green: 230 / 255, blue: 235 / 255), dark: .init(white: 76 / 255))
    /// The glass of a sheet's header buttons (close, confirm, Edit): the
    /// cards' colour in light mode, so they read as the sheet's own; the
    /// usual clear glass in dark.
    static let sheetControlTint = Color(light: .brandMist, dark: .clear)
    /// Text and marks straight on a sheet, with nothing behind them (a
    /// title, a hero name, a label, a text button): the sheet's own text
    /// colour.
    static let sheetBrandText = SurfaceColor(light: .brandNight, dark: .brandPaper)
    static let sheetFilledButton = Color(light: .brandNight, dark: .brandPaper)
    /// A disabled sheet button's label, on its `sheetChip` fill.
    static let sheetDisabledLabel = Color(light: .brandGrey, dark: .init(white: 166 / 255))
    /// Verify's fill and words: the accent with the near black on it
    /// (9.4:1), in either appearance.
    static let confirmButton = Color.brandAccent
    static let onConfirmButton = Color.brandNight
    /// The label on `sheetFilledButton`.
    static let sheetFilledLabel = Color(light: .white, dark: .brandNight)
    /// A sheet's background. Light: solid white. Dark: the page colour let
    /// mostly through the glass.
    static let sheetGlassTint = Color(light: .white, dark: .brandNight.opacity(0.6))
    /// The tab bar's lens under the page showing: a veil of the near black
    /// over the clear glass on white, of white on the dark glass. Its rim
    /// is light along the top and dark down the sides, as glass's is.
    static let tabBarLens = Color(light: .brandNight.opacity(0.07), dark: .brandPaper.opacity(0.16))
    static let tabBarLensEdgeLight = Color(light: .white.opacity(0.8), dark: .white.opacity(0.22))
    static let tabBarLensEdgeDark = Color(light: .brandNight.opacity(0.1), dark: .black.opacity(0.3))
    /// The note sheets' background: solid white in light mode and the
    /// page's own near black in dark, so the note reads as a page.
    static let noteSheetBackground = Color(light: .white, dark: .brandNight)
    /// The dotted line between a sheet card's rows.
    static let sheetDivider = Color(light: .brandNight.opacity(0.22), dark: .brandPaper.opacity(0.22))

    /// A profile without a photo: the cards' foreground behind a person in
    /// the quieter grey.
    static let profilePhotoFill = Color.starhashCard
    static let profilePhotoGlyph = Color.starhashTertiaryText

    /// The carriers' own colours: their logos, and the rings round the
    /// chosen logo on onboarding's carrier step. StarHash's buttons are the
    /// accent whichever carrier pays.
    static let starhashMTN = Color(red: 1, green: 203 / 255, blue: 5 / 255)
    static let starhashOnMTN = Color(white: 0.08)
    static let starhashAirtel = Color(red: 228 / 255, green: 0, blue: 0)
    static let starhashOnAirtel = Color.white

    /// The close (xmark) glyph: grey and lighter in weight than the other
    /// header glyphs (back, add, confirm).
    static let starhashCloseGlyph = Color.starhashSecondaryText

    // MARK: Widgets

    /// The widgets sit on the Home Screen's wallpaper: white in light mode
    /// and the near black in dark, as the app's pages.
    static let widgetCard = Color(light: .white, dark: .brandNight)
    /// Words on the widgets: the near black on white (17:1), the pale grey
    /// on the near black (16:1).
    static let widgetText = Color(light: .brandNight, dark: .brandPaper)
    /// The widgets' symbols: the accent.
    static let widgetAccent = Color.brandAccent

    /// One colour per appearance, resolved by the system whenever the
    /// appearance changes.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// What a view sits on: the page, or a container on it. Every text and
/// accent colour is the same on both now that the page is white, but
/// containers still say which they are, for any colour that comes to need
/// the difference.
enum StarHashSurface {
    /// Straight on the page, or on glass over it.
    case page
    /// Inside a card, a sheet, the Total card or any other container.
    case container
}

extension EnvironmentValues {
    /// Set to `.container` by every container.
    @Entry var starhashSurface: StarHashSurface = .page
}

/// A colour that resolves against the appearance and what it sits on:
/// light mode's page, light mode's containers, and dark mode. Use it as any
/// shape style; where a plain `Color` is needed, `color(in:)` resolves it.
struct SurfaceColor: ShapeStyle, Hashable {
    let page: Color
    let container: Color
    let dark: Color

    init(page: Color, container: Color, dark: Color) {
        self.page = page
        self.container = container
        self.dark = dark
    }

    /// The same colour on the page and in a container.
    init(light: Color, dark: Color) {
        self.init(page: light, container: light, dark: dark)
    }

    func resolve(in environment: EnvironmentValues) -> Color {
        color(in: environment)
    }

    /// The colour for `environment`'s appearance and surface.
    func color(in environment: EnvironmentValues) -> Color {
        if environment.colorScheme == .dark { return dark }
        return environment.starhashSurface == .container ? container : page
    }

    /// The colour inside a container, for the places that are always one
    /// (a UIKit sheet, a widget).
    var inContainer: Color { Color(light: container, dark: dark) }

    /// The colour on the page, for UIKit pieces drawn over it (navigation
    /// bar titles).
    var onPage: Color { Color(light: page, dark: dark) }
}

extension SurfaceColor {
    // The tokens again, for implicit member syntax where a SurfaceColor is
    // expected.
    static var starhashPrimaryText: SurfaceColor { Color.starhashPrimaryText }
    static var starhashSecondaryText: SurfaceColor { Color.starhashSecondaryText }
    static var starhashTertiaryText: SurfaceColor { Color.starhashTertiaryText }
    static var starhashIncoming: SurfaceColor { Color.starhashIncoming }
    static var starhashOnIncoming: SurfaceColor { Color.starhashOnIncoming }
    static var starhashInk: SurfaceColor { Color.starhashInk }
    static var starhashOnInk: SurfaceColor { Color.starhashOnInk }
    static var starhashAccentText: SurfaceColor { Color.starhashAccentText }
    static var starhashMarkGlyph: SurfaceColor { Color.starhashMarkGlyph }
    static var pickerMatch: SurfaceColor { Color.pickerMatch }
    static var sheetBrandText: SurfaceColor { Color.sheetBrandText }
    static var starhashCaptionText: SurfaceColor { Color.starhashCaptionText }
    static var starhashAccentGraphic: SurfaceColor { Color.starhashAccentGraphic }
    static var sheetSecondaryText: SurfaceColor { Color.sheetSecondaryText }
    static var starhashCloseGlyph: SurfaceColor { Color.starhashCloseGlyph }
}

extension View {
    /// Marks this view as a container's content, so `SurfaceColor`s inside
    /// it take their container colours.
    func starhashContainerSurface() -> some View {
        environment(\.starhashSurface, .container)
    }
}

enum StarHashMetrics {
    static let screenPadding: CGFloat = 16
    static let cardRadius: CGFloat = 26
    static let rowRadius: CGFloat = 24
    static let primaryButtonHeight: CGFloat = 58
    /// Every page's title, in the system bar or drawn by the page: 21pt
    /// bold, a size up and a weight up on the system bar's 17 semibold.
    static let pageTitleSize: CGFloat = 21
}

extension Font {
    // Text is set in Space Grotesk, the app's typeface (a variable font,
    // weights 300 to 700). Use `starhash(_:weight:)` where a text style
    // fits and `starhashFont(_:weight:)` for an exact size, never
    // Font.system, so the size still follows Dynamic Type. SF Symbols keep
    // .system sizes.
    //
    // The weights follow GO Club's, measured from its screens: text is
    // medium (500) unless it says otherwise, buttons semibold, headings and
    // numbers bold, and large headings tighten (`StarHashTracking`).

    /// The typeface's family name, as registered from `UIAppFonts`.
    static let starhashFamily = "Space Grotesk"

    /// Space Grotesk at a text style's size, scaling with it: medium, and
    /// headline semibold, unless told otherwise.
    static func starhash(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        .custom(starhashFamily, size: style.starhashDefaultSize, relativeTo: style)
            .weight(weight ?? (style == .headline ? .semibold : .medium))
    }

    /// Space Grotesk at a size that never scales, for the onboarding
    /// pictures, which are drawn at one size like an image.
    static func starhashFixed(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom(starhashFamily, fixedSize: size).weight(weight)
    }

    /// Big titles on a page (Auto-verify's steps): Title 1 bold, 28pt at
    /// the default text size. Pair it with `StarHashTracking.display(28)`.
    static let starhashTitle = Font.starhash(.title, weight: .bold)
}

/// How much large headings tighten, after GO Club's: not at all up to
/// 24pt, then more as they grow, to 2% of the size from 40pt. Numbers keep
/// their spacing, as GO Club's do; pass `tracking: 0` for them.
enum StarHashTracking {
    static func display(_ size: CGFloat) -> CGFloat {
        let amount = min(max((size - 24) / 16, 0), 1) * 0.02
        return -size * amount
    }

    /// Whether a weight is heavy enough to tighten.
    static func tightens(_ weight: Font.Weight) -> Bool {
        [.semibold, .bold, .heavy, .black].contains(weight)
    }
}

extension View {
    /// An exact design size that still follows Dynamic Type: `size` at the
    /// default text size, scaled like `style` at every other size. Use this
    /// instead of `.font(.system(size:))` for any text.
    /// `tracking` nil tightens a large semibold or bold heading as
    /// `StarHashTracking` says; numbers pass 0.
    func starhashFont(
        _ size: CGFloat,
        weight: Font.Weight = .medium,
        design: Font.Design = .default,
        relativeTo style: Font.TextStyle? = nil,
        tracking: CGFloat? = nil
    ) -> some View {
        modifier(ScaledSystemFont(size: size, weight: weight, design: design, style: style ?? .starhashNearest(to: size), tracking: tracking))
    }
}

private struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design
    private let tracking: CGFloat?

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, style: Font.TextStyle, tracking: CGFloat?) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.design = design
        self.tracking = tracking
    }

    func body(content: Content) -> some View {
        // Monospaced stays the system's, for codes typed digit by digit.
        if design == .monospaced {
            content.font(.system(size: size, weight: weight, design: design))
        } else {
            content
                .font(.custom(Font.starhashFamily, fixedSize: size).weight(weight))
                .tracking(tracking ?? (StarHashTracking.tightens(weight) ? StarHashTracking.display(size) : 0))
        }
    }
}

extension Font.TextStyle {
    /// The style's size at the default text size, as the system sets it.
    var starhashDefaultSize: CGFloat {
        switch self {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }

    /// The text style whose default size is closest to `size`, so a custom
    /// size scales at the same rate as the text around it.
    static func starhashNearest(to size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: .caption2
        case ..<12.5: .caption
        case ..<14: .footnote
        case ..<15.5: .subheadline
        case ..<16.5: .callout
        case ..<18.5: .body
        case ..<21: .title3
        case ..<25: .title2
        case ..<31: .title
        default: .largeTitle
        }
    }
}

extension Image {
    /// A destructive menu item's icon, in the same red as its words. Menus
    /// draw an item's icon as a template in the text colour, so a red
    /// "Delete" sat beside a black bin; this one is coloured beforehand,
    /// in the system red the menu gives the words (light and dark alike),
    /// and kept as drawn.
    static func destructiveMenuIcon(_ systemName: String) -> Image {
        guard let symbol = UIImage(systemName: systemName) else { return Image(systemName: systemName) }
        return Image(uiImage: symbol.withTintColor(.systemRed, renderingMode: .alwaysOriginal))
    }
}

extension Text {
    /// Words decided at run time (a title handed to a shared component),
    /// looked up in the string catalog by their English, so they show in
    /// the app's language; shown as they are when the catalog has none.
    init(catalog text: String) {
        self.init(LocalizedStringKey(text))
    }
}

/// A destructive menu item with its icon red to match its words: "Delete"
/// in a long-press menu.
struct DestructiveMenuLabel: View {
    let title: String
    var systemImage = "trash"

    init(_ title: String, systemImage: String = "trash") {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(catalog: title)
        } icon: {
            Image.destructiveMenuIcon(systemImage)
        }
    }
}
