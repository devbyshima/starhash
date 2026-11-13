import SwiftUI

/// A Settings row's icon, in a `size` point square: StarHash's icon for the
/// row's SF Symbol (`Image(symbol:)`), alone in the accent with no tile
/// behind it, as Buy's codes wear theirs.
struct SettingsIconImage: View {
    let symbol: String
    var size: CGFloat = 38

    var body: some View {
        Image(symbol: symbol)
            // 22pt in the usual 36pt square, as Buy's code icons.
            .font(.system(size: size * 0.6))
            .foregroundStyle(Color.starhashAccentGraphic)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
