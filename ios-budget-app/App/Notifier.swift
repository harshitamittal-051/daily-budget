import Foundation
import UserNotifications
import DailyBudgetCore

/// iOS can't run code at 8am/10pm on its own, so notification TEXT is computed now and scheduled.
/// It's recomputed on every app open, new transaction, and plan change — which are exactly the
/// moments the numbers change.
enum Notifier {
    static let creditCategory = "CREDIT_ALLOC"

    static func requestPermission() async {
        registerCategories()
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Lets the user answer "spend pool or savings?" with a button on the notification itself.
    static func registerCategories() {
        let pool = UNNotificationAction(identifier: Allocation.pool.rawValue, title: "Add to spend pool", options: [])
        let savings = UNNotificationAction(identifier: Allocation.savings.rawValue, title: "Add to savings", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: creditCategory, actions: [pool, savings], intentIdentifiers: [], options: [])
        ])
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
        if let plan = store.effectivePlan {
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
        let spend = "\(rupeeString(t.amountPaise)) → \(t.merchant ?? "Unknown") (\(t.category))"
        let c = UNMutableNotificationContent()
        c.sound = .default
        // Crossing 80% or 100% of today's budget turns the spend alert into a warning (one notification, not two).
        if let limit = BudgetEngine.limitAlert(allowancePaise: d.allowancePaise, spentTodayPaise: d.spentTodayPaise, justSpentPaise: t.amountPaise) {
            c.title = limit.title
            c.body = "\(spend). \(limit.body)"
        } else {
            c.title = spend
            c.body = left >= 0 ? "\(rupeeString(left)) left of today's \(rupeeString(d.allowancePaise))."
                               : "Over today's budget by \(rupeeString(-left))."
        }
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    /// A payment OTP just arrived: tell the user what the payment would do to today, before they approve it.
    @MainActor
    @discardableResult
    static func alertPayment(_ warning: PaymentWarning) async -> PaymentWarning {
        let c = UNMutableNotificationContent()
        c.title = warning.title; c.body = warning.body; c.sound = .default
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
        return warning
    }

    /// Money came in. Refunds go straight back to the pool; anything else asks where it should go.
    @MainActor
    static func alertCredit(_ t: Txn, store: Store) async {
        let c = UNMutableNotificationContent(); c.sound = .default
        let who = t.merchant.map { " from \($0)" } ?? ""
        switch t.allocation ?? .none {
        case .pending:
            c.title = "\(rupeeString(t.amountPaise)) received\(who)"
            c.body = "Where should it go? Spend pool raises your daily budget; savings adds to what you have saved."
            c.categoryIdentifier = creditCategory
            c.userInfo = ["txn": t.id.uuidString]
        case .pool:
            c.title = "\(rupeeString(t.amountPaise)) refund received"
            c.body = "Added to your spend pool." + (store.today().map { " Today's budget is now \(rupeeString($0.allowancePaise))." } ?? "")
        default:
            c.title = "\(rupeeString(t.amountPaise)) received\(who)"
            c.body = "Looks like your salary. Open the app to plan the new month."
        }
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    /// Confirmation after the user picks a destination from the notification buttons.
    @MainActor
    static func alertAllocated(id: UUID, to a: Allocation, store: Store) async {
        guard let t = store.txns.first(where: { $0.id == id }) else { return }
        let c = UNMutableNotificationContent(); c.sound = .default
        if a == .pool {
            c.title = "\(rupeeString(t.amountPaise)) added to your spend pool"
            c.body = store.today().map { "Today's budget is now \(rupeeString($0.allowancePaise)) (\($0.daysLeftInclusive) days left)." } ?? ""
        } else {
            c.title = "\(rupeeString(t.amountPaise)) added to savings"
            let goal = store.plan?.savingsGoalPaise ?? 0
            c.body = "Saved this month: \(rupeeString(goal + store.creditsTotal(.savings))) (goal \(rupeeString(goal)) plus extras)."
        }
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

/// Handles taps on the "Add to spend pool / Add to savings" notification buttons and shows banners while the app is open.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["txn"] as? String, let id = UUID(uuidString: raw),
              let dest = Allocation(rawValue: response.actionIdentifier), dest == .pool || dest == .savings else { return }
        await MainActor.run { Store.shared.allocate(id: id, to: dest) }
        await Notifier.alertAllocated(id: id, to: dest, store: Store.shared)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
