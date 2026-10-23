import SwiftUI
import DailyBudgetCore

/// The headline feature: type a price, get a straight answer before you pay.
struct AffordCard: View {
    @EnvironmentObject var store: Store
    @State private var price = ""

    private var result: AffordResult? { store.afford(rupees: Int64(price) ?? 0) }

    var body: some View {
        Section("Can I afford this?") {
            HStack {
                Text("₹").foregroundStyle(.secondary)
                TextField("Price", text: $price).keyboardType(.numberPad)
                    .font(.system(size: 28, weight: .semibold))
            }
            if let r = result {
                Label(title(r), systemImage: icon(r)).font(.headline).foregroundStyle(color(r))
                Text(r.summary).font(.subheadline)
                if r.verdict != .fitsToday {
                    HStack {
                        Text("Tomorrow").font(.caption).foregroundStyle(.secondary)
                        Text("\(rupeeString(r.tomorrowNowPaise)) → \(rupeeString(r.tomorrowAfterPaise))")
                            .font(.caption.monospacedDigit())
                    }
                }
            } else {
                Text("Thinking of buying something? Type the price to see what it does to today and tomorrow.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func title(_ r: AffordResult) -> String {
        switch r.verdict {
        case .fitsToday: return "Yes, go ahead"
        case .stretch: return "Yes, but it costs you tomorrow"
        case .eatsSavings: return "Not without touching savings"
        }
    }
    private func icon(_ r: AffordResult) -> String {
        switch r.verdict {
        case .fitsToday: return "checkmark.circle.fill"
        case .stretch: return "exclamationmark.circle.fill"
        case .eatsSavings: return "xmark.octagon.fill"
        }
    }
    private func color(_ r: AffordResult) -> Color {
        switch r.verdict {
        case .fitsToday: return .green
        case .stretch: return .orange
        case .eatsSavings: return .red
        }
    }
}
