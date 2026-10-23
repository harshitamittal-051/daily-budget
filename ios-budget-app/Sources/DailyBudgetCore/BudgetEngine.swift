import Foundation

private let cal = Calendar(identifier: .gregorian)
func dayNumber(_ d: Date) -> Int {
    cal.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: cal.startOfDay(for: d)).day ?? 0
}

/// One salary cycle. `cycleEnd` is the next payday and is NOT part of this cycle.
public struct Plan: Codable, Equatable {
    public var salaryPaise: Int64
    public var savingsGoalPaise: Int64
    public var fixedExpensesPaise: Int64
    public var cycleStart: Date
    public var cycleEnd: Date

    public init(salaryPaise: Int64, savingsGoalPaise: Int64, fixedExpensesPaise: Int64, cycleStart: Date, cycleEnd: Date) {
        self.salaryPaise = salaryPaise; self.savingsGoalPaise = savingsGoalPaise
        self.fixedExpensesPaise = fixedExpensesPaise; self.cycleStart = cycleStart; self.cycleEnd = cycleEnd
    }

    public var totalDays: Int { max(1, dayNumber(cycleEnd) - dayNumber(cycleStart)) }
    public var spendablePoolPaise: Int64 { max(0, salaryPaise - savingsGoalPaise - fixedExpensesPaise) }
    public var baseDailyPaise: Int64 { spendablePoolPaise / Int64(totalDays) }
}

public struct DayBudget: Equatable {
    public var allowancePaise: Int64
    public var spentTodayPaise: Int64
    public var poolRemainingPaise: Int64
    public var daysLeftInclusive: Int
    public var leftTodayPaise: Int64 { allowancePaise - spentTodayPaise }
    public var overspentToday: Bool { spentTodayPaise > allowancePaise }
    public var poolOverdrawn: Bool { poolRemainingPaise < 0 }
}

public struct NightlyReview: Equatable {
    public var today: DayBudget
    public var diffPaise: Int64            // + under budget, - overspent
    public var tomorrowAllowancePaise: Int64
    public var tomorrowDaysLeft: Int
}

public enum BudgetEngine {
    /// Allowance = (pool - spent before today) / days left including today.
    public static func dayBudget(plan: Plan, spentBefore: Int64, spentToday: Int64, today: Date) -> DayBudget {
        let daysLeft = max(1, dayNumber(plan.cycleEnd) - dayNumber(today))
        let remaining = plan.spendablePoolPaise - spentBefore
        return DayBudget(allowancePaise: max(0, remaining / Int64(daysLeft)), spentTodayPaise: spentToday,
                         poolRemainingPaise: remaining, daysLeftInclusive: daysLeft)
    }

    public static func nightlyReview(plan: Plan, spentBefore: Int64, spentToday: Int64, today: Date) -> NightlyReview {
        let d = dayBudget(plan: plan, spentBefore: spentBefore, spentToday: spentToday, today: today)
        let tmr = cal.date(byAdding: .day, value: 1, to: today)!
        let t = dayBudget(plan: plan, spentBefore: spentBefore + spentToday, spentToday: 0, today: tmr)
        return NightlyReview(today: d, diffPaise: d.allowancePaise - spentToday,
                             tomorrowAllowancePaise: t.allowancePaise, tomorrowDaysLeft: t.daysLeftInclusive)
    }

    /// Paid on the last day of the month -> last day of next month; else same day next month (clamped).
    public static func nextPayday(after from: Date) -> Date {
        let c = cal.dateComponents([.year, .month, .day], from: from)
        let firstOfThis = cal.date(from: DateComponents(year: c.year, month: c.month, day: 1))!
        let thisLen = cal.range(of: .day, in: .month, for: firstOfThis)!.count
        let firstOfNext = cal.date(byAdding: .month, value: 1, to: firstOfThis)!
        let nextLen = cal.range(of: .day, in: .month, for: firstOfNext)!.count
        let day = c.day! == thisLen ? nextLen : min(c.day!, nextLen)
        return cal.date(byAdding: .day, value: day - 1, to: firstOfNext)!
    }
}
