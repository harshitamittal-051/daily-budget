package com.dailybudget.core

import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class BudgetEngineTest {
    private fun rs(n: Long) = n * 100
    // Salary 60,000 on 30 Sep, savings goal 10,000, 20,000 fixed => 30,000 pool over 30 days = 1,000/day.
    private val plan = Plan(rs(60000), rs(10000), rs(20000), LocalDate.of(2025, 9, 30), LocalDate.of(2025, 10, 30))

    @Test fun baseDaily() {
        assertEquals(30, plan.totalDays)
        assertEquals(rs(30000), plan.spendablePoolPaise)
        assertEquals(rs(1000), plan.baseDailyPaise)
    }

    @Test fun dayOneAllowanceIsBase() {
        val d = BudgetEngine.dayBudget(plan, 0, 0, LocalDate.of(2025, 9, 30))
        assertEquals(rs(1000), d.allowancePaise)
        assertEquals(30, d.daysLeftInclusive)
    }

    @Test fun underspendingRaisesTomorrow() {
        val r = BudgetEngine.nightlyReview(plan, 0, rs(400), LocalDate.of(2025, 9, 30))
        assertEquals(rs(600), r.diffPaise)
        // 29,600 left over 29 days
        assertEquals(29600L * 100 / 29, r.tomorrowAllowancePaise)
        assertTrue(r.tomorrowAllowancePaise > rs(1000))
    }

    @Test fun overspendingLowersTomorrow() {
        val r = BudgetEngine.nightlyReview(plan, 0, rs(2500), LocalDate.of(2025, 9, 30))
        assertEquals(rs(-1500), r.diffPaise)
        assertTrue(r.today.overspentToday)
        assertTrue(r.tomorrowAllowancePaise < rs(1000))
    }

    @Test fun overdrawnPoolClampsToZero() {
        val d = BudgetEngine.dayBudget(plan, rs(35000), 0, LocalDate.of(2025, 10, 10))
        assertEquals(0, d.allowancePaise)
        assertTrue(d.poolOverdrawn)
    }

    @Test fun lastDayGetsWholeRemainder() {
        val d = BudgetEngine.dayBudget(plan, rs(29000), 0, LocalDate.of(2025, 10, 29))
        assertEquals(1, d.daysLeftInclusive)
        assertEquals(rs(1000), d.allowancePaise)
    }

    @Test fun paydayLastDayOfMonthRollsToLastDayOfNext() {
        assertEquals(LocalDate.of(2025, 10, 31), BudgetEngine.nextPayday(LocalDate.of(2025, 9, 30)))
        assertEquals(LocalDate.of(2025, 11, 30), BudgetEngine.nextPayday(LocalDate.of(2025, 10, 31)))
        assertEquals(LocalDate.of(2026, 2, 28), BudgetEngine.nextPayday(LocalDate.of(2026, 1, 31)))
        assertEquals(LocalDate.of(2025, 11, 1), BudgetEngine.nextPayday(LocalDate.of(2025, 10, 1)))
        assertEquals(LocalDate.of(2025, 2, 28), BudgetEngine.nextPayday(LocalDate.of(2025, 1, 29)))
    }
}
