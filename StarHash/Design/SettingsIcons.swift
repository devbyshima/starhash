import SwiftUI

/// The Settings rows' icons: soft glass squircles in the brand green, drawn
/// by the tasteful-icons skill from `scripts/settings_icons.json`, one for
/// each SF Symbol a row uses. Each sits in the asset catalog's
/// `SettingsIcons` folder under its symbol's name with the dots turned to
/// hyphens, so a row goes on naming its SF Symbol and finds the drawing
/// from that.
///
/// To change one, edit the spec, build it with the skill's script
/// (`tasteful_icons.py build OUT --spec scripts/settings_icons.json
/// --sizes 1024,256`) and copy each `png@256` file over its imageset's.
enum SettingsIcons {
    /// Every symbol with a drawing. A new one needs its entry in the spec
    /// as well as here, or its row falls back to the plain tile.
    static let symbols: Set<String> = [
        "arrow.counterclockwise",
        "arrow.down.circle.fill",
        "bell.badge.fill",
        "bell.fill",
        "bell.slash.fill",
        "bubble.left.and.bubble.right.fill",
        "calendar",
        "chart.bar.fill",
        "chart.line.uptrend.xyaxis",
        "checkmark.message.fill",
        "checkmark.seal.fill",
        "chevron.left.forwardslash.chevron.right",
        "circle.lefthalf.filled",
        "clock.arrow.circlepath",
        "doc.text.fill",
        "envelope.open.fill",
        "exclamationmark.shield.fill",
        "eye.fill",
        "faceid",
        "flag.fill",
        "globe",
        "hourglass",
        "house.fill",
        "lightbulb.fill",
        "location.fill",
        "lock.fill",
        "person.crop.circle.fill",
        "play.circle.fill",
        "questionmark.bubble.fill",
        "shippingbox.fill",
        "sparkles",
        "speaker.wave.2.fill",
        "square.and.arrow.down.fill",
        "square.and.arrow.up.fill",
        "star.fill",
        "sunset.fill",
        "touchid",
        "tray.full.fill",
    ]

    /// The asset drawn for an SF Symbol ("SettingsIcons/tray-full-fill" for
    /// "tray.full.fill"), or nil when there is none.
    static func assetName(for symbol: String) -> String? {
        guard symbols.contains(symbol) else { return nil }
        return "SettingsIcons/" + symbol.replacingOccurrences(of: ".", with: "-")
    }
}

/// A Settings row's icon, `size` points square. The drawings carry their
/// own tile, so nothing goes behind them. A symbol without one still gets a
/// tile of the same shape, the symbol in white on the switch colour, so a
/// new row looks of a piece with the rest until its drawing is made.
struct SettingsIconImage: View {
    let symbol: String
    var size: CGFloat = 38

    var body: some View {
        if let name = SettingsIcons.assetName(for: symbol) {
            // Drawn at 256px and shown at about 38pt, so high interpolation
            // keeps the glass edge smooth as it shrinks.
            Image(name)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: symbol)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.starhashSwitchOn, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}
