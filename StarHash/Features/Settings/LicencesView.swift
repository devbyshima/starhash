import SwiftUI

/// About StarHash, Licences: what StarHash is built with that is not its
/// own, and the terms each comes under. Space Grotesk is the one
/// third-party piece the app ships, so its copyright, licence notice and
/// the SIL Open Font License's full text are here, as the OFL asks of an
/// app that bundles the font (OFL FAQ 1.20), read from the copy bundled
/// beside the font. Then StarHash's own licence, and the carriers' marks.
/// The licences' own words stay in English, as their authors publish them.
struct LicencesView: View {
    private static let fontSource = URL(string: "https://github.com/floriankarsten/space-grotesk")!
    private static let ofl = URL(string: "https://openfontlicense.org")!
    private static let polyForm = URL(string: "https://polyformproject.org/licenses/noncommercial/1.0.0")!

    /// The OFL's text, as Space Grotesk's authors ship it, reflowed to the
    /// screen (`reflowed`).
    private let fontLicence = Bundle.main.url(forResource: "OFL", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        .map(Self.reflowed) ?? ""

    /// The licence's words as they are, but each paragraph on one line, so
    /// it wraps to the phone's width rather than at the file's 70
    /// characters, a heading in capitals ("PREAMBLE") on a line of its
    /// own, and without the dashed rules, which only frame its title in a
    /// text file.
    nonisolated static func reflowed(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { paragraph in
                let lines = paragraph.split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { line in !line.isEmpty && !line.allSatisfy { $0 == "-" } }
                guard let first = lines.first, lines.count > 1, isHeading(first) else {
                    return lines.joined(separator: " ")
                }
                return first + "\n" + lines.dropFirst().joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// A line in capitals alone ("PERMISSION & CONDITIONS").
    nonisolated private static func isHeading(_ line: String) -> Bool {
        line.contains(where: \.isLetter) && line == line.uppercased()
    }

    var body: some View {
        SettingsScroll(spacing: 28, top: 8) {
            header

            SettingsCard("Font") {
                entry(
                    name: "Space Grotesk",
                    notice: "Copyright 2020 The Space Grotesk Project Authors",
                    licence: "SIL Open Font License, Version 1.1"
                )
                linkRow("Font's source", symbol: "chevron.left.forwardslash.chevron.right", url: Self.fontSource)
                linkRow("SIL Open Font License", symbol: "doc.text.fill", url: Self.ofl)
            }

            if !fontLicence.isEmpty {
                SettingsCard("Licence text") {
                    Text(verbatim: fontLicence)
                        .starhashFont(13.5, relativeTo: .footnote)
                        .lineSpacing(2)
                        .foregroundStyle(Color.starhashSecondaryText)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                        .settingsRowInset()
                }
            }

            SettingsCard("StarHash") {
                entry(
                    name: "StarHash",
                    notice: "Copyright (c) 2026 Shima",
                    licence: "PolyForm Noncommercial License 1.0.0"
                )
                linkRow("PolyForm Noncommercial", symbol: "doc.text.fill", url: Self.polyForm)
                linkRow("Source code", symbol: "chevron.left.forwardslash.chevron.right", url: SettingsLinks.sourceCode)
            }

            SettingsCard("Trademarks") {
                Text("MTN, MoMo, Airtel and Airtel Money, and their logos, are their owners' trademarks, shown only to name the wallets StarHash works with.")
                    .starhashFont(14.5, relativeTo: .subheadline)
                    .lineSpacing(2)
                    .foregroundStyle(Color.starhashSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
                    .settingsRowInset()
            }
        }
        .settingsPage("Licences")
    }

    private var header: some View {
        VStack(spacing: 0) {
            SettingsSymbol(symbol: "doc.text.fill", size: 64)
                .padding(.bottom, 18)
            Text("Licences")
                .starhashFont(30, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color.starhashPrimaryText)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// A piece's name, its copyright as its authors write it, and the
    /// licence it comes under.
    private func entry(name: String, notice: String, licence: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: name)
                .starhashFont(16, weight: .semibold, relativeTo: .callout)
                .foregroundStyle(Color.starhashPrimaryText)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: notice)
                .starhashFont(14.5, relativeTo: .subheadline)
                .foregroundStyle(Color.starhashSecondaryText)
            Text(verbatim: licence)
                .starhashFont(14.5, relativeTo: .subheadline)
                .foregroundStyle(Color.starhashSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .settingsRowInset()
    }

    private func linkRow(_ title: String, symbol: String, url: URL) -> some View {
        Link(destination: url) {
            SettingsRow(symbol: symbol, title: title) {
                SettingsChevron(symbol: "arrow.up.right")
            }
        }
        .buttonStyle(HighlightRowButtonStyle())
    }
}
