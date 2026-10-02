import StarHashKit
import SwiftUI
import UIKit

/// The screen Pay pushes: who gets the money. It opens searching, the
/// keyboard up on its numbers (most payments go to a merchant code typed on
/// the spot) with letters a key away for names: a close button and the
/// search field across the top. Closing the search gives the page its back
/// button, its title and a search button instead, the field sliding out to
/// the right as the title comes in.
///
/// Below, the number or code being typed, recent recipients and contacts,
/// each under a band that stays at the top while its rows scroll, the rows
/// flat with large square avatars and the letters a search matched in the
/// wallet's colour. The total sits in a contrasting bar at the bottom,
/// riding up with the keyboard.
///
/// Picking a recipient pays at once: the system's own call prompt, showing
/// the full code, is the one approval before MoMo asks for the PIN.
struct RecipientPickerView: View {
    let amount: Int
    /// Called with the chosen recipient. The caller records, goes back and
    /// dials.
    let onPay: (Recipient) -> Void

    @Environment(StarHashStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @AppStorage(PreferenceKey.saveRecents) private var saveRecents = true
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn

    @State private var query: String
    /// The search field in the header, rather than the title.
    @State private var isSearching = true
    @State private var choosingNumberFor: PayContact?
    @State private var contacts = PayContacts.shared
    /// Set on the first pick, so a double tap cannot dial twice.
    @State private var hasPaid = false
    @FocusState private var searchFocused: Bool

    init(amount: Int, query: String = "", onPay: @escaping (Recipient) -> Void) {
        self.amount = amount
        self.onPay = onPay
        _query = State(initialValue: query)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if !savedMatches.isEmpty {
                    savedSection
                } else if let typed = search.typedRecipient {
                    typedSection(typed)
                }
                if !recents.isEmpty {
                    Section {
                        ForEach(recents, id: \.self) { recipient in
                            RecipientRow(
                                tile: tile(for: recipient),
                                title: recipient.displayName,
                                subtitle: recipient.name == nil ? kindLabel(recipient) : recipient.formattedDestination,
                                match: search.nameQuery,
                                matchColor: wallet.pickerMatch
                            ) { choose(recipient) }
                        }
                    } header: {
                        PickerBand(title: "Recent")
                    }
                }
                if enableContacts { contactsSection }
            }
            .padding(.bottom, 12)
            .starhashReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        // Centred in what is left between the header and the total (or the
        // keyboard), since it is laid out inside their insets.
        .overlay {
            if showsNoMatches {
                EmptyStateView(
                    symbol: "magnifyingglass",
                    title: "No matches",
                    message: "Type a phone number or a merchant code to pay it directly."
                )
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        // Above the keyboard while it is up, at the bottom edge after.
        .safeAreaInset(edge: .bottom, spacing: 0) { totalBar }
        .background(Color.starhashBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .background(SwipeBackEnabler())
        // Up with the keyboard as the screen slides in.
        .onAppear { if isSearching { searchFocused = true } }
        .task(id: enableContacts) {
            if enableContacts { await contacts.load() }
        }
        #if DEBUG
        // -payChooser: the number chooser for the first contact with several.
        .onChange(of: contacts.contacts) { _, all in
            guard DebugLaunch.arguments.contains("-payChooser"), choosingNumberFor == nil else { return }
            if let contact = all.first(where: { $0.recipients.count > 1 && $0.name == "Pa" }) ?? all.first(where: { $0.recipients.count > 1 }) {
                showChooser(for: contact)
            }
        }
        // -payBrowse: the header with the title, the search closed.
        .onAppear {
            guard DebugLaunch.arguments.contains("-payBrowse") else { return }
            isSearching = false
            searchFocused = false
        }
        #endif
        .sheet(item: $choosingNumberFor) { contact in
            ChooseNumberSheet(contact: contact) { recipient in
                choosingNumberFor = nil
                choose(recipient)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hasPaid)
        .sensoryFeedback(.selection, trigger: isSearching)
    }

    // MARK: Header

    /// Searching: the close button and the field. Not: the back button,
    /// the title centred on the screen and a search button. The field
    /// comes in from the right as the title goes out to the left, and the
    /// leading button's glyph turns between close and back.
    private var header: some View {
        ZStack {
            if !isSearching {
                Text("Select a recipient")
                    .font(.starhash(.headline))
                    .foregroundStyle(Color.starhashPrimaryText)
                    .lineLimit(1)
                    .padding(.horizontal, 56)
                    .accessibilityAddTraits(.isHeader)
                    .transition(.offset(x: -36).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                PickerSquareButton(
                    symbol: isSearching ? "xmark" : "chevron.left",
                    label: isSearching ? "Close search" : "Back"
                ) {
                    if isSearching { closeSearch() } else { dismiss() }
                }
                if isSearching {
                    searchField
                        .transition(.offset(x: 80).combined(with: .opacity))
                } else {
                    Spacer(minLength: 0)
                    PickerSquareButton(symbol: "magnifyingglass", label: "Search") { openSearch() }
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .starhashReadableWidth()
        .background(Color.starhashBackground.ignoresSafeArea(edges: .top))
        .animation(.smooth(duration: 0.32), value: isSearching)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.starhashSecondaryText)
                .accessibilityHidden(true)
            TextField("Type anything, we'll find it", text: $query)
                .accessibilityLabel("Search name, number or merchant code")
                .focused($searchFocused)
                // Numbers first, letters on the keyboard's own ABC key:
                // one keyboard for codes, numbers and names.
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    if let typed = typedRecipient { choose(typed) }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.starhashTertiaryText)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.starhash(.body))
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color.pickerSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.pickerOutline, lineWidth: 1))
    }

    private func openSearch() {
        isSearching = true
        searchFocused = true
    }

    /// Closes the search: the query goes, and the keyboard with it.
    private func closeSearch() {
        query = ""
        searchFocused = false
        isSearching = false
    }

    // MARK: Picking

    private var search: RecipientSearch { RecipientSearch(query: query) }

    /// Recent recipients matching the search, less the one already at the
    /// top as an exact match.
    private var recents: [Recipient] {
        guard saveRecents else { return [] }
        return store.recentRecipients().filter { search.matches($0) && !isTyped($0) }
    }

    /// Contacts matching the search, less any already at the top.
    private var matchingContacts: [PayContact] {
        guard enableContacts else { return [] }
        return contacts.contacts.filter { search.matches($0) && !$0.recipients.contains(where: isTyped) }
    }

    /// Saved recipients (contacts, and past recipients with a name) whose
    /// number or code is exactly the one typed. They take the top of the
    /// list in place of the bare number, so a saved till or friend is paid
    /// by name. One row per name.
    private var savedMatches: [Recipient] {
        guard search.typedRecipient != nil else { return [] }
        let past = saveRecents ? store.recentRecipients(limit: 50).filter { $0.name != nil } : []
        let saved = enableContacts ? contacts.contacts.flatMap(\.recipients) : []
        var names = Set<String>()
        return (saved + past).filter { isTyped($0) && names.insert(($0.name ?? "").lowercased()).inserted }
    }

    /// Whether `recipient` is the number or code in the search field.
    private func isTyped(_ recipient: Recipient) -> Bool {
        guard let typed = search.typedRecipient else { return false }
        return recipient.kind == typed.kind && recipient.destination == typed.destination
    }

    private var showsNoMatches: Bool {
        !search.isEmpty && search.typedRecipient == nil && recents.isEmpty && matchingContacts.isEmpty
            && contacts.access != .denied
    }

    /// What the keyboard's Search key pays: the saved recipient the typed
    /// number or code belongs to, or the number or code itself.
    private var typedRecipient: Recipient? {
        savedMatches.first ?? search.typedRecipient
    }

    // MARK: Sections

    /// The number or code being typed, when nothing saved has it: paid as
    /// typed.
    private func typedSection(_ typed: Recipient) -> some View {
        Section {
            RecipientRow(
                tile: .symbol(typed.kind == .phone ? "phone" : "storefront"),
                title: typed.formattedDestination,
                subtitle: kindLabel(typed),
                matchColor: wallet.pickerMatch
            ) { choose(typed) }
        } header: {
            PickerBand(title: typed.kind == .phone ? "Number" : "Merchant code")
        }
    }

    /// The saved recipients the typed number or code belongs to, by name.
    /// A contact with several numbers is paid on the one typed, with no
    /// need to choose.
    private var savedSection: some View {
        Section {
            ForEach(savedMatches, id: \.self) { recipient in
                RecipientRow(
                    tile: tile(for: recipient),
                    title: recipient.displayName,
                    subtitle: recipient.formattedDestination + " \u{00B7} " + kindLabel(recipient),
                    matchColor: wallet.pickerMatch
                ) { choose(recipient) }
            }
        } header: {
            PickerBand(title: "Saved")
        }
    }

    @ViewBuilder
    private var contactsSection: some View {
        switch contacts.access {
        case .denied:
            Section {
                ContactsAccessCard(
                    message: "Allow StarHash to see your contacts to pay them by name. They stay on your iPhone."
                )
                .padding(16)
            } header: {
                PickerBand(title: "Contacts")
            }
        case .notDetermined:
            if !contacts.hasLoaded { loadingSection }
        case .authorized, .limited:
            if !contacts.hasLoaded {
                loadingSection
            } else if !matchingContacts.isEmpty || contacts.access == .limited {
                Section {
                    ForEach(matchingContacts) { contact in
                        RecipientRow(
                            tile: contact.hasPhoto
                                ? .photo(contactID: contact.id, fallback: .monogram(contact.initials))
                                : .monogram(contact.initials),
                            title: contact.name,
                            subtitle: contactSubtitle(contact),
                            match: search.nameQuery,
                            matchColor: wallet.pickerMatch
                        ) { pick(contact) }
                    }
                    if contacts.access == .limited && search.isEmpty {
                        ContactsAccessCard(
                            message: "StarHash sees only the contacts you chose. You can share more in Settings."
                        )
                        .padding(16)
                    }
                } header: {
                    PickerBand(title: "Contacts")
                }
            }
        }
    }

    /// Placeholder rows, pulsing, while the contacts are read.
    private var loadingSection: some View {
        Section {
            ForEach(0..<4, id: \.self) { _ in PickerSkeletonRow() }
        } header: {
            PickerBand(title: "Contacts")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading contacts")
    }

    /// The amount being paid, in a contrasting bar with rounded top corners
    /// at the bottom, riding up with the keyboard. Paying is a tap on the
    /// number, code or person above, so the bar only states the total,
    /// large: what the iPhone's call prompt will ask to approve.
    private var totalBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Total:")
                .font(.starhash(.body, weight: .semibold))
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Money.format(amount))
                    .font(.sheet(32, .bold, relativeTo: .title))
                    .monospacedDigit()
                Text(Money.currency)
                    .font(.sheet(15, .bold, relativeTo: .subheadline))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .foregroundStyle(Color.starhashOnInk)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .starhashReadableWidth()
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous)
                .fill(Color.starhashInk)
                // Down past the home indicator, never under the keyboard.
                .ignoresSafeArea(.container, edges: .bottom)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total \(Money.formatWithCurrency(amount))")
    }

    // MARK: Building blocks

    /// "0788 123 456", "Merchant code 020205", or "3 phone numbers".
    private func contactSubtitle(_ contact: PayContact) -> String {
        guard contact.recipients.count == 1 else { return "\(contact.recipients.count) phone numbers" }
        let only = contact.recipients[0]
        return only.kind == .merchant ? "Merchant code \(only.destination)" : only.formattedDestination
    }

    /// A storefront for merchants, initials for named people, a phone for
    /// bare numbers; the contact's photo over any of them when the number
    /// or code is saved in Contacts with one.
    private func tile(for recipient: Recipient) -> RecipientRow.Tile {
        .for(recipient, photoContactID: enableContacts ? contacts.photoContactID(for: recipient) : nil)
    }

    /// "MTN number", "Airtel number" or "Merchant code": which code and
    /// fee the payment gets.
    private func kindLabel(_ recipient: Recipient) -> String {
        guard let network = recipient.network else { return "Merchant code" }
        return "\(network.name) number"
    }

    private func pick(_ contact: PayContact) {
        if contact.recipients.count == 1 {
            choose(contact.recipients[0])
        } else {
            showChooser(for: contact)
        }
    }

    /// The keyboard would cover the sheet, so it goes down first and the
    /// sheet comes up once it has.
    private func showChooser(for contact: PayContact) {
        searchFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            choosingNumberFor = contact
        }
    }

