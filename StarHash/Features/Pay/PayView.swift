import StarHashKit
import SwiftUI

/// The Pay tab: type an amount, tap Pay, pick who gets it on the screen
/// that slides in, and StarHash dials the MoMo code. The system's call
/// prompt, showing the whole code, is the approval; MoMo then asks for the
/// PIN. Balance dials the balance code. Nothing is sent by StarHash itself.
struct PayView: View {
    @Environment(StarHashStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage(PreferenceKey.saveTransactions) private var saveTransactions = true
    @AppStorage(PreferenceKey.nearbyLocation) private var nearbyLocation = false
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    @State private var input = AmountInput()
    /// The recipient picker when it is showing.
    @State private var path: [PayRoute] = []
    /// Who to pay, from Pay Again on a transaction. Pay then dials them
    /// straight away instead of opening the picker.
    @State private var chosenRecipient: Recipient?
    /// A code the system would not dial (the simulator, an iPad), shown in
    /// an alert so it can be dialled by hand.
    @State private var undialledCode: String?
    /// Started when the picker opens, so a location fix is usually ready by
    /// the time Pay is tapped; the payment never waits for it.
    @State private var locationTask: Task<LocationFix?, Never>?
    /// Which locating run is current, so a late answer from an older one
    /// is ignored.
    @State private var locatingRun = UUID()
    /// Places' erase count when locating started: a fix that arrives after
    /// an erase (Nearby turned off, Delete All Data) is not remembered.
    @State private var placesGeneration = 0
    /// That fix once it arrives, for the picker's Nearby section.
    @State private var nearbyFix: LocationFix?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where a finger is on Pay, for the bubble under it.
    @GestureState private var payTouch: CGPoint?
    @State private var didApplyDebugLaunch = false

    var body: some View {
        NavigationStack(path: $path) {
            keypadScreen
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: PayRoute.self) { route in
                    switch route {
                    case .recipients(let query):
                        RecipientPickerView(amount: input.value, query: query, nearbyFix: nearbyFix) { recipient in
                            pay(recipient)
                        }
                    }
                }
        }
        .alert(
            "Can't dial on this device",
            isPresented: Binding(get: { undialledCode != nil }, set: { if !$0 { undialledCode = nil } }),
            presenting: undialledCode
        ) { code in
            Button("Copy Code") {
                UIPasteboard.general.string = code
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Button("OK", role: .cancel) {}
        } message: { code in
            Text("Dial \(code) on your phone to finish.")
        }
        // Pay Again on a transaction, from the Activity tab.
        .onChange(of: router.payRequest?.id, initial: true) { takePayRequest() }
        .onChange(of: path) { _, path in
            // Back from the picker without paying: its fix is dropped. Not
            // when Pay Again just chose someone, whose fix is under way.
            if path.isEmpty, chosenRecipient == nil {
                locationTask = nil
                nearbyFix = nil
            }
            router.setHidesTabBar(!path.isEmpty, on: .pay)
        }
        .onAppear(perform: applyDebugLaunch)
        .task { await PayShaders.prepare() }
    }

    private var keypadScreen: some View {
        VStack(spacing: 0) {
            PageHeader(page: .pay) { EmptyView() } trailing: { WalletSwitcher() }

            Spacer(minLength: 12)
            PayAmountDisplay(amount: input.value)
            if let chosenRecipient {
                PayChosenRecipient(recipient: chosenRecipient) {
                    withAnimation(.smooth(duration: 0.25)) { self.chosenRecipient = nil }
                }
                .padding(.top, 12)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            Spacer(minLength: 12)

            // The amount sits midway between the top bar and the currency;
            // the currency, keypad and buttons stack at the bottom, as in a
            // payment app's keypad screen.
            PayCurrencyPill(isEmpty: input.isZero)
                .padding(.bottom, 14)

            // Up to 332pt, four rows of about 83, so keys grow to thumb size
            // and the amount keeps the space above.
            PayKeypad(onKey: press, canClear: !input.isZero, tint: .payKeypadAccent)
                .frame(maxHeight: 332)
                .padding(.horizontal, 8)
                // Takes its full height before the spacers around the
                // amount share what is left, so the keys never move as the
                // amount changes size.
                .layoutPriority(1)

            // Over the tab bar.
            buttons
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 4)
        }
        .starhashTabBarClearance()
        .starhashReadableWidth(StarHashMetrics.narrowReadableWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.starhashPayBackground.ignoresSafeArea())
        .environment(\.starhashGlassTint, .payGlassTint)
        .environment(\.starhashOnPay, true)
    }

    // MARK: Pieces

    private var buttons: some View {
        HStack(spacing: 12) {
            // The system asks before it calls, so Balance needs no prompt
            // of its own.
            Button {
                dial(USSD.balance(for: wallet))
            } label: {
                Label("Balance", systemImage: "wallet.bifold")
                    // At accessibility sizes the word alone, shrunk a little
                    // rather than broken across two lines.
                    .labelStyle(BalanceLabelStyle())
                    .starhashFont(18, weight: .semibold, relativeTo: .body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Color.payPrimaryText)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: StarHashMetrics.primaryButtonHeight)
                    .contentShape(Capsule())
                    // The Total card: tinted glass, or black glass in dark.
                    .starhashTotalCard(in: Capsule(), interactive: true)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityHint("Dials \(USSD.balance(for: wallet))")

            Button("Pay") { next() }
                .buttonStyle(.starhashPrimaryOnPay)
                // Held, as in the reference: the white bubble under the
                // finger and light streaming through the button.
                .overlay {
                    if !reduceMotion { PayPressOverlay(location: payTouch) }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0).updating($payTouch) { value, touch, _ in
                        touch = value.location
                    }
                )
                // Outermost, so a disabled Pay shows no bubble either.
                .disabled(input.isZero)
                .animation(.smooth(duration: 0.2), value: input.isZero)
        }
    }

