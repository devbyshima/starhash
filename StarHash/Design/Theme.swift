import SwiftUI
import UIKit

/// StarHash follows the system appearance in four colours: the brand blue
/// #3020FE, the pale grey #F4F4F4, the near black #171717 and the grey
/// #616161, plus variations of them where contrast needs one. Light: every
/// page is the blue, as Cash App is its green, with white text on it and
/// white cards with near-black text (the near black is 2.4:1 on the blue,
/// white 7.6:1). Dark: every page is the near black, with lifted charcoal
/// cards, pale grey text and the blue as the accent, lifted for text
/// (`brandBlueLift`), since the blue itself is 2.4:1 on the near black.
///
/// Light mode's text and accent differ between the blue page and the white
/// containers on it, so those tokens are `SurfaceColor`s: they resolve
/// against `EnvironmentValues.starhashSurface`, which every container sets
/// to `.container` (`starhashContainer`, the Total card, sheets and their
/// cards). Each colour resolves per appearance, so nothing else needs to
/// know which mode is on.
extension Color {
    // MARK: The palette, exactly as given

    static let brandBlue = Color(red: 48 / 255, green: 32 / 255, blue: 254 / 255)
    static let brandPaper = Color(white: 244 / 255)
    static let brandNight = Color(white: 23 / 255)
    static let brandGrey = Color(white: 97 / 255)

    /// The three status hues, as given: green for money in and a confirmed
    /// payment, yellow for one still pending, red for money out, a failed
    /// payment and anything that deletes.
    static let brandGreen = Color(red: 5 / 255, green: 208 / 255, blue: 121 / 255)
    static let brandYellow = Color(red: 242 / 255, green: 187 / 255, blue: 7 / 255)
    static let brandRed = Color(red: 243 / 255, green: 98 / 255, blue: 9 / 255)

    /// The blue lifted for text and thin marks on the near black: 5.6:1 on
    /// the page, its cards and its sheets, and a white switch knob on it
    /// still 3.2:1.
    static let brandBlueLift = Color(red: 138 / 255, green: 128 / 255, blue: 1)

    // MARK: Pages

    /// Screen background: the blue, or the near black.
    static let starhashBackground = Color(light: .brandBlue, dark: .brandNight)
    /// Pay's background, the same as every page's.
    static let starhashPayBackground = Color.starhashBackground
    /// Cards, list rows, the chart panel: white on the blue, and the
    /// near black lifted a step so a card reads on its page.
    static let starhashCard = Color(light: .white, dark: .init(white: 21 / 255))
    /// Controls sitting on a card (icon tiles, date pill, text fields).
    static let starhashCardRaised = Color(light: .brandPaper, dark: .init(white: 52 / 255))
    /// Hairlines between rows.
    static let starhashSeparator = Color(light: .brandNight.opacity(0.1), dark: .brandPaper.opacity(0.12))
    /// Hairlines between the rows of a settings list, a little fainter on
    /// dark cards; light mode is the same as `starhashSeparator`.
    static let starhashListSeparator = Color(light: .brandNight.opacity(0.1), dark: .brandPaper.opacity(0.08))

    // MARK: Text

