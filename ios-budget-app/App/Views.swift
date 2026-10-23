import SwiftUI
import DailyBudgetCore

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var editing = false

    var body: some View {
        NavigationStack {
            if store.plan == nil || editing {
                SetupView(old: store.plan, salaryTxn: store.newSalary) { store.setPlan($0); editing = false }
            } else {
                DashboardView(onNewMonth: { editing = true })
            }
        }
    }
}

// MARK: - Setup

struct SetupView: View {
    let old: Plan?
    let salaryTxn: Txn?
    let onDone: (Plan) -> Void
    @State private var salary = ""
    @State private var savings = ""
    @State private var fixed = ""

    var plan: Plan {
        let start = Calendar.current.startOfDay(for: salaryTxn?.time ?? Date())
        return Plan(salaryPaise: (Int64(salary) ?? 0) * 100, savingsGoalPaise: (Int64(savings) ?? 0) * 100,
                    fixedExpensesPaise: (Int64(fixed) ?? 0) * 100, cycleStart: start, cycleEnd: BudgetEngine.nextPayday(after: start))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(old == nil ? "Welcome" : "New month, new plan").font(Theme.rounded(32, .bold))
                    Text("Tell me what came in and how much you want to keep. I will turn the rest into a daily budget.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR DAILY BUDGET").font(.caption.weight(.semibold)).opacity(0.8)
                    Text(rupeeString(plan.baseDailyPaise)).font(Theme.rounded(46, .bold)).minimumScaleFactor(0.6).lineLimit(1)
                    Text("\(rupeeString(plan.spendablePoolPaise)) to spend over \(plan.totalDays) days")
                        .font(.subheadline).opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 16) {
                    AmountField(title: "Salary received", text: $salary)
                    VStack(alignment: .leading, spacing: 8) {
                        AmountField(title: "How much do you want to save?", text: $savings)
                        HStack(spacing: 8) {
                            ForEach([5000, 7500, 10000], id: \.self) { v in
                                Button { savings = String(v) } label: {
                                    Text(rupeeString(Int64(v) * 100)).font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Capsule().fill(savings == String(v) ? Theme.brand : Theme.fieldFill))
                                        .foregroundStyle(savings == String(v) ? Color.white : Color.primary)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    AmountField(title: "Rent, EMIs and fixed bills", text: $fixed, hint: "Optional. Taken out before the daily budget.")
                }
                .card()

                if plan.spendablePoolPaise <= 0 && (Int64(salary) ?? 0) > 0 {
                    Text("Savings and bills are more than the salary.").font(.subheadline).foregroundStyle(Theme.bad)
                }

                Button { onDone(plan) } label: {
                    Text("Start tracking").font(Theme.rounded(18, .semibold)).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent).tint(Theme.brand).controlSize(.large)
                .disabled(plan.spendablePoolPaise <= 0)
            }
            .padding(20)
        }
        .background(Theme.pageFill)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            let s = salaryTxn?.amountPaise ?? old?.salaryPaise ?? 0
            if salary.isEmpty && s > 0 { salary = String(s / 100) }
            if savings.isEmpty, let o = old, o.savingsGoalPaise > 0 { savings = String(o.savingsGoalPaise / 100) }
            if fixed.isEmpty, let o = old, o.fixedExpensesPaise > 0 { fixed = String(o.fixedExpensesPaise / 100) }
        }
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject var store: Store
    let onNewMonth: () -> Void
    @State private var adding = false

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if store.newSalary != nil || (store.plan.map { Date() >= $0.cycleEnd } ?? false) { newMonthBanner }
                CreditsCard()
                if let d = store.today(), let plan = store.plan {
                    TodayHero(d: d, dayNumber: dayIndex(plan) + 1, totalDays: plan.totalDays)
                }
                AffordCard()
                SavingsCard()
                CategoriesCard()
                MerchantsCard()
                TransactionsCard()
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .background(Theme.pageFill)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $adding) { AddManualView() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(.subheadline).foregroundStyle(.secondary)
                Text("Your money today").font(Theme.rounded(28, .bold))
            }
            Spacer()
            Button { adding = true } label: {
                Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Circle().fill(Theme.brand))
            }
            .accessibilityLabel("Add a spend")
        }
        .padding(.top, 8)
    }

    private var newMonthBanner: some View {
        Button(action: onNewMonth) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(Theme.brand)
                Text("New salary detected. Plan the new month").font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .card(tint: Theme.brand)
        }
        .buttonStyle(.plain)
    }

    private func dayIndex(_ plan: Plan) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: plan.cycleStart, to: store.startOfDay(Date())).day ?? 0)
    }
}

/// The big card: today's budget, how much is used, and the month at a glance.
struct TodayHero: View {
    let d: DayBudget
    let dayNumber: Int
    let totalDays: Int

