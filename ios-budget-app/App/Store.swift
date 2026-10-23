import Foundation
import DailyBudgetCore

struct Txn: Codable, Identifiable, Equatable {
    var id = UUID()
    var key: String            // dedup: Shortcuts can fire twice for one message
    var isDebit: Bool
    var amountPaise: Int64
    var merchant: String?
    var method: String
    var category: String
    var time: Date
    var isSalary: Bool
    var countsTowardBudget: Bool
}

/// JSON-file store shared by the app UI and the Shortcuts intent (same process/bundle).
@MainActor
final class Store: ObservableObject {
    static let shared = Store()
    @Published private(set) var txns: [Txn] = []
    @Published private(set) var plan: Plan?

    private let url: URL = {
        let dir = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return dir.appendingPathComponent("budget.json")
    }()
    private struct Disk: Codable { var txns: [Txn]; var plan: Plan? }

    private init() {
        if let d = try? Data(contentsOf: url), let disk = try? JSONDecoder().decode(Disk.self, from: d) {
            txns = disk.txns; plan = disk.plan
        }
    }
    private func save() {
        if let d = try? JSONEncoder().encode(Disk(txns: txns, plan: plan)) { try? d.write(to: url, options: .atomic) }
    }

    func setPlan(_ p: Plan) { plan = p; save(); Task { await Notifier.reschedule(self) } }

    func toggleCounts(_ t: Txn) {
        guard let i = txns.firstIndex(where: { $0.id == t.id }) else { return }
        txns[i].countsTowardBudget.toggle(); save(); Task { await Notifier.reschedule(self) }
    }

    /// Parse a message and store it. Returns the stored transaction, nil if not a transaction or a duplicate.
    @discardableResult
    func ingest(message: String, sender: String = "", at time: Date = Date()) -> Txn? {
        guard let p = SmsParser.parse(message, at: time) else { return nil }
        let key = "\(sender)|\(Int(time.timeIntervalSince1970 / 60))|\(message)"
        guard !txns.contains(where: { $0.key == key }) else { return nil }
        let debit = p.type == .debit
        let cat = debit ? Categorizer.categorize(p) : Categories.other
        let t = Txn(key: key, isDebit: debit, amountPaise: p.amountPaise, merchant: p.merchant, method: p.method,
                    category: cat, time: time, isSalary: p.isSalary,
                    countsTowardBudget: debit && !Categories.excludedByDefault.contains(cat))
        txns.insert(t, at: 0); save()
        return t
    }

    func addManual(amountRupees: Int64, merchant: String, category: String) {
        let t = Txn(key: UUID().uuidString, isDebit: true, amountPaise: amountRupees * 100, merchant: merchant, method: "MANUAL",
                    category: category, time: Date(), isSalary: false, countsTowardBudget: true)
        txns.insert(t, at: 0); save(); Task { await Notifier.reschedule(self) }
    }

    // MARK: budget queries
    func spent(from: Date, to: Date) -> Int64 {
        txns.filter { $0.isDebit && $0.countsTowardBudget && $0.time >= from && $0.time < to }.reduce(0) { $0 + $1.amountPaise }
    }
    func startOfDay(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }
    func addDays(_ d: Date, _ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: d)! }

    func today(_ now: Date = Date()) -> DayBudget? {
        guard let plan else { return nil }
        let sod = startOfDay(now)
        return BudgetEngine.dayBudget(plan: plan, spentBefore: spent(from: plan.cycleStart, to: sod),
                                      spentToday: spent(from: sod, to: addDays(sod, 1)), today: sod)
    }
    func review(_ now: Date = Date()) -> NightlyReview? {
        guard let plan else { return nil }
        let sod = startOfDay(now)
        return BudgetEngine.nightlyReview(plan: plan, spentBefore: spent(from: plan.cycleStart, to: sod),
                                          spentToday: spent(from: sod, to: addDays(sod, 1)), today: sod)
    }
    var newSalary: Txn? { plan.flatMap { p in txns.first { $0.isSalary && $0.time > p.cycleStart.addingTimeInterval(60) } } }

    func byCategory() -> [(String, Int64)] {
        guard let plan else { return [] }
        let m = Dictionary(grouping: txns.filter { $0.isDebit && $0.countsTowardBudget && $0.time >= plan.cycleStart }, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amountPaise } }
        return m.sorted { $0.value > $1.value }
    }
    func topMerchants() -> [(String, Int64, Int)] {
        guard let plan else { return [] }
        let g = Dictionary(grouping: txns.filter { $0.isDebit && $0.countsTowardBudget && $0.time >= plan.cycleStart }, by: { $0.merchant ?? "Unknown" })
        return g.map { ($0.key, $0.value.reduce(0) { $0 + $1.amountPaise }, $0.value.count) }.sorted { $0.1 > $1.1 }.prefix(8).map { $0 }
    }
}
