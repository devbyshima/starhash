import SwiftUI
import UIKit

/// StarHash follows the system appearance in four colours: the brand blue
/// #05A9F4, the pale grey #F4F4F4, the near black #171717 and the grey
/// #616161, plus variations of them where contrast needs one. Light: Pay
/// is the blue, as Cash App's keypad is its green, and every other page is
/// the pale grey with white cards and near-black text. Dark: every page,
/// Pay too, is the near black, with lifted charcoal cards, pale grey text
/// and the blue as the accent. Each colour resolves per appearance, so
/// nothing else needs to know which mode is on.
extension Color {
    // MARK: The palette, exactly as given

    static let brandBlue = Color(red: 5 / 255, green: 169 / 255, blue: 244 / 255)
    static let brandPaper = Color(white: 244 / 255)
    static let brandNight = Color(white: 23 / 255)
    static let brandGrey = Color(white: 97 / 255)

    // MARK: Pages

    /// Screen background: the pale grey, or the near black.
    static let starhashBackground = Color(light: .brandPaper, dark: .brandNight)
    /// Pay's background, the brand screen: the blue, or the near black.
    static let starhashPayBackground = Color(light: .brandBlue, dark: .brandNight)
    /// Cards, list rows, the chart panel: white on the pale grey, and the
    /// near black lifted a step so a card reads on its page.
    static let starhashCard = Color(light: .white, dark: .init(white: 38 / 255))
    /// Controls sitting on a card (icon tiles, date pill, text fields).
    static let starhashCardRaised = Color(light: .brandPaper, dark: .init(white: 52 / 255))
    /// Hairlines between rows.
    static let starhashSeparator = Color(light: .brandNight.opacity(0.1), dark: .brandPaper.opacity(0.12))
    /// Hairlines between the rows of a settings list, a little fainter on
    /// dark cards; light mode is the same as `starhashSeparator`.
    static let starhashListSeparator = Color(light: .brandNight.opacity(0.1), dark: .brandPaper.opacity(0.08))

    // MARK: Text

    static let starhashPrimaryText = Color(light: .brandNight, dark: .brandPaper)
    /// The grey: #616161 on light pages (5.6:1 on the pale grey). On the
    /// near black that grey reads at under 3:1, so dark mode lifts it
    /// (7.4:1 on the page, 4.5:1 or more on its cards and glass).
    static let starhashSecondaryText = Color(light: .brandGrey, dark: .init(white: 166 / 255))
    /// Placeholders and muted marks, still 3:1 on their page.
    static let starhashTertiaryText = Color(light: .init(white: 138 / 255), dark: .init(white: 117 / 255))
    /// Section titles and the small print under settings cards.
    static let starhashCaptionText = Color(light: .brandGrey, dark: .init(white: 166 / 255))
    /// Money going out and destructive actions: one of the two hues besides
    /// the blue, each AA on every card it sits on.
    static let starhashDestructive = Color(light: .init(red: 0.84, green: 0.16, blue: 0.13), dark: .init(red: 1, green: 110 / 255, blue: 100 / 255))
    /// Money coming in: the other hue, only on received amounts, the
    /// incoming arrow and a confirmed status.
    static let starhashIncoming = Color(light: .init(red: 16 / 255, green: 120 / 255, blue: 56 / 255), dark: .init(red: 0.3, green: 0.85, blue: 0.48))
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
    /// Pills and pressed discs on Pay.
    static let payWash = Color(light: .brandNight.opacity(0.1), dark: .brandPaper.opacity(0.08))

    // MARK: The accent

    /// The accent as a fill: primary buttons, chart bars, a filled check,
    /// switches. The blue in both appearances.
    static let starhashInk = Color.brandBlue
    /// Text and glyphs drawn on `starhashInk`: the near black (6.8:1).
    static let starhashOnInk = Color.brandNight
    /// The accent as text, which the bright blue cannot be on light pages
    /// (2.4:1 on the pale grey): a deeper blue there (5.0:1 on the pale
    /// grey, 5.4:1 on white), the blue itself on the near black (6.8:1).
    static let starhashAccentText = Color(light: .init(red: 0, green: 110 / 255, blue: 176 / 255), dark: .brandBlue)
    /// The accent as a graphic that has to read against its page (chart
    /// bars, switch tracks, a selection ring, progress): a step deeper
    /// than the blue in light mode for 3:1 on white and the pale grey, the
    /// blue itself in dark mode.
    static let starhashAccentGraphic = Color(light: .init(red: 4 / 255, green: 132 / 255, blue: 195 / 255), dark: .brandBlue)

    /// Letters a search matched: the accent as text.
    static let pickerMatch = Color.starhashAccentText

    /// Sheets: the solid surface cards sit on (the pale grey, or the near
    /// black lifted a little less than a card), the grey of secondary text,
    /// and the fill of a filled button that is not the accent.
    static let sheetSurface = Color(light: .brandPaper, dark: .init(white: 28 / 255))
    static let sheetSecondaryText = Color(light: .brandGrey, dark: .init(white: 166 / 255))
    static let sheetFilledButton = Color(light: .brandNight, dark: .brandPaper)
    /// The tint of a sheet's glass: the page colour let mostly through, so
    /// the glass still refracts but reads as the pale grey or near black.
    static let sheetGlassTint = Color(light: .brandPaper.opacity(0.75), dark: .brandNight.opacity(0.6))
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
}

extension Font {
    // Text is set in Space Grotesk, the app's typeface (a variable font,
    // weights 300 to 700). Use `starhash(_:weight:)` where a text style
    // fits and `starhashFont(_:weight:)` for an exact size, never
    // Font.system, so the size still follows Dynamic Type. SF Symbols keep
    // .system sizes.

    /// The typeface's family name, as registered from `UIAppFonts`.
    static let starhashFamily = "Space Grotesk"

    /// Space Grotesk at a text style's size, scaling with it. Headline is
    /// semibold unless told otherwise, as the system's is.
    static func starhash(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        .custom(starhashFamily, size: style.starhashDefaultSize, relativeTo: style)
            .weight(weight ?? (style == .headline ? .semibold : .regular))
    }

    /// Space Grotesk at a size that never scales, for the onboarding
    /// pictures, which are drawn at one size like an image.
    static func starhashFixed(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(starhashFamily, fixedSize: size).weight(weight)
    }

    /// Onboarding and sheet page titles: Title 1 semibold (28pt at the
    /// default text size).
    static let starhashTitle = Font.starhash(.title, weight: .semibold)
}

extension View {
    /// An exact design size that still follows Dynamic Type: `size` at the
    /// default text size, scaled like `style` at every other size. Use this
    /// instead of `.font(.system(size:))` for any text.
    func starhashFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo style: Font.TextStyle? = nil
    ) -> some View {
        modifier(ScaledSystemFont(size: size, weight: weight, design: design, style: style ?? .starhashNearest(to: size)))
    }
}

private struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        // Monospaced stays the system's, for codes typed digit by digit.
        if design == .monospaced {
            content.font(.system(size: size, weight: weight, design: design))
        } else {
            content.font(.custom(Font.starhashFamily, fixedSize: size).weight(weight))
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
