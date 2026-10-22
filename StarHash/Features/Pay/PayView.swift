import StarHashKit
import SwiftUI

/// The Pay tab: type an amount, tap Pay, pick who gets it on the screen
/// that slides in, and StarHash dials the MoMo code. The system's call
/// prompt, showing the whole code, is the approval; MoMo then asks for the
/// PIN. Pay with nothing typed shakes the amount instead. Balance dials the
/// balance code. Nothing is sent by StarHash itself.
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
    /// The photo a scanned code shares for `chosenRecipient`.
    @State private var chosenPhotoID: UUID?
    /// Whether `chosenRecipient` came from a code other than StarHash's,
    /// which says nothing of who it is: shown as its number alone.
    @State private var chosenIsBare = false
    /// A code the system would not dial (the simulator, an iPad), shown in
    /// an alert so it can be dialled by hand.
    @State private var undialledCode: String?
    /// Started when the picker opens, so a location fix is usually ready by
    /// the time Pay is tapped; the payment never waits for it.
    @State private var locationTask: Task<LocationFix?, Never>?
    /// Which locating run is current, so a late answer from an older one
    /// is ignored.
    @State private var locatingRun = UUID()
    /// The store's location wipe count when locating started: a fix that
    /// arrives after a wipe (Nearby turned off, Delete All Data) is dropped.
    @State private var locationsGeneration = 0
    /// That fix once it arrives, for the picker's Nearby section.
    @State private var nearbyFix: LocationFix?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Whether a finger is on Pay, for the light through it.
    @GestureState private var payHeld = false
    /// Pay tapped with nothing typed, which shakes the amount.
    @State private var zeroShakes = 0
    @State private var didApplyDebugLaunch = false
    /// The QR scanner, over everything.
    @State private var isScanning = false

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
        // Pay Again on a transaction, from the Activity tab, or a
        // StarHash code opened by the Camera.
        .onChange(of: router.payRequest?.id, initial: true) { takePayRequest() }
        // The scanner, asked for by a widget or a link.
        .onChange(of: router.scanRequest, initial: true) {
            if router.takeScanRequest() {
                path = []
                isScanning = true
            }
        }
        .fullScreenCover(isPresented: $isScanning) {
            QRScannerView { request in
                isScanning = false
                take(request)
            }
        }
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
        #if DEBUG
        // -payShake: Pay tapped with nothing typed, three times from 1.5s,
        // about as far apart as in the reference, to record the shake.
        .task {
            guard PayDebug.shakes else { return }
            try? await Task.sleep(for: .seconds(1.5))
            for _ in 0..<3 {
                next()
                try? await Task.sleep(for: .seconds(0.77))
            }
        }
        #endif
    }

    private var keypadScreen: some View {
        VStack(spacing: 0) {
            PageHeader(page: .pay) { EmptyView() } trailing: { ScanButton { isScanning = true } }

            Spacer(minLength: 12)
            PayAmountDisplay(amount: input.value, shakes: zeroShakes)
            if let chosenRecipient {
                PayChosenRecipient(recipient: chosenRecipient, photoID: chosenPhotoID, isBare: chosenIsBare) {
                    withAnimation(.smooth(duration: 0.25)) { self.chosenRecipient = nil }
                }
                .padding(.top, 12)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            Spacer(minLength: 12)

            // The amount sits midway between the top bar and the wallet;
            // the wallet, keypad and buttons stack at the bottom, as in a
            // payment app's keypad screen.
            WalletPill()
                .padding(.bottom, 14)

            // Up to 332pt, four rows of about 83, so keys grow to thumb size
            // and the amount keeps the space above.
            PayKeypad(onKey: press, canClear: !input.isZero)
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
                Text("Balance")
                    // At accessibility sizes shrunk a little rather than
                    // broken across two lines.
                    .starhashFont(18, weight: .semibold, relativeTo: .body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Color.starhashPrimaryText)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: StarHashMetrics.primaryButtonHeight)
                    .contentShape(Capsule())
                    .modifier(BalanceSurface())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityHint("Dials \(USSD.balance(for: wallet))")

            // Never greyed out: with nothing typed it looks as always, and
            // a tap shakes the amount, as in the reference. It then beats
            // twice like a heartbeat, on purpose: the press, then the
            // shake's own softer tap on its widest swing (PayAmountDisplay).
            Button("Pay") { next() }
                .buttonStyle(.starhashPrimaryOnPay)
                // Held, as in the reference: light streaming through the
                // button, with nothing drawn under the finger.
                .overlay {
                    if !reduceMotion { PayPressOverlay(isPressed: payHeld) }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0).updating($payHeld) { _, held, _ in
                        held = true
                    }
                )
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

    /// Pay: the recipient picker, or dialling the chosen recipient. With
    /// nothing typed, the amount shakes.
    private func next() {
        guard !input.isZero else {
            zeroShakes += 1
            AccessibilityNotification.Announcement("Type an amount first").post()
            return
        }
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
        locationsGeneration = store.locationsGeneration
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
        // Pay Again, or StarHash's own link opened from the Camera: both
        // know who they are paying.
        take(PaymentRequest(recipient: request.recipient, amount: request.amount, photoID: request.photoID, isStarHashCode: true))
    }

    /// Who a scanned code (or Pay Again) says to pay: chosen under the
    /// amount, with the amount typed in when the code asks for one, so Pay
    /// dials them without the recipient screen.
    private func take(_ request: PaymentRequest) {
        // Skipping the picker: locate now, while StarHash is still in
        // front, so the fix is in hand when Pay is tapped.
        startLocating()
        withAnimation(.smooth(duration: 0.25)) {
            chosenRecipient = request.recipient
            chosenPhotoID = request.photoID
            chosenIsBare = !request.isStarHashCode
            if let amount = request.amount { input = AmountInput(value: amount) }
        }
        if request.amount == nil {
            let who = request.isStarHashCode ? request.recipient.shownName : request.recipient.formattedDestination
            AccessibilityNotification.Announcement("Paying \(who). Type an amount.").post()
        }
    }

    /// Records the payment (pending until its SMS), goes back to the keypad
    /// and dials. The amount stays, as in the call prompt's wake: a call
    /// cancelled there can be dialled again, and that retry is the same
    /// pending payment rather than a second one.
    private func pay(_ recipient: Recipient) {
        let amount = input.value
        guard amount > 0, recipient.isPayable else { return }
        let pendingLocation = locationTask
        let generation = locationsGeneration
        locationTask = nil

        // Paid, however it was chosen: a Nearby suggestion passed over
        // before is suggested again.
        NearbyMissesStore.paid(recipient)
        var recordedID: UUID?
        if saveTransactions {
            recordedID = store.recordPayment(to: recipient, amount: amount, wallet: wallet, retryWindow: 5 * 60).id
        }
        let code = USSD.payment(to: recipient, amount: amount, from: wallet)
        withAnimation(.smooth(duration: 0.25)) { chosenRecipient = nil }
        path = []
        // The call prompt (or the alert) comes up once the picker has gone.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            dial(code)
        }

        // The location goes on the payment once it arrives, never before
        // dialling: its map, and what Nearby suggests from. Only for a
        // merchant code or a number that is not one of the person's
        // contacts: paying someone they know never records where they were.
        if let pendingLocation, let recordedID {
            Task {
                guard let fix = await pendingLocation.value,
                      await Self.remembersPlace(of: recipient),
                      // Nearby could have been turned off, or everything
                      // erased, while the fix was coming.
                      StarHashPreferences.nearbyLocation,
                      store.locationsGeneration == generation,
                      var transaction = store.transaction(id: recordedID) else { return }
                transaction.location = fix.coordinate
                store.update(transaction)
            }
        }
    }

    /// Whether a payment keeps where it was made: a merchant code always, a
    /// number only when it is not in Contacts. A number needs the contacts
    /// read first; when StarHash cannot read them it cannot tell, so the
    /// place is not kept.
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
        if DebugLaunch.arguments.contains("-payScan") { isScanning = true }
        #endif
    }
}

