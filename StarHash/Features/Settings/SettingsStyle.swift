import SwiftUI

// Shared look for every page in the Settings tab: the outlined cards of a
// transaction's details (a line round them and nothing filled), 16pt from
// the screen's edges, everything in them 16pt in, a section's grey title
// above its card, and a solid line across the card between every row. Rows are an icon in the accent
// (`SettingsIconImage`) and a title. A row's description stays hidden
// until its icon is tapped, and goes again at the next tap; a status line
// (auto-verify waiting) always shows. Sheets presented from Settings keep
// the sheet look instead.

extension Color {
    /// A settings card's fill: the cards' foreground.
    static var settingsCard: Color { .starhashCard }
    /// The tile behind row symbols and the profile monogram: a visible grey
    /// on a white card, a faint veil on a near-black one.
    static let settingsTile = Color(light: .brandForest.opacity(0.07), dark: .brandPaper.opacity(0.07))
    /// Behind every settings page: the app's page colour, so cards stand
    /// out the same way they do on Activity.
    static var settingsCanvas: Color { .starhashBackground }
    /// The track of a switched-on toggle: the accent, with the white knob
    /// showing on it in either appearance.
    static let settingsToggleOn = Color.starhashSwitchOn
}

enum SettingsLayout {
    /// How far everything in a card sits from its edges, the same on
    /// either side.
    static let cardInset: CGFloat = 16
    /// The cards' distance from the screen's edges, as on Activity.
    static let screenMargin: CGFloat = 16
    /// The gap between one card and the next.
    static let cardSpacing: CGFloat = 12
    /// A row's least height, the icon with room round it.
    static let rowHeight: CGFloat = 52
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
        // A number pad has no return key; scrolling puts it away too.
        .scrollDismissesKeyboard(.interactively)
        .starhashSoftEdge()
    }
}

