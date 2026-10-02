import StarHashKit
import SwiftUI
import UIKit

/// The screen Pay pushes: who gets the money. It opens with the search
/// field focused on the number pad, since most payments go to a merchant
/// code typed on the spot. The number or code being typed is the first row;
/// recent recipients and contacts follow. The total sits above the
/// keyboard, with Pay for the typed number or code.
///
/// Picking a recipient pays at once: the system's own call prompt, showing
/// the full code, is the one approval before MoMo asks for the PIN.
struct RecipientPickerView: View {
    let amount: Int
    /// Called with the chosen recipient. The caller records, goes back and
    /// dials.
    let onPay: (Recipient) -> Void

    @Environment(StarHashStore.self) private var store
    @AppStorage(PreferenceKey.enableContacts) private var enableContacts = true
    @AppStorage(PreferenceKey.saveRecents) private var saveRecents = true

    @State private var query: String
    @State private var choosingNumberFor: PayContact?
    @State private var contacts = PayContacts.shared
    /// The letter keyboard instead of the number pad, to search by name.
    @State private var typesLetters = false
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
            LazyVStack(alignment: .leading, spacing: 24) {
                if !savedMatches.isEmpty {
                    savedSection
                } else if let typed = search.typedRecipient {
                    typedSection(typed)
                }
                if !recents.isEmpty {
                    section("Recent") {
                        card(recents, id: { $0.kind.rawValue + $0.destination }) { recipient in
                            RecipientRow(
                                tile: tile(for: recipient),
                                title: recipient.displayName,
                                subtitle: recipient.name == nil ? kindLabel(recipient) : recipient.formattedDestination
                            ) { choose(recipient) }
                        }
                    }
                }
                if enableContacts { contactsSection }
            }
            .padding(.horizontal, StarHashMetrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, StarHashMetrics.screenPadding)
            .starhashReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        // Centred in what is left between the search field and the total
        // (or the keyboard), since it is laid out inside their insets.
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
        .safeAreaInset(edge: .top, spacing: 0) {
            searchField
                .padding(.horizontal, StarHashMetrics.screenPadding)
                .padding(.vertical, 8)
                .starhashReadableWidth()
        }
        // Rows scrolling under the Total bar fade into it instead of
        // showing sharp through the glass.
        .starhashSoftBottomEdge()
        // Above the keyboard while it is up, above the tab bar after.
        .starhashBottomBar { totalBar }
        .background(Color.starhashBackground.ignoresSafeArea())
        .navigationTitle("Select a recipient")
        .navigationBarTitleDisplayMode(.inline)
        // Up with the number pad as the screen slides in.
        .onAppear { searchFocused = true }
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
        #endif
        .sheet(item: $choosingNumberFor) { contact in
            ChooseNumberSheet(contact: contact) { recipient in
                choosingNumberFor = nil
                choose(recipient)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hasPaid)
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

    /// What Pay in the total bar pays: the saved recipient the typed
    /// number or code belongs to, or the number or code itself.
    private var typedRecipient: Recipient? {
        savedMatches.first ?? search.typedRecipient
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.starhashSecondaryText)
                .accessibilityHidden(true)
            TextField("Merchant code, number or name", text: $query)
                .accessibilityLabel("Search name, number or merchant code")
                .focused($searchFocused)
                .keyboardType(typesLetters ? .default : .numberPad)
                .textContentType(typesLetters ? .name : nil)
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
                        .foregroundStyle(Color.starhashSecondaryText)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            keyboardSwitch
        }
        .font(.body)
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(minHeight: 48)
        .starhashGlass(interactive: true)
    }

    /// "ABC" on the number pad, "123" on the letters: which keyboard comes
    /// up next. A focused field keeps its keyboard until it is focused
    /// again, so the switch drops focus and takes it back.
    private var keyboardSwitch: some View {
        Button {
            typesLetters.toggle()
            searchFocused = false
            Task { @MainActor in searchFocused = true }
        } label: {
            Text(typesLetters ? "123" : "ABC")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.starhashPrimaryText)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(Color.starhashInk.opacity(0.08), in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(typesLetters ? "Type numbers" : "Type letters")
    }

    /// The number or code being typed, when nothing saved has it: paid as
    /// typed.
    private func typedSection(_ typed: Recipient) -> some View {
        card([typed], id: { $0.destination }) { recipient in
            RecipientRow(
                tile: .symbol(recipient.kind == .phone ? "phone" : "storefront"),
                title: recipient.formattedDestination,
                subtitle: kindLabel(recipient)
            ) { choose(recipient) }
        }
    }

    /// The saved recipients the typed number or code belongs to, by name.
    /// A contact with several numbers is paid on the one typed, with no
    /// need to choose.
    private var savedSection: some View {
        card(savedMatches, id: { ($0.name ?? "") + $0.destination }) { recipient in
            RecipientRow(
                tile: tile(for: recipient),
                title: recipient.displayName,
                subtitle: recipient.formattedDestination + " \u{00B7} " + kindLabel(recipient)
            ) { choose(recipient) }
        }
    }

    @ViewBuilder
    private var contactsSection: some View {
        switch contacts.access {
        case .denied:
            section("Contacts") {
                ContactsAccessCard(
                    message: "Allow StarHash to see your contacts to pay them by name. They stay on your iPhone."
                )
            }
        case .notDetermined:
            if !contacts.hasLoaded {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
            }
        case .authorized, .limited:
            if !matchingContacts.isEmpty || contacts.access == .limited {
                section("Contacts") {
                    VStack(spacing: 12) {
                        if !matchingContacts.isEmpty {
                            card(matchingContacts, id: \.id) { contact in
                                RecipientRow(
                                    tile: contact.hasPhoto
                                        ? .photo(contactID: contact.id, fallback: .monogram(contact.initials))
                                        : .monogram(contact.initials),
                                    title: contact.name,
                                    subtitle: contactSubtitle(contact)
                                ) { pick(contact) }
                            }
                        }
                        if contacts.access == .limited && search.isEmpty {
                            ContactsAccessCard(
                                message: "StarHash sees only the contacts you chose. You can share more in Settings."
                            )
                        }
                    }
                }
            }
        }
    }

    /// The amount being paid, pinned above the keyboard. Paying is a tap
    /// on the number, code or person above, so the bar only states the
    /// total, large: what the iPhone's call prompt will ask to approve.
    private var totalBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Total")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.starhashSecondaryText)
            Spacer(minLength: 8)
            Text(Money.formatWithCurrency(amount))
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.starhashPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 22)
        .frame(minHeight: 64)
        .starhashGlass()
        .padding(.horizontal, StarHashMetrics.screenPadding)
        .padding(.bottom, 8)
        .starhashReadableWidth()
        .accessibilityElement(children: .combine)
    }

    // MARK: Building blocks

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.starhashCaptionText)
                .padding(.leading, 16)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// A lazily built card of rows with hairlines between them. Contacts can
    /// run to thousands, so this is a LazyVStack rather than `StarHashCard`.
    private func card<Item, ID: Hashable>(
        _ items: [Item], id: @escaping (Item) -> ID, @ViewBuilder row: @escaping (Item) -> some View
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: StarHashMetrics.cardRadius, style: .continuous)
        let keyed = items.enumerated().map { KeyedRow(id: id($1), index: $0, item: $1) }
        return LazyVStack(spacing: 0) {
            ForEach(keyed) { entry in
                row(entry.item)
                if entry.index < items.count - 1 {
                    StarHashRowSeparator(leading: 72, overlapsRows: true)
                }
            }
        }
        .background(Color.starhashCard, in: shape)
        .clipShape(shape)
    }

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

/// An item of a card with a stable identity and its position, so the
/// card knows where hairlines go.
private struct KeyedRow<Item, ID: Hashable>: Identifiable {
    let id: ID
    let index: Int
    let item: Item
}

/// One tappable recipient: a tile, a name and a grey line under it.
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                RecipientTile(tile: tile)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.starhashSecondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.starhashTertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(HighlightRowButtonStyle())
        .accessibilityElement(children: .combine)
    }
}

/// A recipient's initials, or a symbol for numbers and merchants, on a
/// soft ink tile.
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
        Group {
            switch tile {
            case .monogram(let initials):
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            case .symbol(let symbol):
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
            case .photo:
                EmptyView()
            }
        }
        .foregroundStyle(Color.starhashPrimaryText)
        .frame(width: size, height: size)
        .background(Color.starhashInk.opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
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
                        .font(.subheadline)
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
