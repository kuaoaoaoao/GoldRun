import AppIntents
import Foundation

enum GoldRunModuleIntentValue: String, AppEnum, CaseIterable {
    case today
    case monitor
    case gold
    case calendar
    case english
    case ai

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "GoldRun Module")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .today: "Today",
        .monitor: "System Monitor",
        .gold: "Gold",
        .calendar: "Calendar",
        .english: "English",
        .ai: "AI Quota"
    ]

    var viewMode: ViewMode {
        switch self {
        case .today: .today
        case .monitor: .monitor
        case .gold: .gold
        case .calendar: .calendar
        case .english: .english
        case .ai: .codex
        }
    }
}

struct ShowGoldRunTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Show GoldRun Today"
    static var description = IntentDescription("Open GoldRun's prioritized Today overview.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigationRouter.shared.open(.today)
        return .result()
    }
}

struct OpenGoldRunModuleIntent: AppIntent {
    static var title: LocalizedStringResource = "Open GoldRun Module"
    static var description = IntentDescription("Open a specific GoldRun module.")
    static var openAppWhenRun = true

    @Parameter(title: "Module", default: .today)
    var module: GoldRunModuleIntentValue

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigationRouter.shared.open(module.viewMode)
        return .result()
    }
}

struct ToggleGoldRunEnglishIntent: AppIntent {
    static var title: LocalizedStringResource = "Play or Pause GoldRun English"
    static var description = IntentDescription("Start, pause, or resume the current English learning queue.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        EnglishLearningManager.shared.toggleContinuousPlayback()
        return .result()
    }
}

struct RefreshGoldRunIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh GoldRun Data"
    static var description = IntentDescription("Refresh the current gold quote and open the Gold module.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigationRouter.shared.open(.gold)
        NotificationCenter.default.post(name: .goldRunRefreshGold, object: nil)
        return .result()
    }
}

struct GoldRunShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowGoldRunTodayIntent(),
            phrases: ["Show \(.applicationName) today"],
            shortTitle: "GoldRun Today",
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: ToggleGoldRunEnglishIntent(),
            phrases: ["Play English in \(.applicationName)"],
            shortTitle: "Play English",
            systemImageName: "character.book.closed.fill"
        )
        AppShortcut(
            intent: RefreshGoldRunIntent(),
            phrases: ["Refresh \(.applicationName)"],
            shortTitle: "Refresh GoldRun",
            systemImageName: "arrow.clockwise"
        )
    }
}
