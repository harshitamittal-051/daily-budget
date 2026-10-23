package com.dailybudget.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SmsParserTest {
    private fun p(s: String) = SmsParser.parse(s, 0L)

    @Test fun upiDebitWithVpa() {
        val t = assertNotNull(p("Rs.349.50 debited from a/c **1234 on 01-10-25 to VPA swiggy@icici (UPI Ref 123456). Not you? Call 1800"))
        assertEquals(TxnType.DEBIT, t.type)
        assertEquals(34950L, t.amountPaise)
        assertEquals("Swiggy", t.merchant)
        assertEquals("UPI", t.method)
        assertEquals(Categories.FOOD, Categorizer.categorize(t))
    }

    @Test fun amtSentTo() {
        val t = assertNotNull(p("Amt Sent Rs.250.00 From HDFC Bank A/C *1234 To ZOMATO On 01/10/25 Ref 99"))
        assertEquals(TxnType.DEBIT, t.type)
        assertEquals(25000L, t.amountPaise)
        assertEquals("Zomato", t.merchant)
    }

    @Test fun cardSpentAt() {
        val t = assertNotNull(p("Spent Rs.1,299 On HDFC Bank Card 1234 At AMAZON On 2025-10-01:10:22:31. Not You? Call"))
        assertEquals(129900L, t.amountPaise)
        assertEquals("CARD", t.method)
        assertEquals("Amazon", t.merchant)
        assertEquals(Categories.SHOPPING, Categorizer.categorize(t))
    }

    @Test fun inrPrefixAndLakhGrouping() {
        val t = assertNotNull(p("INR 1,25,000.00 credited to your A/c XX1234 on 31-10-25 by NEFT-ACME CORP SALARY. Avl Bal INR 1,40,000"))
        assertEquals(TxnType.CREDIT, t.type)
        assertEquals(12500000L, t.amountPaise)
        assertTrue(t.isSalary)
    }

    @Test fun atmWithdrawal() {
        val t = assertNotNull(p("Rs 2000 withdrawn from ATM on 02-10-25 using card XX1234"))
        assertEquals(TxnType.DEBIT, t.type)
        assertEquals(Categories.CASH, Categorizer.categorize(t))
    }

    @Test fun debitWinsWhenBothVerbsPresent() {
        val t = assertNotNull(p("Rs 100 debited from A/c XX1234 and credited to uber@axis (UPI)"))
        assertEquals(TxnType.DEBIT, t.type)
    }

    @Test fun rejectsOtpsAndReminders() {
        assertNull(p("123456 is your OTP for txn of Rs.500. Do not share"))
        assertNull(p("Rs 5,000 will be debited from your account on 05-Oct for your EMI"))
        assertNull(p("Your credit card statement is generated. Total due Rs 12,000, min amount Rs 600 due on 10-Oct"))
        assertNull(p("Congrats! Pre-approved loan offer of Rs 5,00,000. Apply now"))
        assertNull(p("Hello, no money here"))
    }

    @Test fun phoneNumberVpaIsATransfer() {
        val t = assertNotNull(p("Rs.500.00 debited from a/c **1234 on 03-10-25 to VPA 9876543210@ybl (UPI Ref 1)"))
        assertEquals(Categories.TRANSFERS, Categorizer.categorize(t))
    }

    @Test fun rupeeFormatting() {
        assertEquals("₹1,25,000", 12500000L.toRupeeString())
        assertEquals("₹349.50", 34950L.toRupeeString())
        assertEquals("-₹1,200", (-120000L).toRupeeString())
        assertEquals("₹0", 0L.toRupeeString())
    }
}