    /// Light: white on the blue page (7.6:1), the near black in a
    /// container. Dark: the pale grey.
    static let starhashPrimaryText = SurfaceColor(page: .white, container: .brandNight, dark: .brandPaper)
    /// The quieter text. Light: white at 80% on the blue (5.3:1), the near
    /// black at 80% in a container (9.5:1 on white). Dark: a grey lifted
    /// from #616161, which is under 3:1 on the near black (7.4:1 on the
    /// page, 4.5:1 or more on its cards and glass).
    static let starhashSecondaryText = SurfaceColor(
        page: .white.opacity(0.8), container: .brandNight.opacity(0.8), dark: .init(white: 166 / 255)
    )
    /// Placeholders and muted marks, 3:1 or more on the blue and on cards.
    static let starhashTertiaryText = SurfaceColor(
        page: .white.opacity(0.62), container: .brandNight.opacity(0.6), dark: .init(white: 117 / 255)
    )
    /// Section titles and the small print under settings cards.
    static let starhashCaptionText = Color.starhashSecondaryText
    /// Money going out and destructive actions, on cards and sheets: the
    /// red itself on the near black (5.6:1), and on white a deeper shade of
    /// it for words and arrows (4.7:1), since the red is 3.2:1 there.
    static let starhashDestructive = Color(light: .init(red: 201 / 255, green: 74 / 255, blue: 0), dark: .brandRed)
    /// Buy's call buttons: the blue with a white phone (7.6:1), solid in
    /// light mode, where glass over the blue page would only darken it, and
    /// glass in dark.
    static let callGlassTint = Color(light: .brandBlue, dark: .brandBlue.opacity(0.9))
    static let callSolidFill = Color(light: .brandBlue, dark: .clear)
    static let callGlyph = Color.white
    /// The period control's lens on the page's tinted glass: white, faint,
    /// with a bright rim, as the system's own selection reads.
    static let segmentedLens = Color(light: .white.opacity(0.3), dark: .white.opacity(0.14))
    static let segmentedLensEdge = Color(light: .white.opacity(0.5), dark: .white.opacity(0.18))
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
    /// Red as text straight on the page: no red reaches 4.5:1 on the blue
    /// but a pale one of the same hue (5.0:1); the red itself on the near
    /// black.
    static let starhashDestructiveOnPage = Color(light: .init(red: 1, green: 196 / 255, blue: 168 / 255), dark: .brandRed)
    /// Money coming in: the green, on received amounts, the incoming arrow
    /// and a confirmed status. Itself on the blue page (3.7:1, its large
    /// amounts and marks) and the near black (8.8:1); on white a deeper
    /// shade of it (4.6:1), where the green is 2:1.
    static let starhashIncoming = SurfaceColor(
        page: .brandGreen,
        container: .init(red: 0, green: 135 / 255, blue: 77 / 255),
        dark: .brandGreen
    )
    /// Drawn on the green (the verified tick): the near black (8.8:1).
    static let starhashOnIncoming = SurfaceColor(page: .brandNight, container: .white, dark: .brandNight)

    // MARK: Text on Pay

    /// Pay's text: white on the blue (7.6:1), pale grey on the near black.
    static let payPrimaryText = Color(light: .white, dark: .brandPaper)
    /// Pay's quieter text: white let through to the blue at 5.3:1.
    static let paySecondaryText = Color(light: .white.opacity(0.8), dark: .init(white: 166 / 255))
    /// The amount's zero, a placeholder: 3:1, as large text needs.
    static let payPlaceholderText = Color(light: .white.opacity(0.62), dark: .init(white: 117 / 255))
    /// Pay's primary button: on the blue it turns over, white with
    /// near-black text (17:1), as every white button's; on the near black
    /// it is the blue with white text.
    static let payButtonFill = Color(light: .white, dark: .brandBlue)
    static let payButtonLabel = Color(light: .brandNight, dark: .white)
    /// Glass on the blue, tinted a deeper blue so it reads as a darker
    /// shade of the page rather than a pale hole; untinted on the near
    /// black.
    static let payGlassTint = Color(light: Color(red: 22 / 255, green: 10 / 255, blue: 150 / 255).opacity(0.5), dark: .clear)
    /// The pressed digit's flash as it lifts: the text colour itself on
    /// the blue, the lifted blue on the near black.
    static let payKeypadFlash = Color(light: .white, dark: .brandBlueLift)
    /// Glass on any page: Pay's deep-blue tint in light mode.
    static let starhashGlassTint = Color.payGlassTint
    /// Pills and recipient tiles on Pay, and the primary button there
    /// when disabled.
    static let payWash = Color(light: .white.opacity(0.16), dark: .brandPaper.opacity(0.08))

    // MARK: The accent

    /// The accent as a fill: primary buttons, chart bars, a filled check.
    /// Light: white on the blue page, as a blue button would vanish into
    /// it, and the blue in a container. Dark: the blue.
    static let starhashInk = SurfaceColor(page: .white, container: .brandBlue, dark: .brandBlue)
    /// Text and glyphs drawn on `starhashInk`: the near black on white
    /// (17:1), as every white button's words are, and white on the blue
    /// (7.6:1).
    static let starhashOnInk = SurfaceColor(page: .brandNight, container: .white, dark: .white)
    /// The accent as text or a thin mark (a chosen check): white on the
    /// blue page, the blue in a light container, the lifted blue on the
    /// near black.
    static let starhashAccentText = SurfaceColor(page: .white, container: .brandBlue, dark: .brandBlueLift)
    /// The accent as a graphic that has to read against the page (a
    /// selection ring, progress): the same.
    static let starhashAccentGraphic = Color.starhashAccentText
    /// A switched-on toggle: the brand blue itself, on a white card (7.6:1)
    /// and on a dark one, where its white knob reads on it (7.6:1).
    static let starhashSwitchOn = Color.brandBlue

