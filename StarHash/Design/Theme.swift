import SwiftUI
import UIKit

/// StarHash follows the system appearance in the owner's reference
/// neutrals with their green as the accent: light mode is a white page
/// with #F5F6F5 for what is filled and #E1E1E1 round what is outlined,
/// words in #171717 and #707070; dark mode is a #171717 page with #262626
/// fills and #333333 outlines, words in #FAFBFA and #A3A3A3. The green
/// #64D27B fills (buttons, switches, the chart, the mark, the avatar) with
/// the deep green #091D11 as the words on it (9.2:1) in either appearance;
/// green words are a deeper shade of it on white (`brandAccentDeep`, 5.6:1)
/// and the green itself on the dark page (9:1). Red is kept for what
/// deletes and what failed.
///
/// The page and its cards share their text colours in either appearance,
/// so the `SurfaceColor` tokens resolve the same on both; they keep the
/// page and container split for any colour that ever needs it. Each colour
/// resolves per appearance, so nothing else needs to know which mode is on.
extension Color {
    // MARK: The palette

    /// The accent and brand colour, #64D27B.
    static let brandAccent = Color(red: 100 / 255, green: 210 / 255, blue: 123 / 255)
    /// The deep green, #091D11: the words on the green.
    static let brandForest = Color(red: 9 / 255, green: 29 / 255, blue: 17 / 255)
    /// The accent deepened for words and thin marks on white (5.6:1) and on
    /// light mode's fills (5.2:1).
    static let brandAccentDeep = Color(red: 53 / 255, green: 116 / 255, blue: 68 / 255)

