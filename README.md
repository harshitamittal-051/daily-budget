# Daily Budget — Android + iOS

Reads your bank/UPI transaction messages, splits your salary (minus what you want to save) into a daily budget,
and tells you every morning what you can spend, every night how you did, and where every rupee went.

| Folder | What |
|---|---|
| `android-budget-app/` | Kotlin + Jetpack Compose. Reads SMS directly (inbox scan + live receiver). |
| `ios-budget-app/` | SwiftUI. iOS cannot read SMS, so messages arrive via a Shortcuts automation (below). |

Both share the same logic, ported 1:1 and covered by the same tests: SMS parser, merchant categorizer, budget engine.

## Headline feature: "Can I afford this?"  (iOS first)
Type a price and get a straight answer from your live budget, before you pay:
- **Yes, go ahead**: fits what is left of today.
- **Yes, but it costs you tomorrow**: over today's budget, so tomorrow's drops (e.g. ₹1,034.48 → ₹982.75, ₹51.73 less a day for 29 days).
- **Not without touching savings**: would push the month below your savings goal; shows how much it would take out.

It also says how many days of your daily budget the price equals. On iOS you can ask Siri:
*"Can I afford something in Daily Budget?"* and it asks the price and answers out loud (also available as a Shortcuts action).
Logic: `ios-budget-app/Sources/DailyBudgetCore/Afford.swift` (tests in `AffordTests`). The Android version is not built yet.

## Money received: spend pool or savings?  (iOS first)
When money comes into your account the app handles it by type:
- **Salary**: starts a new month (you set the savings goal).
- **Refund or reversal**: goes straight back into the spend pool automatically, and the daily budget updates.
- **Anything else** (a friend pays you back, a gift, interest): the app asks. On iPhone the notification has two buttons, **Add to spend pool** and **Add to savings**, so you can answer without opening the app.
  - *Spend pool*: the month's pool grows and today's budget (and every day after) rises immediately.
  - *Savings*: adds to "saved this month" on top of your goal; the daily budget does not change.
  - You can move a credit between the two later from the Savings section.

Logic: `Credits.swift` (+ refund detection in `SmsParser.swift`), tests in `CreditsTests`. Android not built yet.

## How the budget works
1. Salary lands (last day of month) → app asks **how much you want to save** (and optional fixed bills).
2. `pool = salary − savings − fixed`, `daily = pool ÷ days until next payday`.
3. **Morning 8:00:** "Today's budget: ₹X".
4. **Night 22:00:** "Budget ₹X, spent ₹Y, under/over by ₹Z. Tomorrow you can spend ₹W."
   The revision is automatic: today's allowance is always `(pool − spent so far) ÷ days left`.
5. A live alert fires on each debit: amount → merchant (category), and what's left today.
6. Credit-card bill payments are excluded (the card purchases were already counted). Tap any transaction to exclude it.
7. A new salary credit is detected and prompts you to plan the next month.

## Android
Needs Android Studio (Gradle wrapper not checked in; open the folder and let it sync). `minSdk 26`.
Grant SMS + notification permissions on first launch. Sideload only: Google Play restricts READ_SMS.
Core tests (no Android SDK needed): `cd android-budget-app && gradle :core:test`

## iOS
Apple does not allow any app to read SMS. Workaround that works: **Shortcuts → Automation**
1. Shortcuts app → Automation → New → **Message** → Message Contains `debited` (add more automations for `spent`, `credited`, `sent Rs`).
2. Action: **Add Transaction from Message** (from Daily Budget), Message = *Shortcut Input*.
3. Set **Run Immediately** and turn off "Notify When Run".
Also: manual "+" entry. The 8am/10pm notifications are scheduled with text computed at schedule time and refreshed whenever you open the app or a message arrives.
Build: `brew install xcodegen && cd ios-budget-app && xcodegen && open DailyBudget.xcodeproj`. Core tests: `swift test`.

## Status / honest caveats
- Android `:core` tests: **16/16 pass**. Android `app` module and **all iOS code were written without a compiler** (no Android SDK / Swift here) — expect small build fixes on first open.
- Parser covers common HDFC/ICICI/SBI/Axis/UPI formats; send me messages it misses and we add cases.
- "Which app you paid with" = merchant/VPA + payment method from the SMS. Capturing GPay/PhonePe notifications would be a follow-up (Android NotificationListener).
- Assumes INR. Data stays on device.
