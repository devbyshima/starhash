import SwiftUI
import UIKit

/// StarHash follows the system appearance in four colours: the brand blue
/// #05A9F4, the pale grey #F4F4F4, the near black #171717 and the grey
/// #616161, plus variations of them where contrast needs one. Light: every
/// page is the blue, as Cash App is its green, with white cards,
/// near-black text and near black as the accent (the blue would vanish on
/// itself). Dark: every page is the near black, with lifted charcoal
/// cards, pale grey text and the blue as the accent. Each colour resolves per appearance, so
/// nothing else needs to know which mode is on.
extension Color {
    // MARK: The palette, exactly as given

    static let brandBlue = Color(red: 5 / 255, green: 169 / 255, blue: 244 / 255)
    static let brandPaper = Color(white: 244 / 255)
    static let brandNight = Color(white: 23 / 255)
    static let brandGrey = Color(white: 97 / 255)

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

    static let starhashPrimaryText = Color(light: .brandNight, dark: .brandPaper)
    /// The quieter text. Light: the near black let through at 80%, which
    /// sits on whatever is under it, so one colour reads on the blue page
    /// (5.0:1) and on a white card or a pale sheet (9:1 or more); #616161
    /// itself is 2.4:1 on the blue. Dark: a grey lifted from #616161, which
    /// is under 3:1 on the near black (7.4:1 on the page, 4.5:1 or more on
    /// its cards and glass).
    static let starhashSecondaryText = Color(light: .brandNight.opacity(0.8), dark: .init(white: 166 / 255))
    /// Placeholders and muted marks, 3:1 or more on the blue and on cards.
    static let starhashTertiaryText = Color(light: .brandNight.opacity(0.6), dark: .init(white: 117 / 255))
    /// Section titles and the small print under settings cards.
    static let starhashCaptionText = Color.starhashSecondaryText
    /// Money going out and destructive actions, on cards and sheets: one of
    /// the two hues besides the accent, AA on everything it sits on there.
    static let starhashDestructive = Color(light: .init(red: 0.84, green: 0.16, blue: 0.13), dark: .init(red: 1, green: 110 / 255, blue: 100 / 255))
    /// The same, as text straight on the page: no brighter red reaches
    /// 4.5:1 on the blue, so light mode deepens it (4.6:1).
    /// The light rising from the foot of the launch splash: the blue on dark
    /// mode's near black, full white on light mode's blue.
    static let splashGlow = Color(light: .white, dark: .brandBlue)
    /// Buy's call buttons. Light: black, as the dark-mode Total card, with
    /// the brand blue phone (6.8:1); over the blue page glass alone turns
    /// teal, so a solid near black sits under it, as the Total card's white
    /// does. Dark: the blue as glass, with a near-black phone.
    static let callGlassTint = Color(light: .brandNight, dark: .brandBlue.opacity(0.9))
    static let callSolidFill = Color(light: .brandNight, dark: .clear)
    static let callGlyph = Color(light: .brandBlue, dark: .brandNight)
    /// The period control's lens on the page's tinted glass: white, faint,
    /// with a bright rim, as the system's own selection reads.
    static let segmentedLens = Color(light: .white.opacity(0.42), dark: .white.opacity(0.14))
    static let segmentedLensEdge = Color(light: .white.opacity(0.6), dark: .white.opacity(0.18))
    /// A payment still waiting for its SMS: an urgent orange, filled
    /// behind a pending badge and for the word on a transaction's page.
    /// Light: a deep orange, white words on it 5.2:1, itself 5.2:1 on a
    /// white card. Dark: a bright orange, the near black on it 6.8:1,
    /// itself 5.8:1 on a charcoal card.
    static let starhashUrgent = Color(
        light: .init(red: 194 / 255, green: 65 / 255, blue: 12 / 255),
        dark: .init(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
    )
    static let starhashOnUrgent = Color(light: .white, dark: .brandNight)
    /// A red button's fill (Delete All Data): blood red, in either
    /// appearance, with white words on it (10:1).
    static let starhashDestructiveButton = Color(red: 138 / 255, green: 3 / 255, blue: 3 / 255)
    static let starhashOnDestructive = Color.white
    static let starhashDestructiveOnPage = Color(light: .init(red: 110 / 255, green: 0, blue: 0), dark: .starhashDestructive)
    /// Money coming in: the other hue, only on received amounts, the
    /// incoming arrow and a confirmed status. Light mode is a deep green
    /// so the amount still reads on the blue page (3.7:1, large) as well as
    /// on cards (8:1 or more).
    static let starhashIncoming = Color(light: .init(red: 0, green: 80 / 255, blue: 30 / 255), dark: .init(red: 0.3, green: 0.85, blue: 0.48))
    /// Drawn on `starhashIncoming` (the verified tick).
    static let starhashOnIncoming = Color(light: .white, dark: .brandNight)

    // MARK: Text on Pay

    /// Pay's text: near black on the blue (6.8:1), pale grey on the near
    /// black.
    static let payPrimaryText = Color(light: .brandNight, dark: .brandPaper)
    /// Pay's quieter text: the near black let through to the blue at 4.5:1.
    static let paySecondaryText = Color(light: .brandNight.opacity(0.78), dark: .init(white: 166 / 255))
    /// The amount's zero, a placeholder: 3:1, as large text needs.
    static let payPlaceholderText = Color(light: .brandNight.opacity(0.6), dark: .init(white: 117 / 255))
    /// Pay's primary button: on the blue it turns over, near black with
    /// blue text (6.8:1); on the near black it is the blue with near-black
    /// text, as everywhere else.
    static let payButtonFill = Color(light: .brandNight, dark: .brandBlue)
    static let payButtonLabel = Color(light: .brandBlue, dark: .brandNight)
    /// The keypad's accent, the puff at the top of each blob of ink and
    /// the flash of a pressed digit: the pale grey on the blue, so a press
    /// leaves a clean white cloud (a dark puff read as a smudge), and the
    /// blue glowing on the near black.
    static let payKeypadAccent = Color(light: .brandPaper, dark: .brandBlue)
    /// Glass on the blue, tinted a deeper blue so it reads as a darker
    /// shade of the page rather than a pale (or, with a grey tint, teal)
    /// hole; untinted on the near black.
    static let payGlassTint = Color(light: Color(red: 0, green: 110 / 255, blue: 176 / 255).opacity(0.55), dark: .clear)
    /// The pressed digit's flash: the text colour itself on the blue (a
    /// pale flash vanished into the white puff), the blue on the near
    /// black.
    static let payKeypadFlash = Color(light: .brandNight, dark: .brandBlue)
    /// A held key's bubble: white on the blue; on the near black, the grey
    /// the shader's blob starts from, where a white disc would glare.
    static let payKeyBubble = Color(light: .white, dark: .init(white: 77 / 255))
    /// Glass on any page: Pay's deep-blue tint in light mode.
    static let starhashGlassTint = Color.payGlassTint
    /// Pills and pressed discs on Pay.
    static let payWash = Color(light: .brandNight.opacity(0.1), dark: .brandPaper.opacity(0.08))

    // MARK: The accent

    /// The accent as a fill: primary buttons, chart bars, a filled check.
    /// Light: near black, as the blue page cannot carry a blue button.
    /// Dark: the blue.
    static let starhashInk = Color(light: .brandNight, dark: .brandBlue)
    /// Text and glyphs drawn on `starhashInk`: the near black (6.8:1).
    /// Text and glyphs drawn on `starhashInk`: the blue on near black,
    /// near black on the blue (6.8:1 both ways).
    static let starhashOnInk = Color(light: .brandBlue, dark: .brandNight)
    /// The accent as text or a thin mark on the page (a chosen check):
    /// near black on the blue, the blue on the near black.
    static let starhashAccentText = Color(light: .brandNight, dark: .brandBlue)
    /// The accent as a graphic that has to read against the page (a
    /// selection ring, progress): the same.
    static let starhashAccentGraphic = Color.starhashAccentText
    /// A switched-on toggle, on a white card in light mode: a step deeper
    /// than the blue for 3:1 there, the blue itself in dark mode.
    static let starhashSwitchOn = Color(light: .init(red: 4 / 255, green: 132 / 255, blue: 195 / 255), dark: .brandBlue)

    /// The StarHash mark's star, drawn bare. Dark: the blue. Light: near
    /// black, the dark page's colour, as a blue star would vanish into the
    /// blue page.
    static let starhashMarkGlyph = Color(light: .brandNight, dark: .brandBlue)

    /// Letters a search matched. Dark: the blue. Light: near black like the
    /// rest of the name, picked out by `pickerMatchBackground` instead, as
    /// no colour stands apart from near black and still reads on the blue.
    static let pickerMatch = Color(light: .brandNight, dark: .brandBlue)
    static let pickerMatchBackground = Color(light: .white.opacity(0.55), dark: .clear)

    /// Sheets: the solid surface cards sit on (on the white sheet, a white
    /// with a breath of the brand blue in it, the near black on it at 17:1;
    /// or the near black lifted a little less than a card), the grey of
    /// secondary text, and the fill of a filled button that is not the
    /// accent.
    static let sheetSurface = Color(light: .init(red: 232 / 255, green: 246 / 255, blue: 254 / 255), dark: .init(white: 28 / 255))
    static let sheetSecondaryText = Color.starhashSecondaryText
    /// Small fills inside a sheet (icon circles, a monogram tile, a pill, a
    /// disabled button): a step deeper than the cards, still near white and
    /// still blue, in light mode; a faint veil in dark mode.
    static let sheetChip = Color(light: .init(red: 205 / 255, green: 235 / 255, blue: 252 / 255), dark: .brandPaper.opacity(0.1))
    /// The glass of a sheet's header buttons (close, confirm, Edit): the
    /// cards' near-white blue in light mode, so they read as the sheet's
    /// own; the usual clear glass in dark.
    static let sheetControlTint = Color(light: .init(red: 232 / 255, green: 246 / 255, blue: 254 / 255), dark: .clear)
    /// Black glass, every container in dark mode: the near black as glass
    /// (the dark-mode Total card).
    static let blackGlassTint = Color.brandNight.opacity(0.6)
    /// Text and marks straight on a sheet, with nothing behind them (a
    /// title, a hero name, a label, a text button): the brand blue. Dark:
    /// the blue itself (6.8:1 on the sheet). Light: the blue deepened just
    /// enough to read on the white sheet (4.7:1), where the blue itself is
    /// 2.6:1.
    static let sheetBrandText = Color(light: .init(red: 0, green: 120 / 255, blue: 190 / 255), dark: .brandBlue)
    static let sheetFilledButton = Color(light: .brandNight, dark: .brandPaper)
    /// A disabled sheet button's label, on its `sheetChip` fill.
    static let sheetDisabledLabel = Color(light: .brandNight.opacity(0.6), dark: .init(white: 166 / 255))
    /// Mark as Confirmed's fill and words: white and the near black in light
    /// mode (18:1), the money-in green and the near black in dark (9.8:1).
    static let confirmButton = Color(light: .white, dark: .init(red: 0.3, green: 0.85, blue: 0.48))
    static let onConfirmButton = Color.brandNight
    /// The label on `sheetFilledButton`.
    static let sheetFilledLabel = Color(light: .white, dark: .init(white: 28 / 255))
    /// A sheet's background. Light: solid white, the founder's pick. Dark:
    /// the page colour let mostly through the glass.
    static let sheetGlassTint = Color(light: .white, dark: .brandNight.opacity(0.6))
    /// The tab bar's lens under the page showing: the grey at 31% over the
    /// glass, which matches the reference's lens on white (200 of 255),
    /// lighter in dark mode so it still reads on the dark glass. Its rim is
    /// light along the top and dark down the sides, as glass's is.
    static let tabBarLens = Color(light: .brandGrey.opacity(0.31), dark: .brandPaper.opacity(0.16))
    static let tabBarLensEdgeLight = Color(light: .white.opacity(0.7), dark: .white.opacity(0.22))
    static let tabBarLensEdgeDark = Color(light: .brandNight.opacity(0.22), dark: .black.opacity(0.3))
    /// Over sheet-coloured glass (the note sheets, the recipient screen's
    /// Total) in light mode: Settings' card white, solid, since
    /// white-tinted glass still lets the blue page and its highlights
    /// through on a device. Dark keeps the glass, tinted `sheetGlassTint`.
    static let sheetSolidFill = Color(light: .white, dark: .clear)
    /// The note sheets' background: solid white in light mode, as
    /// `sheetSolidFill`, and the page's own near black in dark, so the note
    /// reads as a page.
    static let noteSheetBackground = Color(light: .white, dark: .brandNight)
    /// The dotted line between a sheet card's rows.
    static let sheetDivider = Color(light: .brandNight.opacity(0.22), dark: .brandPaper.opacity(0.22))

    /// The carriers' own colours: their logos, and the rings round the
    /// chosen logo on onboarding's carrier step. StarHash's buttons are the
    /// blue whichever carrier pays.
    static let starhashMTN = Color(red: 1, green: 203 / 255, blue: 5 / 255)
    static let starhashOnMTN = Color(white: 0.08)
    /// MTN's yellow as a thin ring: a deeper gold on the pale grey, where
    /// the yellow itself all but vanishes; the yellow on the near black.
    static let starhashMTNRing = Color(light: .init(red: 214 / 255, green: 158 / 255, blue: 0), dark: .starhashMTN)
    static let starhashAirtel = Color(red: 228 / 255, green: 0, blue: 0)
    static let starhashOnAirtel = Color.white

    /// Large empty-state symbols ("No Expenses") and other muted icons.
    static let starhashMutedIcon = Color(light: .init(white: 138 / 255), dark: .init(white: 130 / 255))
    /// The close (xmark) glyph: grey and lighter in weight than the other
    /// header glyphs (back, add, confirm).
    static let starhashCloseGlyph = Color.starhashSecondaryText

    /// One colour per appearance, resolved by the system whenever the
    /// appearance changes.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
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
            Text(title)
        } icon: {
            Image.destructiveMenuIcon(systemImage)
        }
    }
}
