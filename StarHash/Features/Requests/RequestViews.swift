import StarHashKit
import SwiftUI

/// Request on Pay: the amount typed, then who to ask among the people
/// nearby, with a note if the owner wants one. A tap sends it.
struct RequestSheet: View {
    let amount: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(PeopleNearbyService.self) private var nearby
    @Environment(Owner.self) private var owner
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

                    SheetSectionLabel("People Nearby")
                    people
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

    @ViewBuilder
    private var people: some View {
        if let missing = NearbyRequests.missing(in: owner) {
            notice(missing)
        } else if nearby.found.people.isEmpty {
            notice(String(starhash: "No one nearby has StarHash open"))
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

    private func notice(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.sheetBody)
            .foregroundStyle(Color.sheetSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .sheetCard()
    }

    private func ask(_ person: PeopleNearby.Person) {
        noteFocused = false
        Task {
            let photo = ProfilePhoto.shared.image != nil ? AppEnvironment.serverSync.sharedPhotoID : nil
            if await AppEnvironment.nearbyRequests.ask(person, amount: amount, note: note, owner: owner, photoID: photo) != nil {
                sentCount += 1
                AccessibilityNotification.Announcement(String(starhash: "Asked \(person.firstName) for \(Money.format(amount))")).post()
                dismiss()
            } else {
                unreachable = person
            }
        }
    }
}

/// A request waiting for the owner, on Pay in the chosen recipient's
/// place: who asks, how much and what for, with Decline and Pay. Pay
/// chooses them with the amount typed in, as a scanned code does; the
/// owner still taps Pay. A tap on the card opens Requests.
struct RequestCard: View {
    let request: MoneyRequest
    /// More waiting behind this one.
    let others: Int
    let onOpen: () -> Void

    var body: some View {
        // No buttons of its own: Pay is already on the page. A tap opens
        // the request, where it is paid or declined.
        Button(action: onOpen) {
            HStack(spacing: 10) {
                RequestTile(request: request, size: 40, fill: .sheetChip)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(request.person.shownName) asks for \(Money.formatWithCurrency(request.amount))")
                        .font(.starhash(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.payPrimaryText)
                        .lineLimit(1)
                    if let detail {
                        Text(verbatim: detail)
                            .font(.starhash(.caption))
                            .foregroundStyle(Color.paySecondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(symbol: "chevron.right")
                    .font(.starhash(.footnote, weight: .semibold))
                    .foregroundStyle(Color.paySecondaryText)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .starhashContainer(.starhashCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.hapticPlain)
        .padding(.horizontal, StarHashMetrics.screenPadding)
    }

    /// "Lunch · 2 more waiting".
    private var detail: String? {
        let others = others > 0 ? String(starhash: "\(others) more waiting") : nil
        let line = [request.note, others].compactMap { $0 }.joined(separator: " · ")
        return line.isEmpty ? nil : line
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
    @State private var height: CGFloat = 400
    @State private var showsSplit = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(Money.formatWithCurrency(request.amount))

            VStack(spacing: 24) {
                HStack(spacing: 14) {
                    RequestTile(request: request, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: request.person.shownName)
                            .font(.sheetBody)
                            .foregroundStyle(Color.starhashPrimaryText)
                            .lineLimit(1)
                        Text(verbatim: line)
                            .font(.sheet(14, .medium, relativeTo: .subheadline))
                            .foregroundStyle(Color.sheetSecondaryText)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .sheetCard()
                .accessibilityElement(children: .combine)

                VStack(spacing: 6) {
                    switch request.direction {
                    case .received:
                        Button("Pay") { pay() }
                            .buttonStyle(.sheetPrimary)
                        SheetTextButton("Decline") {
                            AppEnvironment.nearbyRequests.decline(request)
                            dismiss()
                        }
                    case .sent:
                        Button("Mark as Paid") {
                            requests.markPaid(request.id)
                            dismiss()
                        }
                        .buttonStyle(.sheetPrimary)
                        SheetTextButton("Cancel Request", role: .destructive) {
                            requests.cancel(request.id)
                            dismiss()
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .sheetHeight($height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .sheetGlass(detents: [.height(height - 4)])
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

    /// "Asks you · Lunch · 26 Nov", or "You asked · ...".
    private var line: String {
        let who = request.direction == .received ? String(starhash: "Asks you") : String(starhash: "You asked")
        let date = request.createdAt.formatted(.dateTime.day().month(.abbreviated).locale(.starhash))
        return [who, request.note, date].compactMap { $0 }.joined(separator: " · ")
    }

    /// Dials the request as Pay would: recorded, then the call prompt. In
    /// parts, when Split Large Payments says that costs less.
    private func pay() {
        switch paying.pay(request.amount, to: request.person) {
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

    var body: some View {
        let asked = requests.requests.filter { $0.direction == .received }
        let sent = requests.requests.filter { $0.direction == .sent }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
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

