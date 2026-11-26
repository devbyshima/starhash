import StarHashKit
import SwiftUI

/// Request on Pay: the amount typed, then who to ask, with a note if the
/// owner wants one: Hold Near first (with Tap to Request on, on an iPhone
/// that can measure), then people nearby, then (with requests anywhere on)
/// contacts and typed numbers, each checked with the directory as it is
/// tapped, never the whole list. A tap sends it; someone not on StarHash
/// gets Share Message instead.
struct RequestSheet: View {
    let amount: Int
    /// Hold Near chosen, with the note typed: Pay opens its sheet.
    var onHoldNear: (String?) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(PeopleNearbyService.self) private var nearby
    @Environment(Owner.self) private var owner
    @FeatureFlagged(.requestsAnywhere) private var anywhereOn
    @FeatureFlagged(.tapToRequest) private var tapOn
    @AppStorage(Preferences.showMyName) private var showMyName: Bool
    @State private var note = ""
    @State private var unreachable: PeopleNearby.Person?
    @State private var sentCount = 0
    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(String(starhash: "Request \(Money.format(amount))"))

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField(text: $note, prompt: Text("What for? (optional)")) { Text("Note") }
                        .font(.sheetBody)
                        .focused($noteFocused)
                        .submitLabel(.done)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .sheetCard()
                        .onChange(of: note) { _, typed in
                            if typed.count > MoneyRequest.maximumNoteLength { note = String(typed.prefix(MoneyRequest.maximumNoteLength)) }
                        }

