import StarHashKit
import SwiftUI

/// Shown once to owners who set StarHash up before Show My Name came, since
/// it starts on: who now sees their name and photo, and where to turn it
/// off. Got It keeps it on; Turn Off turns it off there and then. New
/// owners are told on onboarding's number page instead.
struct ShowMyNameNoticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Preferences.showMyName) private var showMyName: Bool
    @State private var height: CGFloat = 400

    private var points: [(symbol: String, text: String)] {
        [
            ("eye.fill", String(starhash: "People who type your number in StarHash see your name and photo")),
            ("gearshape.fill", String(starhash: "Turn it off any time in Settings, under Your SIMs")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(String(starhash: "Your name on StarHash"))

            // Room to breathe: the card well below the title, each point in
            // a row of its own height, and the buttons apart from the card.
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        if index > 0 { SheetDivider().padding(.leading, 54) }
                        HStack(spacing: 16) {
                            SheetIconCircle(symbol: point.symbol)
                            Text(verbatim: point.text)
                                .font(.sheetBody)
                                .lineSpacing(2)
                                .foregroundStyle(Color.starhashPrimaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 14)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .sheetCard()

                VStack(spacing: 6) {
                    Button("Got It") { dismiss() }
                        .buttonStyle(.sheetPrimary)
                    SheetTextButton("Turn Off") {
                        showMyName = false
                        dismiss()
                    }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
    }

    /// `-showMyNameNotice` (DEBUG) shows it at launch, for screenshots.
    static var forcedAtLaunch: Bool {
        #if DEBUG
        DebugLaunch.arguments.contains("-showMyNameNotice")
        #else
        false
        #endif
    }
}
