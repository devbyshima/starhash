import StarHashKit
import SwiftUI
import UserNotifications

extension PreferenceKey {
    /// The Notifications page's choices (`NotificationPlan.Settings`).
    static let notifyPaymentReminders = "notifyPaymentReminders"
    /// Minutes, one of `NotificationPlan.reminderDelays`.
    static let paymentReminderDelay = "paymentReminderDelay"
    static let notifyConfirmedPayments = "notifyConfirmedPayments"
    static let notifyMoneyReceived = "notifyMoneyReceived"
    static let notifyWeeklySummary = "notifyWeeklySummary"
    /// A `Calendar` weekday, 1 for Sunday.
    static let weeklySummaryDay = "weeklySummaryDay"
    static let notifyMonthlySummary = "notifyMonthlySummary"
    /// The hour both summaries come, 0 to 23.
    static let summaryHour = "summaryHour"
    static let notificationAmounts = "notificationAmounts"
    static let notificationSound = "notificationSound"
}

extension StarHashPreferences {
    /// The Notifications page's choices, with the defaults it shows, and
    /// whether auto-verify fails unconfirmed payments.
    @MainActor
    static var notifications: NotificationPlan.Settings {
        let defaults = NotificationPlan.Settings()
        let saved = UserDefaults.standard
        return NotificationPlan.Settings(
            paymentReminders: bool(PreferenceKey.notifyPaymentReminders, default: defaults.paymentReminders),
            reminderDelay: saved.object(forKey: PreferenceKey.paymentReminderDelay) as? Int ?? defaults.reminderDelay,
            confirmedPayments: bool(PreferenceKey.notifyConfirmedPayments, default: defaults.confirmedPayments),
            moneyReceived: bool(PreferenceKey.notifyMoneyReceived, default: defaults.moneyReceived),
            weeklySummary: bool(PreferenceKey.notifyWeeklySummary, default: defaults.weeklySummary),
            weeklyDay: saved.object(forKey: PreferenceKey.weeklySummaryDay) as? Int ?? defaults.weeklyDay,
            monthlySummary: bool(PreferenceKey.notifyMonthlySummary, default: defaults.monthlySummary),
            summaryHour: saved.object(forKey: PreferenceKey.summaryHour) as? Int ?? defaults.summaryHour,
            showsAmounts: bool(PreferenceKey.notificationAmounts, default: defaults.showsAmounts),
            failsUnconfirmed: PaymentExpiry.isActive
        )
    }

    static var notificationSound: Bool { bool(PreferenceKey.notificationSound, default: true) }
}

extension UNAuthorizationStatus {
    /// Whether iOS shows what StarHash schedules.
    var allowsDelivery: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }
}

/// StarHash's notifications, all made on the iPhone from what it already
/// keeps (`NotificationPlan` works out what they say): it keeps iOS's queue
/// in step with the transactions and the Notifications page, says what a
/// carrier SMS just did, and answers a tap or a reminder's buttons.
@MainActor
final class StarHashNotifications {
    static let shared = StarHashNotifications()

    private let center = UNUserNotificationCenter.current()
    private let responder = NotificationResponder()
    /// Each sync waits for the one before, so an older plan never lands
    /// on top of a newer one.
    private var lastSync: Task<Void, Never>?

    /// A reminder's buttons.
    enum Action {
        static let confirm = "confirm"
        static let fail = "fail"
    }

    static let reminderCategory = "payment-reminder"
    /// A payment auto-verify failed, with one button to say it went
    /// through after all.
    static let expiredCategory = "payment-expired"

    private init() {}

