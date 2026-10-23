import Foundation

/// Where a credit (money coming in) was assigned.
public enum Allocation: String, Codable, Equatable {
    case none      // salary (starts a new month) or not applicable
    case pending   // waiting for the user to choose
    case pool      // added to this month's spend pool
    case savings   // added to savings
}

public enum Credits {
    /// Salary starts a new month (handled separately), a refund goes straight back to the
    /// spend pool, and every other credit asks the user.
    public static func defaultAllocation(isSalary: Bool, isRefund: Bool) -> Allocation {
        if isSalary { return .none }
        return isRefund ? .pool : .pending
    }
}

public extension Plan {
    /// The same month with extra money in the spend pool. Today's budget and every later
    /// day are computed from this plan, so adding to the pool changes the budget immediately.
    func withExtraPool(_ paise: Int64) -> Plan {
        var p = self
        p.salaryPaise += paise
        return p
    }
}