    private var fraction: Double {
        if d.allowancePaise == 0 { return d.spentTodayPaise > 0 ? 1.5 : 0 }
        return Double(d.spentTodayPaise) / Double(d.allowancePaise)
    }
    private var status: String {
        if d.poolOverdrawn { return "This month's pool is used up. More spending now eats into savings." }
        if d.overspentToday { return "Over by \(rupeeString(-d.leftTodayPaise)). Tomorrow's budget shrinks." }
        return "\(rupeeString(d.leftTodayPaise)) left today"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S BUDGET").font(.caption.weight(.semibold)).opacity(0.8)
                    Text(rupeeString(d.allowancePaise)).font(Theme.rounded(42, .bold)).minimumScaleFactor(0.6).lineLimit(1)
                    Text(status).font(.subheadline.weight(.medium)).opacity(0.95).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                ZStack {
                    BudgetRing(fraction: fraction).frame(width: 88, height: 88)
                    Text("\(Int(min(fraction, 9.99) * 100))%").font(Theme.rounded(17, .bold))
                }
            }

            HStack(spacing: 10) {
                stat("Spent", rupeeString(d.spentTodayPaise))
                stat("Pool left", rupeeString(d.poolRemainingPaise))
                stat("Days left", "\(d.daysLeftInclusive)")
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: Double(min(dayNumber, totalDays)), total: Double(totalDays)).tint(.white)
                Text("Day \(min(dayNumber, totalDays)) of \(totalDays)").font(.caption).opacity(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.brandDeep.opacity(0.28), radius: 16, y: 8)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).opacity(0.8)
            Text(value).font(Theme.rounded(15, .semibold)).minimumScaleFactor(0.7).lineLimit(1)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.16)))
    }
}

struct CategoriesCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let cats = store.byCategory()
        let total = max(1, cats.reduce(0) { $0 + $1.1 })
        VStack(alignment: .leading, spacing: 14) {
            CardTitle(text: "Where your money went", icon: "chart.pie.fill")
            if cats.isEmpty {
                Text("Nothing spent yet.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(cats, id: \.0) { c in
                HStack(spacing: 12) {
                    CategoryBadge(category: c.0)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(c.0).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(rupeeString(c.1)).font(Theme.rounded(15, .semibold)).monospacedDigit()
                        }
                        ShareBar(fraction: Double(c.1) / Double(total), color: CategoryStyle.color(c.0))
                    }
                }
            }
        }
        .card()
    }
}

struct MerchantsCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let ms = store.topMerchants()
        if !ms.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "Top apps and merchants", icon: "storefront.fill")
                ForEach(ms, id: \.0) { m in
                    HStack(spacing: 12) {
                        Text(String(m.0.prefix(1)).uppercased()).font(Theme.rounded(16, .bold)).foregroundStyle(Theme.brand)
                            .frame(width: 36, height: 36).background(Circle().fill(Theme.brand.opacity(0.14)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.0).font(.subheadline.weight(.medium))
                            Text("\(m.2) payment" + (m.2 == 1 ? "" : "s")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(rupeeString(m.1)).font(Theme.rounded(15, .semibold)).monospacedDigit()
                    }
                }
            }
            .card()
        }
    }
}

struct TransactionsCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let items = store.txns.filter(\.isDebit).prefix(25)
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(text: "Recent spends", icon: "list.bullet.rectangle.fill")
            Text("Tap one to leave it out of the budget.").font(.caption).foregroundStyle(.secondary)
            if items.isEmpty {
                Text("No spends yet. They appear here as your bank messages arrive.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(items) { t in
                Button { store.toggleCounts(t) } label: {
                    HStack(spacing: 12) {
                        CategoryBadge(category: t.category, size: 38)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.merchant ?? "Unknown").font(.subheadline.weight(.medium)).strikethrough(!t.countsTowardBudget)
                            Text("\(t.category) · \(t.method)" + (t.countsTowardBudget ? "" : " · left out"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(rupeeString(t.amountPaise)).font(Theme.rounded(15, .semibold)).monospacedDigit()
                            .foregroundStyle(t.countsTowardBudget ? Color.primary : Color.secondary)
                    }
                    .opacity(t.countsTowardBudget ? 1 : 0.6)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }
}

// MARK: - Manual add

struct AddManualView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var merchant = ""
    @State private var category = Categories.other

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AmountField(title: "Amount", text: $amount)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Where?").font(.subheadline).foregroundStyle(.secondary)
                        TextField("Shop or app", text: $merchant).padding(14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.fieldFill))
                    }
                    Text("Category").font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        ForEach(Categories.all, id: \.self) { c in
                            Button { category = c } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: CategoryStyle.icon(c))
                                    Text(c).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 9).frame(maxWidth: .infinity)
                                .background(Capsule().fill(category == c ? CategoryStyle.color(c) : Theme.fieldFill))
                                .foregroundStyle(category == c ? Color.white : Color.primary)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.pageFill)
            .navigationTitle("Add a spend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addManual(amountRupees: Int64(amount) ?? 0, merchant: merchant, category: category); dismiss()
                    }.disabled((Int64(amount) ?? 0) <= 0)
                }
            }
        }
    }
}