    /// At launch, before any notification can be answered: the delegate,
    /// the reminder's two buttons and the failed payment's one. All ask
    /// for Face ID or the passcode first, so a locked phone cannot settle
    /// a payment.
    func start() {
        center.delegate = responder
        let confirm = UNNotificationAction(identifier: Action.confirm, title: "Mark as Confirmed", options: [.authenticationRequired])
        let fail = UNNotificationAction(identifier: Action.fail, title: "Mark as Failed", options: [.authenticationRequired, .destructive])
        let wentThrough = UNNotificationAction(identifier: Action.confirm, title: "It Went Through", options: [.authenticationRequired])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.reminderCategory, actions: [confirm, fail], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.expiredCategory, actions: [wentThrough], intentIdentifiers: []),
        ])
    }

    /// What iOS said last time it was asked (every sync asks), for a page
    /// that wants to open without waiting for it.
    private(set) var lastStatus: UNAuthorizationStatus?

    func authorizationStatus() async -> UNAuthorizationStatus {
        let status = await center.notificationSettings().authorizationStatus
        lastStatus = status
        return status
    }

    /// Asks iOS, the first time only; after a refusal only the Settings app
    /// can change it. Schedules what is due once it is allowed.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let allowed = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        if allowed { await sync() }
        return allowed
    }

    /// Brings iOS's queue in line with the plan: what is no longer due
    /// goes, and every reminder and summary is scheduled again (the same
    /// id replaces it), so a summary counts everything up to now. A
    /// reminder already showing goes once its payment is settled.
    func sync() async {
        let previous = lastSync
        let task = Task {
            await previous?.value
            await performSync()
        }
        lastSync = task
        await task.value
    }

    private func performSync() async {
        let waiting = await center.pendingNotificationRequests().map(\.identifier).filter(Self.isScheduled)
        guard await authorizationStatus().allowsDelivery else {
            center.removePendingNotificationRequests(withIdentifiers: waiting)
            return
        }
        let transactions = AppEnvironment.store.transactions
        let plan = NotificationPlan.scheduled(
            for: transactions, settings: StarHashPreferences.notifications, now: .now, calendar: .current
        )
        let planned = Set(plan.map(\.id))
        center.removePendingNotificationRequests(withIdentifiers: waiting.filter { !planned.contains($0) })
        for item in plan {
            try? await center.add(request(for: item))
        }

        // A reminder stays while its payment is pending, word that one
        // failed until it is confirmed after all.
        let pending = Set(transactions.filter { $0.status == .pending }.map(\.id))
        let unconfirmed = Set(transactions.filter { $0.status != .confirmed }.map(\.id))
        let settled = await center.deliveredNotifications()
            .filter { notification in
                let content = notification.request.content
                guard let id = Self.transactionID(of: content.userInfo) else { return false }
                switch content.categoryIdentifier {
                case Self.reminderCategory: return !pending.contains(id)
                case Self.expiredCategory: return !unconfirmed.contains(id)
                default: return false
                }
            }
            .map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: settled)
    }

    /// A carrier SMS was just applied to `transaction`, which stood as
    /// `previous` before it (nil when the message added it): says so, when
    /// the owner asked to hear of it.
    func messageApplied(_ transaction: StarHashKit.Transaction, previous: StarHashKit.Transaction?) async {
        guard let item = NotificationPlan.afterMessage(
            applied: transaction, previous: previous, settings: StarHashPreferences.notifications
        ), await authorizationStatus().allowsDelivery else { return }
        try? await center.add(request(for: item))
    }

    /// Delete All Data: nothing left waiting or showing.
    func removeAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// A tap opens what the notification is about: its transaction, or
    /// Activity for a summary. The buttons settle the payment as its
    /// details page would: a failed one can still be confirmed.
    func answer(action: String, transactionID: UUID?) async {
        let store = AppEnvironment.store
        switch action {
        case Action.confirm, Action.fail:
            // StarHash may have woken in the background just for this.
            store.reloadFromDisk()
            guard let id = transactionID, let transaction = store.transaction(id: id) else { return }
            if action == Action.confirm, transaction.status != .confirmed {
                store.update(transaction.confirmedByHand(wallet: StarHashPreferences.wallet))
            } else if action == Action.fail, transaction.status == .pending {
                store.update(transaction.markedFailed())
            }
            await sync()
        case UNNotificationDefaultActionIdentifier:
            if let id = transactionID, let url = URL(string: "starhash://transaction/\(id.uuidString)") {
                AppEnvironment.router.handle(url)
            } else {
                AppEnvironment.router.show(.activity)
            }
        default:
            break
        }
    }

    private func request(for item: NotificationPlan.Item) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = StarHashPreferences.notificationSound ? .default : nil
        // Payments stack apart from the summaries.
        content.threadIdentifier = item.transactionID == nil ? "summaries" : "payments"
        if let id = item.transactionID {
            content.userInfo = ["transaction": id.uuidString]
        }
        switch item.kind {
        case .paymentReminder: content.categoryIdentifier = Self.reminderCategory
        case .paymentExpired: content.categoryIdentifier = Self.expiredCategory
        default: break
        }
        let trigger = item.date.map {
            UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: $0),
                repeats: false
            )
        }
        return UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
    }

    private static func isScheduled(_ id: String) -> Bool {
        NotificationPlan.scheduledPrefixes.contains { id.hasPrefix($0) }
    }

    nonisolated static func transactionID(of userInfo: [AnyHashable: Any]) -> UUID? {
        (userInfo["transaction"] as? String).flatMap(UUID.init(uuidString:))
    }
}

/// iOS's side of the conversation, apart from the main actor: it shows
/// StarHash's notifications while the app is open too, and hands a tap or
/// a button to `StarHashNotifications`.
private final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let id = StarHashNotifications.transactionID(of: response.notification.request.content.userInfo)
        await StarHashNotifications.shared.answer(action: action, transactionID: id)
    }
}