    private func choose(_ recipient: Recipient) {
        guard !hasPaid, recipient.isPayable else { return }
        hasPaid = true
        searchFocused = false
        onPay(recipient)
    }
}

// MARK: - Pieces

/// A full-width band over a section: its title small, uppercase and grey,
/// staying at the top while the section's rows scroll under it.
private struct PickerBand: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.starhash(.footnote, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Color.starhashSecondaryText)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .background(Color.pickerSurface)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The header's square buttons: a glyph on a raised, outlined square.
private struct PickerSquareButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.starhashPrimaryText)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .background(Color.pickerSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.pickerOutline, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }
}

/// A row's shape while the contacts load, pulsing softly.
private struct PickerSkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dims = false

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.pickerSurface)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(Color.pickerSurface).frame(width: 140, height: 14)
                Capsule().fill(Color.pickerSurface).frame(width: 96, height: 12)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(dims ? 0.45 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dims = true }
        }
    }
}

/// One tappable recipient, flat on the page: a large square avatar, the
/// name with what the search matched in the wallet's colour, and a grey
/// line under it.
struct RecipientRow: View {
    indirect enum Tile {
        case monogram(String)
        case symbol(String)
        /// A contact's photo, showing `fallback` until it loads.
        case photo(contactID: String, fallback: Tile)

        /// A storefront for merchants, initials for named people, a phone
        /// for bare numbers; the photo of `photoContactID` over any of them.
        static func `for`(_ recipient: Recipient, photoContactID: String?) -> Tile {
            let plain: Tile = if recipient.kind == .merchant {
                .symbol("storefront")
            } else if let name = recipient.name {
                .monogram(PayContact.initials(for: name))
            } else {
                .symbol("phone")
            }
            guard let photoContactID else { return plain }
            return .photo(contactID: photoContactID, fallback: plain)
        }
    }

