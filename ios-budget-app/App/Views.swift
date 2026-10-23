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
        Form {
            Section("Plan this month") {
                TextField("Salary received (₹)", text: $salary).keyboardType(.numberPad)
                TextField("How much do you want to save? (₹5,000–10,000?)", text: $savings).keyboardType(.numberPad)
                TextField("Rent / EMIs / fixed bills (₹, optional)", text: $fixed).keyboardType(.numberPad)
            }
            Section {
                Text("Daily budget: \(rupeeString(plan.baseDailyPaise))").font(.title2)
                Text("\(rupeeString(plan.spendablePoolPaise)) over \(plan.totalDays) days")
            }
            Button("Start tracking") { onDone(plan) }.disabled(plan.spendablePoolPaise <= 0)
        }
        .navigationTitle("Daily Budget")
        .onAppear {
            let s = salaryTxn?.amountPaise ?? old?.salaryPaise ?? 0
            if salary.isEmpty && s > 0 { salary = String(s / 100) }
            if savings.isEmpty, let o = old, o.savingsGoalPaise > 0 { savings = String(o.savingsGoalPaise / 100) }
            if fixed.isEmpty, let o = old, o.fixedExpensesPaise > 0 { fixed = String(o.fixedExpensesPaise / 100) }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var store: Store
    let onNewMonth: () -> Void
    @State private var adding = false

    var body: some View {
        List {
            if store.newSalary != nil || (store.plan.map { Date() >= $0.cycleEnd } ?? false) {
                Button("New salary detected — tap to plan the new month", action: onNewMonth)
            }
            if let d = store.today() {
                Section("Today's budget") {
                    Text(rupeeString(d.allowancePaise)).font(.system(size: 36, weight: .bold))
                    Text("Spent \(rupeeString(d.spentTodayPaise)) · " + (d.overspentToday ? "over by \(rupeeString(-d.leftTodayPaise))" : "\(rupeeString(d.leftTodayPaise)) left"))
                    ProgressView(value: d.allowancePaise == 0 ? 1 : min(1, Double(d.spentTodayPaise) / Double(d.allowancePaise)))
                    Text("Pool left: \(rupeeString(d.poolRemainingPaise)) for \(d.daysLeftInclusive) days").font(.footnote)
                }
            }
            Section("Where your money went") {
                let cats = store.byCategory(); let total = max(1, cats.reduce(0) { $0 + $1.1 })
                ForEach(cats, id: \.0) { c in
                    VStack(alignment: .leading) {
                        HStack { Text(c.0); Spacer(); Text(rupeeString(c.1)) }
                        ProgressView(value: Double(c.1) / Double(total))
                    }
                }
            }
            Section("Top apps & merchants") {
                ForEach(store.topMerchants(), id: \.0) { m in
                    HStack { Text("\(m.0) · \(m.2)×"); Spacer(); Text(rupeeString(m.1)) }
                }
            }
            Section("Recent (tap to exclude from budget)") {
                ForEach(store.txns.filter(\.isDebit).prefix(40)) { t in
                    Button { store.toggleCounts(t) } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(t.merchant ?? "Unknown")
                                Text("\(t.category) · \(t.method)" + (t.countsTowardBudget ? "" : " · excluded")).font(.caption)
                            }
                            Spacer(); Text(rupeeString(t.amountPaise))
                        }
                    }.foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Daily Budget")
        .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $adding) { AddManualView() }
    }
}

struct AddManualView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""; @State private var merchant = ""; @State private var category = Categories.other
    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount (₹)", text: $amount).keyboardType(.numberPad)
                TextField("Where?", text: $merchant)
                Picker("Category", selection: $category) { ForEach(Categories.all, id: \.self) { Text($0) } }
            }
            .navigationTitle("Add spend")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.addManual(amountRupees: Int64(amount) ?? 0, merchant: merchant, category: category); dismiss() }
                        .disabled((Int64(amount) ?? 0) <= 0)
                }
            }
        }
    }
}
