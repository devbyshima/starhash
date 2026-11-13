import Foundation

/// A choice the owner makes in Settings, under its key, with its one
/// default. Views read it through `@AppStorage(preference)` (the app's own
/// extension) and everything else through `value(in:)`, so the default is
/// written here and nowhere else.
public struct Preference<Value: Sendable>: Sendable {
    public let key: String
    public let defaultValue: Value

    public init(_ key: String, default defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
    }

    /// The choice made, or the default until one is.
    public func value(in defaults: UserDefaults = .standard) -> Value {
        defaults.object(forKey: key) as? Value ?? defaultValue
    }
}

/// Every choice in Settings: everything on, every notification included,
/// except Nearby (it needs location permission first) and the Face ID
/// lock. The keys are the ones StarHash has always kept them under.
public enum Preferences {
    // MARK: Transactions and paying

    public static let saveTransactions = Preference("saveTransactions", default: true)
    public static let saveRecents = Preference("saveRecents", default: true)
    public static let enableContacts = Preference("enableContacts", default: true)
    public static let nearbyLocation = Preference("nearbyLocation", default: false)
    /// Whether deleting one transaction asks first. Turned off with Don't
    /// Ask Again on the question itself, back on in Settings.
    public static let confirmDeletes = Preference("confirmDeletes", default: true)
    /// Whether the on-device model may name the categories the rules
    /// cannot (iOS 26 and later, with Apple Intelligence).
    public static let smartCategories = Preference("smartCategories", default: true)

    // MARK: Security

    /// Whether a message that looks like the wallet's but may be a scam is
    /// held back with a warning.
    public static let scamWarnings = Preference("scamWarnings", default: true)
    public static let appLock = Preference("appLock", default: false)
    /// Whether people who type the owner's number in StarHash see their
    /// name and photo.
    public static let showMyName = Preference("showMyName", default: true)

    // MARK: Notifications

    public static let paymentReminders = Preference("notifyPaymentReminders", default: true)
    /// Minutes, one of `NotificationPlan.reminderDelays`.
    public static let reminderDelay = Preference("paymentReminderDelay", default: NotificationPlan.defaultReminderDelay)
    public static let confirmedPayments = Preference("notifyConfirmedPayments", default: true)
    public static let moneyReceived = Preference("notifyMoneyReceived", default: true)
    public static let weeklySummary = Preference("notifyWeeklySummary", default: true)
    /// A `Calendar` weekday, 1 for Sunday.
    public static let weeklySummaryDay = Preference("weeklySummaryDay", default: NotificationPlan.defaultWeeklyDay)
    public static let monthlySummary = Preference("notifyMonthlySummary", default: true)
    /// The hour both summaries come, 0 to 23.
    public static let summaryHour = Preference("summaryHour", default: NotificationPlan.defaultSummaryHour)
    public static let showsAmounts = Preference("notificationAmounts", default: true)
    public static let notificationSound = Preference("notificationSound", default: true)
}

extension NotificationPlan.Settings {
    /// The Notifications page's choices as saved, with
    /// `failsUnconfirmedSince` from auto-verify, which is no choice on the
    /// page.
    public static func stored(in defaults: UserDefaults = .standard, failsUnconfirmedSince: Date?) -> Self {
        Self(
            paymentReminders: Preferences.paymentReminders.value(in: defaults),
            reminderDelay: Preferences.reminderDelay.value(in: defaults),
            confirmedPayments: Preferences.confirmedPayments.value(in: defaults),
            moneyReceived: Preferences.moneyReceived.value(in: defaults),
            weeklySummary: Preferences.weeklySummary.value(in: defaults),
            weeklyDay: Preferences.weeklySummaryDay.value(in: defaults),
            monthlySummary: Preferences.monthlySummary.value(in: defaults),
            summaryHour: Preferences.summaryHour.value(in: defaults),
            showsAmounts: Preferences.showsAmounts.value(in: defaults),
            failsUnconfirmedSince: failsUnconfirmedSince
        )
    }
}
