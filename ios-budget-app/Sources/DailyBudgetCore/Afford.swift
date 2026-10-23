import Foundation

public enum AffordVerdict: String, Equatable {
    /// Fits what is left of today's budget.
    case fitsToday
    /// Over today's budget, but the month's spending pool covers it: tomorrow's budget shrinks.
    case stretch
    /// Would push the month's pool below zero, i.e. into the savings goal.
    case eatsSavings
}

public struct AffordResult: Equatable {
    public var pricePaise: Int64
    public var verdict: AffordVerdict
    public var allowanceTodayPaise: Int64
    public var leftTodayPaise: Int64
    /// leftToday - price. Negative means over today's budget.
    public var leftAfterPaise: Int64
    public var tomorrowNowPaise: Int64
    public var tomorrowAfterPaise: Int64
    public var tomorrowDaysLeft: Int
    /// How far below zero the month's pool would go (0 if it stays positive).
    public var savingsDipPaise: Int64
    /// The price expressed in days of today's budget (nil when today's budget is zero).
    public var budgetDays: Double?

    /// How much less you can spend each day from tomorrow on if you buy it.
    public var cutPerDayPaise: Int64 { max(0, tomorrowNowPaise - tomorrowAfterPaise) }

    /// One shared wording for the app card, Siri and Shortcuts.
    public var summary: String {
        let days = budgetDays.map { " That is \(AffordResult.days($0)) days of your daily budget." } ?? ""
        switch verdict {
        case .fitsToday:
            return "Yes. It fits today's budget and leaves \(rupeeString(leftAfterPaise)) for the rest of today."
        case .stretch:
            let lead = leftTodayPaise > 0
                ? "You can, but it is \(rupeeString(-leftAfterPaise)) more than you have left today."
                : "You can, but today's budget is already used up, so all of it comes out of the coming days."
            return lead + days +
                " Tomorrow's budget drops from \(rupeeString(tomorrowNowPaise)) to \(rupeeString(tomorrowAfterPaise))" +
                ", \(rupeeString(cutPerDayPaise)) less a day for \(tomorrowDaysLeft) days."
        case .eatsSavings:
            return "Not without dipping into your savings. It would take \(rupeeString(savingsDipPaise)) out of this month's savings goal." + days
        }
    }

    static func days(_ d: Double) -> String {
        let s = String(format: "%.1f", d)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}

public extension BudgetEngine {
    /// "Can I afford this?" evaluated against today's real numbers.
    static func canIAfford(plan: Plan, pricePaise: Int64, spentBefore: Int64, spentToday: Int64, today: Date) -> AffordResult {
        let d = dayBudget(plan: plan, spentBefore: spentBefore, spentToday: spentToday, today: today)
        let spentThrough = spentBefore + spentToday
        let tomorrow = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: today)!
        let now = dayBudget(plan: plan, spentBefore: spentThrough, spentToday: 0, today: tomorrow)
        let after = dayBudget(plan: plan, spentBefore: spentThrough + pricePaise, spentToday: 0, today: tomorrow)
        let poolAfter = plan.spendablePoolPaise - spentThrough - pricePaise
        let verdict: AffordVerdict = pricePaise <= d.leftTodayPaise ? .fitsToday : (poolAfter >= 0 ? .stretch : .eatsSavings)
        return AffordResult(
            pricePaise: pricePaise, verdict: verdict,
            allowanceTodayPaise: d.allowancePaise, leftTodayPaise: d.leftTodayPaise,
            leftAfterPaise: d.leftTodayPaise - pricePaise,
            tomorrowNowPaise: now.allowancePaise, tomorrowAfterPaise: after.allowancePaise,
            tomorrowDaysLeft: now.daysLeftInclusive,
            savingsDipPaise: max(0, -poolAfter),
            budgetDays: d.allowancePaise > 0 ? Double(pricePaise) / Double(d.allowancePaise) : nil)
    }
}