    // MARK: Actions

    private func press(_ key: AmountInput.Key) -> Bool {
        var next = input
        let changed = next.apply(key)
        if changed {
            withAnimation(.snappy(duration: 0.25)) { input = next }
        }
        return changed
    }

    /// Pay: the recipient picker, or dialling the chosen recipient.
    private func next() {
        if let chosenRecipient {
            pay(chosenRecipient)
        } else {
            openPicker()
        }
    }

    private func openPicker(query: String = "") {
        startLocating()
        path = [.recipients(query: query)]
    }

    /// With Nearby on, a fix for the payment and the picker's suggestions.
    private func startLocating() {
        nearbyFix = nil
        locationTask = nil
        let run = UUID()
        locatingRun = run
        placesGeneration = AppEnvironment.places.generation
        #if DEBUG
        if let fix = DebugLaunch.nearbyFix {
            nearbyFix = fix
            locationTask = Task { fix }
            return
        }
        #endif
        guard nearbyLocation, PaymentLocation.isAuthorized else { return }
        locationTask = Task {
            await PaymentLocation.current { fix in
                // The first usable fix reaches the picker at once.
                if locatingRun == run, nearbyFix == nil { nearbyFix = fix }
            }
        }
    }

    /// The recipient waits under the amount, and Pay dials them.
    private func takePayRequest() {
        guard let request = router.takePayRequest() else { return }
        path = []
        // Pay Again skips the picker: locate now, while StarHash is still in
        // front, so the fix is in hand when Pay is tapped.
        startLocating()
        withAnimation(.smooth(duration: 0.25)) { chosenRecipient = request.recipient }
    }

