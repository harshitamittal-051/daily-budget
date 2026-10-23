import SwiftUI
import UserNotifications

@main
struct DailyBudgetApp: App {
    @StateObject private var store = Store.shared
    @Environment(\.scenePhase) private var phase

    init() { UNUserNotificationCenter.current().delegate = NotificationRouter.shared }

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .task { await Notifier.requestPermission(); await Notifier.reschedule(store) }
                .onChange(of: phase) { _, p in if p == .active { Task { await Notifier.reschedule(store) } } }
        }
    }
}
