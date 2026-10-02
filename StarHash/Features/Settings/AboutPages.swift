import StarHashKit
import SwiftUI

/// How StarHash works: the three steps of a payment and how the history is
/// kept, as numbered cards.
struct HowStarHashWorksView: View {
    private let steps: [(symbol: String, title: String, text: String)] = [
        ("number", "Type an amount", "Enter what you want to pay on the keypad. Balance checks your MoMo balance with *182*6*1#."),
        ("person.fill", "Pick who", "Choose a contact, a recent recipient, or type a number or merchant code. Ten digits or more is a phone number; fewer is a MoMo Pay code."),
        ("phone.fill", "StarHash dials", "StarHash opens the dialer with the right USSD code: *182*1*1*number*amount# to send to MTN, *182*1*2*number*amount# to send to Airtel, *182*8*1*code*amount# to pay a merchant. You confirm with your PIN, as always."),
        ("checkmark.message.fill", "Every payment, logged", "The payment shows in Activity. With auto-verify set up, MTN's confirmation SMS fills in the fee, the reference and your new balance."),
    ]

    var body: some View {
        List {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        SettingsSymbol(symbol: step.symbol)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(index + 1). \(step.title)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.starhashPrimaryText)
                            Text(step.text)
                                .font(.subheadline)
                                .foregroundStyle(Color.starhashSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 16)
                    .accessibilityElement(children: .combine)
                    .settingsCardRow(.single)
                }
            }
            Section {
                SettingsFootnote("StarHash never sees your PIN and never moves money itself. It only fills in the code your phone dials.")
                    .padding(.horizontal, 16)
                    .settingsPlainRow()
            }
        }
        .settingsListStyle(sectionSpacing: 12)
        .settingsPage("How StarHash Works")
    }
}

/// Privacy, in plain words: everything stays on this iPhone.
struct PrivacyView: View {
    private let points: [(symbol: String, title: String, text: String)] = [
        ("iphone", "Everything stays on this iPhone", "Transactions, recipients and your profile are saved on this device only. There is no account, no login and no server."),
        ("person.crop.circle", "Contacts", "Read on your iPhone to show who you can pay. They are never copied or uploaded."),
        ("location", "Location", "Only when Nearby is on, and only while you pay, to show each payment on a map."),
        ("message", "Messages", "StarHash cannot read your SMS. Your own Shortcuts automation passes MTN's confirmation messages to it, and you can turn that off at any time."),
        ("trash", "Your data, your call", "Delete all transactions in Settings, or delete the app to remove everything."),
    ]

    var body: some View {
        List {
            Section {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 12) {
                        SettingsSymbol(symbol: point.symbol)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(point.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.starhashPrimaryText)
                            Text(point.text)
                                .font(.subheadline)
                                .foregroundStyle(Color.starhashSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                    }
                    .padding(.vertical, 16)
                    .accessibilityElement(children: .combine)
                    .settingsCardRow(SettingsCardPosition(index: index, count: points.count))
                }
            }
        }
        .settingsListStyle()
        .settingsPage("Privacy")
    }
}