    let tile: Tile
    let title: String
    let subtitle: String
    /// Letters to mark in the title: what the search typed.
    var match: String = ""
    var matchColor: Color = .starhashPrimaryText
    let action: () -> Void

    /// The title with the first stretch the search matched coloured, the
    /// way the search matches: ignoring case and accents.
    private var styledTitle: AttributedString {
        var text = AttributedString(title)
        if !match.isEmpty, let range = text.range(of: match, options: [.caseInsensitive, .diacriticInsensitive]) {
            text[range].foregroundColor = matchColor
        }
        return text
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RecipientTile(tile: tile, size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(styledTitle)
                        .font(.starhash(.body, weight: .semibold))
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.starhash(.subheadline))
                        .foregroundStyle(Color.starhashSecondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(HighlightRowButtonStyle())
        .accessibilityElement(children: .combine)
    }
}

/// A recipient's initials, or a symbol for numbers and merchants, on a
/// raised, outlined square.
struct RecipientTile: View {
    let tile: RecipientRow.Tile
    var size: CGFloat = 40

    var body: some View {
        if case .photo(let contactID, let fallback) = tile {
            ContactPhotoTile(contactID: contactID, size: size) {
                RecipientTile(tile: fallback, size: size)
            }
            .accessibilityHidden(true)
        } else {
            plainTile
        }
    }

