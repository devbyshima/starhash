import StarHashKit
import SwiftUI

/// Changes the owner's MTN MoMo number (a new SIM), from My Wallets. The
/// number is first asked for in onboarding; nothing leaves the phone.
struct MoMoNumberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.ownerNumber) private var ownerNumber = ""

    @State private var input = ""
    @FocusState private var isFocused: Bool

    private var number: String? { Recipient.ownMoMoNumber(from: input) }
    private var showsError: Bool { input.filter(\.isNumber).count >= 9 && number == nil }

    var body: some View {
        VStack(spacing: 0) {
            StarHashSheetHeader(title: "MoMo Number") {
                StarHashCircleButton("xmark", label: "Cancel") { dismiss() }
            } trailing: {
                StarHashConfirmButton("Save", isEnabled: number != nil) { save() }
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 10) {
                StarHashCard {
                    HStack(spacing: 12) {
                        Text("Number")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.starhashPrimaryText)
                        TextField("Number", text: $input, prompt: Text("078 123 4567"))
                            .keyboardType(.numberPad)
                            .textContentType(.telephoneNumber)
                            .multilineTextAlignment(.trailing)
                            .focused($isFocused)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                }
                Text(showsError
                     ? "Enter an MTN number, starting with 078 or 079."
                     : "StarHash pays from this MTN number. It stays on this iPhone.")
                    .starhashFont(13, relativeTo: .footnote)
                    .foregroundStyle(showsError ? Color.starhashDestructive : Color.starhashCaptionText)
                    .padding(.horizontal, 16)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .presentationDetents([.medium])
        .starhashSheetChrome()
        .onAppear {
            input = Recipient(input: ownerNumber)?.formattedDestination ?? ownerNumber
            isFocused = true
        }
    }

    private func save() {
        guard let number else { return }
        ownerNumber = number
        dismiss()
    }
}
