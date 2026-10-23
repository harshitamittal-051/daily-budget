package com.dailybudget.app.work

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import com.dailybudget.app.data.BudgetRepo
import com.dailybudget.app.data.SmsImporter
import com.dailybudget.core.toRupeeString
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Live alert the moment a debit SMS lands: where it went and what's left today. */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val msgs = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (msgs.isNullOrEmpty()) return
        val sender = msgs[0].originatingAddress ?: ""
        val body = msgs.joinToString("") { it.messageBody ?: "" }
        val time = msgs[0].timestampMillis
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val repo = BudgetRepo(c)
                val e = SmsImporter.ingest(repo.db, sender, body, time) ?: return@launch
                if (!e.isDebit || !e.countsTowardBudget) return@launch
                val d = repo.today() ?: return@launch
                val left = d.leftTodayPaise
                Notifier.show(
                    c, 3, "${e.amountPaise.toRupeeString()} → ${e.merchant ?: "Unknown"} (${e.category})",
                    if (left >= 0) "${left.toRupeeString()} left of today's ${d.allowancePaise.toRupeeString()}."
                    else "Over today's budget by ${(-left).toRupeeString()}."
                )
            } finally { pending.finish() }
        }
    }
}
