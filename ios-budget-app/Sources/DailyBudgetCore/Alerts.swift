import Foundation

public enum LimitLevel: Int, Comparable {
    case none = 0, eighty = 80, hundred = 100
    public static func < (a: LimitLevel, b: LimitLevel) -> Bool { a.rawValue < b.rawValue }
}

public struct LimitAlert: Equatable {
    public var level: LimitLevel
    public var title: String
    public var body: String
}

public struct PaymentWarning: Equatable {
    public enum Severity: Equatable { case info, caution, alert }
    public var severity: Severity
    public var title: String
    public var body: String
}

public extension BudgetEngine {
    static func limitLevel(spentTodayPaise: Int64, allowancePaise: Int64) -> LimitLevel {
        if allowancePaise <= 0 { return spentTodayPaise > 0 ? .hundred : .none }
        if spentTodayPaise >= allowancePaise { return .hundred }
        return spentTodayPaise * 100 >= allowancePaise * 80 ? .eighty : .none
    }

    /// An alert only when the spend that was just recorded pushed today over 80% or 100% of the budget.
    static func limitAlert(allowancePaise: Int64, spentTodayPaise: Int64, justSpentPaise: Int64) -> LimitAlert? {
        let before = limitLevel(spentTodayPaise: spentTodayPaise - justSpentPaise, allowancePaise: allowancePaise)
        let after = limitLevel(spentTodayPaise: spentTodayPaise, allowancePaise: allowancePaise)
        guard after > before else { return nil }
        let left = allowancePaise - spentTodayPaise
        switch after {
        case .eighty:
            let pct = Int(spentTodayPaise * 100 / allowancePaise)
            return LimitAlert(level: .eighty, title: "\(pct)% of today's budget used",
                body: "\(rupeeString(spentTodayPaise)) of \(rupeeString(allowancePaise)) spent, \(rupeeString(left)) left. If it isn't important, hold off on spending for the rest of today.")
        case .hundred:
            let body = left < 0
                ? "You are \(rupeeString(-left)) over. Every extra rupee comes out of tomorrow's budget, so skip anything non-essential."
                : "You have spent all of today's \(rupeeString(allowancePaise)). Anything more comes out of tomorrow's budget."
            return LimitAlert(level: .hundred, title: left < 0 ? "Over today's budget" : "Today's budget is used up", body: body)
        case .none:
            return nil
        }
    }

    /// What to tell the user the moment a payment OTP arrives, before they approve the payment.
    static func paymentWarning(_ r: AffordResult, merchant: String?) -> PaymentWarning {
        let spentAfter = (r.allowanceTodayPaise - r.leftTodayPaise) + r.pricePaise
        let pct: Int? = r.allowanceTodayPaise > 0 ? Int(spentAfter * 100 / r.allowanceTodayPaise) : nil
        let at = merchant.map { " at \($0)" } ?? ""
        let title = "\(rupeeString(r.pricePaise)) payment\(at) is waiting for your OTP"
        let skip = "If it isn't important, don't enter the OTP."
        switch r.verdict {
        case .fitsToday:
            if (pct ?? 100) >= 80 {
                return PaymentWarning(severity: .caution, title: title,
                    body: "It fits, but it would use \(pct ?? 100)% of today's budget and leave \(rupeeString(r.leftAfterPaise)). \(skip)")
            }
            return PaymentWarning(severity: .info, title: title,
                body: "It fits today's budget and leaves \(rupeeString(r.leftAfterPaise)). Go ahead if you need it.")
        case .stretch:
            let over = r.leftTodayPaise > 0 ? "It is \(rupeeString(-r.leftAfterPaise)) over today's budget" : "Today's budget is already used up"
            return PaymentWarning(severity: .caution, title: title,
                body: "\(over), and tomorrow's drops from \(rupeeString(r.tomorrowNowPaise)) to \(rupeeString(r.tomorrowAfterPaise)). \(skip)")
        case .eatsSavings:
            return PaymentWarning(severity: .alert, title: title,
                body: "It would take \(rupeeString(r.savingsDipPaise)) out of your savings goal. If it isn't essential, don't enter the OTP.")
        }
    }
}
