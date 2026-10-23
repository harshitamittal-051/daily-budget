package com.dailybudget.app.data

import android.content.Context
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import com.dailybudget.core.Plan
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.time.LocalDate

private val Context.store by preferencesDataStore("budget_prefs")

class Prefs(private val c: Context) {
    private object K {
        val salary = longPreferencesKey("salary")
        val savings = longPreferencesKey("savings")
        val fixed = longPreferencesKey("fixed")
        val start = longPreferencesKey("start")
        val end = longPreferencesKey("end")
    }

    val plan: Flow<Plan?> = c.store.data.map { p ->
        val s = p[K.start] ?: return@map null
        Plan(p[K.salary] ?: 0, p[K.savings] ?: 0, p[K.fixed] ?: 0, LocalDate.ofEpochDay(s), LocalDate.ofEpochDay(p[K.end] ?: s + 30))
    }

    suspend fun currentPlan(): Plan? = plan.first()

    suspend fun save(plan: Plan) {
        c.store.edit {
            it[K.salary] = plan.salaryPaise; it[K.savings] = plan.savingsGoalPaise; it[K.fixed] = plan.fixedExpensesPaise
            it[K.start] = plan.cycleStart.toEpochDay(); it[K.end] = plan.cycleEnd.toEpochDay()
        }
    }
}