    private var plainTile: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
        return Group {
            switch tile {
            case .monogram(let initials):
                Text(initials)
                    .font(.starhashFixed(size * 0.36, weight: .bold))
            case .symbol(let symbol):
                Image(systemName: symbol)
                    .font(.system(size: size * 0.36, weight: .semibold))
            case .photo:
                EmptyView()
            }
        }
        .foregroundStyle(Color.starhashPrimaryText)
        .frame(width: size, height: size)
        .background(Color.pickerSurface, in: shape)
        .overlay(shape.strokeBorder(Color.pickerOutline, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// Shown in place of contacts when access is off or limited: why, and a
/// way to the app's page in Settings, the only place it can be changed.
private struct ContactsAccessCard: View {
    let message: String

    var body: some View {
        StarHashCard(fill: .starhashCard) {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(message)
                        .font(.starhash(.subheadline))
                        .foregroundStyle(Color.starhashSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(Color.starhashPrimaryText)
                }
                Button("Open Settings") { USSDDialer.openSettings() }
                    .buttonStyle(.starhashCapsule(height: 36, horizontalPadding: 16))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Keeps the swipe in from the left edge going back on a pushed page that
/// draws its own header: hiding the navigation bar would otherwise turn it
/// off. The navigation controller's own delegate is put back as the page
/// goes, so the root page never starts a swipe with nothing to go back to.
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        private weak var savedDelegate: (any UIGestureRecognizerDelegate)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let pop = navigationController?.interactivePopGestureRecognizer else { return }
            savedDelegate = pop.delegate
            pop.delegate = nil
            pop.isEnabled = true
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.delegate = savedDelegate
        }
    }
}

extension Recipient.Network {
    /// The colour of letters a search matched, on this wallet.
    var pickerMatch: Color {
        switch self {
        case .mtn: .pickerMatchMTN
        case .airtel: .pickerMatchAirtel
        }
    }
}