    /// Records the payment (pending until its SMS), goes back to the keypad
    /// and dials. The amount stays, as in the call prompt's wake: a call
    /// cancelled there can be dialled again, and that retry is the same
    /// pending payment rather than a second one.
    private func pay(_ recipient: Recipient) {
        let amount = input.value
        guard amount > 0, recipient.isPayable else { return }
        let pendingLocation = locationTask
        let generation = placesGeneration
        locationTask = nil

        var recordedID: UUID?
        if saveTransactions {
            recordedID = store.recordPayment(to: recipient, amount: amount, retryWindow: 5 * 60).id
        }
        let code = USSD.payment(to: recipient, amount: amount, from: wallet)
        withAnimation(.smooth(duration: 0.25)) { chosenRecipient = nil }
        path = []
        // The call prompt (or the alert) comes up once the picker has gone.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            dial(code)
        }

        // The location is filled in once it arrives, never before dialling:
        // on the transaction (its map), and in Nearby's memory for a number
        // or code that is not one of the person's contacts.
        if let pendingLocation {
            Task {
                guard let fix = await pendingLocation.value,
                      // Nearby could have been turned off, or everything
                      // erased, while the fix was coming.
                      StarHashPreferences.nearbyLocation,
                      AppEnvironment.places.generation == generation else { return }
                if let recordedID, var transaction = store.transaction(id: recordedID) {
                    transaction.location = fix.coordinate
                    store.update(transaction)
                }
                if await Self.remembersPlace(of: recipient) {
                    AppEnvironment.places.record(
                        recipient, latitude: fix.latitude, longitude: fix.longitude,
                        accuracy: fix.accuracy, generation: generation
                    )
                }
            }
        }
    }

    /// Nearby remembers numbers and codes that are not in Contacts. A
    /// merchant code never is. A number needs the contacts read first; when
    /// StarHash cannot read them it cannot tell, so it does not remember it.
    private static func remembersPlace(of recipient: Recipient) async -> Bool {
        guard recipient.kind == .phone else { return true }
        let contacts = PayContacts.shared
        await contacts.loadIfAllowed()
        guard contacts.hasLoaded, contacts.access == .authorized else { return false }
        return !contacts.isContact(recipient)
    }

    private func dial(_ code: String) {
        Task {
            if await !USSDDialer.dial(code) {
                undialledCode = code
            }
        }
    }

    // MARK: Debug

    private func applyDebugLaunch() {
        #if DEBUG
        guard !didApplyDebugLaunch else { return }
        didApplyDebugLaunch = true
        if let amount = PayDebug.amount { input = AmountInput(value: amount) }
        if let recipient = PayDebug.chosenRecipient(in: store) { chosenRecipient = recipient }
        if PayDebug.opensPicker {
            openPicker(query: PayDebug.query ?? "")
        }
        #endif
    }
}

/// The wallet icon and "Balance", or only the word at accessibility text
/// sizes, where the button is half the screen's width.
private struct BalanceLabelStyle: LabelStyle {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            if !dynamicTypeSize.isAccessibilitySize { configuration.icon }
            configuration.title
        }
    }
}

/// The screens Pay pushes.
private enum PayRoute: Hashable {
    /// The recipient picker, searching for `query`.
    case recipients(query: String)
}

/// The recipient Pay Again chose, under an empty amount: who the next
/// payment goes to, with a way to drop them and pick someone else.
private struct PayChosenRecipient: View {
    let recipient: Recipient
    let onClear: () -> Void

    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    private var contacts: PayContacts { .shared }

    var body: some View {
        HStack(spacing: 10) {
            RecipientTile(
                tile: .for(recipient, photoContactID: enableContacts ? contacts.photoContactID(for: recipient) : nil),
                size: 28
            )
            Text("To \(recipient.displayName)")
                .font(.starhash(.subheadline, weight: .semibold))
                .foregroundStyle(Color.payPrimaryText)
                .lineLimit(1)
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.starhash(.body))
                    .foregroundStyle(Color.paySecondaryText)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.hapticPlain)
            .accessibilityLabel("Remove \(recipient.displayName)")
        }
        .padding(.leading, 6)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .starhashGlass()
        .padding(.horizontal, StarHashMetrics.screenPadding)
        // The photo, when the number or code is saved in Contacts.
        .task(id: enableContacts) {
            if enableContacts { await contacts.loadIfAllowed() }
        }
    }
}