                    if let missing = NearbyRequests.missing(in: owner) {
                        RequestNotice(text: missing)
                    } else {
                        if tapOn && TapToRequestService.isSupported {
                            holdNearRow
                        }
                        // With requests anywhere, an empty nearby says
                        // nothing: the contacts below are the way.
                        if !anywhere || !nearby.found.people.isEmpty {
                            SheetSectionLabel("People Nearby")
                            people
                        }
                        if anywhere {
                            RequestAnywhereSection(amount: amount, note: note, showMyName: showMyName) { sent in
                                asked(sent.person.shownName)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .sheetGlass(detents: [.medium, .large])
        .unreachableAlert($unreachable)
        .sensoryFeedback(.success, trigger: sentCount)
    }

    /// Hold Near: the request held out for the next iPhone held to this
    /// one, on a sheet of its own.
    private var holdNearRow: some View {
        Button {
            noteFocused = false
            let typed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            onHoldNear(typed.isEmpty ? nil : typed)
        } label: {
            HStack(spacing: 12) {
                SheetIconCircle(symbol: "antenna.radiowaves.left.and.right")
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hold Near Their iPhone")
                        .font(PickerType.rowName)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                Image(symbol: "chevron.right")
                    .font(.starhash(.footnote, weight: .semibold))
                    .foregroundStyle(Color.sheetSecondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .sheetCard()
        .accessibilityHint(Text("Shows the request for someone to hold their iPhone to"))
    }

    /// Requests through the server: both flags, as the Request button
    /// already needs People Nearby's.
    private var anywhere: Bool { anywhereOn && FeatureFlags.isOn(.peopleNearby) }

    @ViewBuilder
    private var people: some View {
        if nearby.found.people.isEmpty {
            RequestNotice(text: String(starhash: "No one nearby has StarHash open"))
        } else {
            VStack(spacing: 0) {
                ForEach(Array(nearby.found.people.enumerated()), id: \.element.id) { index, person in
                    if index > 0 { SheetDivider().padding(.leading, 70) }
                    Button { ask(person) } label: {
                        HStack(spacing: 12) {
                            PeopleNearbyTile(person: person, size: 44)
                            Text(verbatim: person.name)
                                .font(PickerType.rowName)
                                .foregroundStyle(Color.starhashPrimaryText)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if nearby.reaching == person.id { ProgressView() }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.hapticPlain)
                    .disabled(nearby.reaching != nil)
                    .accessibilityLabel(Text("Request \(Money.format(amount)) from \(person.name)"))
                }
            }
            .sheetCard()
        }
    }

    private func ask(_ person: PeopleNearby.Person) {
        noteFocused = false
        Task {
            let photo = ProfilePhoto.shared.image != nil ? AppEnvironment.serverSync.sharedPhotoID : nil
            if await AppEnvironment.nearbyRequests.ask(person, amount: amount, note: note, owner: owner, photoID: photo) != nil {
                asked(person.firstName)
            } else {
                unreachable = person
            }
        }
    }

    private func asked(_ name: String) {
        sentCount += 1
        AccessibilityNotification.Announcement(String(starhash: "Asked \(name) for \(Money.format(amount))")).post()
        dismiss()
    }
}

/// A line on a card where a list would be: why there is nothing to tap.
private struct RequestNotice: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.sheetBody)
            .foregroundStyle(Color.sheetSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .sheetCard()
    }
}

/// Request's way to anyone on StarHash: a search over the owner's contacts
/// and a number typed, each row looked up in the directory as it is
/// tapped. Listed with a key, they are asked through the server; anyone
/// else gets Share Message, the owner's number, the amount and the note
/// through the share sheet.
private struct RequestAnywhereSection: View {
    let amount: Int
    let note: String
    let showMyName: Bool
    let onSent: (MoneyRequest) -> Void

    @Environment(Owner.self) private var owner
    @AppStorage(Preferences.enableContacts) private var enableContacts: Bool
    @State private var contacts = PayContacts.shared
    @State private var query = ""
    /// The number being looked up and asked, while it is.
    @State private var checking: String?
    /// What came of the last tap, when it was not sent.
    @State private var outcome: Outcome?
    @FocusState private var searchFocused: Bool

    /// One number to ask, from a contact or typed.
    struct Row: Identifiable, Hashable {
        let recipient: Recipient
        /// The contact's name, nil for a number typed.
        let name: String?
        let contactID: String?
        let hasPhoto: Bool

        var id: String { recipient.destination }
    }

    /// Why the last one tapped was not asked.
    struct Outcome: Equatable {
        enum Kind: Equatable { case notOnStarHash, takesNoRequests, alreadyAsked, tooMany, notListed, failed }
        let kind: Kind
        let name: String
    }

    /// At most this many contacts at once: a search narrows them.
    private static let shownLimit = 60

    var body: some View {
        if !showMyName {
            SheetSectionLabel("Anyone on StarHash")
            RequestNotice(text: String(starhash: "Turn on Show My Name in Settings to ask people who aren't nearby"))
        } else {
            SheetSectionLabel("Anyone on StarHash")
            searchField
            if let outcome { outcomeCard(outcome) }
            let rows = rows
            if !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { SheetDivider().padding(.leading, 70) }
                        rowButton(row)
                    }
                }
                .sheetCard()
            } else if !query.isEmpty {
                RequestNotice(text: String(starhash: "Type a full number to ask someone not in your contacts"))
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(symbol: "magnifyingglass")
                .foregroundStyle(Color.sheetSecondaryText)
                .accessibilityHidden(true)
            TextField(text: $query, prompt: Text("Name or number")) { Text("Search contacts or type a number") }
                .font(.sheetBody)
                .focused($searchFocused)
                .keyboardType(.namePhonePad)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .sheetCard()
        .task(id: enableContacts) {
            if enableContacts { await contacts.loadIfAllowed() }
        }
        .onChange(of: query) { outcome = nil }
    }

    /// A number typed in full first, then the contacts' numbers matching
    /// the search, never the owner's own.
    private var rows: [Row] {
        let search = RecipientSearch(query: query)
        let own = Set([owner.defaultSIM, owner.otherSIM].compactMap { $0?.destination })
        var rows: [Row] = []
        var seen = own
        if let typed = search.typedRecipient, typed.kind == .phone, typed.isRwandanMobile, !seen.contains(typed.destination) {
            let saved = enableContacts ? contacts.contacts.first { $0.recipients.contains { $0.destination == typed.destination } } : nil
            rows.append(Row(recipient: typed, name: saved?.name, contactID: saved?.id, hasPhoto: saved?.hasPhoto ?? false))
            seen.insert(typed.destination)
        }
        guard enableContacts else { return rows }
        for contact in contacts.contacts where search.isEmpty || search.matches(contact) {
            for recipient in contact.recipients where recipient.kind == .phone && recipient.isRwandanMobile {
                guard seen.insert(recipient.destination).inserted else { continue }
                rows.append(Row(recipient: recipient, name: contact.name, contactID: contact.id, hasPhoto: contact.hasPhoto))
                if rows.count >= Self.shownLimit { return rows }
            }
        }
        return rows
    }

    private func rowButton(_ row: Row) -> some View {
        Button { ask(row) } label: {
            HStack(spacing: 12) {
                RecipientTile(tile: tile(for: row), size: 44, fill: .sheetChip)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: row.name ?? row.recipient.formattedDestination)
                        .font(PickerType.rowName)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                    if row.name != nil {
                        Text(verbatim: row.recipient.formattedDestination)
                            .font(PickerType.rowDetail)
                            .foregroundStyle(Color.sheetSecondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if checking == row.recipient.destination { ProgressView() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .disabled(checking != nil)
        .accessibilityLabel(Text("Request \(Money.format(amount)) from \(row.name ?? row.recipient.formattedDestination)"))
    }

    private func tile(for row: Row) -> RecipientRow.Tile {
        let initials: RecipientRow.Tile = row.name.map { .monogram(PayContact.initials(for: $0)) } ?? .shadow(seed: row.recipient.destination)
        guard let id = row.contactID, row.hasPhoto else { return initials }
        return .photo(contactID: id, fallback: initials)
    }

    /// Why it was not sent, with Share Message for someone StarHash cannot
    /// ask.
    private func outcomeCard(_ outcome: Outcome) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: message(for: outcome))
                .font(.sheetBody)
                .foregroundStyle(Color.starhashPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if outcome.kind == .notOnStarHash || outcome.kind == .takesNoRequests {
                ShareLink(item: shareText) {
                    Text("Share Message")
                }
                .buttonStyle(.sheetFilled)
            }
        }
        .padding(16)
        .sheetCard()
        .transition(.opacity)
    }

    private func message(for outcome: Outcome) -> String {
        let name = outcome.name
        return switch outcome.kind {
        case .notOnStarHash: String(starhash: "\(name) isn't on StarHash")
        case .takesNoRequests: String(starhash: "\(name) can't get requests on StarHash yet")
        case .alreadyAsked: String(starhash: "You already asked \(name). Their answer will show under Requests")
        case .tooMany: String(starhash: "You've sent 20 requests today. Ask again tomorrow")
        case .notListed: String(starhash: "Your name isn't on StarHash yet. Try again in a moment")
        case .failed: String(starhash: "Couldn't reach StarHash. Try again")
        }
    }

    /// What Share Message hands the share sheet: the amount, the note and
    /// the owner's number, for someone to pay by hand.
    private var shareText: String {
        let money = Money.formatWithCurrency(amount)
        let number = owner.defaultSIM?.formattedDestination ?? ""
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return if !note.isEmpty {
            String(starhash: "Could you send me \(money) for \(note)? My number is \(number).")
        } else {
            String(starhash: "Could you send me \(money)? My number is \(number).")
        }
    }

    private func ask(_ row: Row) {
        guard checking == nil, let own = owner.defaultSIM else { return }
        searchFocused = false
        checking = row.recipient.destination
        let shownName = row.name.map { $0.split(separator: " ").first.map(String.init) ?? $0 } ?? row.recipient.formattedDestination
        Task {
            defer { checking = nil }
            let anywhere = AppEnvironment.requestsAnywhere
            let listed: RequestsAnywhere.Listed
            switch await anywhere.lookUp(row.recipient.destination) {
            case .listed(let found): listed = found
            case .notListed: return show(.notOnStarHash, shownName)
            case .failed: return show(.failed, shownName)
            }
            let photo = ProfilePhoto.shared.image != nil ? AppEnvironment.serverSync.sharedPhotoID : nil
            let ask = MoneyRequest.Message.Ask(
                id: UUID(), name: owner.name.trimmingCharacters(in: .whitespacesAndNewlines), number: own.destination,
                photoID: photo, amount: amount, note: note
            )
            let person = Recipient(name: row.name, destination: row.recipient.destination, kind: .phone)
            switch await anywhere.ask(ask, to: person, listed: listed) {
            case .success(let sent): onSent(sent)
            case .failure(.notOnStarHash): show(.notOnStarHash, shownName)
            case .failure(.takesNoRequests): show(.takesNoRequests, shownName)
            case .failure(.alreadyAsked): show(.alreadyAsked, shownName)
            case .failure(.tooMany): show(.tooMany, shownName)
            case .failure(.notListed): show(.notListed, shownName)
            case .failure(.failed): show(.failed, shownName)
            }
        }
    }

    private func show(_ kind: Outcome.Kind, _ name: String) {
        withAnimation(.smooth(duration: 0.25)) { outcome = Outcome(kind: kind, name: name) }
    }
}

/// The requests waiting for the owner, in Pay's pill (`PayPill`, on Liquid
/// Glass) ahead of anyone nearby: "JEAN ASKS FOR 5,000 RWF" by their face,
/// turning through them while there are several. No buttons of its own:
/// Pay is already on the page. A tap opens the request's sheet, where it is
/// paid or declined, whatever way it came (nearby, the server, a touch).
struct RequestPill: View {
    let requests: [MoneyRequest]
    let onOpen: (MoneyRequest) -> Void

    var body: some View {
        PayPill(items: requests, onTap: onOpen) { request in
            HStack(spacing: 8) {
                RequestTile(request: request, size: 24)
                PayPillText(text: Text("\(request.person.firstName) asks for \(Money.formatWithCurrency(request.amount))"))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(request.person.shownName) asks for \(Money.formatWithCurrency(request.amount))"))
        }
    }
}

extension Recipient {
    /// The first word of the name shown, for Pay's pill.
    @MainActor
    var firstName: String {
        shownName.split(separator: " ").first.map(String.init) ?? shownName
    }
}

/// One waiting request, with its two answers and no keypad: the request
/// already says how much. Asked of the owner, Pay dials it at once and
/// Decline says no; asked by the owner, Mark as Paid (money that came some
/// way StarHash didn't see) and Cancel Request.
struct RequestAnswerSheet: View {
    let request: MoneyRequest
    @Environment(\.dismiss) private var dismiss
    @Environment(MoneyRequests.self) private var requests
    @Environment(Paying.self) private var paying
    @State private var showsSplit = false

    var body: some View {
        HeroSheet(
            caption: String(starhash: "Request"),
            title: title,
            onClose: { dismiss() }
        ) {
            TileHero { RequestTile(request: request, size: 84) }
        } actions: {
            switch request.direction {
            case .received:
                Button("Pay") { pay() }
                    .buttonStyle(.sheetPrimary)
                SheetTextButton("Decline") {
                    AnywhereRequests.decline(request)
                    dismiss()
                }
            case .sent:
                Button("Mark as Paid") {
                    requests.markPaid(request.id)
                    dismiss()
                }
                .buttonStyle(.sheetPrimary)
                SheetTextButton("Cancel Request", role: .destructive) {
                    AnywhereRequests.cancel(request)
                    dismiss()
                }
            }
        }
        // Locating starts now, so the payment's place is in hand at Pay.
        .onAppear { if request.direction == .received { paying.prepare() } }
        .sheet(isPresented: $showsSplit, onDismiss: {
            paying.stop()
            dismiss()
        }) {
            SplitPaymentSheet()
        }
        // No dial alert of its own: it closes as the code is dialled, and the
        // page under it (Pay, Requests) shows one the system would not dial.
    }

    /// "Ariane asks for 5,000 RWF", or "You asked Ariane for 5,000 RWF".
    private var title: String {
        let name = request.person.shownName
        let amount = Money.formatWithCurrency(request.amount)
        return request.direction == .received
            ? String(starhash: "\(name) asks for \(amount)")
            : String(starhash: "You asked \(name) for \(amount)")
    }

    /// Dials the request as Pay would: recorded, then the call prompt. In
    /// parts, when Split Large Payments says that costs less. One that came
    /// by a tap first tells the asker who is paying, before the call prompt
    /// takes StarHash from the front.
    private func pay() {
        let outcome = paying.pay(request.amount, to: request.person)
        if outcome != .refused { AppEnvironment.nearbyRequests.willPay(request, owner: AppEnvironment.owner) }
        switch outcome {
        case .dialled: dismiss()
        case .split: showsSplit = true
        case .refused: break
        }
    }
}

/// A request's person: the photo their phone shared, or their initials.
struct RequestTile: View {
    let request: MoneyRequest
    var size: CGFloat = 44
    /// Its chip's own fill, on a card the page's chip would vanish into.
    var fill: Color?
    @State private var photo: UIImage?

    var body: some View {
        RecipientTile(tile: photo.map { .image($0) } ?? .monogram(PayContact.initials(for: request.person.shownName)), size: size, fill: fill)
            .task(id: request.photoID) {
                photo = nil
                guard let id = request.photoID else { return }
                #if DEBUG
                if let sample = PeopleNearbyDebug.photo(for: id) {
                    photo = sample
                    return
                }
                #endif
                photo = await StarHashCloud.photo(id)
            }
    }
}

/// Requests, from Transactions: those asked of the owner, then those they
/// sent, each with how it stands. A waiting one opens its answers.
struct RequestsPage: View {
    @Environment(MoneyRequests.self) private var requests
    @State private var opened: MoneyRequest?
    @FeatureFlagged(.requestsAnywhere) private var anywhereOn
    @AppStorage(Preferences.enableContacts) private var enableContacts: Bool
    @State private var contacts = PayContacts.shared

    var body: some View {
        let asked = requests.requests.filter { $0.direction == .received }
        let sent = requests.requests.filter { $0.direction == .sent }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if cannotTellWhoAsks {
                    // Requests from anywhere wait on the server, unread,
                    // until StarHash can tell who sent them.
                    Text("Only people in your Contacts can ask you, and StarHash can't read your Contacts now, so their requests wait.")
                        .font(.starhash(.subheadline))
                        .foregroundStyle(Color.starhashSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .starhashOutlinedCard()
                        .padding(.horizontal, StarHashMetrics.screenPadding)
                        .padding(.top, 16)
                }
                if !asked.isEmpty {
                    section("Asked of you", asked)
                }
                if !sent.isEmpty {
                    section("You asked", sent)
                }
            }
            .padding(.bottom, 24)
            .starhashReadableWidth()
        }
        .overlay {
            if requests.requests.isEmpty {
                EmptyStateView(doodle: .transactions, title: "No Requests")
                    .padding(.horizontal, StarHashMetrics.screenPadding)
                    .allowsHitTesting(false)
            }
        }
        .starhashSoftEdge()
        .background(Color.starhashBackground.ignoresSafeArea())
        .starhashNavigationTitle(String(starhash: "Requests"))
        .sheet(item: $opened) { RequestAnswerSheet(request: $0) }
        .dialFailureAlert()
        .task(id: enableContacts) { await contacts.loadIfAllowed() }
    }

    /// Whether StarHash cannot read the owner's Contacts, so cannot tell
    /// who a request from anywhere comes from (`NearbyRequests.mayAsk`).
    private var cannotTellWhoAsks: Bool {
        anywhereOn && FeatureFlags.isOn(.peopleNearby) && !(enableContacts && contacts.access == .authorized)
    }

    private func section(_ title: String, _ list: [MoneyRequest]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetSectionLabel(title, onPage: true)
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 6)
            ForEach(list) { request in
                RequestRow(request: request) { opened = request }
            }
        }
    }
}

/// One request on the Requests page: the person, the amount and how it
/// stands. Only a waiting one is a button.
private struct RequestRow: View {
    let request: MoneyRequest
    let open: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                RequestTile(request: request)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: request.person.shownName)
                        .font(PickerType.rowName)
                        .foregroundStyle(Color.starhashPrimaryText)
                        .lineLimit(1)
                    Text(verbatim: subtitle)
                        .font(PickerType.rowDetail)
                        .foregroundStyle(Color.sheetSecondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(verbatim: Money.formatWithCurrency(request.amount))
                        .font(.starhashNumber(16, weight: .semibold))
                        .foregroundStyle(Color.starhashPrimaryText)
                    Text(verbatim: status)
                        .font(PickerType.rowDetail)
                        .foregroundStyle(request.status == .waiting ? Color.starhashUrgentText : Color.starhashSecondaryText.color(scheme: colorScheme, surface: .page))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                SheetDivider().padding(.leading, 18 + 44 + 12).padding(.trailing, 18)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HighlightRowButtonStyle())
        .disabled(request.status != .waiting)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let date = request.createdAt.formatted(.dateTime.day().month(.abbreviated).locale(.starhash))
        return [request.note, date].compactMap { $0 }.joined(separator: " · ")
    }

    private var status: String {
        switch request.status {
        case .waiting: String(starhash: "Waiting")
        case .paid: String(starhash: "Paid")
        case .declined: String(starhash: "Declined")
        case .cancelled: String(starhash: "Cancelled")
        case .expired: String(starhash: "Expired")
        }
    }
}

/// Transactions' way to Requests: a row at the top of the list while there
/// are any, with how many wait for the owner.
struct RequestsLinkRow: View {
    @Environment(MoneyRequests.self) private var requests
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(symbol: "arrow.left.arrow.right")
                    .font(.starhash(.body, weight: .semibold))
                    .foregroundStyle(Color.starhashAccentText)
                    .frame(width: 24)
                Text("Requests")
                    .font(.starhash(.body, weight: .semibold))
                    .foregroundStyle(Color.starhashPrimaryText)
                Spacer(minLength: 8)
                let waiting = requests.waitingForOwner.count
                if waiting > 0 {
                    Text(verbatim: String(starhash: "\(waiting) waiting"))
                        .font(.starhash(.subheadline))
                        .foregroundStyle(Color.starhashUrgentText)
                }
                Image(symbol: "chevron.right")
                    .font(.starhash(.footnote, weight: .semibold))
                    .foregroundStyle(Color.starhashSecondaryText)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        // The list already sits in from the screen's edges.
        .starhashOutlinedCard()
    }
}