/// Balance's capsule: Liquid Glass, tinted with the cards' colour so it
/// reads clearly on the pale page and the deep green alike, and lit by a
/// press. Before iOS 26, the cards' fill.
private struct BalanceSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.starhashGlass(in: Capsule(), interactive: true, tint: .balanceGlassTint)
    }
}

/// The scanner's button at the top right of Pay, in the round glass the
/// other header buttons wear.
private struct ScanButton: View {
    let action: () -> Void

    var body: some View {
        SwapGlassButton(symbol: "qrcode.viewfinder", label: "Scan a QR code", action: action)
    }
}

/// The screens Pay pushes.
private enum PayRoute: Hashable {
    /// The recipient picker, searching for `query`.
    case recipients(query: String)
}

/// The recipient Pay Again chose, under an empty amount: who the next
/// payment goes to, with a way to drop them and pick someone else. One
/// from a code other than StarHash's is its number or code alone, with no
/// tile: the code says nothing more.
private struct PayChosenRecipient: View {
    let recipient: Recipient
    /// Their photo on StarHash's server, when their code shared one.
    var photoID: UUID?
    var isBare = false
    let onClear: () -> Void

    @State private var sharedPhoto: UIImage?

    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    private var contacts: PayContacts { .shared }

    var body: some View {
        HStack(spacing: 10) {
            // A photo saved in Contacts comes first; then the one their
            // code shared; then the tile.
            let contactPhoto = enableContacts ? contacts.photoContactID(for: recipient) : nil
            if isBare {
                EmptyView()
            } else if contactPhoto == nil, let sharedPhoto {
                Image(uiImage: sharedPhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
            } else {
                RecipientTile(tile: .for(recipient, photoContactID: contactPhoto), size: 28)
            }
            Text("To \(isBare ? recipient.formattedDestination : recipient.shownName)")
                .font(.starhash(.subheadline, weight: .semibold))
                .foregroundStyle(Color.payPrimaryText)
                .lineLimit(1)
            Button(action: onClear) {
                Image(symbol: "xmark.circle.fill")
                    .font(.starhash(.body))
                    .foregroundStyle(Color.paySecondaryText)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.hapticPlain)
            .accessibilityLabel("Remove \(isBare ? recipient.formattedDestination : recipient.shownName)")
        }
        .padding(.leading, isBare ? 14 : 6)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .starhashGlass()
        .padding(.horizontal, StarHashMetrics.screenPadding)
        // The photo, when the number or code is saved in Contacts.
        .task(id: enableContacts) {
            if enableContacts { await contacts.loadIfAllowed() }
        }
        // The photo their code shared, when it shared one.
        .task(id: photoID) {
            sharedPhoto = nil
            if let photoID { sharedPhoto = await StarHashCloud.photo(photoID) }
        }
    }
}
