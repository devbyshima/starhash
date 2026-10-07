import StarHashKit
import SwiftUI
import UserNotifications

/// Notifications, one row away from Settings: whether iOS lets StarHash
/// notify at all, then what it tells you of and when, and how it shows.
/// Every choice can be made before notifications are allowed, and each one
/// reschedules what is waiting at once.
struct NotificationSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(StarHashStore.self) private var store

    @AppStorage(PreferenceKey.notifyPaymentReminders) private var paymentReminders = true
    @AppStorage(PreferenceKey.paymentReminderDelay) private var reminderDelay = NotificationPlan.defaultReminderDelay
    @AppStorage(PreferenceKey.notifyConfirmedPayments) private var confirmedPayments = false
    @AppStorage(PreferenceKey.notifyMoneyReceived) private var moneyReceived = false
    @AppStorage(PreferenceKey.notifyWeeklySummary) private var weeklySummary = true
    @AppStorage(PreferenceKey.weeklySummaryDay) private var weeklyDay = NotificationPlan.defaultWeeklyDay
    @AppStorage(PreferenceKey.notifyMonthlySummary) private var monthlySummary = true
    @AppStorage(PreferenceKey.summaryHour) private var summaryHour = NotificationPlan.defaultSummaryHour
    @AppStorage(PreferenceKey.notificationAmounts) private var showsAmounts = true
    @AppStorage(PreferenceKey.notificationSound) private var sound = true
    @AppStorage(PreferenceKey.wallet) private var wallet: Recipient.Network = .mtn
    @AppStorage(PreferenceKey.autoVerifySetUp) private var autoVerifySetUp = false
    @AppStorage(PreferenceKey.lastVerifiedAt) private var lastVerifiedAt: Double = 0
    @AppStorage(PreferenceKey.lastMessageAt) private var lastMessageAt: Double = 0
    @AppStorage(PreferenceKey.autoVerifySince) private var autoVerifySince: Double = 0

    /// What iOS last said, so the page opens as it will stay; nil until
    /// it has answered once.
    @State private var status = StarHashNotifications.shared.lastStatus

    var body: some View {
        SettingsScroll {
            if let status, !status.allowsDelivery {
                permissionCard(denied: status == .denied)
                    .transition(.opacity)
            }

            SettingsCard("Payments") {
                SettingsToggleRow(
                    symbol: "bell.badge.fill",
                    title: "Payment reminders",
                    caption: failsUnconfirmed
                        ? "When no \(wallet.messagesName) message confirms a payment within an hour"
                        : "When a payment you made is still pending",
                    isOn: $paymentReminders
                )
                // With auto-verify, the hour is the reminder's time.
                if paymentReminders, !failsUnconfirmed {
                    SettingsRow(symbol: "hourglass", title: "Remind me after", caption: "How long a payment waits first") {
                        SettingsChoiceMenu(
                            title: "Remind me after",
                            selection: $reminderDelay,
                            choices: NotificationPlan.reminderDelays,
                            label: Self.delayTitle
                        )
                    }
                }
                SettingsToggleRow(
                    symbol: "checkmark.seal.fill",
                    title: "Confirmed payments",
                    caption: autoVerifyOn
                        ? "When a \(wallet.messagesName) message confirms a payment"
                        : "Needs auto-verify, under Transactions",
                    isOn: $confirmedPayments
                )
                SettingsToggleRow(
                    symbol: "arrow.down.circle.fill",
                    title: "Money received",
                    caption: autoVerifyOn
                        ? "When a \(wallet.messagesName) message brings money in"
                        : "Needs auto-verify, under Transactions",
                    isOn: $moneyReceived
                )
            }

            SettingsCard("Summaries") {
                SettingsToggleRow(
                    symbol: "chart.bar.fill",
                    title: "Weekly summary",
                    caption: "What you sent and received in the week",
                    isOn: $weeklySummary
                )
                if weeklySummary {
                    SettingsRow(symbol: "calendar", title: "Day", caption: "The day it comes") {
                        SettingsChoiceMenu(
                            title: "Day",
                            selection: $weeklyDay,
                            choices: Self.weekdays,
                            label: Self.weekdayTitle
                        )
                    }
                }
                SettingsToggleRow(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: "Monthly summary",
                    caption: "The month just ended, on the 1st",
                    isOn: $monthlySummary
                )
                if weeklySummary || monthlySummary {
                    SettingsRow(symbol: "sunset.fill", title: "Time", caption: "When the summaries come") {
                        SettingsChoiceMenu(
                            title: "Time",
                            selection: $summaryHour,
                            choices: NotificationPlan.summaryHours,
                            label: Self.hourTitle
                        )
                    }
                }
            }

            SettingsCard("Privacy & Sound") {
                SettingsToggleRow(
                    symbol: "eye.fill",
                    title: "Show amounts",
                    caption: "Off keeps amounts and balances off the Lock Screen",
                    isOn: $showsAmounts
                )
                SettingsToggleRow(
                    symbol: "speaker.wave.2.fill",
                    title: "Sound",
                    caption: "Play a sound with each notification",
                    isOn: $sound
                )
            }
        }
        #if DEBUG
        // -settingsScrolled: start at the foot, for screenshots.
        .defaultScrollAnchor(DebugLaunch.arguments.contains("-settingsScrolled") ? .bottom : nil)
        #endif
        .settingsPage("Notifications")
        .animation(.smooth, value: paymentReminders)
        .animation(.smooth, value: weeklySummary || monthlySummary)
        .animation(.smooth, value: weeklySummary)
        .animation(.smooth, value: status)
        .task { await refreshStatus() }
        // Back from the Settings app, where they may have been turned on.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshStatus() }
        }
        .onChange(of: choices) {
            Task { await StarHashNotifications.shared.sync() }
        }
        .onChange(of: sound) {
            Task { await StarHashNotifications.shared.sync() }
        }
    }

    /// What the page shows, as the plan reads it.
    private var choices: NotificationPlan.Settings {
        NotificationPlan.Settings(
            paymentReminders: paymentReminders, reminderDelay: reminderDelay,
            confirmedPayments: confirmedPayments, moneyReceived: moneyReceived,
            weeklySummary: weeklySummary, weeklyDay: weeklyDay,
            monthlySummary: monthlySummary, summaryHour: summaryHour,
            showsAmounts: showsAmounts
        )
    }

    private var autoVerifyOn: Bool { autoVerifySetUp && lastVerifiedAt > 0 }

    /// Auto-verify fails a payment no message confirms within the hour, so
    /// the reminder says that instead (`PaymentExpiry`). Read here from the
    /// page's own values, so it follows them.
    private var failsUnconfirmed: Bool {
        autoVerifyOn
            && StarHashPreferences.automationProven(lastMessageAt: lastMessageAt, since: autoVerifySince)
            && !AutoVerify.looksBroken(
                store.transactions,
                lastMessageAt: Date(timeIntervalSince1970: lastMessageAt),
                now: .now
            )
    }

    /// Above everything while iOS does not let StarHash notify: Turn On
    /// asks the first time, and after a refusal the Settings app is the
    /// only way back.
    private func permissionCard(denied: Bool) -> some View {
        SettingsCard {
            SettingsRow(
                symbol: "bell.slash.fill",
                title: denied ? "Notifications are off" : "Allow notifications",
                caption: denied
                    ? "Turn them on for StarHash in the Settings app"
                    : "Nothing below arrives until you do"
            ) {
                Button(denied ? "Open Settings" : "Turn On") {
                    if denied {
                        SettingsAppLink.openNotifications()
                    } else {
                        Task {
                            await StarHashNotifications.shared.requestAuthorization()
                            await refreshStatus()
                        }
                    }
                }
                .buttonStyle(.starhashCapsule(height: 36, horizontalPadding: 16))
                .fixedSize()
            }
        }
    }

    private func refreshStatus() async {
        status = await StarHashNotifications.shared.authorizationStatus()
    }

    // MARK: Labels

    /// "10 minutes", "1 hour".
    private static func delayTitle(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) minutes" }
        let hours = minutes / 60
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }

    /// The week's days from the one the calendar starts on, as `Calendar`
    /// numbers them.
    private static var weekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private static func weekdayTitle(_ day: Int) -> String {
        Calendar.current.weekdaySymbols[day - 1]
    }

    /// "18:00" or "6 PM", as the iPhone writes the time.
    private static func hourTitle(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