    /// The StarHash mark's star, drawn bare. Light: white on the blue page,
    /// the blue on white. Dark: the blue.
    static let starhashMarkGlyph = SurfaceColor(page: .white, container: .brandBlue, dark: .brandBlue)

    /// Letters a search matched: white on the blue, picked out by
    /// `pickerMatchBackground`, and the lifted blue on the near black.
    static let pickerMatch = SurfaceColor(page: .white, container: .brandBlue, dark: .brandBlueLift)
    static let pickerMatchBackground = Color(light: .white.opacity(0.24), dark: .clear)

    /// Sheets: the solid surface cards sit on (on the white sheet, a white
    /// with a breath of the brand blue in it, the near black on it at 16:1;
    /// or the near black lifted a little less than a card), the grey of
    /// secondary text, and the fill of a filled button that is not the
    /// accent.
    static let sheetSurface = Color(light: .init(red: 240 / 255, green: 239 / 255, blue: 1), dark: .init(white: 28 / 255))
    static let sheetSecondaryText = Color.starhashSecondaryText
    /// Small fills inside a sheet (icon circles, a monogram tile, a pill, a
    /// disabled button): a step deeper than the cards, still near white and
    /// still blue, in light mode; a faint veil in dark mode.
    static let sheetChip = Color(light: .init(red: 224 / 255, green: 221 / 255, blue: 1), dark: .brandPaper.opacity(0.1))
    /// The glass of a sheet's header buttons (close, confirm, Edit): the
    /// cards' near-white blue in light mode, so they read as the sheet's
    /// own; the usual clear glass in dark.
    static let sheetControlTint = Color(light: .init(red: 240 / 255, green: 239 / 255, blue: 1), dark: .clear)
    /// Black glass, every container in dark mode: the near black as glass
    /// (the dark-mode Total card).
    static let blackGlassTint = Color.brandNight.opacity(0.6)
    /// Text and marks straight on a sheet, with nothing behind them (a
    /// title, a hero name, a label, a text button). Dark: the lifted blue
    /// (5.4:1 on the sheet). Light: the near black (17:1 on the white
    /// sheet), as the rest of the sheet's text is, and white where the
    /// same piece sits on the blue page.
    static let sheetBrandText = SurfaceColor(page: .white, container: .brandNight, dark: .brandBlueLift)
    static let sheetFilledButton = Color(light: .brandNight, dark: .brandPaper)
    /// A disabled sheet button's label, on its `sheetChip` fill.
    static let sheetDisabledLabel = Color(light: .brandNight.opacity(0.6), dark: .init(white: 166 / 255))
    /// Verify's fill and words: the green with the near black on it (8.8:1),
    /// in either appearance.
    static let confirmButton = Color.brandGreen
    static let onConfirmButton = Color.brandNight
    /// The label on `sheetFilledButton`.
    static let sheetFilledLabel = Color(light: .white, dark: .init(white: 28 / 255))
    /// A sheet's background. Light: solid white, the founder's pick. Dark:
    /// the page colour let mostly through the glass.
    static let sheetGlassTint = Color(light: .white, dark: .brandNight.opacity(0.6))
    /// The tab bar's lens under the page showing: white over the glass on
    /// the blue, lighter in dark mode so it still reads on the dark glass.
    /// Its rim is light along the top and dark down the sides, as glass's
    /// is.
    static let tabBarLens = Color(light: .white.opacity(0.22), dark: .brandPaper.opacity(0.16))
    static let tabBarLensEdgeLight = Color(light: .white.opacity(0.6), dark: .white.opacity(0.22))
    static let tabBarLensEdgeDark = Color(light: .brandNight.opacity(0.22), dark: .black.opacity(0.3))
    /// Over sheet-coloured glass (the recipient screen's Total, Balance,
    /// Buy's codes) in light mode: Settings' card white, solid, since
    /// white-tinted glass still lets the blue page and its highlights
    /// through on a device. Dark keeps the glass, tinted `sheetGlassTint`.
    static let sheetSolidFill = Color(light: .white, dark: .clear)
    /// The note sheets' background: solid white in light mode, as
    /// `sheetSolidFill`, and the page's own near black in dark, so the note
    /// reads as a page.
    static let noteSheetBackground = Color(light: .white, dark: .brandNight)
    /// The dotted line between a sheet card's rows.
    static let sheetDivider = Color(light: .brandNight.opacity(0.22), dark: .brandPaper.opacity(0.22))

