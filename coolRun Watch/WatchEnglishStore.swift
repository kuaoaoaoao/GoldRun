import Combine
import Foundation

/// 手表端“英语打卡”视图模型：读取 macOS 端镜像到 iCloud 的打卡快照。
/// 数据由 Mac 在打开英语学习页时推送（连续天数、今日已学/目标、今日单词与释义）。
@MainActor
final class WatchEnglishStore: ObservableObject {
    @Published private(set) var streak: Int = 0
    @Published private(set) var learnedToday: Int = 0
    @Published private(set) var dailyTarget: Int = 0
    @Published private(set) var word: String = ""
    @Published private(set) var translation: String = ""
    @Published private(set) var accent: String = "en-US"

    private let kvStore = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?

    // 与 macOS CloudSyncStore.Key 的 rawValue 保持一致。
    private let streakKey = "englishStreakDays"
    private let learnedKey = "englishLearnedToday"
    private let targetKey = "englishDailyTargetSync"
    private let wordKey = "englishTodayWord"
    private let translationKey = "englishTodayTranslation"
    private let accentKey = "englishAccentSync"

    init() {
        reload()
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reload()
            }
        }
        kvStore.synchronize()
    }

    // MARK: - 计算属性

    var hasData: Bool {
        !word.isEmpty || streak > 0 || learnedToday > 0 || dailyTarget > 0
    }

    var isGoalComplete: Bool {
        dailyTarget > 0 && learnedToday >= dailyTarget
    }

    var progress: Double {
        guard dailyTarget > 0 else { return 0 }
        return min(Double(learnedToday) / Double(dailyTarget), 1)
    }

    // MARK: - 刷新

    func reload() {
        streak = intValue(streakKey)
        learnedToday = intValue(learnedKey)
        dailyTarget = intValue(targetKey)
        word = kvStore.string(forKey: wordKey) ?? ""
        translation = kvStore.string(forKey: translationKey) ?? ""
        let syncedAccent = kvStore.string(forKey: accentKey) ?? ""
        accent = syncedAccent.isEmpty ? "en-US" : syncedAccent
    }

    private func intValue(_ key: String) -> Int {
        guard let text = kvStore.string(forKey: key), let value = Int(text) else { return 0 }
        return value
    }
}
