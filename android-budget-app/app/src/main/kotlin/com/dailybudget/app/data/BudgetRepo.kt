package com.dailybudget.app.data

import android.content.Context
import com.dailybudget.core.*
import java.time.LocalDate
import java.time.ZoneId

class BudgetRepo(c: Context) {
    val db = AppDb.get(c)
    val prefs = Prefs(c)
    private val zone = ZoneId.systemDefault()

    fun millis(d: LocalDate) = d.atStartOfDay(zone).toInstant().toEpochMilli()

    suspend fun today(now: LocalDate = LocalDate.now()): DayBudget? {
        val plan = prefs.currentPlan() ?: return null
        val before = db.txns().spentBetween(millis(plan.cycleStart), millis(now))
        val today = db.txns().spentBetween(millis(now), millis(now.plusDays(1)))
        return BudgetEngine.dayBudget(plan, before, today, now)
    }

    suspend fun review(now: LocalDate = LocalDate.now()): NightlyReview? {
        val plan = prefs.currentPlan() ?: return null
        val before = db.txns().spentBetween(millis(plan.cycleStart), millis(now))
        val today = db.txns().spentBetween(millis(now), millis(now.plusDays(1)))
        return BudgetEngine.nightlyReview(plan, before, today, now)
    }

    /** A salary SMS newer than this cycle's start means a new month is ready to be planned. */
    suspend fun newSalarySinceCycleStart(): TxnEntity? {
        val plan = prefs.currentPlan() ?: return null
        return db.txns().latestSalaryAfter(millis(plan.cycleStart) + 60_000)
    }
}
