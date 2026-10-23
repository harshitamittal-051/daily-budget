package com.dailybudget.app.data

import android.content.Context
import android.net.Uri
import com.dailybudget.core.*

object SmsImporter {
    /** Parse one SMS and store it. Returns the stored entity, or null if it isn't a transaction / already seen. */
    suspend fun ingest(db: AppDb, sender: String, body: String, timeMillis: Long): TxnEntity? {
        val p = SmsParser.parse(body, timeMillis) ?: return null
        val cat = if (p.type == TxnType.DEBIT) Categorizer.categorize(p) else Categories.OTHER
        val e = TxnEntity(
            key = "$sender|$timeMillis|${body.hashCode()}",
            isDebit = p.type == TxnType.DEBIT,
            amountPaise = p.amountPaise,
            merchant = p.merchant,
            method = p.method,
            category = cat,
            timeMillis = timeMillis,
            isSalary = p.isSalary,
            countsTowardBudget = p.type == TxnType.DEBIT && cat !in Categories.excludedByDefault,
        )
        return if (db.txns().insert(e) == -1L) null else e
    }

    /** Scan the inbox. Needs READ_SMS; safe to call repeatedly thanks to the dedup key. */
    suspend fun scanInbox(c: Context, db: AppDb, sinceMillis: Long): Int {
        var n = 0
        val cursor = try {
            c.contentResolver.query(
                Uri.parse("content://sms/inbox"), arrayOf("address", "body", "date"),
                "date >= ?", arrayOf(sinceMillis.toString()), "date ASC"
            )
        } catch (_: SecurityException) { null } ?: return 0
        cursor.use {
            while (it.moveToNext()) {
                if (ingest(db, it.getString(0) ?: "", it.getString(1) ?: "", it.getLong(2)) != null) n++
            }
        }
        return n
    }
}
