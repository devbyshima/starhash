import SwiftUI

// Shared look for every page in the Settings tab, after Keaser's: rounded
// 26pt cards on the settings canvas (white on grouped grey in light mode,
// charcoal on black in dark mode), rows with a symbol on a faint tile, a
// title and a small caption, grey sentence-case section titles. Sheets
// presented from Settings keep the sheet look instead.

extension Color {
    /// Cards on a settings page: white in light mode, charcoal in dark mode.
    static var settingsCard: Color { .starhashCard }
    /// The tile behind row symbols and the profile monogram: a visible grey
    /// on a white card, a faint veil on a charcoal one.
    static let settingsTile = Color(light: .black.opacity(0.08), dark: .white.opacity(0.06))
    /// Behind every settings page: the grouped grey in light mode, so white
    /// cards stand out; black in dark mode, under charcoal cards.
    static let settingsCanvas = Color(light: .init(red: 242 / 255, green: 242 / 255, blue: 247 / 255), dark: .black)
    /// The track of a switched-on toggle. The system green, as Keaser draws
    /// its switches: ink would put a white knob on a white track in dark mode.
    static let settingsToggleOn = Color(uiColor: .systemGreen)
}

/// Where a row sits in its card, so its background rounds the right corners.
enum SettingsCardPosition {
    case single, first, middle, last

    init(index: Int, count: Int) {
        switch (index, count) {
        case (_, ...1): self = .single
        case (0, _): self = .first
        case (count - 1, _): self = .last
        default: self = .middle
        }
    }

    var roundsTop: Bool { self == .single || self == .first }
    var roundsBottom: Bool { self == .single || self == .last }
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

extension EdgeInsets {
    /// Rows with a leading symbol tile.
    static let settingsRow = EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 16)
    /// Text-only rows and the profile card.
    static let settingsTextRow = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
}

extension View {
    /// The list look shared by every settings page. `sectionSpacing` is the
    /// gap between cards; pages whose sections start with a
    /// `SettingsSectionTitle` use a tighter one, since the title adds its
    /// own height.
    func settingsListStyle(sectionSpacing: CGFloat = 28, topMargin: CGFloat = 16) -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.settingsCanvas.ignoresSafeArea())
            .starhashReadableScrollContent(base: StarHashMetrics.screenPadding)
            .contentMargins(.top, topMargin, for: .scrollContent)
            .listSectionSpacing(sectionSpacing)
            .starhashSoftTopEdge()
            .starhashSoftBottomEdge()
            .environment(\.defaultMinListRowHeight, 44)
    }

    /// Places a row in a card at `position`.
    func settingsCardRow(_ position: SettingsCardPosition, insets: EdgeInsets = .settingsRow) -> some View {
        self
            .listRowInsets(insets)
            .listRowBackground(SettingsCardRowBackground(position: position))
            .listRowSeparatorTint(Color.starhashListSeparator)
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
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
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
                .font(.body)
                .foregroundStyle(Color.starhashSecondaryText)
        }
    }
}

/// The row's title (medium, as in Keaser) over its caption.
struct SettingsRowText: View {
    let title: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.starhashPrimaryText)
            if let caption {
                Text(caption)
                    .starhashFont(13, relativeTo: .footnote)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
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

/// Section title in the iOS 26 style (sentence case, grey, semibold), as
/// the first row of its section, so it sits the same distance from the
/// card on iOS 18 and iOS 26.
struct SettingsSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .starhashFont(17, weight: .semibold, relativeTo: .headline)
            .foregroundStyle(Color.starhashCaptionText)
            .padding(.leading, 16)
            .padding(.top, 13)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            .accessibilityAddTraits(.isHeader)
            .settingsPlainRow()
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

/// A small capsule label beside a row's title or at its end ("Main",
/// "Coming soon").
struct SettingsBadge: View {
    let text: String
    var filled = false

    var body: some View {
        Text(text)
            .starhashFont(12, weight: .semibold, relativeTo: .caption)
            .foregroundStyle(filled ? Color.starhashOnInk : Color.starhashSecondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(filled ? Color.starhashInk : Color.settingsTile, in: Capsule())
    }
}
