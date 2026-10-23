// swift-tools-version:5.9
import PackageDescription

// Pure-Swift core (parser + categorizer + budget math), a port of android-budget-app/core.
// `swift test` runs on macOS or Linux; the iOS app in App/ links this same code.
let package = Package(
    name: "DailyBudgetCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "DailyBudgetCore", targets: ["DailyBudgetCore"])],
    targets: [
        .target(name: "DailyBudgetCore"),
        .testTarget(name: "DailyBudgetCoreTests", dependencies: ["DailyBudgetCore"]),
    ]
)
