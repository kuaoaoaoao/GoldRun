import Foundation
import SwiftUI
import Combine

// MARK: - 应用设置管理器

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // 语言设置
    @Published var language: AppLanguage {
        didSet {
            userDefaults.set(language.rawValue, forKey: "app_language")
        }
    }

    // 监控模块开关
    @Published var showCPU: Bool {
        didSet { userDefaults.set(showCPU, forKey: "monitor_cpu") }
    }
    @Published var showMemory: Bool {
        didSet { userDefaults.set(showMemory, forKey: "monitor_memory") }
    }
    @Published var showStorage: Bool {
        didSet { userDefaults.set(showStorage, forKey: "monitor_storage") }
    }
    @Published var showBattery: Bool {
        didSet { userDefaults.set(showBattery, forKey: "monitor_battery") }
    }
    @Published var showNetwork: Bool {
        didSet { userDefaults.set(showNetwork, forKey: "monitor_network") }
    }
    @Published var showUptime: Bool {
        didSet { userDefaults.set(showUptime, forKey: "monitor_uptime") }
    }
    @Published var showTemperature: Bool {
        didSet { userDefaults.set(showTemperature, forKey: "monitor_temperature") }
    }

    // 菜单栏显示模式
    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            userDefaults.set(menuBarDisplayMode.rawValue, forKey: "menubar_display_mode")
        }
    }

    private init() {
        // 从 UserDefaults 加载设置
        let langRaw = userDefaults.string(forKey: "app_language") ?? AppLanguage.chinese.rawValue
        self.language = AppLanguage(rawValue: langRaw) ?? .chinese

        self.showCPU = userDefaults.object(forKey: "monitor_cpu") as? Bool ?? true
        self.showMemory = userDefaults.object(forKey: "monitor_memory") as? Bool ?? true
        self.showStorage = userDefaults.object(forKey: "monitor_storage") as? Bool ?? true
        self.showBattery = userDefaults.object(forKey: "monitor_battery") as? Bool ?? true
        self.showNetwork = userDefaults.object(forKey: "monitor_network") as? Bool ?? true
        self.showUptime = userDefaults.object(forKey: "monitor_uptime") as? Bool ?? true
        self.showTemperature = userDefaults.object(forKey: "monitor_temperature") as? Bool ?? true

        let modeRaw = userDefaults.string(forKey: "menubar_display_mode") ?? MenuBarDisplayMode.goldPrice.rawValue
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: modeRaw) ?? .goldPrice
    }
}

// MARK: - 语言枚举

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese: return "简体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

// MARK: - 菜单栏显示模式

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case goldPrice = "gold_price"
    case date = "date"

    var id: String { rawValue }

    func displayName(lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch self {
        case .goldPrice:
            return currentLang == .english ? "Gold Price" : "金价"
        case .date:
            return currentLang == .english ? "Date" : "日期"
        }
    }

    var icon: String {
        switch self {
        case .goldPrice: return "dollarsign.circle"
        case .date: return "calendar"
        }
    }
}

// MARK: - 本地化字符串

