package com.dailybudget.core

/**
 * Turns a bank / UPI SMS into a [ParsedTxn]. Returns null for OTPs, promos,
 * bill reminders, collect requests and anything that is not a completed
 * debit or credit.
 */
object SmsParser {
    private val amountRe = Regex(
        """(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)""", RegexOption.IGNORE_CASE
    )
    private val debitWords = Regex(
        """\b(debited|spent|paid|sent|withdrawn|purchase|purchased|payment of|txn of|deducted)\b""",
        RegexOption.IGNORE_CASE
    )
    private val creditWords = Regex(
        """\b(credited|received|deposited|refund(?:ed)?|salary)\b""", RegexOption.IGNORE_CASE
    )
    private val rejectWords = Regex(
        """\b(otp|one[- ]time password|verification code|will be debited|is due|due on|""" +
            """min(?:imum)? amount|statement|requested money|collect request|""" +
            """pre-?approved|loan offer|apply now|avail(?:able)? (?:bal|limit)\b.*\boffer)\b""",
        RegexOption.IGNORE_CASE
    )
    private val vpaRe = Regex("""\bVPA\s+([\w.\-]+)@[\w]+""", RegexOption.IGNORE_CASE)
    private val targetRe = Regex(
        """\b(?:at|to|towards|info:?)\s+([A-Za-z0-9][A-Za-z0-9&.'\-/ ]{1,30}?)""" +
            """(?=\s+(?:on|ref|via|using|upi|txn|from|avl|bal|not you|if not)\b|[.,;(]|\s*$)""",
        RegexOption.IGNORE_CASE
    )
    private val sourceRe = Regex(
        """\b(?:by|from)\s+(?:neft|imps|upi|rtgs)?[-/ ]*([A-Za-z][A-Za-z0-9&.'\- ]{2,30}?)""" +
            """(?=\s+(?:on|ref|via|txn|avl|bal)\b|[.,;(]|\s*$)""",
        RegexOption.IGNORE_CASE
    )
    private val notMerchant = setOf("a/c", "ac", "account", "your", "you", "card", "bank", "self")

    fun parse(body: String, timeMillis: Long): ParsedTxn? {
        val text = body.replace('\n', ' ').replace(Regex("\\s+"), " ").trim()
        if (rejectWords.containsMatchIn(text)) return null

        val amount = amountRe.find(text)?.groupValues?.get(1)?.let(::toPaise) ?: return null
        if (amount <= 0) return null

        val debitAt = debitWords.find(text)?.range?.first
        val creditAt = creditWords.find(text)?.range?.first
        val type = when {
            debitAt == null && creditAt == null -> return null
            creditAt == null -> TxnType.DEBIT
            debitAt == null -> TxnType.CREDIT
            // "debited from your a/c ... credited to merchant": first verb is ours.
            debitAt < creditAt -> TxnType.DEBIT
            else -> TxnType.CREDIT
        }

        val method = when {
            Regex("""\bUPI\b|VPA""", RegexOption.IGNORE_CASE).containsMatchIn(text) -> "UPI"
            Regex("""\bATM\b|withdrawn""", RegexOption.IGNORE_CASE).containsMatchIn(text) -> "ATM"
            Regex("""\bcard\b""", RegexOption.IGNORE_CASE).containsMatchIn(text) -> "CARD"
            Regex("""\bNEFT|IMPS|RTGS""", RegexOption.IGNORE_CASE).containsMatchIn(text) -> "BANK"
            else -> "OTHER"
        }

        val merchant = when (type) {
            TxnType.DEBIT -> vpaRe.find(text)?.groupValues?.get(1)?.let(::cleanVpa)
                ?: targetRe.findAll(text).map { clean(it.groupValues[1]) }.firstOrNull { it != null }
                ?: if (method == "ATM") "ATM" else null
            TxnType.CREDIT -> sourceRe.find(text)?.let { clean(it.groupValues[1]) }
        }

        val isSalary = type == TxnType.CREDIT &&
            Regex("""\bsalary\b|\bsal\b""", RegexOption.IGNORE_CASE).containsMatchIn(text)

        return ParsedTxn(type, amount, merchant, method, timeMillis, isSalary)
    }

    private fun toPaise(s: String): Long {
        val clean = s.replace(",", "")
        val (r, p) = clean.split('.').let { it[0] to (it.getOrNull(1) ?: "") }
        return r.toLong() * 100 + p.padEnd(2, '0').take(2).toLong()
    }

    private fun clean(raw: String): String? {
        val s = raw.trim().trimEnd('.', '-', '/').trim()
        if (s.length < 2 || s.lowercase() in notMerchant) return null
        if (s.lowercase().startsWith("a/c") || s.lowercase().startsWith("your ")) return null
        return s.split(' ').joinToString(" ") { w -> w.lowercase().replaceFirstChar { it.uppercase() } }
    }

    /** "swiggy.food" -> "Swiggy Food"; plain phone numbers stay as person-to-person transfers. */
    private fun cleanVpa(local: String): String? =
        clean(local.replace('.', ' ').replace('_', ' ').replace('-', ' '))
}
