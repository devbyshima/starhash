import StarHashKit
import SwiftUI
import UniformTypeIdentifiers

/// The Report as a PDF, made only when the share sheet asks for it: one
/// tall page of the same cards the screen shows, in light mode, with every
/// category listed, so it reads the same printed or sent on.
struct ReportPDF: Transferable {
    let report: SpendingReport
    let title: String
    let calendar: Calendar

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { pdf in
            SentTransferredFile(try await pdf.render())
        }
    }

    /// The page's width: an iPhone's, so the cards lay out as on screen.
    private static let width: CGFloat = 430

    @MainActor
    func render() throws -> URL {
        let content = ReportExportPage(report: report, title: title, calendar: calendar)
            .environment(\.colorScheme, .light)
            .environment(\.locale, .starhash)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: Self.width, height: nil)

        let folder = FileManager.default.temporaryDirectory.appending(path: "Report", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = title.replacingOccurrences(of: "/", with: "-")
        let url = folder.appending(path: "\(name).pdf")
        try? FileManager.default.removeItem(at: url)

        var wrote = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            wrote = true
        }
        guard wrote else { throw CocoaError(.fileWriteUnknown) }
        return url
    }
}

/// What the PDF draws: StarHash's mark and the report's name, then its
/// cards.
private struct ReportExportPage: View {
    let report: SpendingReport
    let title: String
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                StarHashMarkShape()
                    .fill(Color.starhashPrimaryText)
                    .frame(width: 30, height: 30)
                Text(title)
                    .starhashFont(20, weight: .bold, relativeTo: .title3)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ReportContent(report: report, calendar: calendar, rollsDigits: false, onOpen: nil, isExport: true)
        }
        .padding(20)
        .frame(width: 430)
        .background(Color.starhashBackground)
    }
}