enum LocalizedString {
    // 通用
    static func common(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "settings":
            return currentLang == .english ? "Settings" : "设置"
        case "about":
            return currentLang == .english ? "About" : "关于"
        case "cancel":
            return currentLang == .english ? "Cancel" : "取消"
        case "confirm":
            return currentLang == .english ? "Confirm" : "确定"
        case "save":
            return currentLang == .english ? "Save" : "保存"
        case "close":
            return currentLang == .english ? "Close" : "关闭"
        case "done":
            return currentLang == .english ? "Done" : "完成"
        case "optional":
            return currentLang == .english ? "Optional" : "可选"
        default:
            return key
        }
    }

    // 设置页面
    static func settings(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "language":
            return currentLang == .english ? "Language" : "语言"
        case "language_desc":
            return currentLang == .english ? "Select display language" : "选择显示语言"
        case "monitor_modules":
            return currentLang == .english ? "Monitor Modules" : "监控模块"
        case "monitor_modules_desc":
            return currentLang == .english ? "Choose which modules to display" : "选择要显示的监控模块"
        case "menu_bar_display":
            return currentLang == .english ? "Menu Bar Display" : "菜单栏显示"
        case "menu_bar_display_desc":
            return currentLang == .english ? "Choose what to show in menu bar" : "选择菜单栏显示内容"
        case "author":
            return currentLang == .english ? "Author" : "作者"
        case "version":
            return currentLang == .english ? "Version" : "版本"
        case "platform":
            return currentLang == .english ? "Platform" : "平台"
        case "project_home":
            return currentLang == .english ? "Project Home" : "项目主页"
        case "check_update":
            return currentLang == .english ? "Check Update" : "检查更新"
        default:
            return key
        }
    }

    // 监控模块
    static func monitor(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "cpu":
            return "CPU"
        case "memory":
            return currentLang == .english ? "Memory" : "内存"
        case "storage":
            return currentLang == .english ? "Storage" : "储存"
        case "battery":
            return currentLang == .english ? "Battery" : "电池"
        case "network":
            return currentLang == .english ? "Network" : "网络"
        case "uptime":
            return currentLang == .english ? "Uptime" : "运行时间"
        case "temperature":
            return currentLang == .english ? "Temperature" : "温度"
        case "core_count":
            return currentLang == .english ? "Cores" : "核心数"
        case "cpu_temp":
            return currentLang == .english ? "CPU Temp" : "CPU 温度"
        case "gpu_temp":
            return currentLang == .english ? "GPU Temp" : "GPU 温度"
        case "used":
            return currentLang == .english ? "Used" : "已用"
        case "total":
            return currentLang == .english ? "Total" : "总量"
        case "available":
            return currentLang == .english ? "Available" : "可用"
        case "pressure":
            return currentLang == .english ? "Pressure" : "压力"
        case "status":
            return currentLang == .english ? "Status" : "状态"
        case "low_power":
            return currentLang == .english ? "Low Power" : "低电量模式"
        case "local_ip":
            return currentLang == .english ? "Local IP" : "本地 IP"
        case "interfaces":
            return currentLang == .english ? "Interfaces" : "接口"
        case "download":
            return currentLang == .english ? "Download" : "下载"
        case "upload":
            return currentLang == .english ? "Upload" : "上传"
        case "running_time":
            return currentLang == .english ? "Running" : "已运行"
        case "connected":
            return currentLang == .english ? "Connected" : "已连接"
        case "disconnected":
            return currentLang == .english ? "Disconnected" : "未连接"
        default:
            return key
        }
    }

    // 菜单栏
    static func menuBar(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "gold_price":
            return currentLang == .english ? "Gold Price" : "金价"
        case "date":
            return currentLang == .english ? "Date" : "日期"
        case "settings":
            return currentLang == .english ? "Settings" : "设置"
        case "quit":
            return currentLang == .english ? "Quit" : "退出程序"
        default:
            return key
        }
    }

    // 电池状态
    static func batteryState(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "unknown":
            return currentLang == .english ? "Unknown" : "未知"
        case "unplugged":
            return currentLang == .english ? "Battery" : "电池供电"
        case "charging":
            return currentLang == .english ? "Charging" : "充电中"
        case "full":
            return currentLang == .english ? "Full" : "已充满"
        case "no_battery":
            return currentLang == .english ? "No Battery" : "无电池"
        default:
            return key
        }
    }

    // 内存压力
    static func memoryPressure(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "low":
            return currentLang == .english ? "Low" : "轻"
        case "medium":
            return currentLang == .english ? "Medium" : "中"
        case "high":
            return currentLang == .english ? "High" : "高"
        default:
            return key
        }
    }

    // 通用标签
    static func label(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "copy_hint":
            return currentLang == .english ? "Click to copy" : "点击复制"
        case "on":
            return currentLang == .english ? "On" : "开启"
        case "off":
            return currentLang == .english ? "Off" : "关闭"
        case "enabled":
            return currentLang == .english ? "Enabled" : "已启用"
        case "disabled":
            return currentLang == .english ? "Disabled" : "已禁用"
        default:
            return key
        }
    }

    // 日历
    static func calendar(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "monitor":
            return currentLang == .english ? "Monitor" : "监控"
        case "calendar":
            return currentLang == .english ? "Calendar" : "日历"
        case "birthday":
            return currentLang == .english ? "Birthday" : "生日"
        case "birthday_manage":
            return currentLang == .english ? "Birthday Manage" : "生日管理"
        case "add_birthday":
            return currentLang == .english ? "Add Birthday" : "添加生日"
        case "edit_birthday":
            return currentLang == .english ? "Edit Birthday" : "编辑生日"
        case "name":
            return currentLang == .english ? "Name" : "姓名"
        case "lunar_birthday":
            return currentLang == .english ? "Lunar Birthday" : "农历生日"
        case "leap_month":
            return currentLang == .english ? "Leap Month" : "闰月"
        case "note":
            return currentLang == .english ? "Note" : "备注"
        case "note_placeholder":
            return currentLang == .english ? "e.g.: Mom, Friend" : "如：妈妈、朋友"
        case "select_year_month":
            return currentLang == .english ? "Select Year/Month" : "选择年月"
        case "today":
            return currentLang == .english ? "Today" : "今天"
        case "zodiac":
            return currentLang == .english ? "Zodiac" : "生肖"
        case "solar_term":
            return currentLang == .english ? "Solar Term" : "节气"
        case "festival":
            return currentLang == .english ? "Festival" : "节日"
        case "year":
            return currentLang == .english ? "Year" : "年份"
        case "month":
            return currentLang == .english ? "Month" : "月份"
        case "date":
            return currentLang == .english ? "Date" : "日期"
        case "holiday":
            return currentLang == .english ? "Off" : "休"
        case "workday":
            return currentLang == .english ? "Work" : "班"
        case "lunar":
            return currentLang == .english ? "Lunar" : "农历"
        case "empty_birthday":
            return currentLang == .english ? "No birthdays recorded" : "还没有记录生日"
        case "add_first_birthday":
            return currentLang == .english ? "Add your first birthday below" : "点击下方按钮添加第一个生日"
        case "birthday_reminder":
            return currentLang == .english ? "Birthday Reminder" : "生日提醒"
        case "got_it":
            return currentLang == .english ? "Got it" : "知道了"
        case "select_year_month_help":
            return currentLang == .english ? "Click to select year/month" : "点击选择年月"
        case "unnamed":
            return currentLang == .english ? "Unnamed" : "未命名"
        case "preview":
            return currentLang == .english ? "Preview" : "预览"
        case "and_more":
            return currentLang == .english ? " etc." : "等"
        default:
            return key
        }
    }

    // 数据管理
    static func data(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "holiday_data":
            return currentLang == .english ? "Holiday Data" : "节假日数据"
        case "holiday_data_desc":
            return currentLang == .english ? "Manage holiday and workday arrangements" : "管理节假日和调休安排数据"
        case "data_version":
            return currentLang == .english ? "Data Version" : "数据版本"
        case "record_count":
            return currentLang == .english ? "Records" : "条记录"
        case "last_update":
            return currentLang == .english ? "Last Update" : "最后更新"
        case "update_data":
            return currentLang == .english ? "Update Data" : "更新数据"
        case "updating":
            return currentLang == .english ? "Updating..." : "更新中..."
        case "update_success":
            return currentLang == .english ? "Data updated to latest version!" : "数据已更新到最新版本！"
        case "update_failed":
            return currentLang == .english ? "Update failed" : "更新失败"
        case "data_note":
            return currentLang == .english ? "Data Note" : "数据说明"
        case "data_note_content":
            return currentLang == .english ? "• Includes 2024-2026 statutory holidays\n• Includes workday arrangements\n• Data from State Council Office" : "• 包含2024-2026年法定节假日\n• 包含调休工作日安排\n• 数据来源于国务院办公厅通知"
        default:
            return key
        }
    }

    // 金价
    static func goldPrice(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "gold_price":
            return currentLang == .english ? "Gold" : "金价"
        case "loading":
            return currentLang == .english ? "Loading..." : "--"
        case "rate_limited":
            return currentLang == .english ? "Rate Limited" : "限频"
        case "network_error":
            return currentLang == .english ? "Network Error" : "网络失败"
        case "parse_error":
            return currentLang == .english ? "Parse Error" : "解析失败"
        default:
            return key
        }
    }

}
