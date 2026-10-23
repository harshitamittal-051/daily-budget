import XCTest
@testable import DailyBudgetCore

final class SmsParserTests: XCTestCase {
    func p(_ s: String) -> ParsedTxn? { SmsParser.parse(s) }

    func testUpiDebitWithVpa() throws {
        let t = try XCTUnwrap(p("Rs.349.50 debited from a/c **1234 on 01-10-25 to VPA swiggy@icici (UPI Ref 123456). Not you? Call 1800"))
        XCTAssertEqual(t.type, .debit); XCTAssertEqual(t.amountPaise, 34950)
        XCTAssertEqual(t.merchant, "Swiggy"); XCTAssertEqual(t.method, "UPI")
        XCTAssertEqual(Categorizer.categorize(t), Categories.food)
    }
    func testAmtSentTo() throws {
        let t = try XCTUnwrap(p("Amt Sent Rs.250.00 From HDFC Bank A/C *1234 To ZOMATO On 01/10/25 Ref 99"))
        XCTAssertEqual(t.amountPaise, 25000); XCTAssertEqual(t.merchant, "Zomato")
    }
    func testCardSpentAt() throws {
        let t = try XCTUnwrap(p("Spent Rs.1,299 On HDFC Bank Card 1234 At AMAZON On 2025-10-01:10:22:31. Not You? Call"))
        XCTAssertEqual(t.amountPaise, 129900); XCTAssertEqual(t.method, "CARD"); XCTAssertEqual(t.merchant, "Amazon")
    }
    func testSalaryCredit() throws {
        let t = try XCTUnwrap(p("INR 1,25,000.00 credited to your A/c XX1234 on 31-10-25 by NEFT-ACME CORP SALARY. Avl Bal INR 1,40,000"))
        XCTAssertEqual(t.type, .credit); XCTAssertEqual(t.amountPaise, 12_500_000); XCTAssertTrue(t.isSalary)
    }
    func testAtm() throws {
        let t = try XCTUnwrap(p("Rs 2000 withdrawn from ATM on 02-10-25 using card XX1234"))
        XCTAssertEqual(Categorizer.categorize(t), Categories.cash)
    }
    func testDebitWinsWhenBothVerbs() throws {
        XCTAssertEqual(try XCTUnwrap(p("Rs 100 debited from A/c XX1234 and credited to uber@axis (UPI)")).type, .debit)
    }
    func testRejects() {
        XCTAssertNil(p("123456 is your OTP for txn of Rs.500. Do not share"))
        XCTAssertNil(p("Rs 5,000 will be debited from your account on 05-Oct for your EMI"))
        XCTAssertNil(p("Your credit card statement is generated. Total due Rs 12,000, min amount Rs 600 due on 10-Oct"))
        XCTAssertNil(p("Congrats! Pre-approved loan offer of Rs 5,00,000. Apply now"))
        XCTAssertNil(p("Hello, no money here"))
    }
    func testPhoneVpaIsTransfer() throws {
        let t = try XCTUnwrap(p("Rs.500.00 debited from a/c **1234 on 03-10-25 to VPA 9876543210@ybl (UPI Ref 1)"))
        XCTAssertEqual(Categorizer.categorize(t), Categories.transfers)
    }
    func testRupeeFormatting() {
        XCTAssertEqual(rupeeString(12_500_000), "₹1,25,000"); XCTAssertEqual(rupeeString(34950), "₹349.50")
        XCTAssertEqual(rupeeString(-120_000), "-₹1,200"); XCTAssertEqual(rupeeString(0), "₹0")
    }
}

