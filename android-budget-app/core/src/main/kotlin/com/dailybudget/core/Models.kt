package com.dailybudget.core

enum class TxnType { DEBIT, CREDIT }

/** All money is in paise (1/100 rupee) to avoid floating point drift. */
data class ParsedTxn(
    val type: TxnType,
    val amountPaise: Long,
    val merchant: String?,
    val method: String,
    val timeMillis: Long,
    val isSalary: Boolean = false,
)

fun Long.toRupeeString(): String {
    val neg = this < 0
    val abs = kotlin.math.abs(this)
    val rupees = abs / 100
    val paise = abs % 100
    // Indian digit grouping: 12,34,567
    val s = rupees.toString()
    val grouped = if (s.length <= 3) s else {
        val head = s.dropLast(3)
        val tail = s.takeLast(3)
        head.reversed().chunked(2).joinToString(",").reversed() + "," + tail
    }
    val body = if (paise == 0L) grouped else "%s.%02d".format(grouped, paise)
    return (if (neg) "-" else "") + "₹" + body
}
