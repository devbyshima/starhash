import StarHashKit
import SwiftUI

/// Every release, newest first, as in Keaser.
struct WhatsNewView: View {
    var body: some View {
        let releases = ReleaseHistory.releases
        SettingsScroll {
            SettingsCard {
                ForEach(releases) { release in
                    NavigationLink(value: SettingsPage.release(release.version)) {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(release.title)
                                    .font(.starhash(.body))
                                    .foregroundStyle(Color.starhashPrimaryText)
                                Text(release.date)
                                    .font(.starhash(.footnote))
                                    .foregroundStyle(Color.starhashSecondaryText)
                            }
                            Spacer(minLength: 8)
                            SettingsChevron()
                        }
                        .frame(minHeight: 66)
                        .settingsRowInset()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HighlightRowButtonStyle(pressHaptic: false))
                }
            }
        }
        .settingsPage("What's New")
    }
}

/// What one release brought: the version large, its date and a line about
/// it, then each highlight with its symbol.
struct ReleaseDetailView: View {
    let version: String

    var body: some View {
        let release = ReleaseHistory.releases.first { $0.version == version }
        SettingsScroll(spacing: 20) {
            if let release {
                VStack(alignment: .leading, spacing: 6) {
                    Text(release.title)
                        .starhashFont(28, weight: .bold, relativeTo: .title)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .accessibilityAddTraits(.isHeader)
                    Text(release.date)
                        .font(.starhash(.subheadline))
                        .foregroundStyle(Color.starhashSecondaryText)
                    Text(release.summary)
                        .font(.starhash(.body))
                        .foregroundStyle(Color.starhashPrimaryText.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

                SettingsCard {
                    ForEach(Array(release.highlights.enumerated()), id: \.offset) { _, highlight in
                        HStack(alignment: .top, spacing: 13) {
                            SettingsSymbol(symbol: highlight.symbol)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(highlight.title)
                                    .starhashFont(17, weight: .semibold, relativeTo: .headline)
                                    .foregroundStyle(Color.starhashPrimaryText)
                                Text(highlight.detail)
                                    .font(.starhash(.subheadline))
                                    .foregroundStyle(Color.starhashSecondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 12)
                        .settingsRowInset()
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .settingsPage(release?.title ?? "What's New")
    }
}