final class BudgetEngineTests: XCTestCase {
    func d(_ y: Int, _ m: Int, _ day: Int) -> Date { Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: day))! }
    func rs(_ n: Int64) -> Int64 { n * 100 }
    var plan: Plan { Plan(salaryPaise: rs(60000), savingsGoalPaise: rs(10000), fixedExpensesPaise: rs(20000), cycleStart: d(2025, 9, 30), cycleEnd: d(2025, 10, 30)) }

    func testBaseDaily() {
        XCTAssertEqual(plan.totalDays, 30); XCTAssertEqual(plan.baseDailyPaise, rs(1000))
    }
    func testUnderspendRaisesTomorrow() {
        let r = BudgetEngine.nightlyReview(plan: plan, spentBefore: 0, spentToday: rs(400), today: d(2025, 9, 30))
        XCTAssertEqual(r.diffPaise, rs(600)); XCTAssertEqual(r.tomorrowAllowancePaise, 29600 * 100 / 29)
    }
    func testOverspendLowersTomorrow() {
        let r = BudgetEngine.nightlyReview(plan: plan, spentBefore: 0, spentToday: rs(2500), today: d(2025, 9, 30))
        XCTAssertEqual(r.diffPaise, rs(-1500)); XCTAssertTrue(r.tomorrowAllowancePaise < rs(1000))
    }
    func testOverdrawnClamps() {
        let b = BudgetEngine.dayBudget(plan: plan, spentBefore: rs(35000), spentToday: 0, today: d(2025, 10, 10))
        XCTAssertEqual(b.allowancePaise, 0); XCTAssertTrue(b.poolOverdrawn)
    }
    func testNextPayday() {
        XCTAssertEqual(BudgetEngine.nextPayday(after: d(2025, 9, 30)), d(2025, 10, 31))
        XCTAssertEqual(BudgetEngine.nextPayday(after: d(2025, 10, 31)), d(2025, 11, 30))
        XCTAssertEqual(BudgetEngine.nextPayday(after: d(2026, 1, 31)), d(2026, 2, 28))
        XCTAssertEqual(BudgetEngine.nextPayday(after: d(2025, 10, 1)), d(2025, 11, 1))
        XCTAssertEqual(BudgetEngine.nextPayday(after: d(2025, 1, 29)), d(2025, 2, 28))
    }
}

final class AffordTests: XCTestCase {
    func d(_ y: Int, _ m: Int, _ day: Int) -> Date { Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: day))! }
    func rs(_ n: Int64) -> Int64 { n * 100 }
    // Pool 30,000 over 30 days = 1,000 a day.
    var plan: Plan { Plan(salaryPaise: rs(60000), savingsGoalPaise: rs(10000), fixedExpensesPaise: rs(20000), cycleStart: d(2025, 9, 30), cycleEnd: d(2025, 10, 30)) }
    func a(_ price: Int64, today: Int64 = 0, before: Int64 = 0, day: Date? = nil) -> AffordResult {
        BudgetEngine.canIAfford(plan: plan, pricePaise: rs(price), spentBefore: rs(before), spentToday: rs(today), today: day ?? d(2025, 9, 30))
    }

    func testFitsToday() {
        let r = a(400)
        XCTAssertEqual(r.verdict, .fitsToday); XCTAssertEqual(r.leftAfterPaise, rs(600))
        XCTAssertTrue(r.summary.hasPrefix("Yes."))
    }
    func testExactlyTheRemainderStillFits() {
        XCTAssertEqual(a(300, today: 700).verdict, .fitsToday)
        XCTAssertEqual(a(301, today: 700).verdict, .stretch)
    }
    func testStretchShrinksTomorrow() {
        let r = a(1500)
        XCTAssertEqual(r.verdict, .stretch)
        XCTAssertEqual(r.leftAfterPaise, rs(-500))
        XCTAssertEqual(r.tomorrowNowPaise, 3_000_000 / 29)
        XCTAssertEqual(r.tomorrowAfterPaise, 2_850_000 / 29)
        XCTAssertEqual(r.cutPerDayPaise, 3_000_000 / 29 - 2_850_000 / 29)
        XCTAssertEqual(r.tomorrowDaysLeft, 29)
        XCTAssertEqual(r.budgetDays!, 1.5, accuracy: 0.0001)
        XCTAssertEqual(r.savingsDipPaise, 0)
    }
    func testWordingWhenTodayIsAlreadyUsedUp() {
        let r = a(100, today: 1200)
        XCTAssertEqual(r.verdict, .stretch)
        XCTAssertTrue(r.summary.contains("already used up"))
        XCTAssertFalse(r.summary.contains("more than you have left"))
    }
    func testEatsSavings() {
        let r = a(31000)
        XCTAssertEqual(r.verdict, .eatsSavings); XCTAssertEqual(r.savingsDipPaise, rs(1000))
        XCTAssertTrue(r.summary.contains("savings"))
    }
    func testPoolAlreadyOverdrawnAlwaysEatsSavings() {
        let r = a(100, before: 35000, day: d(2025, 10, 10))
        XCTAssertEqual(r.allowanceTodayPaise, 0); XCTAssertNil(r.budgetDays); XCTAssertEqual(r.verdict, .eatsSavings)
    }
    func testWordingHelper() {
        XCTAssertEqual(AffordResult.days(1.5), "1.5"); XCTAssertEqual(AffordResult.days(3.0), "3")
    }
}
