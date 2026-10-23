import SwiftUI
import DailyBudgetCore

/// Money received that is not salary or a refund: ask where it should go.
struct CreditsCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        if !store.pendingCredits.isEmpty {
            Section("Money received: where should it go?") {
                ForEach(store.pendingCredits) { t in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(t.merchant.map { "From \($0)" } ?? "Credit")
                            Spacer()
                            Text(rupeeString(t.amountPaise)).bold().monospacedDigit()
                        }
                        HStack {
                            Button("Spend pool") { store.allocate(id: t.id, to: .pool) }.buttonStyle(.borderedProminent)
                            Button("Savings") { store.allocate(id: t.id, to: .savings) }.buttonStyle(.bordered)
                        }
                        Text("Spend pool raises today's budget and every day after it. Savings only adds to what you have saved.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

/// Savings goal plus anything the user sent to savings, and a way to move a past credit.
struct SavingsCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        if let plan = store.plan {
            let extra = store.creditsTotal(.savings)
            Section("Savings this month") {
                row("Goal from salary", rupeeString(plan.savingsGoalPaise))
                if extra > 0 { row("Extra from credits", "+" + rupeeString(extra)) }
                row("Total saved", rupeeString(plan.savingsGoalPaise + extra), bold: true)
                ForEach(store.resolvedCredits.filter { $0.time >= plan.cycleStart }) { t in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(t.merchant ?? (t.isRefund == true ? "Refund" : "Credit"))
                            Text("\(rupeeString(t.amountPaise)) → " + (t.allocation == .pool ? "spend pool" : "savings"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if t.isRefund != true {
                            Button(t.allocation == .pool ? "Move to savings" : "Move to pool") {
                                store.allocate(id: t.id, to: t.allocation == .pool ? .savings : .pool)
                            }.buttonStyle(.borderless).font(.caption)
                        }
                    }
                }
            }
        }
    }

    private func row(_ l: String, _ v: String, bold: Bool = false) -> some View {
        HStack { Text(l); Spacer(); Text(v).monospacedDigit().fontWeight(bold ? .semibold : .regular) }
    }
}
