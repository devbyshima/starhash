import StarHashKit
import SwiftUI

/// A document in Settings, More: its symbol on a tile, its title and the
/// day it took effect, all centred, a line on what it covers, then its
/// sections on one card, and a way to ask about it.
struct LegalDocument {
    struct Section {
        let title: String
        let text: String
    }

    let title: String
    let symbol: String
    /// "yyyy-MM-dd", in Kigali.
    let effective: String
    let summary: String
    let sections: [Section]
}

struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        SettingsScroll(spacing: 28, top: 8) {
            header
            SettingsCard {
                ForEach(Array(document.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(catalog: section.title)
                            .starhashFont(16, weight: .semibold, relativeTo: .callout)
                            .foregroundStyle(Color.starhashPrimaryText)
                            .accessibilityAddTraits(.isHeader)
                        Text(catalog: section.text)
                            .starhashFont(14.5, relativeTo: .subheadline)
                            .lineSpacing(2)
                            .foregroundStyle(Color.starhashSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 18)
                    .settingsRowInset()
                }
            }
            SettingsCard {
                Link(destination: DeveloperNoteLinks.write) {
                    SettingsRow(symbol: "bubble.left.and.bubble.right.fill", title: "Questions?", caption: "Ask on StarHash's GitHub page") {
                        SettingsChevron(symbol: "arrow.up.right")
                    }
                }
                .buttonStyle(HighlightRowButtonStyle())
                .accessibilityHint("Opens a new issue on GitHub")
            }
        }
        .settingsPage(document.title)
    }

    private var header: some View {
        VStack(spacing: 0) {
            SettingsSymbol(symbol: document.symbol, size: 64, pointSize: 28)
                .padding(.bottom, 18)
            Text(catalog: document.title)
                .starhashFont(30, weight: .bold, relativeTo: .title)
                .foregroundStyle(Color.starhashPrimaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Effective \(KigaliDay.text(document.effective))")
                .starhashFont(13.5, weight: .semibold, relativeTo: .footnote)
                .foregroundStyle(Color.starhashSecondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.settingsTile, in: Capsule())
                .padding(.top, 10)
            Text(catalog: document.summary)
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

/// The terms of using StarHash.
struct TermsOfServiceView: View {
    var body: some View {
        LegalDocumentView(document: .termsOfService)
    }
}

/// What StarHash keeps, where, and what it never does with it.
struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(document: .privacyPolicy)
    }
}

extension LegalDocument {
    static let termsOfService = LegalDocument(
        title: "Terms of Service",
        symbol: "doc.text.fill",
        effective: "2026-10-05",
        summary: "The terms for using StarHash, in plain words.",
        sections: [
            .init(
                title: "Using StarHash",
                text: "StarHash is a free app that helps you pay with MTN MoMo and Airtel Money in Rwanda: it fills in the USSD code your wallet uses and opens your iPhone's dialer. By using StarHash you agree to these terms. If you do not agree, please do not use it."
            ),
            .init(
                title: "Your wallet, your payments",
                text: "StarHash never holds, sends or receives money. Every payment is made by your mobile money provider, after you check its details on the provider's own prompt and enter your PIN there. Check the amount and who it goes to before you confirm. A payment you confirm is between you and your provider, under its own terms and fees."
            ),
            .init(
                title: "Not affiliated",
                text: "StarHash is an independent app. It is not made, endorsed or supported by MTN Group, MTN Rwanda, Airtel Africa or Airtel Rwanda. MTN, MoMo, Airtel and Airtel Money are their owners' trademarks, used only to name the services StarHash works with."
            ),
            .init(
                title: "Codes, fees and records",
                text: "The USSD codes, fees and limits StarHash uses come from the providers' published information, and the providers may change them without notice. Activity is a record kept for you, from what you dial and the messages you pass to StarHash; your provider's records are the ones that count. With auto-verify on, a payment that no message confirms within an hour is marked failed; if it did go through, mark it as confirmed. StarHash's reminders and summaries are worked out from that record, and iOS decides when they show: a reminder that is late or never comes says nothing about whether a payment went through."
            ),
            .init(
                title: "Free, with source available",
                text: "StarHash is free, with no account, subscription or advertising. Its source code is published under the PolyForm Noncommercial License 1.0.0, which lets you use and change the code for any non-commercial purpose."
            ),
            .init(
                title: "No warranty",
                text: "StarHash is provided as it is, without warranty of any kind. As far as the law allows, its developer is not liable for any loss from using it, including a payment sent to the wrong person or for the wrong amount, a failed or delayed payment, a record that is missing or wrong, or a notification that is late, missing or wrong."
            ),
            .init(
                title: "Your iPhone and your PIN",
                text: "You are responsible for your iPhone, its passcode and who can use it. StarHash's Face ID lock keeps Activity private, but your wallet is protected by your PIN. Never share your PIN with anyone, including someone who says they are from StarHash or your provider."
            ),
            .init(
                title: "Changes to these terms",
                text: "These terms may change as StarHash does. The current terms are always here, with the day they took effect, and using StarHash after a change means you accept them."
            ),
        ]
    )

    static let privacyPolicy = LegalDocument(
        title: "Privacy Policy",
        symbol: "lock.fill",
        effective: "2026-10-05",
        summary: "StarHash has no account, no server and no tracking. What it keeps stays on your iPhone.",
        sections: [
            .init(
                title: "What StarHash keeps",
                text: "Your transactions (who, how much, when, whether they are confirmed, and the fee, reference and balance when a message gives them), the categories you add, your recent recipients, Buy's codes and your settings. All of it is saved in StarHash's own storage on your iPhone, and none of it is sent anywhere."
            ),
            .init(
                title: "Contacts",
                text: "With your permission, StarHash reads your contacts to show who you can pay and to put names and photos on your payments. They are read on your iPhone only and never copied off it."
            ),
            .init(
                title: "Location",
                text: "Only if you turn on Nearby, and only while you pay. When you pay a merchant code, or a number that is not in your contacts, StarHash notes where the payment was made, to show it on a map and to suggest it when you are back there. Paying one of your contacts never records where you were. Where a payment was made is kept with that payment, on your iPhone and in your backups as your transactions are. Turning Nearby off erases it."
            ),
            .init(
                title: "Messages",
                text: "StarHash cannot read your SMS. If you set up auto-verify, your own Shortcuts automation passes messages containing RWF to StarHash, which reads them on your iPhone to confirm payments. Messages that are not MTN MoMo or Airtel Money transactions are ignored and not kept."
            ),
            .init(
                title: "Notifications",
                text: "Only if you allow them, which StarHash asks once as you set it up. It makes its reminders and summaries on your iPhone from the transactions it already keeps; nothing is sent to it from a server. Choose on its Notifications page what they tell you of, and whether they show amounts on your Lock Screen."
            ),
            .init(
                title: "Face ID",
                text: "If you turn on the lock, iOS checks your Face ID, Touch ID or passcode. StarHash never sees your face or fingerprint; it is only told whether the check passed."
            ),
            .init(
                title: "What StarHash shares",
                text: "Nothing. It has no analytics, no advertising and no third-party code that collects data. Request a Feature and the source code open GitHub in your browser, under GitHub's own privacy policy, and every code you dial goes through your phone and your provider, under theirs."
            ),
            .init(
                title: "Backups",
                text: "Your transactions (with where each was paid, when Nearby is on) and settings are part of your iPhone's own backups, to iCloud or your computer, which you control."
            ),
            .init(
                title: "Your choices",
                text: "In Settings you can stop StarHash saving transactions, using contacts, remembering recent recipients, Nearby, auto-verify and each of its notifications at any time. You can delete any transaction, or erase everything with Delete All Data. Deleting the app removes it all too."
            ),
            .init(
                title: "Children",
                text: "StarHash is meant for people old enough to have a mobile money account, and is not directed at children."
            ),
            .init(
                title: "Changes to this policy",
                text: "Any change to this policy will be shown here, with the day it took effect."
            ),
        ]
    )
}
