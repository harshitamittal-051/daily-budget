package com.dailybudget.app.ui

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.clickable
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.lifecycleScope
import com.dailybudget.app.data.*
import com.dailybudget.core.*
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

class MainActivity : ComponentActivity() {
    private lateinit var repo: BudgetRepo

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repo = BudgetRepo(this)
        setContent { MaterialTheme { Surface(Modifier.fillMaxSize()) { Root() } } }
    }

    @Composable
    private fun Root() {
        val plan by repo.prefs.plan.collectAsState(initial = null)
        var loaded by remember { mutableStateOf(false) }
        var editing by remember { mutableStateOf(false) }
        var newSalary by remember { mutableStateOf<TxnEntity?>(null) }
        var tick by remember { mutableIntStateOf(0) }

        val perms = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { tick++ }
        LaunchedEffect(Unit) {
            perms.launch(arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS, Manifest.permission.POST_NOTIFICATIONS))
        }
        // Import on every open and whenever permissions change.
        LaunchedEffect(tick, plan) {
            val since = plan?.cycleStart?.let { repo.millis(it.minusDays(1)) } ?: (System.currentTimeMillis() - 45 * 86_400_000L)
            SmsImporter.scanInbox(this@MainActivity, repo.db, since)
            newSalary = repo.newSalarySinceCycleStart()
            loaded = true
        }

        when {
            !loaded -> Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
            plan == null || editing -> SetupScreen(plan, newSalary, onDone = { p ->
                lifecycleScope.launch { repo.prefs.save(p); editing = false }
            })
            else -> Dashboard(plan!!, newSalary, onNewMonth = { editing = true })
        }
    }

    @Composable
    private fun SetupScreen(old: Plan?, salaryTxn: TxnEntity?, onDone: (Plan) -> Unit) {
        // Prefill from the detected salary credit so a new month is two taps.
        var salary by remember { mutableStateOf(((salaryTxn?.amountPaise ?: old?.salaryPaise ?: 0L) / 100).takeIf { it > 0 }?.toString() ?: "") }
        var savings by remember { mutableStateOf(((old?.savingsGoalPaise ?: 0L) / 100).takeIf { it > 0 }?.toString() ?: "") }
        var fixed by remember { mutableStateOf(((old?.fixedExpensesPaise ?: 0L) / 100).takeIf { it > 0 }?.toString() ?: "") }
        val start = salaryTxn?.let { LocalDateTime.ofInstant(java.time.Instant.ofEpochMilli(it.timeMillis), ZoneId.systemDefault()).toLocalDate() }
            ?: LocalDate.now()
        val end = BudgetEngine.nextPayday(start)

        val s = salary.toLongOrNull() ?: 0; val sv = savings.toLongOrNull() ?: 0; val f = fixed.toLongOrNull() ?: 0
        val plan = Plan(s * 100, sv * 100, f * 100, start, end)

        Column(Modifier.padding(20.dp).fillMaxSize(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Plan this month", fontSize = 26.sp)
            Text("Cycle: $start → ${end.minusDays(1)} (${plan.totalDays} days)")
            OutlinedTextField(salary, { salary = it.filter(Char::isDigit) }, label = { Text("Salary received (₹)") }, singleLine = true)
            OutlinedTextField(savings, { savings = it.filter(Char::isDigit) }, label = { Text("How much do you want to save? (₹5,000–10,000?)") }, singleLine = true)
            OutlinedTextField(fixed, { fixed = it.filter(Char::isDigit) }, label = { Text("Rent / EMIs / fixed bills (₹, optional)") }, singleLine = true)
            Text("Daily budget: ${plan.baseDailyPaise.toRupeeString()}", fontSize = 22.sp)
            Text("(${plan.spendablePoolPaise.toRupeeString()} to spend over ${plan.totalDays} days)")
            Button(onClick = { onDone(plan) }, enabled = s > 0 && plan.spendablePoolPaise > 0) { Text("Start tracking") }
        }
    }

    @Composable
    private fun Dashboard(plan: Plan, newSalary: TxnEntity?, onNewMonth: () -> Unit) {
        val from = repo.millis(plan.cycleStart)
        val txns by repo.db.txns().since(from).collectAsState(emptyList())
        val cats by repo.db.txns().byCategory(from).collectAsState(emptyList())
        val merchants by repo.db.txns().topMerchants(from).collectAsState(emptyList())
        var day by remember { mutableStateOf<DayBudget?>(null) }
        LaunchedEffect(txns) { day = repo.today() }
        val scope = rememberCoroutineScope()

        LazyColumn(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (newSalary != null || LocalDate.now() >= plan.cycleEnd) item {
                Card(Modifier.fillMaxWidth().clickable { onNewMonth() }) {
                    Text("New salary detected — tap to plan the new month", Modifier.padding(16.dp))
                }
            }
            day?.let { d -> item { TodayCard(d) } }
            item { Text("Where your money went", fontSize = 20.sp) }
            val total = cats.sumOf { it.total }.coerceAtLeast(1)
            items(cats) { c ->
                Column {
                    Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween) { Text(c.category); Text(c.total.toRupeeString()) }
                    LinearProgressIndicator(progress = { c.total.toFloat() / total }, Modifier.fillMaxWidth())
                }
            }
            item { Text("Top apps & merchants", fontSize = 20.sp) }
            items(merchants) { m ->
                Row(Modifier.fillMaxWidth(), Arrangement.SpaceBetween) {
                    Text("${m.merchant ?: "Unknown"} · ${m.n}×"); Text(m.total.toRupeeString())
                }
            }
            item { Text("Recent (tap to exclude from budget)", fontSize = 20.sp) }
            items(txns.filter { it.isDebit }.take(40), key = { it.id }) { t ->
                Row(Modifier.fillMaxWidth().clickable { scope.launch { repo.db.txns().setCounts(t.id, !t.countsTowardBudget) } },
                    Arrangement.SpaceBetween) {
                    Column {
                        Text(t.merchant ?: "Unknown")
                        Text("${t.category} · ${t.method}" + if (!t.countsTowardBudget) " · excluded" else "", fontSize = 12.sp)
                    }
                    Text(t.amountPaise.toRupeeString())
                }
            }
        }
    }

    @Composable
    private fun TodayCard(d: DayBudget) {
        Card(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("Today's budget", fontSize = 14.sp)
                Text(d.allowancePaise.toRupeeString(), fontSize = 36.sp)
                Text("Spent ${d.spentTodayPaise.toRupeeString()} · " +
                    if (d.overspentToday) "over by ${(-d.leftTodayPaise).toRupeeString()}" else "${d.leftTodayPaise.toRupeeString()} left")
                LinearProgressIndicator(
                    progress = { if (d.allowancePaise == 0L) 1f else (d.spentTodayPaise.toFloat() / d.allowancePaise).coerceIn(0f, 1f) },
                    Modifier.fillMaxWidth()
                )
                Text("Pool left: ${d.poolRemainingPaise.toRupeeString()} for ${d.daysLeftInclusive} days", fontSize = 12.sp)
            }
        }
    }
}
