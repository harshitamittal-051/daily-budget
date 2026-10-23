import SwiftUI
import DailyBudgetCore

/// Money received that is not salary or a refund: ask where it should go.
struct CreditsCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        if !store.pendingCredits.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                CardTitle(text: "Money received. Where should it go?", icon: "arrow.down.circle.fill", tint: Theme.warn)
                ForEach(store.pendingCredits) { t in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(t.merchant.map { "From \($0)" } ?? "Credit").font(.subheadline.weight(.medium))
                            Spacer()
                            Text(rupeeString(t.amountPaise)).font(Theme.rounded(24, .bold)).monospacedDigit()
                        }
                        HStack(spacing: 10) {
                            Button { store.allocate(id: t.id, to: .pool) } label: {
                                Label("Spend pool", systemImage: "wallet.pass.fill").frame(maxWidth: .infinity)
                            }.buttonStyle(.borderedProminent).tint(Theme.brand)
                            Button { store.allocate(id: t.id, to: .savings) } label: {
                                Label("Savings", systemImage: "banknote.fill").frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered).tint(Theme.brand)
                        }
                        .controlSize(.large)
                        Text("Spend pool raises today's budget and every day after it. Savings only adds to what you have saved.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .card(tint: Theme.warn)
        }
    }
}

/// Savings goal plus anything the user sent to savings, and a way to move a past credit.
struct SavingsCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        if let plan = store.plan {
            let extra = store.creditsTotal(.savings)
            let credits = store.resolvedCredits.filter { $0.time >= plan.cycleStart }
            VStack(alignment: .leading, spacing: 12) {
                CardTitle(text: "Savings this month", icon: "leaf.fill", tint: Theme.good)
                Text(rupeeString(plan.savingsGoalPaise + extra)).font(Theme.rounded(34, .bold)).foregroundStyle(Theme.good).monospacedDigit()
                HStack {
                    Text("Goal \(rupeeString(plan.savingsGoalPaise))").font(.subheadline).foregroundStyle(.secondary)
                    if extra > 0 {
                        Text("+ \(rupeeString(extra)) extra").font(.subheadline.weight(.medium)).foregroundStyle(Theme.good)
                    }
                }
                ForEach(credits) { t in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.merchant ?? (t.isRefund == true ? "Refund" : "Credit")).font(.subheadline.weight(.medium))
                            Text("\(rupeeString(t.amountPaise)) → " + (t.allocation == .pool ? "spend pool" : "savings"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if t.isRefund != true {
                            Button(t.allocation == .pool ? "Move to savings" : "Move to pool") {
                                store.allocate(id: t.id, to: t.allocation == .pool ? .savings : .pool)
                            }.buttonStyle(.bordered).controlSize(.small).tint(Theme.brand)
                        }
                    }
                }
            }
            .card()
        }
    }
}
