import StarHashKit
import SwiftUI

/// Every release, newest first, as in Keaser.
struct WhatsNewView: View {
    var body: some View {
        let releases = ReleaseHistory.releases
        List {
            Section {
                ForEach(Array(releases.enumerated()), id: \.element.id) { index, release in
                    NavigationLink(value: SettingsPage.release(release.version)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(release.title)
                                .font(.starhash(.body))
                                .foregroundStyle(Color.starhashPrimaryText)
                            Text(release.date)
                                .font(.starhash(.footnote))
                                .foregroundStyle(Color.starhashSecondaryText)
                        }
                        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                    }
                    .settingsCardRow(SettingsCardPosition(index: index, count: releases.count), insets: .settingsTextRow)
                }
            }
        }
        .settingsListStyle()
        .settingsPage("What's New")
    }
}

/// What one release brought: the version large, its date and a line about
/// it, then each highlight with its symbol.
struct ReleaseDetailView: View {
    let version: String

    var body: some View {
        let release = ReleaseHistory.releases.first { $0.version == version }
        List {
            if let release {
                Section {
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
                    .settingsPlainRow()
                }

                Section {
                    ForEach(Array(release.highlights.enumerated()), id: \.offset) { index, highlight in
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
                            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .settingsCardRow(SettingsCardPosition(index: index, count: release.highlights.count))
                    }
                }
            }
        }
        .settingsListStyle(sectionSpacing: 20)
        .settingsPage(release?.title ?? "What's New")
    }
}
