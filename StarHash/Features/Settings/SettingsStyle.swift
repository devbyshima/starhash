import SwiftUI

// Shared look for every page in the Settings tab, after GO Club's: rounded
// 26pt cards 10pt from the screen's edges (white in light mode, charcoal in
// dark mode), everything in them 20pt in, a section's grey title inside
// its card at the top, and a dashed line across the card between every
// row. Rows keep a symbol on a faint tile, a title and a small caption.
// Sheets presented from Settings keep the sheet look instead.

extension Color {
    /// Cards on a settings page: white in light mode, charcoal in dark mode.
    static var settingsCard: Color { .starhashCard }
    /// The tile behind row symbols and the profile monogram: a visible grey
    /// on a white card, a faint veil on a charcoal one.
    static let settingsTile = Color(light: .brandNight.opacity(0.07), dark: .brandPaper.opacity(0.07))
    /// Behind every settings page: the app's page colour, so cards stand
    /// out the same way they do on Activity.
    static var settingsCanvas: Color { .starhashBackground }
    /// The track of a switched-on toggle: the accent as a graphic, 3:1 on
    /// a white card, with the white knob showing in either appearance.
    static let settingsToggleOn = Color.starhashSwitchOn
}

/// Where a row sits in its card, so its background rounds the right
/// corners and only rows after another draw the line above them.
enum SettingsCardPosition {
    case single, first, middle, last
    /// The first row under a `SettingsSectionTitle`, which holds the card's
    /// top: square above, and no line between the title and the row.
    case firstUnderTitle
    /// The only row under a title: square above, rounded below.
    case onlyUnderTitle

    init(index: Int, count: Int) {
        switch (index, count) {
        case (_, ...1): self = .single
        case (0, _): self = .first
        case (count - 1, _): self = .last
        default: self = .middle
        }
    }

    var roundsTop: Bool { self == .single || self == .first }
    var roundsBottom: Bool { self == .single || self == .last || self == .onlyUnderTitle }
    var hasLineAbove: Bool { self == .middle || self == .last }
}

/// One row's slice of a rounded card. Drawing the corners per row (instead
/// of relying on the list's section shape) gives the same 26pt corners on
/// iOS 18, whose inset-grouped sections are only slightly rounded.
struct SettingsCardRowBackground: View {
    let position: SettingsCardPosition
    var fill: Color = .settingsCard

    var body: some View {
        let top = position.roundsTop ? StarHashMetrics.cardRadius : 0
        let bottom = position.roundsBottom ? StarHashMetrics.cardRadius : 0
        UnevenRoundedRectangle(
            topLeadingRadius: top,
            bottomLeadingRadius: bottom,
            bottomTrailingRadius: bottom,
            topTrailingRadius: top,
            style: .continuous
        )
        .fill(fill)
    }
}

enum SettingsLayout {
    /// How far everything in a card sits from its edges, GO Club's 20.
    static let cardInset: CGFloat = 20
    /// The cards' distance from the screen's edges.
    static let screenMargin: CGFloat = 10
}

extension EdgeInsets {
    /// Rows with a leading symbol tile.
    static let settingsRow = EdgeInsets(top: 0, leading: SettingsLayout.cardInset, bottom: 0, trailing: SettingsLayout.cardInset)
    /// Text-only rows and the profile card.
    static let settingsTextRow = settingsRow
}

extension View {
    /// The list look shared by every settings page. `sectionSpacing` is the
    /// gap between cards; pages whose sections start with a
    /// `SettingsSectionTitle` use a tighter one, since the title adds its
    /// own height.
    func settingsListStyle(sectionSpacing: CGFloat = 12, topMargin: CGFloat = 16) -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.settingsCanvas.ignoresSafeArea())
            .starhashReadableScrollContent(base: SettingsLayout.screenMargin)
            .contentMargins(.top, topMargin, for: .scrollContent)
            .listSectionSpacing(sectionSpacing)
            .starhashSoftTopEdge()
            .starhashSoftBottomEdge()
            .environment(\.defaultMinListRowHeight, 44)
    }

    /// Places a row in a card at `position`. The list's own solid lines are
    /// hidden; each row after another draws the dashed one above it, right
    /// across the card inside its 20pt inset, as GO Club's do.
    func settingsCardRow(_ position: SettingsCardPosition, insets: EdgeInsets = .settingsRow) -> some View {
        self
            .listRowInsets(insets)
            .listRowBackground(SettingsCardRowBackground(position: position))
            .listRowSeparator(.hidden)
            .overlay(alignment: .top) {
                if position.hasLineAbove {
                    StarHashRowSeparator(leading: 0, trailing: 0, overlapsRows: true)
                }
            }
    }

    /// A list row that is not a card: stat tiles, footers, free text.
    func settingsPlainRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// Title for a page pushed inside Settings. iOS 26's own back button is
    /// already a round glass chevron, so the system one stays.
    func settingsPage(_ title: String) -> some View {
        starhashNavigationTitle(title)
    }
}

/// An SF Symbol on the faint square tile the reference puts behind row
/// icons. It grows with the text beside it, up to half as big again.
struct SettingsSymbol: View {
    let symbol: String
    var size: CGFloat = 38
    var pointSize: CGFloat = 17

    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    var body: some View {
        let scale = min(textScale, 1.5)
        Image(systemName: symbol)
            .font(.system(size: pointSize * scale, weight: .medium))
            .foregroundStyle(Color.starhashPrimaryText)
            .frame(width: size * scale, height: size * scale)
            .background(Color.settingsTile, in: RoundedRectangle(cornerRadius: size * scale * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Symbol, title, a small caption under it and whatever trails the row (a
/// value, a badge, nothing before a `NavigationLink`'s chevron).
struct SettingsRow<Trailing: View>: View {
    let symbol: String
    let title: String
    var caption: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            SettingsSymbol(symbol: symbol)
            SettingsRowText(title: title, caption: caption)
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: 68)
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
            Text(value)
                .font(.starhash(.body))
                .foregroundStyle(Color.starhashSecondaryText)
        }
    }
}

/// The row's title (16pt medium, as GO Club's) over its caption.
struct SettingsRowText: View {
    let title: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .starhashFont(16, weight: .medium, relativeTo: .callout)
                .foregroundStyle(Color.starhashPrimaryText)
            if let caption {
                Text(caption)
                    .starhashFont(13.5, weight: .medium, relativeTo: .footnote)
                    .foregroundStyle(Color.starhashTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
    }
}

/// A row with a switch: symbol, title, caption, toggle. The whole row is
/// the toggle's label, so VoiceOver reads it as one switch.
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
            .alignmentGuide(.listRowSeparatorLeading) { _ in 50 }
        }
        .tint(Color.settingsToggleOn)
        .frame(minHeight: 68)
    }
}

/// A section's title inside its card, as GO Club sets "App Settings": the
/// card's first row, small, medium and grey, with no line under it. The
/// rows under it start at `.firstUnderTitle` (or `.onlyUnderTitle`).
struct SettingsSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .starhashFont(14, weight: .medium, relativeTo: .subheadline)
            .foregroundStyle(Color.starhashTertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
            .listRowInsets(.settingsRow)
            .listRowBackground(SettingsCardRowBackground(position: .first))
            .listRowSeparator(.hidden)
    }
}

/// Small print under a card.
struct SettingsFootnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .starhashFont(13, relativeTo: .footnote)
            .lineSpacing(0.5)
            .foregroundStyle(Color.starhashCaptionText)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

