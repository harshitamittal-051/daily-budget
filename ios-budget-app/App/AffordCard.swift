import SwiftUI
import DailyBudgetCore

/// The headline feature: type a price, get a straight answer before you pay.
struct AffordCard: View {
    @EnvironmentObject var store: Store
    @State private var price = ""

    private var result: AffordResult? { store.afford(rupees: Int64(price) ?? 0) }

    var body: some View {
        let r = result
        VStack(alignment: .leading, spacing: 14) {
            CardTitle(text: "Can I afford this?", icon: "questionmark.circle.fill", tint: r.map(color) ?? Theme.brand)

            HStack(spacing: 6) {
                Text("₹").font(Theme.rounded(26, .medium)).foregroundStyle(.secondary)
                TextField("Price", text: $price).keyboardType(.numberPad).font(Theme.rounded(32, .bold))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.fieldFill))

            HStack(spacing: 8) {
                ForEach([500, 1500, 5000], id: \.self) { v in
                    Button { price = String(v) } label: {
                        Text(rupeeString(Int64(v) * 100)).font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Theme.fieldFill))
                    }.buttonStyle(.plain)
                }
            }

            if let r {
                HStack(spacing: 8) {
                    Image(systemName: icon(r))
                    Text(title(r)).font(Theme.rounded(17, .bold))
                }
                .foregroundStyle(color(r))
                Text(r.summary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                if r.verdict != .fitsToday {
                    HStack(spacing: 10) {
                        compare("Tomorrow now", rupeeString(r.tomorrowNowPaise), Color.primary)
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        compare("After buying", rupeeString(r.tomorrowAfterPaise), color(r))
                    }
                }
            } else {
                Text("Thinking of buying something? Type the price to see what it does to today and tomorrow.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card(tint: r.map(color))
        .animation(.easeOut(duration: 0.2), value: r?.verdict)
    }

    private func compare(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(Theme.rounded(17, .bold)).foregroundStyle(tint).monospacedDigit()
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.cardFill))
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
        case .fitsToday: return Theme.good
        case .stretch: return Theme.warn
        case .eatsSavings: return Theme.bad
        }
    }
}
