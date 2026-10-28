import SwiftUI

/// About StarHash, Licences, laid out as a third-party notice: StarHash's
/// own licence first, then everything it is built with that is not its
/// own as a list, each by its name and version with its licence, a row
/// that opens the piece's own page (`LicenceView`) with the licence's full
/// text. Then the carriers' marks. The licences' own words stay in
/// English, as their authors publish them.
struct LicencesView: View {
    private static let polyForm = URL(string: "https://polyformproject.org/licenses/noncommercial/1.0.0")!

    var body: some View {
        SettingsScroll(spacing: 28, top: 8) {
            LicencesHeader(symbol: "doc.text.fill", title: Text("Licences"))

            SettingsCard("StarHash") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "StarHash")
                        .starhashFont(16, weight: .semibold, relativeTo: .callout)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: "Copyright (c) 2026 Shima")
                    Text(verbatim: "PolyForm Noncommercial License 1.0.0")
                }
                .starhashFont(14.5, relativeTo: .subheadline)
                .foregroundStyle(Color.starhashSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .settingsRowInset()
                LicenceLinkRow(title: "PolyForm Noncommercial", symbol: "doc.text.fill", url: Self.polyForm)
                LicenceLinkRow(title: "Source code", symbol: "chevron.left.forwardslash.chevron.right", url: SettingsLinks.sourceCode)
            }

            SettingsCard("Built with") {
                LicenceParagraph(text: Text("StarHash is built with the work of others, which goes out with it under their own terms: each piece below, by its name and version, with its licence, and that licence's text where it has one."))
                ForEach(ThirdPartyPiece.all) { piece in
                    SettingsLinkRow(
                        page: .licence(piece),
                        symbol: piece.symbol,
                        title: piece.name,
                        status: "\(piece.version) · \(piece.licence)"
                    )
                }
            }

            SettingsCard("Trademarks") {
                LicenceParagraph(text: Text("MTN, MoMo, Airtel and Airtel Money, and their logos, are their owners' trademarks, shown only to name the wallets StarHash works with."))
            }
        }
        .settingsPage("Licences")
    }
}

/// One piece's page, as a third-party notice gives it: its name and
/// version, the licence it comes under and where it comes from, then the
/// licence's full text from the copy bundled beside it, as the licence
/// asks of an app that ships the piece (the OFL's FAQ 1.20 for a font).
struct LicenceView: View {
    let piece: ThirdPartyPiece
    private let text: String?

    init(piece: ThirdPartyPiece) {
        self.piece = piece
        text = piece.text
    }

    var body: some View {
        SettingsScroll(spacing: 28, top: 8) {
            LicencesHeader(symbol: piece.symbol, title: Text(verbatim: piece.name))

            SettingsCard {
                SettingsRow(symbol: "number", title: "Version", value: piece.version)
                SettingsRow(symbol: "doc.text.fill", title: "Licence", value: piece.licence)
                LicenceLinkRow(title: "Source", symbol: "chevron.left.forwardslash.chevron.right", url: piece.source)
                LicenceLinkRow(title: piece.licenceName, symbol: "doc.text.fill", url: piece.licenceURL)
            }

            if let text {
                SettingsCard("Licence text") {
                    Text(verbatim: text)
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
        }
        .settingsPage(piece.name)
    }
}

/// A piece StarHash ships that is not its own, by what a third-party
/// notice gives for it: its name and version as its authors give them, the
/// licence's SPDX id and name, where it comes from, and the licence's text,
/// bundled beside it. Anything new that is not StarHash's own (a font, an
/// image, a package) gets one in `all`, and its licence file in the bundle.
struct ThirdPartyPiece: Identifiable, Hashable {
    let name: String
    let version: String
    let symbol: String
    /// The licence's SPDX id ("OFL-1.1").
    let licence: String
    let licenceName: String
    let licenceURL: URL
    let source: URL
    /// The licence's text in the bundle, a .txt file by this name.
    let textFile: String

    var id: String { name }

    static let all: [ThirdPartyPiece] = [spaceGrotesk]

    static let spaceGrotesk = ThirdPartyPiece(
        name: "Space Grotesk",
        // The bundled font's own version, from its name table.
        version: "2.000",
        symbol: "doc.text.fill",
        licence: "OFL-1.1",
        licenceName: "SIL Open Font License",
        licenceURL: URL(string: "https://openfontlicense.org")!,
        source: URL(string: "https://github.com/floriankarsten/space-grotesk")!,
        textFile: "OFL"
    )

    /// The licence's text as its authors ship it, reflowed to the screen,
    /// or nil if the bundle has no copy.
    var text: String? {
        Bundle.main.url(forResource: textFile, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            .map(Self.reflowed)
    }

    /// The licence's words as they are, but each paragraph on one line, so
    /// it wraps to the phone's width rather than at the file's 70
    /// characters, a heading in capitals ("PREAMBLE") on a line of its
    /// own, and without the dashed rules, which only frame its title in a
    /// text file.
    static func reflowed(_ text: String) -> String {
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
    private static func isHeading(_ line: String) -> Bool {
        line.contains(where: \.isLetter) && line == line.uppercased()
    }
}

/// The icon and title at the top of the list and of each piece's page.
private struct LicencesHeader: View {
    let symbol: String
    let title: Text

    var body: some View {
        VStack(spacing: 0) {
            SettingsSymbol(symbol: symbol, size: 64)
                .padding(.bottom, 18)
            title
                .starhashFont(30, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

/// A card's words in a row of their own: the list's opening, the
/// trademarks.
private struct LicenceParagraph: View {
    let text: Text

    var body: some View {
        text
            .starhashFont(14.5, relativeTo: .subheadline)
            .lineSpacing(2)
            .foregroundStyle(Color.starhashSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
            .settingsRowInset()
    }
}

/// A row that leaves the app for a web page.
private struct LicenceLinkRow: View {
    let title: String
    let symbol: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            SettingsRow(symbol: symbol, title: title) {
                SettingsChevron(symbol: "arrow.up.right")
            }
        }
        .buttonStyle(HighlightRowButtonStyle())
    }
}
