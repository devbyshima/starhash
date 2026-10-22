import SwiftUI
import UIKit

/// StarHash follows the system appearance in the owner's two greens and
/// variations of them, nothing else: the green #64D27B, the accent and the
/// brand, and the deep green #091D11. Light mode is the green itself as the
/// page, with lighter greens for its cards (#9FE3AD) and the deep green as
/// its text (9.2:1); dark mode is the deep green as the page, lifted a step
/// for its cards (#102B19), with a pale green-white as its text. So in
/// light mode the accent's fills (buttons, switches, the chart, the mark)
/// are the deep green with the green as the words on them, and in dark mode
/// the green with the deep green on it (9.2:1 either way); green words in
/// dark mode are the green itself, and in light mode, where the green is
/// the page, the deep green. Red is the one colour from outside, kept for
/// what deletes and what failed, where a green would say the opposite.
///
/// The page and its cards share their text colours in either appearance,
/// so the `SurfaceColor` tokens resolve the same on both; they keep the
/// page and container split for any colour that ever needs it. Each colour
/// resolves per appearance, so nothing else needs to know which mode is on.
extension Color {
    // MARK: The palette, exactly as given

    /// The accent and brand colour, #64D27B: light mode's page.
    static let brandAccent = Color(red: 100 / 255, green: 210 / 255, blue: 123 / 255)
    /// The deep green, #091D11: light mode's text, dark mode's page, and the
    /// words on the green.
    static let brandForest = Color(red: 9 / 255, green: 29 / 255, blue: 17 / 255)

    // MARK: Variations of the two

    /// Light mode's foreground, the green lightened (#9FE3AD): cards, fields,
    /// every container; and between it and the page (#83DB95) for the
    /// controls on them.
    static let brandLeaf = Color(red: 159 / 255, green: 227 / 255, blue: 173 / 255)
    static let brandShoot = Color(red: 131 / 255, green: 219 / 255, blue: 149 / 255)
    /// Dark mode's foreground, the deep green lifted with the green
    /// (#102B19): cards, fields, every container; and a step further
    /// (#183C23) for the controls on them.
    static let brandMoss = Color(red: 16 / 255, green: 43 / 255, blue: 25 / 255)
    static let brandFern = Color(red: 24 / 255, green: 60 / 255, blue: 35 / 255)
    /// Text on the deep green, a green-white (#F3FBF4), and its quieter
    /// words there (#90A996, 6.9:1).
    static let brandPaper = Color(red: 243 / 255, green: 251 / 255, blue: 244 / 255)
    static let brandPaperQuiet = Color(red: 144 / 255, green: 169 / 255, blue: 150 / 255)
    /// The quieter words on the green page, the deep green let a little of
    /// the green through (#245331, 4.7:1), and placeholders a step further
    /// (#326E41, 3.2:1).
    static let brandGrey = Color(red: 36 / 255, green: 83 / 255, blue: 49 / 255)
    static let brandMuted = Color(red: 50 / 255, green: 110 / 255, blue: 65 / 255)
    /// A payment still waiting for its SMS: a pale wash of the green in
    /// light mode (#D4F2DA), a mid green in dark (#2A5A36), quieter than the
    /// solid fill of a confirmed one.
    static let brandSprout = Color(light: .init(red: 212 / 255, green: 242 / 255, blue: 218 / 255), dark: .init(red: 42 / 255, green: 90 / 255, blue: 54 / 255))

    /// Blood red, #C1121F: delete buttons and failed payments, and a deeper
    /// red (#8E0D17, 5:1) for its words on the green page.
    static let brandRed = Color(red: 193 / 255, green: 18 / 255, blue: 31 / 255)
    static let brandRedDeep = Color(red: 142 / 255, green: 13 / 255, blue: 23 / 255)

    /// The accent deepened (#357444), for the letter on a pale tile.
    static let brandAccentDeep = Color(red: 53 / 255, green: 116 / 255, blue: 68 / 255)

    /// The accent as it fills: the deep green on the green page, the green
    /// on the deep green one; and what is drawn on it, the other.
    static let brandFill = Color(light: .brandForest, dark: .brandAccent)
    static let brandOnFill = Color(light: .brandAccent, dark: .brandForest)

    // MARK: Pages

