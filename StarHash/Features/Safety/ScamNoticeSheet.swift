import StarHashKit
import SwiftUI

/// What a scam warning's notification opens: what the message claimed, and
/// how the trick goes, so nothing is sent back on its word. Beam's sheet
/// language, as every sheet.
struct ScamNoticeSheet: View {
    let notice: ScamNotice

    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn
    @State private var height: CGFloat = 0

    private var tips: [(symbol: String, text: String)] {
        [
            ("person.crop.circle.badge.exclamationmark", String(starhash: "\(wallet.walletName)'s own messages come from \(wallet.messagesName), never from a phone number.")),
            ("arrow.uturn.backward.circle", String(starhash: "Someone who says they sent you money by mistake and asks for it back is the usual trick.")),
            ("banknote", String(starhash: "Check your balance with your wallet before you send anything back.")),
            ("lock.shield", String(starhash: "Never share your PIN. Your wallet never asks for it in a message or a call.")),
        ]
    }

    var body: some View {
        VStack(spacing: 18) {
            SheetHeader(String(starhash: "This may be a scam"))
            if !notice.message.isEmpty {
                Text(notice.message)
                    .font(.sheetBody)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .sheetCard()
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(tips, id: \.text) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        SheetIconCircle(symbol: tip.symbol, tint: .starhashDestructive)
                        Text(tip.text)
                            .font(.sheetBody)
                            .foregroundStyle(Color.starhashPrimaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(starhash: "Check Balance")) {
                Task { _ = await USSDDialer.dial(USSD.balance(for: wallet)) }
                dismiss()
            }
            .buttonStyle(.sheetPrimary)
            SheetTextButton(String(starhash: "Close")) { dismiss() }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .sheetHeight($height)
        .sheetGlass(detents: [.height(max(height, 300) + 8)])
    }
}