    /// A profile's face (`AvatarView`): a white face with its features cut
    /// through to what is behind it, on a faint ring. The blue behind the
    /// reference's faces is its page, not part of the face: on the near
    /// black the features are the near black and the ring a faint white.
    /// In a light container the ring is the sheets' pale blue chip.
    static let avatarRing = SurfaceColor(
        page: .white.opacity(0.18), container: .init(red: 224 / 255, green: 221 / 255, blue: 1), dark: .white.opacity(0.1)
    )
    static let avatarFace = Color.white
    static let avatarFeature = SurfaceColor(page: .brandBlue, container: .brandBlue, dark: .brandNight)
    /// The faint rings and mark behind the top of Profile.
    static let profileBackdrop = Color.white.opacity(0.15)

    /// Reports, after GO's "Carbon" screens: the day bars quiet on the
    /// page and the biggest day lit in the yellow; the dot beside the month
    /// against the one before, red when more went out and green when less.
    static let reportBar = Color(light: .white.opacity(0.26), dark: .brandPaper.opacity(0.16))
    static let reportHighlight = Color.brandYellow
    static let reportUp = Color.brandRed
    static let reportDown = Color.brandGreen

    /// The carriers' own colours: their logos, and in dark mode the rings
    /// round the chosen logo on onboarding's carrier step (light mode draws
    /// both in white on the blue). StarHash's buttons are the blue whichever
    /// carrier pays.
    static let starhashMTN = Color(red: 1, green: 203 / 255, blue: 5 / 255)
    static let starhashOnMTN = Color(white: 0.08)
    static let starhashAirtel = Color(red: 228 / 255, green: 0, blue: 0)
    static let starhashOnAirtel = Color.white

    /// The close (xmark) glyph: grey and lighter in weight than the other
    /// header glyphs (back, add, confirm).
    static let starhashCloseGlyph = Color.starhashSecondaryText

    // MARK: Widgets

    /// The Buy widget is GO Club's card: white in light mode and the near
    /// black in dark, since it sits on the Home Screen's wallpaper rather
    /// than StarHash's blue page.
    static let widgetCard = Color(light: .white, dark: .brandNight)
    /// Words on the card and its tiles: the near black on white (17:1),
    /// the pale grey on the near black (16:1).
    static let widgetText = Color(light: .brandNight, dark: .brandPaper)
    /// The code tiles: the pale grey on white, a veil on the near black.
    static let widgetChip = Color(light: .brandPaper, dark: .brandPaper.opacity(0.08))
    /// The codes' symbols: the blue on white (7.6:1), the lifted blue on
    /// the near black.
    static let widgetAccent = Color(light: .brandBlue, dark: .brandBlueLift)

    /// One colour per appearance, resolved by the system whenever the
    /// appearance changes.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// What a view sits on, for the colours that differ between the blue page
/// and a white container in light mode.
enum StarHashSurface {
    /// Straight on the page, or on glass over it.
    case page
    /// Inside a card, a sheet, the Total card or any other container.
    case container
}

extension EnvironmentValues {
    /// Set to `.container` by every container, so the text inside it reads
    /// on white in light mode.
    @Entry var starhashSurface: StarHashSurface = .page
}

/// A colour that resolves against the appearance and what it sits on:
/// light mode's page, light mode's containers, and dark mode (where the
/// page and its containers are both near black). Use it as any shape
/// style; where a plain `Color` is needed, `color(in:)` resolves it.
struct SurfaceColor: ShapeStyle, Hashable {
    let page: Color
    let container: Color
    let dark: Color

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