    /// Screen background: the green, or the deep green.
    static let starhashBackground = Color(light: .brandAccent, dark: .brandForest)
    /// Pay's background, the same as every page's.
    static let starhashPayBackground = Color.starhashBackground
    /// Cards, list rows, the chart panel, fields: the lighter green on the
    /// green, the lifted deep green on the deep green.
    static let starhashCard = Color(light: .brandLeaf, dark: .brandMoss)
    /// Controls sitting on a card (icon tiles, date pill, text fields).
    static let starhashCardRaised = Color(light: .brandShoot, dark: .brandFern)
    /// The line round an outlined card (a transaction's details, Settings'
    /// groups): the cards' hairline, a touch firmer.
    static let starhashOutline = Color(light: .brandForest.opacity(0.16), dark: .brandPaper.opacity(0.13))
    /// Hairlines between rows.
    static let starhashSeparator = Color(light: .brandForest.opacity(0.14), dark: .brandPaper.opacity(0.14))
    /// Hairlines between the rows of a settings list.
    static let starhashListSeparator = Color(light: .brandForest.opacity(0.14), dark: .brandPaper.opacity(0.12))

    // MARK: Text

    /// The deep green on the green page and its cards (9.2:1, 11.8:1), the
    /// green-white on the deep green page and its cards (16.7:1, 14.4:1).
    static let starhashPrimaryText = SurfaceColor(light: .brandForest, dark: .brandPaper)
    /// The quieter text: 4.7:1 or more on either page and its cards.
    static let starhashSecondaryText = SurfaceColor(light: .brandGrey, dark: .brandPaperQuiet)
    /// Placeholders and muted marks, 3:1 or more on the page and on cards.
    static let starhashTertiaryText = SurfaceColor(light: .brandMuted, dark: .init(red: 108 / 255, green: 136 / 255, blue: 116 / 255))
    /// Section titles and small print.
    static let starhashCaptionText = Color.starhashSecondaryText
    /// What failed and destructive actions as words: the deeper red on the
    /// green (5:1), and a lighter red in dark mode (7:1 on the page, 6:1 on
    /// a card), where the blood red is too dark to read.
    static let starhashDestructive = Color(
        light: .brandRedDeep,
        dark: .init(red: 1, green: 123 / 255, blue: 123 / 255)
    )
    /// Buy's call buttons, the one glass left on Buy: Liquid Glass tinted
    /// the accent's fill, with its words' colour for the phone.
    static let callGlassTint = Color.brandFill.opacity(0.92)
    static let callSolidFill = Color.clear
    static let callGlyph = Color.brandOnFill
    /// The period control's lens on the clear glass: a faint veil of the
    /// text colour, as the system's own selection reads.
    static let segmentedLens = Color(light: .brandForest.opacity(0.1), dark: .white.opacity(0.14))
    static let segmentedLensEdge = Color(light: .brandForest.opacity(0.1), dark: .white.opacity(0.18))
    /// A payment still waiting for its SMS: the sprout green behind a
    /// pending badge, with the text colour on it (15:1 in light mode, 7.6:1
    /// in dark), quieter than a confirmed payment's solid fill.
    static let starhashUrgent = Color.brandSprout
    static let starhashOnUrgent = Color(light: .brandForest, dark: .brandPaper)
    /// Pending as words (on a transaction's page): the quieter text, since a
    /// payment still waiting says nothing yet.
    static let starhashUrgentText = Color(light: .brandGrey, dark: .brandPaperQuiet)
    /// Money going out, as an arrow or an amount: the text colour. Red is
    /// kept for what failed or deletes.
    static let starhashOutgoing = SurfaceColor(light: .brandForest, dark: .brandPaper)
    /// A delete button's fill (Delete All Data, Delete Transaction): the
    /// blood red, in either appearance, with white words on it (6.2:1).
    static let starhashDestructiveButton = Color.brandRed
    static let starhashOnDestructive = Color.white
    /// Red as text straight on the page, the same as on a card.
    static let starhashDestructiveOnPage = Color.starhashDestructive
    /// Money coming in and a confirmed payment: the green as words on the
    /// deep green page (9.2:1); on the green page, where green words would
    /// vanish, the deep green, with its arrow saying which way.
    static let starhashIncoming = SurfaceColor(light: .brandForest, dark: .brandAccent)
    /// Drawn on `starhashIncoming` as a fill (the verified tick): the other
    /// green (9.2:1).
    static let starhashOnIncoming = SurfaceColor(light: .brandAccent, dark: .brandForest)

    // MARK: Text on Pay

