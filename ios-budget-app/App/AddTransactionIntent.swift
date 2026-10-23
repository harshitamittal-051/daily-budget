import AppIntents
import Foundation

/// The bridge that replaces SMS access on iOS. A Shortcuts *Personal Automation*
/// ("When I get a message containing 'debited'") runs this action with the message text.
struct AddTransactionFromMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Transaction from Message"
    static var description = IntentDescription("Reads a bank or UPI message and logs the spend in Daily Budget.")

    @Parameter(title: "Message") var message: String
    @Parameter(title: "Sender") var sender: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store.shared
        guard let t = store.ingest(message: message, sender: sender ?? "") else {
            return .result(dialog: "Not a new transaction.")
        }
        await Notifier.reschedule(store)
        await Notifier.alertSpend(t, store: store)
        return .result(dialog: "Logged.")
    }
}

/// "Hey Siri, can I afford something in Daily Budget?" -> Siri asks the price and answers out loud.
struct CanIAffordIntent: AppIntent {
    static var title: LocalizedStringResource = "Can I Afford This?"
    static var description = IntentDescription("Checks a price against today's budget and your savings goal.")

    @Parameter(title: "Price (₹)", requestValueDialog: "How much is it?") var price: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let r = Store.shared.afford(rupees: Int64(price)) else {
            return .result(dialog: "Set up your month in Daily Budget first.")
        }
        return .result(dialog: "\(r.summary)")
    }
}

struct BudgetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddTransactionFromMessageIntent(), phrases: ["Add a transaction in \(.applicationName)"],
                    shortTitle: "Add Transaction", systemImageName: "indianrupeesign.circle")
        AppShortcut(intent: CanIAffordIntent(),
                    phrases: ["Can I afford something in \(.applicationName)", "Check a purchase in \(.applicationName)"],
                    shortTitle: "Can I Afford This?", systemImageName: "questionmark.circle")
    }
}