/// A card of rows: the section's grey title above it when it has one, a
/// line round it as round a transaction's details, and a solid line right
/// across it between each row and the next. Each row keeps the card's 16pt
/// inset itself (`settingsRowInset()`), so a pressed row tints right
/// across.
struct SettingsCard<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StarHashMetrics.outlinedCardRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                SettingsSectionTitle(title)
            }
            card(shape)
        }
    }

    private func card(_ shape: RoundedRectangle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
        .overlay(shape.strokeBorder(Color.starhashOutline, lineWidth: 1))
        .starhashContainerSurface()
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
    var status: String?

    var body: some View {
        NavigationLink(value: page) {
            SettingsRow(symbol: symbol, title: title, caption: caption, status: status) {
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
                Image(symbol: "chevron.up.chevron.down")
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
        Image(symbol: symbol)
            .starhashFont(14, weight: .semibold, relativeTo: .footnote)
            .foregroundStyle(Color.starhashTertiaryText)
            .accessibilityHidden(true)
    }
}

/// A row's icon: StarHash's icon for the symbol in the accent
/// (`SettingsIconImage`). It grows with the text beside
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

/// A row's icon that shows its description, and hides it again: a tap on
/// the icon alone, ahead of the row's own tap (a page to open, a switch),
/// with a light tick. VoiceOver hears the description as the row's hint
/// instead.
private struct SettingsCaptionIcon: View {
    let symbol: String
    let hasCaption: Bool
    @Binding var showsCaption: Bool

    var body: some View {
        if hasCaption {
            SettingsSymbol(symbol: symbol)
                .contentShape(Rectangle())
                .highPriorityGesture(TapGesture().onEnded {
                    TapHaptic.play()
                    withAnimation(SettingsCaptionMotion.open) { showsCaption.toggle() }
                })
        } else {
            SettingsSymbol(symbol: symbol)
        }
    }
}

/// How a description comes and goes. The row opens on a soft spring and
/// the words settle into it from a blur a beat later, so they never sit on
/// the row below while it is still making room; closing, they fade first
/// and quickly, and the row closes behind them.
@MainActor
enum SettingsCaptionMotion {
    static let open = Animation.spring(response: 0.42, dampingFraction: 0.9)

    static var transition: AnyTransition {
        .asymmetric(
        insertion: AnyTransition(.blurReplace)
            .combined(with: .offset(y: -4))
            .animation(.smooth(duration: 0.34).delay(0.07)),
        removal: AnyTransition.opacity
            .combined(with: .offset(y: -2))
            .animation(.smooth(duration: 0.14))
        )
    }
}

/// Icon, title, its description under it while shown and its status line
/// when there is one, and whatever trails the row (a value, a badge,
/// nothing before a `NavigationLink`'s chevron).
struct SettingsRow<Trailing: View>: View {
    let symbol: String
    let title: String
    /// What the row is for, hidden until its icon is tapped.
    var caption: String?
    /// Something the row has to report, always shown.
    var status: String?
    @ViewBuilder var trailing: Trailing

    @State private var showsCaption = false

    var body: some View {
        HStack(spacing: 12) {
            SettingsCaptionIcon(symbol: symbol, hasCaption: caption != nil, showsCaption: $showsCaption)
            SettingsRowText(title: title, caption: caption, status: status, showsCaption: showsCaption)
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: SettingsLayout.rowHeight)
        .settingsRowInset()
        .contentShape(Rectangle())
        .accessibilityHint(caption.map { Text(catalog: $0) } ?? Text(verbatim: ""))
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(symbol: String, title: String, caption: String? = nil, status: String? = nil) {
        self.init(symbol: symbol, title: title, caption: caption, status: status) { EmptyView() }
    }
}

extension SettingsRow where Trailing == Text {
    /// A row with a grey value at its end ("On", "1.0.0").
    init(symbol: String, title: String, caption: String? = nil, status: String? = nil, value: String) {
        self.init(symbol: symbol, title: title, caption: caption, status: status) {
            Text(catalog: value)
                .font(.starhash(.body))
                .foregroundStyle(Color.starhashSecondaryText)
        }
    }
}

/// The row's title (16pt medium, as GO Club's) over its status line and,
/// while shown, its description.
struct SettingsRowText: View {
    let title: String
    var caption: String?
    var status: String?
    var showsCaption = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(catalog: title)
                .starhashFont(16, weight: .medium, relativeTo: .callout)
                .foregroundStyle(Color.starhashPrimaryText)
            if let status {
                line(status)
            }
            if let caption, showsCaption {
                line(caption)
                    .transition(SettingsCaptionMotion.transition)
            }
        }
        .padding(.vertical, 11)
    }

    private func line(_ text: String) -> some View {
        Text(catalog: text)
            .starhashFont(13.5, weight: .medium, relativeTo: .footnote)
            .foregroundStyle(Color.starhashTertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A row with a switch: icon, title, toggle. The whole row is the toggle's
/// label, so VoiceOver reads it as one switch; its icon shows and hides
/// the description, as every row's does.
struct SettingsToggleRow: View {
    let symbol: String
    let title: String
    var caption: String?
    var status: String?
    @Binding var isOn: Bool

    @State private var showsCaption = false

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                SettingsCaptionIcon(symbol: symbol, hasCaption: caption != nil, showsCaption: $showsCaption)
                SettingsRowText(title: title, caption: caption, status: status, showsCaption: showsCaption)
            }
        }
        .tint(Color.settingsToggleOn)
        .frame(minHeight: SettingsLayout.rowHeight)
        .settingsRowInset()
        .accessibilityHint(caption.map { Text(catalog: $0) } ?? Text(verbatim: ""))
    }
}

/// A section's title above its card: small, medium and grey, in line with
/// the rows' icons (`SettingsCard` puts it there).
struct SettingsSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(catalog: title)
            .starhashFont(14, weight: .medium, relativeTo: .subheadline)
            .foregroundStyle(Color.starhashSecondaryText)
            .padding(.top, 12)
            .padding(.bottom, 8)
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