    /// Pay's text, the same as every page's.
    static let payPrimaryText = Color(light: .brandForest, dark: .brandPaper)
    static let paySecondaryText = Color(light: .brandGrey, dark: .brandPaperQuiet)
    /// The amount's zero, a placeholder: 3:1, as large text needs.
    static let payPlaceholderText = Color(light: .brandMuted, dark: .init(red: 108 / 255, green: 136 / 255, blue: 116 / 255))
    /// Pay's primary button: the accent's fill with its words (9.2:1), as
    /// every primary button.
    static let payButtonFill = Color.brandFill
    static let payButtonLabel = Color.brandOnFill
    /// Glass on Pay: clear, as on every page.
    static let payGlassTint = Color.clear
    /// The pressed digit's flash as it lifts: the accent's fill.
    static let payKeypadFlash = Color.brandFill
    /// Glass on any page: clear.
    static let starhashGlassTint = Color.clear
    /// The soft lift under glass that floats over a list (the recipient
    /// screen's Total), so it parts from the page in light mode; dark
    /// mode's glass reads on its own.
    static let floatingShadow = Color(light: .brandForest.opacity(0.14), dark: .clear)
    /// Balance's glass: a veil of the cards' colour over clear Liquid
    /// Glass, so the capsule stands out on Pay's page in either
    /// appearance.
    static let balanceGlassTint = Color(light: .brandLeaf.opacity(0.8), dark: .brandFern.opacity(0.7))
    /// Pills and recipient tiles on Pay, and the primary button there
    /// when disabled: the cards' foreground.
    static let payWash = Color(light: .brandLeaf, dark: .brandMoss)

    // MARK: The accent

    /// The accent as a fill: primary buttons, chart bars, a filled check.
    static let starhashInk = SurfaceColor(light: .brandForest, dark: .brandAccent)
    /// Text and glyphs drawn on `starhashInk` (9.2:1).
    static let starhashOnInk = SurfaceColor(light: .brandAccent, dark: .brandForest)
    /// The accent as text or a thin mark (a chosen check): the deep green
    /// on the green page, the green on the deep green.
    static let starhashAccentText = SurfaceColor(light: .brandForest, dark: .brandAccent)
    /// The accent as a graphic that has to stand out (a selection ring,
    /// progress).
    static let starhashAccentGraphic = SurfaceColor(light: .brandForest, dark: .brandAccent)
    /// A switched-on toggle: the accent's fill, its white knob on it.
    static let starhashSwitchOn = Color.brandFill

    /// The StarHash mark's star, drawn bare.
    static let starhashMarkGlyph = SurfaceColor(light: .brandForest, dark: .brandAccent)

    /// Letters a search matched: the deep green on a light veil in light
    /// mode, the green in dark.
    static let pickerMatch = SurfaceColor(light: .brandForest, dark: .brandAccent)
    static let pickerMatchBackground = Color(light: .white.opacity(0.4), dark: .clear)

    /// Sheets: the solid surface cards sit on (the foreground, as every
    /// card), the quieter text, and the fill of a filled button that is not
    /// the accent.
    static let sheetSurface = Color(light: .brandLeaf, dark: .brandMoss)
    static let sheetSecondaryText = Color.starhashSecondaryText
    /// Small fills inside a sheet (icon circles, a monogram tile, a pill, a
    /// disabled button): between the sheet and its cards in light mode, a
    /// step lighter than its cards in dark, so they read on the sheet and on
    /// its cards alike.
    static let sheetChip = Color(light: .brandShoot, dark: .init(red: 33 / 255, green: 76 / 255, blue: 45 / 255))
    /// The glass of a sheet's header buttons (close, confirm, Edit): the
    /// cards' colour in light mode, so they read as the sheet's own; the
    /// usual clear glass in dark.
    static let sheetControlTint = Color(light: .brandLeaf, dark: .clear)
    /// Text and marks straight on a sheet, with nothing behind them (a
    /// title, a hero name, a label, a text button): the sheet's own text
    /// colour.
    static let sheetBrandText = SurfaceColor(light: .brandForest, dark: .brandPaper)
    static let sheetFilledButton = Color(light: .brandForest, dark: .brandPaper)
    /// A disabled sheet button's label, on its `sheetChip` fill.
    static let sheetDisabledLabel = Color(light: .brandMuted, dark: .brandPaperQuiet)
    /// Verify's fill and words: the accent's fill with its words (9.2:1).
    static let confirmButton = Color.brandFill
    static let onConfirmButton = Color.brandOnFill
    /// The label on `sheetFilledButton`.
    static let sheetFilledLabel = Color(light: .brandAccent, dark: .brandForest)
    /// A sheet's background: the page's own colour, the green in light mode,
    /// the deep green let mostly through the glass in dark.
    static let sheetGlassTint = Color(light: .brandAccent, dark: .brandForest.opacity(0.6))
    /// The tab bar's lens under the page showing: a veil of the deep green
    /// over the clear glass on the green, of white on the dark glass. Its
    /// rim is light along the top and dark down the sides, as glass's is.
    static let tabBarLens = Color(light: .brandForest.opacity(0.1), dark: .brandPaper.opacity(0.16))
    static let tabBarLensEdgeLight = Color(light: .white.opacity(0.55), dark: .white.opacity(0.22))
    static let tabBarLensEdgeDark = Color(light: .brandForest.opacity(0.14), dark: .black.opacity(0.3))
    /// The note sheets' background: the page's own colour, so the note
    /// reads as a page.
    static let noteSheetBackground = Color(light: .brandAccent, dark: .brandForest)
    /// The developer's note in the brand's colours the other way round from
    /// the page it opens over, so it stands apart in either appearance: the
    /// deep green with the green-white on it over light mode's green page,
    /// the green with the deep green on it over dark mode's deep green; its
    /// button the page's own fill.
    static let noteBrandBackground = Color(light: .brandForest, dark: .brandAccent)
    static let noteBrandText = Color(light: .brandPaper, dark: .brandForest)
    static let noteBrandSecondary = Color(light: .brandPaperQuiet, dark: .brandForest.opacity(0.78))
    static let noteBrandButton = Color(light: .brandAccent, dark: .brandForest)
    static let noteBrandButtonLabel = Color(light: .brandForest, dark: .brandAccent)
    /// The solid line between a card's rows.
    static let sheetDivider = Color(light: .brandForest.opacity(0.14), dark: .brandPaper.opacity(0.13))

