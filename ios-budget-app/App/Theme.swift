import SwiftUI
import DailyBudgetCore

/// One place for the app's look: colours, rounded type, card style and category icons.
enum Theme {
    static let brand = Color(red: 0.06, green: 0.56, blue: 0.50)
    static let brandDeep = Color(red: 0.03, green: 0.27, blue: 0.30)
    static let good = Color(red: 0.13, green: 0.64, blue: 0.40)
    static let warn = Color(red: 0.96, green: 0.58, blue: 0.10)
    static let bad = Color(red: 0.88, green: 0.24, blue: 0.22)

    static let heroGradient = LinearGradient(colors: [brand, brandDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static var cardFill: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    static var fieldFill: Color { Color(uiColor: .tertiarySystemGroupedBackground) }
    static var pageFill: Color { Color(uiColor: .systemGroupedBackground) }
}

struct CardModifier: ViewModifier {
    var tint: Color?
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(tint.map { $0.opacity(0.13) } ?? Theme.cardFill))
    }
}

extension View {
    /// Rounded card. Pass a tint to colour the card by meaning (green = fine, orange = careful, red = stop).
    func card(tint: Color? = nil) -> some View { modifier(CardModifier(tint: tint)) }
}

/// Small bold title with an icon, used at the top of every card.
struct CardTitle: View {
    let text: String
    let icon: String
    var tint: Color = Theme.brand
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(Theme.rounded(15, .semibold))
            Spacer(minLength: 0)
        }
    }
}

/// Each spending category gets its own icon and colour so the dashboard reads at a glance.
enum CategoryStyle {
    static func icon(_ c: String) -> String {
        switch c {
        case Categories.food: return "fork.knife"
        case Categories.groceries: return "basket.fill"
        case Categories.transport: return "car.fill"
        case Categories.shopping: return "bag.fill"
        case Categories.bills: return "bolt.fill"
        case Categories.entertainment: return "film.fill"
        case Categories.health: return "cross.case.fill"
        case Categories.cash: return "banknote.fill"
        case Categories.transfers: return "arrow.left.arrow.right"
        case Categories.cardBill: return "creditcard.fill"
        default: return "circle.grid.2x2.fill"
        }
    }
    static func color(_ c: String) -> Color {
        switch c {
        case Categories.food: return Color(red: 0.95, green: 0.45, blue: 0.20)
        case Categories.groceries: return Color(red: 0.30, green: 0.70, blue: 0.35)
        case Categories.transport: return Color(red: 0.20, green: 0.52, blue: 0.92)
        case Categories.shopping: return Color(red: 0.80, green: 0.30, blue: 0.62)
        case Categories.bills: return Color(red: 0.90, green: 0.72, blue: 0.10)
        case Categories.entertainment: return Color(red: 0.55, green: 0.35, blue: 0.90)
        case Categories.health: return Color(red: 0.90, green: 0.25, blue: 0.35)
        case Categories.cash: return Color(red: 0.25, green: 0.65, blue: 0.60)
        case Categories.transfers: return Color(red: 0.40, green: 0.45, blue: 0.55)
        case Categories.cardBill: return Color(red: 0.45, green: 0.45, blue: 0.50)
        default: return Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }
}

struct CategoryBadge: View {
    let category: String
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: CategoryStyle.icon(category))
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(CategoryStyle.color(category))
            .frame(width: size, height: size)
            .background(Circle().fill(CategoryStyle.color(category).opacity(0.15)))
    }
}

/// Rounded progress ring. Turns orange past 80% and red past 100% of the day's budget.
struct BudgetRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 12
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: fraction)
        }
    }
    private var color: Color { fraction >= 1 ? Color(red: 1, green: 0.45, blue: 0.40) : fraction >= 0.8 ? Theme.warn : .white }
}

/// Thin coloured bar used for category shares.
struct ShareBar: View {
    let fraction: Double
    let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.16))
                Capsule().fill(color).frame(width: max(8, g.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 8)
    }
}

/// Labelled amount field with a big rounded number, used on the setup screen.
struct AmountField: View {
    let title: String
    @Binding var text: String
    var hint: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text("₹").font(Theme.rounded(22, .medium)).foregroundStyle(.secondary)
                TextField("0", text: $text).keyboardType(.numberPad).font(Theme.rounded(26, .bold))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.fieldFill))
            if let hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
