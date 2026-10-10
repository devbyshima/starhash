import SwiftUI

// Shared look for every page in the Settings tab, after GO Club's: rounded
// 26pt cards 10pt from the screen's edges, flat in the cards' foreground
// (#F2F3F6 in light mode, #3A3A3A in dark), everything in them 20pt in, a
// section's grey title inside its card at the top, and a dashed line
// across the card between every row. Rows are an icon in the green glass
// style (`SettingsIcons`) and a title; a small line under it only when a
// row has something to report (auto-verify waiting). Sheets presented
// from Settings keep the sheet look instead.

extension Color {
    /// A settings card's fill: the cards' foreground.
    static var settingsCard: Color { .starhashCard }
    /// The tile behind row symbols and the profile monogram: a visible grey
    /// on a white card, a faint veil on a charcoal one.
    static let settingsTile = Color(light: .brandNight.opacity(0.07), dark: .brandPaper.opacity(0.07))
    /// Behind every settings page: the app's page colour, so cards stand
    /// out the same way they do on Activity.
    static var settingsCanvas: Color { .starhashBackground }
    /// The track of a switched-on toggle: the accent, with the white knob
    /// showing on it in either appearance.
    static let settingsToggleOn = Color.starhashSwitchOn
}

enum SettingsLayout {
    /// How far everything in a card sits from its edges, GO Club's 20.
    static let cardInset: CGFloat = 20
    /// The cards' distance from the screen's edges.
    static let screenMargin: CGFloat = 10
    /// The gap between one card and the next.
    static let cardSpacing: CGFloat = 12
    /// A row's least height, the icon with room round it.
    static let rowHeight: CGFloat = 60
}

/// A settings page: its cards down a scroll view, `spacing` apart, 10pt
/// from the screen's edges (a centred column in a wide window) and `top`
/// under the bar, with the Soft Edge.
struct SettingsScroll<Content: View>: View {
    var spacing: CGFloat = SettingsLayout.cardSpacing
    var top: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: spacing) {
                content
            }
            .padding(.bottom, 20)
        }
        .background(Color.settingsCanvas.ignoresSafeArea())
        .starhashReadableScrollContent(base: SettingsLayout.screenMargin)
        .contentMargins(.top, top, for: .scrollContent)
        .starhashSoftEdge()
    }
}

/// A card of rows, as GO Club's: the section's grey title inside it at the
/// top when it has one, and a dashed line right across it between each row
/// and the next. The whole card is one container (`starhashContainer`),
/// the same flat foreground as every other card in the app. Each row keeps
/// the card's 20pt inset itself (`settingsRowInset()`), so a pressed row
/// tints right across.
struct SettingsCard<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                SettingsSectionTitle(title)
            }
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    row.overlay(alignment: .top) {
                        if row.id != rows.first?.id {
                            StarHashRowSeparator(
                                leading: SettingsLayout.cardInset,
                                trailing: SettingsLayout.cardInset,
                                overlapsRows: true
                            )
                        }
                    }
                }
            }
        }
        // A pressed row's tint follows the card's corners.
        .clipShape(shape)
        .starhashContainer(.settingsCard, in: shape)
    }
}

extension View {
    /// A row's place in a `SettingsCard`: the card's full width, its
    /// content 20pt in from either edge.
    func settingsRowInset() -> some View {
        padding(.horizontal, SettingsLayout.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Title for a page pushed inside Settings. iOS 26's own back button is
    /// already a round glass chevron, so the system one stays.
    func settingsPage(_ title: String) -> some View {
        starhashNavigationTitle(title)
    }
}

/// A row that opens a page, with the chevron a list puts at its end. The
/// press plays no impact: Settings taps as the page opens.
struct SettingsLinkRow: View {
    let page: SettingsPage
    let symbol: String
    let title: String
    var caption: String?

    var body: some View {
        NavigationLink(value: page) {
            SettingsRow(symbol: symbol, title: title, caption: caption) {
                SettingsChevron()
            }
        }
        .buttonStyle(HighlightRowButtonStyle(pressHaptic: false))
    }
}

/// A choice from a menu at a row's end, as GO Club's settings show one:
/// the value and the up and down chevron.
struct SettingsChoiceMenu<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let choices: [Value]
    let label: (Value) -> String

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(choices, id: \.self) { choice in
                    Text(catalog: label(choice)).tag(choice)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(catalog: label(selection))
                    .starhashFont(16, weight: .medium, relativeTo: .callout)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.starhashPrimaryText)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
        .buttonStyle(.hapticPlain)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityLabel(LocalizedStringKey(title))
        .accessibilityValue(label(selection))
    }
}