    /// A profile without a photo: the cards' foreground behind a person in
    /// the quieter text.
    static let profilePhotoFill = Color.starhashCard
    static let profilePhotoGlyph = Color.starhashTertiaryText

    /// The carriers' own colours: their logos, and the rings round the
    /// chosen logo on onboarding's carrier step. StarHash's buttons are the
    /// accent whichever carrier pays.
    static let starhashMTN = Color(red: 1, green: 203 / 255, blue: 5 / 255)
    static let starhashOnMTN = Color(white: 0.08)
    static let starhashAirtel = Color(red: 228 / 255, green: 0, blue: 0)
    static let starhashOnAirtel = Color.white

    /// The close (xmark) glyph: the quieter text and lighter in weight than
    /// the other header glyphs (back, add, confirm).
    static let starhashCloseGlyph = Color.starhashSecondaryText

    // MARK: Widgets

    /// The widgets sit on the Home Screen's wallpaper in the app's page
    /// colours.
    static let widgetCard = Color(light: .brandAccent, dark: .brandForest)
    /// Words on the widgets: the text colours.
    static let widgetText = Color(light: .brandForest, dark: .brandPaper)
    /// The medium Buy widget's tiles: the cards' colour.
    static let widgetChip = Color(light: .brandLeaf, dark: .brandMoss)
    /// The widgets' symbols: the accent's fill.
    static let widgetAccent = Color.brandFill

    /// One colour per appearance, resolved by the system whenever the
    /// appearance changes.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// What a view sits on: the page, or a container on it. Every text and
/// accent colour is the same on both, but containers still say which they
/// are, for any colour that comes to need the difference.
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
    /// Outlined cards and the action list under them, as the reference's.
    static let outlinedCardRadius: CGFloat = 24
    static let rowRadius: CGFloat = 24
    static let primaryButtonHeight: CGFloat = 58
    /// Every page's title, in the system bar or drawn by the page: 21pt
    /// bold, a size up and a weight up on the system bar's 17 semibold.
    static let pageTitleSize: CGFloat = 21
}

extension Font {
    // Text, titles and numbers are set in Space Grotesk, the app's typeface
    // (a variable font, weights 300 to 700). Use `starhash(_:weight:)` where a text style fits,
    // `starhashFont(_:weight:)` for an exact size and `starhashNumber` for
    // a number, never Font.system, so the size still follows Dynamic Type.
    // SF Symbols keep .system sizes.
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

    /// Space Grotesk for numbers (amounts, the keypad, codes, phone
    /// numbers), with figures all of one width so a total does not shift as
    /// it changes: `size` at the default text size, scaling like the style
    /// nearest it.
    static func starhashNumber(_ size: CGFloat, weight: Font.Weight = .medium, relativeTo style: Font.TextStyle? = nil) -> Font {
        .custom(starhashFamily, size: size, relativeTo: style ?? .starhashNearest(to: size))
            .weight(weight)
            .monospacedDigit()
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
    static func destructiveMenuIcon(_ symbol: String) -> Image {
        guard let image = UIImage.starhashSymbol(symbol) else { return Image(symbol: symbol) }
        return Image(uiImage: image.withTintColor(.systemRed, renderingMode: .alwaysOriginal))
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
    var symbol = "trash"

    init(_ title: String, symbol: String = "trash") {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        Label {
            Text(catalog: title)
        } icon: {
            Image.destructiveMenuIcon(symbol)
        }
    }
}
