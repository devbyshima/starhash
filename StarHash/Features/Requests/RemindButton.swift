import StarHashKit
import SwiftUI

/// Remind: for requests the owner sent that are still waiting, word to each
/// person asked, through the server, at most once a day each
/// (`RequestsAnywhere.remind`). It reminds everyone it may now, and while
/// none may, says when it can next ("Remind at 8:00 PM", "Remind
/// Tomorrow"). On a request's sheet it is the primary button; at the foot
/// of a bulk request's card, a full-width line in the accent.
struct RemindButton: View {
    enum Style { case sheet, card }

    /// The requests it is for; read again from the store, as reminding
    /// changes them.
    let requests: [MoneyRequest]
    let style: Style

    @Environment(MoneyRequests.self) private var store
    @State private var sending = false
    @State private var failure: RequestsAnywhere.RemindFailure?
    @State private var reminded = 0

    var body: some View {
        // Redrawn each minute, so it turns to Remind once the day is up.
        TimelineView(.everyMinute) { context in
            let live = requests.compactMap { store.request(id: $0.id) }.filter(\.isRemindable)
            let due = live.filter { $0.canRemind(at: context.date) }
            let title = title(due: due, live: live, now: context.date)
            Group {
                switch style {
                case .sheet:
                    Button(title) { remind(due) }
                        .buttonStyle(.sheetPrimary)
                case .card:
                    Button { remind(due) } label: {
                        Text(verbatim: title)
                            .font(.starhash(.body, weight: .semibold))
                            .foregroundStyle(due.isEmpty || sending
                                ? AnyShapeStyle(Color.starhashSecondaryText)
                                : AnyShapeStyle(Color.starhashAccentText))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HighlightRowButtonStyle())
                }
            }
            .disabled(due.isEmpty || sending)
            .contentTransition(.opacity)
            .animation(.smooth(duration: 0.25), value: title)
        }
        .sensoryFeedback(.success, trigger: reminded)
        .alert(
            "Couldn't Remind",
            isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }),
            presenting: failure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(verbatim: message(for: failure))
        }
    }

    /// "Remind Ariane", "Remind 2 People", "Reminding", or when it can next.
    private func title(due: [MoneyRequest], live: [MoneyRequest], now: Date) -> String {
        if sending { return String(starhash: "Reminding") }
        if due.count == 1, let one = due.first { return String(starhash: "Remind \(one.person.firstName)") }
        if due.count > 1 { return String(starhash: "Remind \(due.count) People") }
        guard let next = live.map(\.nextReminderAt).min() else { return String(starhash: "Remind") }
        if Calendar.current.isDate(next, inSameDayAs: now) {
            let time = next.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.starhash))
            return String(starhash: "Remind at \(time)")
        }
        return String(starhash: "Remind Tomorrow")
    }

    private func message(for failure: RequestsAnywhere.RemindFailure) -> String {
        switch failure {
        case .tooSoon: String(starhash: "You can remind someone once a day")
        case .notWaiting: String(starhash: "That request isn't waiting anymore")
        case .failed: String(starhash: "Couldn't reach StarHash. Try again")
        }
    }

    private func remind(_ due: [MoneyRequest]) {
        guard !sending, !due.isEmpty else { return }
        sending = true
        Task {
            let outcome = await AnywhereRequests.remind(due)
            sending = false
            if outcome.reminded > 0 {
                reminded += 1
                AccessibilityNotification.Announcement(
                    outcome.reminded == 1 ? String(starhash: "Reminded 1 person") : String(starhash: "Reminded \(outcome.reminded) people")
                ).post()
            } else {
                // Said only when none went: those that did show it already.
                failure = outcome.failure ?? .failed
            }
        }
    }
}