    // Light mode, from the reference.
    static let brandWhite = Color.white
    /// What is filled on white (a list of actions, a summary), and a step
    /// further for the controls on it.
    static let brandMist = Color(red: 245 / 255, green: 246 / 255, blue: 245 / 255)
    static let brandCloud = Color(red: 235 / 255, green: 236 / 255, blue: 235 / 255)
    /// The line round an outlined card, and between rows.
    static let brandHairline = Color(red: 225 / 255, green: 225 / 255, blue: 225 / 255)
    static let brandDivider = Color(red: 223 / 255, green: 223 / 255, blue: 224 / 255)
    /// Words: #171717, the quieter #707070 (5:1), placeholders #8A8A8A
    /// (3.4:1).
    static let brandInk = Color(red: 23 / 255, green: 23 / 255, blue: 23 / 255)
    static let brandGrey = Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255)
    static let brandMuted = Color(red: 138 / 255, green: 138 / 255, blue: 138 / 255)

    // Dark mode, from the reference: the page is `brandInk`.
    /// What is filled on the dark page, and a step further for the controls
    /// on it, which is also the line round an outlined card.
    static let brandCoal = Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255)
    static let brandSlate = Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255)
    static let brandDividerDark = Color(red: 61 / 255, green: 61 / 255, blue: 63 / 255)
    /// Words: #FAFBFA, the quieter #A3A3A3 (7:1), placeholders #808080
    /// (4.5:1).
    static let brandPaper = Color(red: 250 / 255, green: 251 / 255, blue: 250 / 255)
    static let brandPaperQuiet = Color(red: 163 / 255, green: 163 / 255, blue: 163 / 255)
    static let brandPaperMuted = Color(red: 128 / 255, green: 128 / 255, blue: 128 / 255)

    /// A payment still waiting for its SMS: yellow, #F2BB07, so the three
    /// states read apart at a glance, as they did before the redesign:
    /// yellow pending, red failed, green confirmed.
    static let brandYellow = Color(red: 242 / 255, green: 187 / 255, blue: 7 / 255)

    /// Blood red, #C1121F: delete buttons and failed payments (5.9:1 on
    /// white).
    static let brandRed = Color(red: 193 / 255, green: 18 / 255, blue: 31 / 255)

    /// The accent as it fills, the green, and what is drawn on it, the deep
    /// green: the same in either appearance.
    static let brandFill = Color.brandAccent
    static let brandOnFill = Color.brandForest

    // MARK: Pages

    /// Screen background: white, or #171717.
    static let starhashBackground = Color(light: .brandWhite, dark: .brandInk)
    /// Pay's background, the same as every page's.
    static let starhashPayBackground = Color.starhashBackground
    /// What is filled (a list of actions, the summary, fields): #F5F6F5 on
    /// white, #262626 on #171717.
    static let starhashCard = Color(light: .brandMist, dark: .brandCoal)
    /// Controls sitting on a card (icon tiles, date pill, text fields).
    static let starhashCardRaised = Color(light: .brandCloud, dark: .brandSlate)
    /// The line round an outlined card (a transaction's details, Settings'
    /// groups).
    static let starhashOutline = Color(light: .brandHairline, dark: .brandSlate)
    /// Hairlines between rows.
    static let starhashSeparator = Color(light: .brandDivider, dark: .brandDividerDark)
    /// Hairlines between the rows of a settings list.
    static let starhashListSeparator = Color(light: .brandDivider, dark: .brandDividerDark)

    // MARK: Text

    /// #171717 on white and its fills (18:1, 17:1), #FAFBFA on #171717 and
    /// its fills (17:1, 14:1).
    static let starhashPrimaryText = SurfaceColor(light: .brandInk, dark: .brandPaper)
    /// The quieter text: 4.5:1 or more on either page and its fills.
    static let starhashSecondaryText = SurfaceColor(light: .brandGrey, dark: .brandPaperQuiet)
    /// Placeholders and muted marks, 3:1 or more on the page and on fills.
    static let starhashTertiaryText = SurfaceColor(light: .brandMuted, dark: .brandPaperMuted)
    /// Section titles and small print.
    static let starhashCaptionText = Color.starhashSecondaryText
    /// What failed and destructive actions as words: the blood red on
    /// white, a lighter red in dark mode, where the blood red is too dark to
    /// read.
    static let starhashDestructive = Color(
        light: .brandRed,
        dark: .init(red: 1, green: 123 / 255, blue: 123 / 255)
    )
    /// Buy's call buttons, the one glass left on Buy: Liquid Glass tinted
    /// the green, with the deep green phone on it.
    static let callGlassTint = Color.brandFill.opacity(0.92)
    static let callSolidFill = Color.clear
    static let callGlyph = Color.brandOnFill
    /// The period control's lens on the clear glass: a faint veil of the
    /// text colour, as the system's own selection reads.
    static let segmentedLens = Color(light: .black.opacity(0.07), dark: .white.opacity(0.14))
    static let segmentedLensEdge = Color(light: .black.opacity(0.08), dark: .white.opacity(0.18))
    /// A payment still waiting for its SMS: the yellow behind a pending
    /// badge, with near-black words on it (10:1), in either appearance.
    static let starhashUrgent = Color.brandYellow
    static let starhashOnUrgent = Color.brandInk
    /// Pending as words (on a transaction's page): the yellow itself in dark
    /// mode (10:1 on #171717), a deep amber on light mode's white (#8A6500,
    /// 5.3:1), where the yellow is 1.8:1.
    static let starhashUrgentText = Color(light: .init(red: 138 / 255, green: 101 / 255, blue: 0), dark: .brandYellow)
    /// Money going out, as an arrow or an amount: the text colour. Red is
    /// kept for what failed or deletes.
    static let starhashOutgoing = SurfaceColor(light: .brandInk, dark: .brandPaper)
    /// A delete button's fill (Delete All Data, Delete Transaction): the
    /// blood red, in either appearance, with white words on it (6.2:1).
    static let starhashDestructiveButton = Color.brandRed
    static let starhashOnDestructive = Color.white
    /// Red as text straight on the page, the same as on a card.
    static let starhashDestructiveOnPage = Color.starhashDestructive
    /// Money coming in and a confirmed payment: the deeper green on white,
    /// the green itself on #171717.
    static let starhashIncoming = SurfaceColor(light: .brandAccentDeep, dark: .brandAccent)
    /// Drawn on `starhashIncoming` as a fill (the verified tick).
    static let starhashOnIncoming = SurfaceColor(light: .white, dark: .brandForest)

    // MARK: Text on Pay

    /// Pay's text, the same as every page's.
    static let payPrimaryText = Color(light: .brandInk, dark: .brandPaper)
    static let paySecondaryText = Color(light: .brandGrey, dark: .brandPaperQuiet)
    /// The amount's zero, a placeholder: 3:1, as large text needs.
    static let payPlaceholderText = Color(light: .brandMuted, dark: .brandPaperMuted)
    /// Pay's primary button: the green with the deep green on it (9.2:1),
    /// as every primary button.
    static let payButtonFill = Color.brandFill
    static let payButtonLabel = Color.brandOnFill
    /// Glass on Pay: clear, as on every page.
    static let payGlassTint = Color.clear
    /// The pressed digit's flash as it lifts: the green.
    static let payKeypadFlash = Color.brandFill
    /// Glass on any page: clear.
    static let starhashGlassTint = Color.clear
    /// The soft lift under glass that floats over a list (the recipient
    /// screen's Total), so it parts from the white page in light mode; dark
    /// mode's glass reads on its own.
    static let floatingShadow = Color(light: .black.opacity(0.1), dark: .clear)
    /// Balance's glass: a veil of the fills' colour over clear Liquid
    /// Glass, so the capsule stands out on Pay's page in either appearance.
    static let balanceGlassTint = Color(light: .brandMist.opacity(0.85), dark: .brandCoal.opacity(0.8))
    /// Pills and recipient tiles on Pay, and the primary button there
    /// when disabled: the fills' colour.
    static let payWash = Color(light: .brandMist, dark: .brandCoal)

    // MARK: The accent

    /// The accent as a fill: primary buttons, chart bars, a filled check.
    static let starhashInk = SurfaceColor(light: .brandAccent, dark: .brandAccent)
    /// Text and glyphs drawn on `starhashInk`: the deep green (9.2:1).
    static let starhashOnInk = SurfaceColor(light: .brandForest, dark: .brandForest)
    /// The accent as text or a thin mark (a chosen check): the deeper green
    /// on white, the green on #171717.
    static let starhashAccentText = SurfaceColor(light: .brandAccentDeep, dark: .brandAccent)
    /// The accent as a graphic that has to stand out (a selection ring,
    /// progress): the green itself.
    static let starhashAccentGraphic = SurfaceColor(light: .brandAccent, dark: .brandAccent)
    /// A switched-on toggle: the green, its white knob on it.
    static let starhashSwitchOn = Color.brandFill

    /// The StarHash mark's star, drawn bare: the green.
    static let starhashMarkGlyph = SurfaceColor(light: .brandAccent, dark: .brandAccent)

    /// Letters a search matched: the deeper green on a pale wash of the
    /// green, and the green in dark mode.
    static let pickerMatch = SurfaceColor(light: .brandAccentDeep, dark: .brandAccent)
    static let pickerMatchBackground = Color(light: .brandAccent.opacity(0.16), dark: .clear)

    /// Sheets: the solid surface cards sit on (the fills' colour), the
    /// quieter text, and the fill of a filled button that is not the accent.
    static let sheetSurface = Color(light: .brandMist, dark: .brandCoal)
    static let sheetSecondaryText = Color.starhashSecondaryText
    /// Small fills inside a sheet (icon circles, a monogram tile, a pill, a
    /// disabled button): a step past its cards, so they read on the sheet and
    /// on its cards alike.
    static let sheetChip = Color(light: .brandCloud, dark: .brandSlate)
    /// The glass of a sheet's header buttons (close, confirm, Edit): white
    /// in light mode, so they read as the sheet's own; the usual clear glass
    /// in dark.
    static let sheetControlTint = Color(light: .brandWhite, dark: .clear)
    /// Text and marks straight on a sheet, with nothing behind them (a
    /// title, a hero name, a label, a text button): the sheet's own text
    /// colour.
    static let sheetBrandText = SurfaceColor(light: .brandInk, dark: .brandPaper)
    static let sheetFilledButton = Color(light: .brandInk, dark: .brandPaper)
    /// A disabled sheet button's label, on its `sheetChip` fill.
    static let sheetDisabledLabel = Color(light: .brandGrey, dark: .brandPaperQuiet)
    /// Verify's fill and words: the green with the deep green on it.
    static let confirmButton = Color.brandFill
    static let onConfirmButton = Color.brandOnFill
    /// The label on `sheetFilledButton`.
    static let sheetFilledLabel = Color(light: .white, dark: .brandInk)
    /// A sheet's background: the page's own white in light mode, the page's
    /// #171717 let mostly through the glass in dark.
    static let sheetGlassTint = Color(light: .brandWhite, dark: .brandInk.opacity(0.6))
    /// The tab bar's lens under the page showing: a veil of the text colour
    /// over the clear glass. Its rim is light along the top and dark down
    /// the sides, as glass's is.
    static let tabBarLens = Color(light: .black.opacity(0.07), dark: .brandPaper.opacity(0.16))
    static let tabBarLensEdgeLight = Color(light: .white.opacity(0.8), dark: .white.opacity(0.22))
    static let tabBarLensEdgeDark = Color(light: .black.opacity(0.1), dark: .black.opacity(0.3))
    /// The note sheets' background: the page's own colour, so the note
    /// reads as a page.
    static let noteSheetBackground = Color(light: .brandWhite, dark: .brandInk)
    /// The developer's note in the brand's own colours, so it stands apart
    /// from the neutral page it opens over: the deep green on the green
    /// (9.2:1), its quieter words a little lighter, and its button the other
    /// way round.
    static let noteBrandBackground = Color.brandAccent
    static let noteBrandText = Color.brandForest
    static let noteBrandSecondary = Color.brandForest.opacity(0.78)
    static let noteBrandButton = Color.brandForest
    static let noteBrandButtonLabel = Color.brandAccent
    /// The solid line between a card's rows.
    static let sheetDivider = Color(light: .brandDivider, dark: .brandDividerDark)

    /// A profile without a photo: the fills' colour behind a person in the
    /// muted text.
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
    static let widgetCard = Color(light: .brandWhite, dark: .brandInk)
    /// Words on the widgets: the text colours.
    static let widgetText = Color(light: .brandInk, dark: .brandPaper)
    /// The quieter words on a widget (the pill's "Pay").
    static let widgetSecondaryText = Color(light: .brandGrey, dark: .brandPaperQuiet)
    /// The widgets' tiles, pills and circles: a step past the fills, as the
    /// reference's grey tiles stand on its card.
    static let widgetChip = Color(light: .brandCloud, dark: .brandSlate)
    /// The widgets' symbols: the green.
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
