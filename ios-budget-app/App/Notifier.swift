import Foundation
import UserNotifications
import DailyBudgetCore

/// iOS can't run code at 8am/10pm on its own, so notification TEXT is computed now and scheduled.
/// It's recomputed on every app open, new transaction, and plan change — which are exactly the
/// moments the numbers change.
enum Notifier {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    @MainActor
    static func reschedule(_ store: Store) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["morning", "night"])
        guard store.plan != nil else { return }
        let now = Date(), cal = Calendar.current

        // Night review: today's numbers if 10pm is still ahead, else tomorrow's projection (no spend yet).
        if let r = store.review(now) {
            var when = cal.date(bySettingHour: 22, minute: 0, second: 0, of: now)!
            var review = r
            if when <= now { when = store.addDays(when, 1); review = store.review(store.addDays(now, 1)) ?? r }
            let verdict = review.diffPaise >= 0
                ? "Under by \(rupeeString(review.diffPaise)) — carried into the next days."
                : "Over by \(rupeeString(-review.diffPaise)) — tomorrow's budget shrinks."
            await add(id: "night", title: "Tonight's review 🌙", at: when,
                      body: "Budget \(rupeeString(review.today.allowancePaise)), spent \(rupeeString(review.today.spentTodayPaise)). \(verdict) Tomorrow you can spend \(rupeeString(review.tomorrowAllowancePaise)).")
        }

        // Morning: the next 8am, using the pool as it stands after today's spending.
        var m = cal.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        if m <= now { m = store.addDays(m, 1) }
        let target = cal.startOfDay(for: m)
        if let plan = store.plan {
            let before = store.spent(from: plan.cycleStart, to: target)
            let d = BudgetEngine.dayBudget(plan: plan, spentBefore: before, spentToday: 0, today: target)
            let body = d.poolOverdrawn
                ? "You've used up this month's spending pool. Every rupee now eats into your savings goal."
                : "Today's budget: \(rupeeString(d.allowancePaise)) (\(d.daysLeftInclusive) days left, \(rupeeString(d.poolRemainingPaise)) in the pool)."
            await add(id: "morning", title: "Good morning ☀️", at: m, body: body)
        }
    }

    /// Instant "where did it go" alert for a just-ingested debit.
    @MainActor
    static func alertSpend(_ t: Txn, store: Store) async {
        guard t.isDebit, t.countsTowardBudget, let d = store.today() else { return }
        let left = d.leftTodayPaise
        let body = left >= 0 ? "\(rupeeString(left)) left of today's \(rupeeString(d.allowancePaise))."
                             : "Over today's budget by \(rupeeString(-left))."
        let c = UNMutableNotificationContent()
        c.title = "\(rupeeString(t.amountPaise)) → \(t.merchant ?? "Unknown") (\(t.category))"; c.body = body; c.sound = .default
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    private static func add(id: String, title: String, at: Date, body: String) async {
        let c = UNMutableNotificationContent(); c.title = title; c.body = body; c.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: c, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }
}
