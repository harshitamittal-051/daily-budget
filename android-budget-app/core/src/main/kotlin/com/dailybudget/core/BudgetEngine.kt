package com.dailybudget.core

import java.time.LocalDate
import java.time.YearMonth

/**
 * One salary cycle. [cycleEnd] is the date the next salary is expected and is
 * NOT part of this cycle (the last day of the cycle is cycleEnd - 1).
 */
data class Plan(
    val salaryPaise: Long,
    val savingsGoalPaise: Long,
    val fixedExpensesPaise: Long,
    val cycleStart: LocalDate,
    val cycleEnd: LocalDate,
) {
    val totalDays: Int get() = (cycleEnd.toEpochDay() - cycleStart.toEpochDay()).toInt().coerceAtLeast(1)
    val spendablePoolPaise: Long get() = (salaryPaise - savingsGoalPaise - fixedExpensesPaise).coerceAtLeast(0)
    /** What the plan says on day one, before any spending. */
    val baseDailyPaise: Long get() = spendablePoolPaise / totalDays
}

data class DayBudget(
    val date: LocalDate,
    /** What you may spend today, recomputed from what is left of the pool. */
    val allowancePaise: Long,
    val spentTodayPaise: Long,
    val poolRemainingPaise: Long,
    val daysLeftInclusive: Int,
) {
    val leftTodayPaise: Long get() = allowancePaise - spentTodayPaise
    val overspentToday: Boolean get() = spentTodayPaise > allowancePaise
    val poolOverdrawn: Boolean get() = poolRemainingPaise < 0
}

data class NightlyReview(
    val today: DayBudget,
    /** Positive = under budget (carried forward), negative = overspent. */
    val diffPaise: Long,
    val tomorrowAllowancePaise: Long,
    val tomorrowDaysLeft: Int,
)

object BudgetEngine {

    /**
     * Today's allowance = (pool - everything spent before today) / days left including today.
     * Underspending automatically raises tomorrow's number; overspending lowers it.
     */
    fun dayBudget(plan: Plan, spentBeforeTodayPaise: Long, spentTodayPaise: Long, today: LocalDate): DayBudget {
        val daysLeft = (plan.cycleEnd.toEpochDay() - today.toEpochDay()).toInt().coerceAtLeast(1)
        val remaining = plan.spendablePoolPaise - spentBeforeTodayPaise
        val allowance = (remaining / daysLeft).coerceAtLeast(0)
        return DayBudget(today, allowance, spentTodayPaise, remaining, daysLeft)
    }

    fun nightlyReview(plan: Plan, spentBeforeTodayPaise: Long, spentTodayPaise: Long, today: LocalDate): NightlyReview {
        val d = dayBudget(plan, spentBeforeTodayPaise, spentTodayPaise, today)
        val tomorrow = dayBudget(plan, spentBeforeTodayPaise + spentTodayPaise, 0, today.plusDays(1))
        return NightlyReview(d, d.allowancePaise - spentTodayPaise, tomorrow.allowancePaise, tomorrow.daysLeftInclusive)
    }

    /**
     * Next payday after [from]. Paid on the last day of the month -> next payday is the last
     * day of next month; otherwise the same day next month (clamped, e.g. 31st -> 28th).
     */
    fun nextPayday(from: LocalDate): LocalDate {
        val ym = YearMonth.from(from)
        val next = ym.plusMonths(1)
        return if (from.dayOfMonth == ym.lengthOfMonth()) next.atEndOfMonth()
        else next.atDay(minOf(from.dayOfMonth, next.lengthOfMonth()))
    }
}
