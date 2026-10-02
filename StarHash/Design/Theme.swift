import SwiftUI
import UIKit

/// StarHash, like Keaser, is monochrome and follows the system appearance. Dark: black
/// canvas, charcoal cards, white ink. Light: pale grey canvas, white cards,
/// black ink. "Ink" is the one accent: chart bars, the add button, primary
/// buttons. Every colour in the app comes from here, and each one resolves
/// per appearance, so nothing else needs to know which mode is on.
extension Color {
    /// Screen background: pure black, or the reference's pale grey.
    static let starhashBackground = Color(light: .init(white: 245 / 255), dark: .black)
    /// Cards, list rows, the chart panel.
    static let starhashCard = Color(light: .white, dark: .init(red: 28 / 255, green: 28 / 255, blue: 30 / 255))
    /// Controls sitting on a card (icon tiles, date pill, text fields).
    static let starhashCardRaised = Color(light: .init(white: 242 / 255), dark: .init(red: 44 / 255, green: 44 / 255, blue: 46 / 255))
    /// Hairlines between rows.
    static let starhashSeparator = Color(light: .black.opacity(0.1), dark: .white.opacity(0.12))
    /// Hairlines between the rows of a settings list. The reference draws
    /// them fainter on its dark cards than the ones in sheets such as New
    /// Expense; light mode is the same as `starhashSeparator`.
    static let starhashListSeparator = Color(light: .black.opacity(0.1), dark: .white.opacity(0.08))
    static let starhashPrimaryText = Color(light: .black, dark: .white)
    static let starhashSecondaryText = Color(light: .init(white: 0.45), dark: .init(white: 0.56))
    static let starhashTertiaryText = Color(light: .init(white: 0.68), dark: .init(white: 0.36))
    /// Section titles and the small print under settings cards: the cool
    /// grey the reference uses there, a little lighter than
    /// `starhashSecondaryText` in light mode. Row values stay secondary.
    static let starhashCaptionText = Color(
        light: .init(red: 122 / 255, green: 121 / 255, blue: 128 / 255),
        dark: .init(red: 142 / 255, green: 141 / 255, blue: 148 / 255)
    )
    static let starhashDestructive = Color(red: 1, green: 0.27, blue: 0.23)
    /// Money coming in: the one hue besides ink, used only on received
    /// amounts and the incoming arrow.
    static let starhashIncoming = Color(light: .init(red: 0.11, green: 0.6, blue: 0.3), dark: .init(red: 0.3, green: 0.85, blue: 0.48))

    /// The accent: chart bars, the add button, primary and capsule buttons,
    /// a filled confirm check. White in dark mode, black in light mode.
    static let starhashInk = Color(light: .black, dark: .white)
    /// Text and glyphs drawn on `starhashInk`.
    static let starhashOnInk = Color(light: .white, dark: .black)

    /// The recipient picker's raised surfaces: its square header buttons
    /// and search field, avatar tiles and the bands over its sections, a
    /// step off the page in either appearance.
    static let pickerSurface = Color(light: .init(white: 0.925), dark: .init(white: 0.075))
    /// The outline of the picker's square buttons, field and tiles.
    static let pickerOutline = Color(light: .black.opacity(0.08), dark: .white.opacity(0.1))
    /// Letters a search matched, in the wallet's colour: MTN's yellow is
    /// darkened on a light page, where the bright one would not read.
    static let pickerMatchMTN = Color(light: .init(red: 0.62, green: 0.47, blue: 0), dark: .init(red: 1, green: 203 / 255, blue: 5 / 255))
    static let pickerMatchAirtel = Color(light: .init(red: 0.8, green: 0, blue: 0), dark: .init(red: 1, green: 0.3, blue: 0.3))

    /// Sheets, in Beam's colours: the solid surface cards sit on, the grey
    /// of secondary text, and the fill of a filled button that is not the
    /// accent.
    static let sheetSurface = Color(light: .init(red: 251 / 255, green: 252 / 255, blue: 248 / 255),
                                    dark: .init(red: 26 / 255, green: 26 / 255, blue: 26 / 255))
    static let sheetSecondaryText = Color(light: .init(red: 116 / 255, green: 117 / 255, blue: 113 / 255),
                                          dark: .init(red: 170 / 255, green: 172 / 255, blue: 167 / 255))
    static let sheetFilledButton = Color(light: .init(red: 38 / 255, green: 38 / 255, blue: 38 / 255),
                                         dark: .init(red: 233 / 255, green: 235 / 255, blue: 229 / 255))
    /// The dotted line between a sheet card's rows.
    static let sheetDivider = Color(light: .black.opacity(0.22), dark: .white.opacity(0.22))

    /// The wallets' colours, which fill the primary buttons once a wallet
    /// is chosen (`PrimaryButtonStyle`), so Pay says which wallet pays:
    /// MTN's yellow with dark text, Airtel's red with white.
    static let starhashMTN = Color(red: 1, green: 203 / 255, blue: 5 / 255)
    static let starhashOnMTN = Color(white: 0.08)
    static let starhashAirtel = Color(red: 228 / 255, green: 0, blue: 0)
    static let starhashOnAirtel = Color.white

    /// Large empty-state symbols ("No Expenses") and other muted icons.
    static let starhashMutedIcon = Color(light: .init(white: 0.55), dark: .init(white: 0.62))
    /// The close (xmark) glyph: grey and lighter in weight than the other
    /// header glyphs (back, add, confirm), as in the reference. It lets the
    /// glass behind it through, as the reference's does on every sheet
    /// (Accounts, Settings, the paywall, the welcome letter): a grey of 143
    /// measures 100 on a 51 circle and 106 on a 64 one in dark mode, 168 on
    /// 230 and 176 on 249 in light mode.
    static let starhashCloseGlyph = Color(
        light: Color(white: 0.56).opacity(0.7),
        dark: Color(white: 0.56).opacity(0.53)
    )
    /// Behind a row's non-destructive swipe action (Edit), whose label the
    /// system draws white: a grey dark enough for that in both appearances.
    static let starhashSwipeAction = Color(light: .init(white: 0.45), dark: .init(white: 0.32))
    /// Labels and symbols on the shortcut's expense card: the system's
    /// secondary label over its card, which the reference card uses
    /// (measured 0.52 to 0.54 in light mode against 0.45 for
    /// `starhashSecondaryText`), in both appearances.
    static let starhashSnippetLabel = Color(light: .init(white: 0.54), dark: .init(white: 0.6))


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
