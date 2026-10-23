package com.dailybudget.app.work

import android.content.Context
import androidx.work.*
import com.dailybudget.app.data.BudgetRepo
import com.dailybudget.app.data.SmsImporter
import com.dailybudget.core.toRupeeString
import java.time.Duration
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.concurrent.TimeUnit

/** 8:00 — "you can spend ₹X today". */
class MorningWorker(c: Context, p: WorkerParameters) : CoroutineWorker(c, p) {
    override suspend fun doWork(): Result {
        val repo = BudgetRepo(applicationContext)
        SmsImporter.scanInbox(applicationContext, repo.db, System.currentTimeMillis() - 2 * 86_400_000L)
        val d = repo.today() ?: return Result.success().also { Scheduler.scheduleNext(applicationContext, true) }
        val text = if (d.poolOverdrawn)
            "You've used up this month's spending pool. Every rupee now eats into your savings goal."
        else "Today's budget: ${d.allowancePaise.toRupeeString()} (${d.daysLeftInclusive} days left, ${d.poolRemainingPaise.toRupeeString()} in the pool)."
        Notifier.show(applicationContext, 1, "Good morning ☀️", text)
        Scheduler.scheduleNext(applicationContext, morning = true)
        return Result.success()
    }
}

/** 22:00 — "you spent X of Y; from tomorrow you can spend Z". */
class NightWorker(c: Context, p: WorkerParameters) : CoroutineWorker(c, p) {
    override suspend fun doWork(): Result {
        val repo = BudgetRepo(applicationContext)
        SmsImporter.scanInbox(applicationContext, repo.db, System.currentTimeMillis() - 2 * 86_400_000L)
        val r = repo.review() ?: return Result.success().also { Scheduler.scheduleNext(applicationContext, false) }
        val verdict = when {
            r.diffPaise >= 0 -> "Under by ${r.diffPaise.toRupeeString()} — carried into the next days."
            else -> "Over by ${(-r.diffPaise).toRupeeString()} — tomorrow's budget shrinks."
        }
        Notifier.show(
            applicationContext, 2, "Tonight's review 🌙",
            "Budget ${r.today.allowancePaise.toRupeeString()}, spent ${r.today.spentTodayPaise.toRupeeString()}. $verdict " +
                "Tomorrow you can spend ${r.tomorrowAllowancePaise.toRupeeString()}."
        )
        Scheduler.scheduleNext(applicationContext, morning = false)
        return Result.success()
    }
}

object Scheduler {
    private val morningAt = LocalTime.of(8, 0)
    private val nightAt = LocalTime.of(22, 0)

    /** App start: (re)book both, replacing any pending run. */
    fun scheduleAll(c: Context) {
        schedule(c, "morning", morningAt, OneTimeWorkRequestBuilder<MorningWorker>(), ExistingWorkPolicy.REPLACE)
        schedule(c, "night", nightAt, OneTimeWorkRequestBuilder<NightWorker>(), ExistingWorkPolicy.REPLACE)
    }

    /** Called from inside a worker so tomorrow's run is queued behind the current one. */
    fun scheduleNext(c: Context, morning: Boolean) = if (morning)
        schedule(c, "morning", morningAt, OneTimeWorkRequestBuilder<MorningWorker>(), ExistingWorkPolicy.APPEND_OR_REPLACE)
    else
        schedule(c, "night", nightAt, OneTimeWorkRequestBuilder<NightWorker>(), ExistingWorkPolicy.APPEND_OR_REPLACE)

    private fun schedule(c: Context, name: String, at: LocalTime, b: OneTimeWorkRequest.Builder, policy: ExistingWorkPolicy) {
        val now = LocalDateTime.now()
        var next = now.with(at)
        if (!next.isAfter(now.plusMinutes(1))) next = next.plusDays(1)
        WorkManager.getInstance(c).enqueueUniqueWork(
            name, policy, b.setInitialDelay(Duration.between(now, next).toMillis(), TimeUnit.MILLISECONDS).build()
        )
    }
}
