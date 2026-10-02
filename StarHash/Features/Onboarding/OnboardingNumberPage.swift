import StarHashKit
import SwiftUI

/// Onboarding's one question about the owner: their MTN MoMo number. It is
/// the wallet StarHash pays from and what the side menu shows. (The name
/// registered on it is not asked for: the person should not have to type
/// what MTN already knows.) Also shown on its own after an update, to an
/// install that finished onboarding before this page existed.
struct OnboardingNumberPage: View {
    var buttonTitle = "Continue"
    let onDone: () -> Void

    @AppStorage(PreferenceKey.ownerNumber) private var ownerNumber = ""
    @State private var input = ""
    @FocusState private var isFocused: Bool

    private var number: String? { Recipient.ownMoMoNumber(from: input) }
    private var showsError: Bool { input.filter(\.isNumber).count >= 9 && number == nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Image(systemName: "simcard.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(Color.starhashPrimaryText)
                        .frame(width: 84, height: 84)
                        .background(OnboardingPalette.tile, in: Circle())
                        .accessibilityHidden(true)
                        .padding(.top, 56)

                    Text("Your MoMo Number")
                        .font(.starhashTitle)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 24)
                    Text("StarHash pays from this MTN number. It stays on your iPhone.")
                        .font(.body)
                        .foregroundStyle(Color.starhashSecondaryText)
                        .padding(.top, 8)

                    field
                        .padding(.top, 32)

                    Text(showsError ? "Enter an MTN number, starting with 078 or 079." : " ")
                        .font(.footnote)
                        .foregroundStyle(Color.starhashDestructive)
                        .padding(.top, 10)
                        .accessibilityHidden(!showsError)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button(buttonTitle, action: save)
                .buttonStyle(.starhashPrimary)
                .disabled(number == nil)
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.bottom, 8)
        }
        .onAppear {
            if input.isEmpty { input = ownerNumber }
            isFocused = true
        }
    }

    private var field: some View {
        TextField("078 123 4567", text: $input)
            .keyboardType(.numberPad)
            .textContentType(.telephoneNumber)
            .focused($isFocused)
            .starhashFont(24, weight: .semibold, relativeTo: .title2)
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .frame(minHeight: 64)
            .background(OnboardingPalette.pill, in: Capsule())
            .overlay(Capsule().strokeBorder(OnboardingPalette.pillRimBottom, lineWidth: 1))
            .accessibilityLabel("MoMo number")
    }

    private func save() {
        guard let number else { return }
        ownerNumber = number
        isFocused = false
        onDone()
    }
}
