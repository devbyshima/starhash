import StarHashKit
import SwiftUI

/// Every release, newest first: each on a row with its symbol on a tile,
/// the version and the day it shipped, the newest marked Latest.
struct WhatsNewView: View {
    var body: some View {
        let releases = ReleaseHistory.releases
        SettingsScroll {
            SettingsCard {
                ForEach(releases) { release in
                    NavigationLink(value: SettingsPage.release(release.version)) {
                        HStack(spacing: 14) {
                            SettingsSymbol(symbol: "sparkles", size: 44, pointSize: 19)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Version \(release.version)")
                                    .starhashFont(16, weight: .semibold, relativeTo: .callout)
                                    .foregroundStyle(Color.starhashPrimaryText)
                                Text(KigaliDay.text(release.date))
                                    .starhashFont(13.5, relativeTo: .footnote)
                                    .foregroundStyle(Color.starhashTertiaryText)
                            }
                            Spacer(minLength: 8)
                            if release.id == releases.first?.id {
                                ReleaseLatestTag()
                            }
                            SettingsChevron()
                        }
                        .padding(.vertical, 14)
                        .frame(minHeight: 72)
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

/// What one release brought: StarHash's mark, the version, the day it
/// shipped and a line about it, all centred, then each highlight on a card,
/// its symbol on a tile centred against its title and words.
struct ReleaseDetailView: View {
    let version: String

    var body: some View {
        let release = ReleaseHistory.releases.first { $0.version == version }
        SettingsScroll(spacing: 28, top: 8) {
            if let release {
                header(release)
                SettingsCard {
                    ForEach(Array(release.highlights.enumerated()), id: \.offset) { _, highlight in
                        ReleaseHighlightRow(highlight: highlight)
                    }
                }
            }
        }
        .settingsPage("Release Notes")
    }

    private func header(_ release: Release) -> some View {
        VStack(spacing: 0) {
            StarHashMark(size: 64)
                .padding(.bottom, 18)
            Text("Version \(release.version)")
                .starhashFont(30, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color.starhashPrimaryText)
                .accessibilityAddTraits(.isHeader)
            Text(KigaliDay.text(release.date))
                .starhashFont(13.5, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(Color.starhashSecondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.settingsTile, in: Capsule())
                .padding(.top, 10)
            Text(release.summary)
                .font(.starhash(.body))
                .foregroundStyle(Color.starhashSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

/// One highlight: its symbol on a tile, centred against the title and the
/// words under it, however many lines they run to.
private struct ReleaseHighlightRow: View {
    let highlight: Release.Highlight

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SettingsSymbol(symbol: highlight.symbol, size: 46, pointSize: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(highlight.title)
                    .starhashFont(16, weight: .semibold, relativeTo: .callout)
                    .foregroundStyle(Color.starhashPrimaryText)
                Text(highlight.detail)
                    .starhashFont(14, relativeTo: .subheadline)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 18)
        .settingsRowInset()
        .accessibilityElement(children: .combine)
    }
}

/// The newest release's small tag.
private struct ReleaseLatestTag: View {
    var body: some View {
        Text("Latest")
            .starhashFont(12, weight: .bold, relativeTo: .caption)
            .foregroundStyle(Color.starhashOnInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.starhashInk, in: Capsule())
    }
}

/// A day kept as "yyyy-MM-dd" (a release, a document taking effect), as
/// the reader writes dates ("2 October 2026"), read as the Kigali day it
/// was, whatever zone the iPhone is in.
enum KigaliDay {
    static func text(_ date: String) -> String {
        let kigali = TimeZone(identifier: "Africa/Kigali") ?? .current
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = kigali
        parser.dateFormat = "yyyy-MM-dd"
        guard let day = parser.date(from: date) else { return date }
        var style = Date.FormatStyle.dateTime.day().month(.wide).year()
        style.timeZone = kigali
        return day.formatted(style)
    }
}
