import Combine
import Foundation

/// 手表端“今日”视图模型：
/// - 今日农历/节气/节日：本地纯计算（`WatchLunarCalendar`），无需网络或同步。
/// - 近期生日：读取 macOS 端镜像到 iCloud 的生日 JSON，按农历换算下一次公历日期并排序。
@MainActor
final class WatchTodayStore: ObservableObject {
    /// 与 macOS `Birthday` 保持一致的可解码结构（仅解码所需字段）。
    struct WatchBirthday: Codable, Identifiable {
        let id: UUID
        let name: String
        let lunarMonth: Int
        let lunarDay: Int
        let isLeapMonth: Bool
        let note: String
    }

    struct UpcomingBirthday: Identifiable {
        let id: UUID
        let name: String
        let lunarText: String
        let daysUntil: Int
    }

    @Published private(set) var today: Date = Date()
    @Published private(set) var lunar: WatchLunarDate = WatchLunarCalendar.convertSolarToLunar(date: Date())
    @Published private(set) var upcoming: [UpcomingBirthday] = []

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let birthdaysKey = "cloudBirthdaysJSON"
    private var observer: NSObjectProtocol?

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

    // MARK: - 显示文本

    var solarDayNumber: String {
        String(Calendar.current.component(.day, from: today))
    }

    var solarMonthText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: today)
    }

    var weekdayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: today)
    }

    var lunarText: String {
        "\(lunar.monthChinese)\(lunar.dayChinese)"
    }

    var lunarYearText: String {
        "\(lunar.yearChinese) · \(lunar.zodiac)年"
    }

    /// 今日节日或节气（优先节日）。
    var todayBadge: String? {
        lunar.festival ?? lunar.solarTerm
    }

    // MARK: - 刷新

    func reload() {
        today = Date()
        lunar = WatchLunarCalendar.convertSolarToLunar(date: today)
        upcoming = computeUpcomingBirthdays()
    }

    // MARK: - 私有

    private func computeUpcomingBirthdays() -> [UpcomingBirthday] {
        guard let json = kvStore.string(forKey: birthdaysKey),
              let data = json.data(using: .utf8),
              let list = try? JSONDecoder().decode([WatchBirthday].self, from: data) else {
            return []
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let currentYear = calendar.component(.year, from: today)

        var results: [UpcomingBirthday] = []
        for birthday in list {
            guard let days = nextBirthdayDays(
                lunarMonth: birthday.lunarMonth,
                lunarDay: birthday.lunarDay,
                isLeapMonth: birthday.isLeapMonth,
                startOfToday: startOfToday,
                currentYear: currentYear,
                calendar: calendar
            ) else { continue }

            results.append(
                UpcomingBirthday(
                    id: birthday.id,
                    name: birthday.name,
                    lunarText: WatchLunarCalendar.lunarMonthDayString(
                        month: birthday.lunarMonth,
                        day: birthday.lunarDay,
                        isLeapMonth: birthday.isLeapMonth
                    ),
                    daysUntil: days
                )
            )
        }

        return results.sorted { $0.daysUntil < $1.daysUntil }
    }

    /// 计算距下一次生日的天数（0 = 今天）。尝试今年与明年两个公历日期，取最近的未来日期。
    private func nextBirthdayDays(
        lunarMonth: Int,
        lunarDay: Int,
        isLeapMonth: Bool,
        startOfToday: Date,
        currentYear: Int,
        calendar: Calendar
    ) -> Int? {
        for yearOffset in 0...1 {
            guard let solar = WatchLunarCalendar.lunarToSolar(
                year: currentYear + yearOffset,
                month: lunarMonth,
                day: lunarDay,
                isLeapMonth: isLeapMonth
            ) else { continue }

            let startOfBirthday = calendar.startOfDay(for: solar)
            let days = calendar.dateComponents([.day], from: startOfToday, to: startOfBirthday).day ?? -1
            if days >= 0 {
                return days
            }
        }
        return nil
    }
}