/// The small grey mark at a row's end: a list's chevron, or the arrow of a
/// row that leaves the app.
struct SettingsChevron: View {
    var symbol = "chevron.right"

    var body: some View {
        Image(systemName: symbol)
            .starhashFont(14, weight: .semibold, relativeTo: .footnote)
            .foregroundStyle(Color.starhashTertiaryText)
            .accessibilityHidden(true)
    }
}

/// A row's icon: the symbol's drawing in the green glass style
/// (`SettingsIconImage`), all one colour. It grows with the text beside
/// it, up to half as big again.
struct SettingsSymbol: View {
    let symbol: String
    var size: CGFloat = 36

    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    var body: some View {
        SettingsIconImage(symbol: symbol, size: size * min(textScale, 1.5))
            .accessibilityHidden(true)
    }
}

/// Icon, title, a small status line under it when there is one, and
/// whatever trails the row (a value, a badge, nothing before a
/// `NavigationLink`'s chevron).
struct SettingsRow<Trailing: View>: View {
    let symbol: String
    let title: String
    var caption: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            SettingsSymbol(symbol: symbol)
            SettingsRowText(title: title, caption: caption)
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: SettingsLayout.rowHeight)
        .settingsRowInset()
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(symbol: String, title: String, caption: String? = nil) {
        self.init(symbol: symbol, title: title, caption: caption) { EmptyView() }
    }
}

extension SettingsRow where Trailing == Text {
    /// A row with a grey value at its end ("On", "1.0.0").
    init(symbol: String, title: String, caption: String? = nil, value: String) {
        self.init(symbol: symbol, title: title, caption: caption) {
            Text(catalog: value)
                .font(.starhash(.body))
                .foregroundStyle(Color.starhashSecondaryText)
        }
    }
}

/// The row's title (16pt medium, as GO Club's) over its status line.
struct SettingsRowText: View {
    let title: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(catalog: title)
                .starhashFont(16, weight: .medium, relativeTo: .callout)
                .foregroundStyle(Color.starhashPrimaryText)
            if let caption {
                Text(catalog: caption)
                    .starhashFont(13.5, weight: .medium, relativeTo: .footnote)
                    .foregroundStyle(Color.starhashTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
    }
}

/// A row with a switch: icon, title, toggle. The whole row is the toggle's
/// label, so VoiceOver reads it as one switch.
struct SettingsToggleRow: View {
    let symbol: String
    let title: String
    var caption: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                SettingsSymbol(symbol: symbol)
                SettingsRowText(title: title, caption: caption)
            }
        }
        .tint(Color.settingsToggleOn)
        .frame(minHeight: SettingsLayout.rowHeight)
        .settingsRowInset()
    }
}

/// A section's title inside its card, as GO Club sets "App Settings": the
/// card's first row, small, medium and grey, with no line under it
/// (`SettingsCard` puts it there).
struct SettingsSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(catalog: title)
            .starhashFont(14, weight: .medium, relativeTo: .subheadline)
            .foregroundStyle(Color.starhashTertiaryText)
            .padding(.top, 20)
            .padding(.bottom, 2)
            // A list row's least height, which the title was first set in.
            .frame(minHeight: 44)
            .settingsRowInset()
            .accessibilityAddTraits(.isHeader)
    }
}

/// Small print under a card.
struct SettingsFootnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(catalog: text)
            .starhashFont(13, relativeTo: .footnote)
            .lineSpacing(0.5)
            .foregroundStyle(Color.starhashCaptionText)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

