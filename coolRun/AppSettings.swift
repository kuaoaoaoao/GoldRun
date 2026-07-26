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

    // 常驻刷新策略
    @Published var systemRefreshRate: SystemRefreshRate {
        didSet { userDefaults.set(systemRefreshRate.rawValue, forKey: "system_refresh_rate") }
    }

    @Published var menuBarAnimationRate: MenuBarAnimationRate {
        didSet { userDefaults.set(menuBarAnimationRate.rawValue, forKey: "menubar_animation_rate") }
    }

    @Published var goldRefreshRate: GoldRefreshRate {
        didSet { userDefaults.set(goldRefreshRate.rawValue, forKey: "gold_refresh_rate") }
    }

    // 预测自动校准：关闭后只观察历史表现，不自动调整信心和仓位
    @Published var goldAutoCalibrationEnabled: Bool {
        didSet { userDefaults.set(goldAutoCalibrationEnabled, forKey: "gold_auto_calibration_enabled") }
    }

    // 金价到价提醒：触达上/下限时发系统通知
    @Published var goldAlertEnabled: Bool {
        didSet { userDefaults.set(goldAlertEnabled, forKey: "gold_alert_enabled") }
    }
    @Published var goldAlertUpperText: String {
        didSet { userDefaults.set(goldAlertUpperText, forKey: "gold_alert_upper") }
    }
    @Published var goldAlertLowerText: String {
        didSet { userDefaults.set(goldAlertLowerText, forKey: "gold_alert_lower") }
    }

    // 隐私设置
    @Published var analyticsEnabled: Bool {
        didSet {
            userDefaults.set(analyticsEnabled, forKey: "analytics_enabled")
            Analytics.setEnabled(analyticsEnabled)
        }
    }

    // 菜单栏显示模式
    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            userDefaults.set(menuBarDisplayMode.rawValue, forKey: "menubar_display_mode")
        }
    }

    // 英语学习设置
    @Published var englishAccent: EnglishAccent {
        didSet { userDefaults.set(englishAccent.rawValue, forKey: "english_accent") }
    }
    @Published var englishVoiceIdentifier: String {
        didSet { userDefaults.set(englishVoiceIdentifier, forKey: "english_voice_identifier") }
    }
    @Published var englishTTSBackend: EnglishTTSBackend {
        didSet { userDefaults.set(englishTTSBackend.rawValue, forKey: "english_tts_backend") }
    }
    @Published var englishKokoroCommandPath: String {
        didSet { userDefaults.set(englishKokoroCommandPath, forKey: "english_kokoro_command_path") }
    }
    @Published var englishKokoroVoice: String {
        didSet { userDefaults.set(englishKokoroVoice, forKey: "english_kokoro_voice") }
    }
    @Published var englishNormalRate: Double {
        didSet { userDefaults.set(englishNormalRate, forKey: "english_normal_rate") }
    }
    @Published var englishSlowRate: Double {
        didSet { userDefaults.set(englishSlowRate, forKey: "english_slow_rate") }
    }
    @Published var englishVolume: Double {
        didSet { userDefaults.set(englishVolume, forKey: "english_volume") }
    }
    @Published var englishRepeatCount: Int {
        didSet { userDefaults.set(englishRepeatCount, forKey: "english_repeat_count") }
    }
    @Published var englishItemInterval: Double {
        didSet { userDefaults.set(englishItemInterval, forKey: "english_item_interval") }
    }
    @Published var englishShowTranslation: Bool {
        didSet { userDefaults.set(englishShowTranslation, forKey: "english_show_translation") }
    }
    @Published var englishSpeakTranslation: Bool {
        didSet { userDefaults.set(englishSpeakTranslation, forKey: "english_speak_translation") }
    }
    @Published var englishMenuTextStyle: EnglishMenuTextStyle {
        didSet { userDefaults.set(englishMenuTextStyle.rawValue, forKey: "english_menu_text_style") }
    }
    @Published var englishDailyTarget: Int {
        didSet { userDefaults.set(englishDailyTarget, forKey: "english_daily_target") }
    }
    @Published var englishHasSeenVoiceOnboarding: Bool {
        didSet { userDefaults.set(englishHasSeenVoiceOnboarding, forKey: "english_has_seen_voice_onboarding") }
    }
    // 语音质量横幅关闭后持久记住，不随面板重建反复出现
    @Published var englishVoiceHintDismissed: Bool {
        didSet { userDefaults.set(englishVoiceHintDismissed, forKey: "english_voice_hint_dismissed") }
    }
    @Published var englishStage: EnglishStage {
        didSet { userDefaults.set(englishStage.rawValue, forKey: "english_stage") }
    }

    // 记住上次使用的模块，重启后直接回到该模块
    @Published var lastViewModeRaw: String {
        didSet { userDefaults.set(lastViewModeRaw, forKey: "last_view_mode") }
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

        let systemRefreshRaw = userDefaults.string(forKey: "system_refresh_rate") ?? SystemRefreshRate.balanced.rawValue
        self.systemRefreshRate = SystemRefreshRate(rawValue: systemRefreshRaw) ?? .balanced

        let animationRaw = userDefaults.string(forKey: "menubar_animation_rate") ?? MenuBarAnimationRate.energySaving.rawValue
        self.menuBarAnimationRate = MenuBarAnimationRate(rawValue: animationRaw) ?? .energySaving

        let goldRefreshRaw = userDefaults.string(forKey: "gold_refresh_rate") ?? GoldRefreshRate.minute.rawValue
        self.goldRefreshRate = GoldRefreshRate(rawValue: goldRefreshRaw) ?? .minute

        self.goldAutoCalibrationEnabled = userDefaults.object(forKey: "gold_auto_calibration_enabled") as? Bool ?? true

        self.goldAlertEnabled = userDefaults.object(forKey: "gold_alert_enabled") as? Bool ?? false
        self.goldAlertUpperText = userDefaults.string(forKey: "gold_alert_upper") ?? ""
        self.goldAlertLowerText = userDefaults.string(forKey: "gold_alert_lower") ?? ""

        self.analyticsEnabled = userDefaults.object(forKey: "analytics_enabled") as? Bool ?? true

        self.lastViewModeRaw = userDefaults.string(forKey: "last_view_mode") ?? ""

        let modeRaw = userDefaults.string(forKey: "menubar_display_mode") ?? MenuBarDisplayMode.goldPrice.rawValue
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: modeRaw) ?? .goldPrice

        let accentRaw = userDefaults.string(forKey: "english_accent") ?? EnglishAccent.american.rawValue
        self.englishAccent = EnglishAccent(rawValue: accentRaw) ?? .american
        self.englishVoiceIdentifier = userDefaults.string(forKey: "english_voice_identifier") ?? ""
        let ttsBackendRaw = userDefaults.string(forKey: "english_tts_backend") ?? EnglishTTSBackend.system.rawValue
        self.englishTTSBackend = EnglishTTSBackend(rawValue: ttsBackendRaw) ?? .system
        self.englishKokoroCommandPath = userDefaults.string(forKey: "english_kokoro_command_path") ?? ""
        self.englishKokoroVoice = userDefaults.string(forKey: "english_kokoro_voice") ?? KokoroEnglishSpeechProvider.defaultVoice
        self.englishNormalRate = userDefaults.object(forKey: "english_normal_rate") as? Double ?? 0.43
        self.englishSlowRate = userDefaults.object(forKey: "english_slow_rate") as? Double ?? 0.30
        let savedEnglishVolume = userDefaults.object(forKey: "english_volume") as? Double ?? 0.9
        self.englishVolume = min(max(savedEnglishVolume, 0.1), 1)
        self.englishRepeatCount = userDefaults.object(forKey: "english_repeat_count") as? Int ?? 2
        self.englishItemInterval = userDefaults.object(forKey: "english_item_interval") as? Double ?? 7
        self.englishShowTranslation = userDefaults.object(forKey: "english_show_translation") as? Bool ?? true
        self.englishSpeakTranslation = userDefaults.object(forKey: "english_speak_translation") as? Bool ?? false
        let textStyleRaw = userDefaults.string(forKey: "english_menu_text_style") ?? EnglishMenuTextStyle.englishOnly.rawValue
        self.englishMenuTextStyle = EnglishMenuTextStyle(rawValue: textStyleRaw) ?? .englishOnly
        self.englishDailyTarget = userDefaults.object(forKey: "english_daily_target") as? Int ?? 10
        self.englishHasSeenVoiceOnboarding = userDefaults.object(forKey: "english_has_seen_voice_onboarding") as? Bool ?? false
        self.englishVoiceHintDismissed = userDefaults.object(forKey: "english_voice_hint_dismissed") as? Bool ?? false
        let stageRaw = userDefaults.string(forKey: "english_stage") ?? EnglishStage.daily.rawValue
        self.englishStage = EnglishStage(rawValue: stageRaw) ?? .daily
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
    case cpu = "cpu"
    case memory = "memory"
    case network = "network"
    case novel = "novel"
    case english = "english"
    case codex = "codex"

    var id: String { rawValue }

    func displayName(lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch self {
        case .goldPrice:
            return LocalizedString.l(currentLang, en: "Gold Price", zh: "金价", ja: "金価格", ko: "금 가격")
        case .date:
            return LocalizedString.l(currentLang, en: "Date", zh: "日期", ja: "日付", ko: "날짜")
        case .cpu:
            return LocalizedString.l(currentLang, en: "CPU Usage", zh: "CPU 占用", ja: "CPU 使用率", ko: "CPU 사용률")
        case .memory:
            return LocalizedString.l(currentLang, en: "Memory Usage", zh: "内存占用", ja: "メモリ使用率", ko: "메모리 사용량")
        case .network:
            return LocalizedString.l(currentLang, en: "Network Speed", zh: "实时网速", ja: "ネットワーク速度", ko: "네트워크 속도")
        case .novel:
            return LocalizedString.l(currentLang, en: "Novel", zh: "小说", ja: "小説", ko: "소설")
        case .english:
            return LocalizedString.l(currentLang, en: "English Learning", zh: "英语学习", ja: "英語学習", ko: "영어 학습")
        case .codex:
            return "Codex"
        }
    }

    var icon: String {
        switch self {
        case .goldPrice: return "dollarsign.circle"
        case .date: return "calendar"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .network: return "arrow.up.arrow.down"
        case .novel: return "book.pages"
        case .english: return "character.book.closed"
        case .codex: return "sparkles"
        }
    }
}

// MARK: - 刷新与动画策略

enum SystemRefreshRate: String, CaseIterable, Identifiable {
    case realtime
    case balanced
    case energySaving = "energy_saving"

    var id: String { rawValue }

    var duration: Duration {
        switch self {
        case .realtime: return .seconds(1)
        case .balanced: return .seconds(2)
        case .energySaving: return .seconds(5)
        }
    }

    func displayName(lang: AppLanguage) -> String {
        switch self {
        case .realtime: return LocalizedString.l(lang, en: "Real-time (1s)", zh: "实时（1 秒）", ja: "リアルタイム（1秒）", ko: "실시간(1초)")
        case .balanced: return LocalizedString.l(lang, en: "Balanced (2s)", zh: "均衡（2 秒）", ja: "バランス（2秒）", ko: "균형(2초)")
        case .energySaving: return LocalizedString.l(lang, en: "Energy Saving (5s)", zh: "节能（5 秒）", ja: "省電力（5秒）", ko: "절전(5초)")
        }
    }
}

enum MenuBarAnimationRate: String, CaseIterable, Identifiable {
    case off
    case energySaving = "energy_saving"
    case smooth

    var id: String { rawValue }

    var framesPerSecond: Double? {
        switch self {
        case .off: return nil
        case .energySaving: return 8
        case .smooth: return 20
        }
    }

    func displayName(lang: AppLanguage) -> String {
        switch self {
        case .off: return LocalizedString.l(lang, en: "Off", zh: "关闭", ja: "オフ", ko: "끄기")
        case .energySaving: return LocalizedString.l(lang, en: "Energy Saving (8 FPS)", zh: "节能（8 FPS）", ja: "省電力（8 FPS）", ko: "절전(8 FPS)")
        case .smooth: return LocalizedString.l(lang, en: "Smooth (20 FPS)", zh: "流畅（20 FPS）", ja: "なめらか（20 FPS）", ko: "부드럽게(20 FPS)")
        }
    }
}

enum GoldRefreshRate: String, CaseIterable, Identifiable {
    case seconds30 = "30_seconds"
    case minute = "1_minute"
    case minutes5 = "5_minutes"

    var id: String { rawValue }

    var duration: Duration {
        switch self {
        case .seconds30: return .seconds(30)
        case .minute: return .seconds(60)
        case .minutes5: return .seconds(300)
        }
    }

    func displayName(lang: AppLanguage) -> String {
        switch self {
        case .seconds30: return LocalizedString.l(lang, en: "30 seconds", zh: "30 秒", ja: "30秒", ko: "30초")
        case .minute: return LocalizedString.l(lang, en: "1 minute", zh: "1 分钟", ja: "1分", ko: "1분")
        case .minutes5: return LocalizedString.l(lang, en: "5 minutes", zh: "5 分钟", ja: "5分", ko: "5분")
        }
    }
}

// MARK: - 本地化字符串

enum LocalizedString {
    // MARK: - Helper

    static func l(
        _ lang: AppLanguage,
        en: String,
        zh: String,
        ja: String? = nil,
        ko: String? = nil
    ) -> String {
        switch lang {
        case .chinese: return zh
        case .english: return en
        case .japanese: return ja ?? en
        case .korean: return ko ?? en
        }
    }

    // MARK: - 通用

    static func common(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "settings": return l(currentLang, en: "Settings", zh: "设置", ja: "設定", ko: "설정")
        case "about": return l(currentLang, en: "About", zh: "关于", ja: "このアプリについて", ko: "정보")
        case "cancel": return l(currentLang, en: "Cancel", zh: "取消", ja: "キャンセル", ko: "취소")
        case "confirm": return l(currentLang, en: "Confirm", zh: "确定", ja: "確認", ko: "확인")
        case "save": return l(currentLang, en: "Save", zh: "保存", ja: "保存", ko: "저장")
        case "close": return l(currentLang, en: "Close", zh: "关闭", ja: "閉じる", ko: "닫기")
        case "done": return l(currentLang, en: "Done", zh: "完成", ja: "完了", ko: "완료")
        case "optional": return l(currentLang, en: "Optional", zh: "可选", ja: "任意", ko: "선택 사항")
        case "delete": return l(currentLang, en: "Delete", zh: "删除", ja: "削除", ko: "삭제")
        case "ok": return l(currentLang, en: "OK", zh: "好", ja: "OK", ko: "확인")
        case "import": return l(currentLang, en: "Import", zh: "导入", ja: "インポート", ko: "가져오기")
        case "previous": return l(currentLang, en: "Previous", zh: "上一条", ja: "前へ", ko: "이전")
        case "next": return l(currentLang, en: "Next", zh: "下一条", ja: "次へ", ko: "다음")
        case "stop": return l(currentLang, en: "Stop", zh: "停止", ja: "停止", ko: "정지")
        case "play": return l(currentLang, en: "Play", zh: "播放", ja: "再生", ko: "재생")
        case "pause": return l(currentLang, en: "Pause", zh: "暂停", ja: "一時停止", ko: "일시 정지")
        default: return key
        }
    }

    // MARK: - 设置页面

    static func settings(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "language": return l(currentLang, en: "Language", zh: "语言", ja: "言語", ko: "언어")
        case "language_desc": return l(currentLang, en: "Select display language", zh: "选择显示语言", ja: "表示言語を選択", ko: "표시 언어 선택")
        case "monitor_modules": return l(currentLang, en: "Monitor Modules", zh: "监控模块", ja: "監視モジュール", ko: "모니터링 모듈")
        case "monitor_modules_desc": return l(currentLang, en: "Choose which modules to display", zh: "选择要显示的监控模块", ja: "表示するモジュールを選択", ko: "표시할 모듈 선택")
        case "menu_bar_display": return l(currentLang, en: "Menu Bar Display", zh: "菜单栏显示", ja: "メニューバー表示", ko: "메뉴 막대 표시")
        case "menu_bar_display_desc": return l(currentLang, en: "Choose what to show in menu bar", zh: "选择菜单栏显示内容", ja: "メニューバーに表示する内容を選択", ko: "메뉴 막대에 표시할 내용 선택")
        case "author": return l(currentLang, en: "Author", zh: "作者", ja: "作者", ko: "작성자")
        case "version": return l(currentLang, en: "Version", zh: "版本", ja: "バージョン", ko: "버전")
        case "platform": return l(currentLang, en: "Platform", zh: "平台", ja: "プラットフォーム", ko: "플랫폼")
        case "project_home": return l(currentLang, en: "Project Home", zh: "项目主页", ja: "プロジェクトページ", ko: "프로젝트 홈")
        case "check_update": return l(currentLang, en: "Check Update", zh: "检查更新", ja: "更新を確認", ko: "업데이트 확인")
        case "startup": return l(currentLang, en: "Startup", zh: "启动", ja: "起動", ko: "시작")
        case "startup_desc": return l(currentLang, en: "Keep coolRun available after signing in", zh: "登录 Mac 后自动运行 coolRun", ja: "Mac にサインインした後も coolRun を起動", ko: "Mac 로그인 후 coolRun 자동 실행")
        case "launch_at_login": return l(currentLang, en: "Launch at Login", zh: "登录时启动", ja: "ログイン時に起動", ko: "로그인 시 실행")
        case "privacy": return l(currentLang, en: "Privacy", zh: "隐私", ja: "プライバシー", ko: "개인정보")
        case "privacy_desc": return l(currentLang, en: "Control anonymous product analytics", zh: "控制匿名使用数据统计", ja: "匿名の利用統計を管理", ko: "익명 사용 통계 관리")
        case "share_analytics": return l(currentLang, en: "Share Anonymous Usage Data", zh: "共享匿名使用数据", ja: "匿名の利用データを共有", ko: "익명 사용 데이터 공유")
        case "privacy_note": return l(currentLang, en: "Novel text, birthdays, notes, holdings and profit amounts are never included.", zh: "不会上传小说正文、生日、备注、持仓和盈亏金额。", ja: "小説本文、誕生日、メモ、保有情報、損益額は送信されません。", ko: "소설 본문, 생일, 메모, 보유 정보와 손익 금액은 전송되지 않습니다.")
        case "refresh_rate": return l(currentLang, en: "Refresh Rate", zh: "刷新频率", ja: "更新頻度", ko: "새로 고침 빈도")
        case "refresh_rate_desc": return l(currentLang, en: "Lower rates reduce background CPU and power usage", zh: "降低频率可以减少后台 CPU 与耗电", ja: "頻度を下げるとバックグラウンドの CPU と電力を節約", ko: "빈도를 낮추면 백그라운드 CPU와 전력 사용량 감소")
        case "system_sampling": return l(currentLang, en: "System Sampling", zh: "系统采样", ja: "システムサンプリング", ko: "시스템 샘플링")
        case "menubar_animation": return l(currentLang, en: "Menu Bar Animation", zh: "菜单栏动画", ja: "メニューバーアニメーション", ko: "메뉴 막대 애니메이션")
        case "menubar_animation_desc": return l(currentLang, en: "Choose a balance between motion and energy use", zh: "在动画流畅度和能耗之间选择", ja: "動きと消費電力のバランスを選択", ko: "움직임과 에너지 사용량의 균형 선택")
        case "coin_animation": return l(currentLang, en: "Coin Animation", zh: "金币动画", ja: "コインアニメーション", ko: "코인 애니메이션")
        case "gold_updates": return l(currentLang, en: "Gold Price Updates", zh: "金价更新", ja: "金価格の更新", ko: "금 가격 업데이트")
        case "gold_updates_desc": return l(currentLang, en: "Control request frequency to the price provider", zh: "控制向金价数据源发起请求的频率", ja: "価格データ提供元へのリクエスト頻度を管理", ko: "가격 제공자 요청 빈도 관리")
        // 卡片新标题：刷新频率与到价提醒合并在同一卡，标题要能覆盖两者
        case "gold_data_alerts": return l(currentLang, en: "Gold Data & Alerts", zh: "金价数据与提醒", ja: "金価格データとアラート", ko: "금 가격 데이터 및 알림")
        case "gold_data_alerts_desc": return l(currentLang, en: "Refresh frequency and price alert thresholds", zh: "刷新频率与到价提醒阈值", ja: "更新頻度と価格アラートのしきい値", ko: "새로고침 빈도와 가격 알림 임계값")
        // 到价提醒阈值非法输入提示
        case "gold_alert_invalid": return l(currentLang, en: "Threshold must be a number greater than 0", zh: "阈值需为大于 0 的数字", ja: "しきい値は 0 より大きい数値を入力してください", ko: "임계값은 0보다 큰 숫자여야 합니다")
        case "gold_alert_inverted": return l(currentLang, en: "Upper limit must be higher than lower limit", zh: "上限价需高于下限价", ja: "上限価格は下限価格より高くしてください", ko: "상한 가격은 하한 가격보다 높아야 합니다")
        case "notification_permission_denied": return l(currentLang, en: "System notifications are disabled. Enable them in System Settings → Notifications.", zh: "系统通知权限未开启，提醒无法送达。可在 系统设置 → 通知 中开启", ja: "システム通知がオフのため通知を届けられません。システム設定 → 通知 で有効にしてください", ko: "시스템 알림이 꺼져 있어 알림을 받을 수 없습니다. 시스템 설정 → 알림에서 켜주세요")
        case "refresh_every": return l(currentLang, en: "Refresh Every", zh: "刷新间隔", ja: "更新間隔", ko: "새로 고침 간격")
        case "gold_auto_calibration": return l(currentLang, en: "Auto Calibration", zh: "预测自动校准", ja: "予測自動補正", ko: "예측 자동 보정")
        case "gold_auto_calibration_note": return l(currentLang, en: "Adjust confidence and position by historical hit rate. When off, results are observed only.", zh: "根据历史预测命中率自动调整信心和建议仓位；关闭后只展示观察结果，不参与调参。", ja: "履歴的中率に基づき信頼度とポジションを自動調整します。オフにすると観察のみ行います。", ko: "과거 적중률에 따라 신뢰도와 포지션을 자동 조정합니다. 끄면 관찰만 합니다.")
        case "gold_alert": return l(currentLang, en: "Price Alert", zh: "到价提醒", ja: "価格アラート", ko: "가격 알림")
        case "gold_alert_upper": return l(currentLang, en: "Upper Limit (¥/g)", zh: "上限价（元/克）", ja: "上限価格（元/g）", ko: "상한 가격 (위안/g)")
        case "gold_alert_lower": return l(currentLang, en: "Lower Limit (¥/g)", zh: "下限价（元/克）", ja: "下限価格（元/g）", ko: "하한 가격 (위안/g)")
        case "gold_alert_note": return l(currentLang, en: "Sends a system notification when the price crosses a limit. Re-arms after the price moves back inside.", zh: "金价触达上限或下限时发系统通知；价格回到区间内后会重新监控，避免反复提醒。", ja: "価格が上限・下限に達すると通知します。区間内に戻ると再監視します。", ko: "가격이 상한/하한에 도달하면 알림을 보냅니다. 구간 안으로 돌아오면 다시 감시합니다.")
        case "english_voice": return l(currentLang, en: "English Voice", zh: "英语语音", ja: "英語音声", ko: "영어 음성")
        case "english_voice_desc": return l(currentLang, en: "Choose an accent, installed system voice and speaking speed", zh: "选择口音、系统语音和朗读速度", ja: "アクセント、インストール済みの音声、読み上げ速度を選択", ko: "억양, 설치된 시스템 음성과 말하기 속도 선택")
        case "continuous_learning": return l(currentLang, en: "Continuous Learning", zh: "连续学习", ja: "連続学習", ko: "연속 학습")
        case "continuous_learning_desc": return l(currentLang, en: "Control repetition, pauses and menu bar presentation", zh: "控制重复次数、切换间隔和菜单栏展示", ja: "繰り返し、間隔、メニューバー表示を管理", ko: "반복, 간격과 메뉴 막대 표시 관리")
        case "learning_plan": return l(currentLang, en: "Learning Plan", zh: "学习计划", ja: "学習プラン", ko: "학습 계획")
        case "learning_plan_desc": return l(currentLang, en: "Set a manageable daily goal and translation assistance", zh: "设置适合自己的每日目标和中文辅助", ja: "毎日の目標と翻訳サポートを設定", ko: "일일 목표와 번역 지원 설정")
        case "kokoro_command": return l(currentLang, en: "Kokoro Command", zh: "Kokoro 命令", ja: "Kokoro コマンド", ko: "Kokoro 명령")
        case "kokoro_voice": return l(currentLang, en: "Kokoro Voice", zh: "Kokoro 音色", ja: "Kokoro 音声", ko: "Kokoro 음성")
        case "data_backup": return l(currentLang, en: "Data Backup & Migration", zh: "数据备份与迁移", ja: "データのバックアップと移行", ko: "데이터 백업 및 마이그레이션")
        case "data_backup_desc": return l(currentLang, en: "Export all data for backup or transfer to another Mac", zh: "导出全部数据用于备份或迁移到另一台 Mac", ja: "バックアップまたは別の Mac への移行用に全データをエクスポート", ko: "백업 또는 다른 Mac으로 이동하기 위해 모든 데이터 내보내기")
        case "export_success": return l(currentLang, en: "Export successful!", zh: "导出成功！", ja: "エクスポートしました！", ko: "내보내기 완료!")
        case "export": return l(currentLang, en: "Export", zh: "导出数据", ja: "エクスポート", ko: "내보내기")
        case "import_success": return l(currentLang, en: "Import successful!", zh: "导入成功！", ja: "インポートしました！", ko: "가져오기 완료!")
        case "import_data": return l(currentLang, en: "Import", zh: "导入数据", ja: "インポート", ko: "가져오기")
        case "data_backup_note": return l(currentLang, en: "Exports birthdays, English progress, gold price history, novel bookmarks and app settings as a single file.", zh: "导出包含生日、英语学习进度、金价历史、小说书签和应用设置。导入时采用合并模式，不会覆盖已有数据。", ja: "誕生日、英語学習の進捗、金価格履歴、小説のしおり、アプリ設定を1つのファイルにエクスポートします。インポートは統合モードで、既存データを上書きしません。", ko: "생일, 영어 학습 진행도, 금 가격 기록, 소설 책갈피와 앱 설정을 하나의 파일로 내보냅니다. 가져오기는 병합 방식이며 기존 데이터를 덮어쓰지 않습니다.")
        case "app_updates": return l(currentLang, en: "App Updates", zh: "应用更新", ja: "アプリの更新", ko: "앱 업데이트")
        case "app_updates_desc": return l(currentLang, en: "Check for the latest version from GitHub", zh: "从 GitHub 检查最新版本", ja: "GitHub で最新バージョンを確認", ko: "GitHub에서 최신 버전 확인")
        case "available": return l(currentLang, en: "available", zh: "可用", ja: "利用可能", ko: "사용 가능")
        case "up_to_date": return l(currentLang, en: "is up to date", zh: "已是最新", ja: "は最新です", ko: "최신 상태입니다")
        case "last_checked": return l(currentLang, en: "Last checked:", zh: "上次检查：", ja: "最終確認：", ko: "마지막 확인:")
        case "checking": return l(currentLang, en: "Checking...", zh: "检查中...", ja: "確認中...", ko: "확인 중...")
        case "check_now": return l(currentLang, en: "Check Now", zh: "立即检查", ja: "今すぐ確認", ko: "지금 확인")
        case "download_page": return l(currentLang, en: "Go to download page", zh: "前往下载页面", ja: "ダウンロードページへ", ko: "다운로드 페이지로 이동")
        default: return key
        }
    }

    // MARK: - 监控模块

    static func monitor(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "cpu": return "CPU"
        case "memory": return l(currentLang, en: "Memory", zh: "内存", ja: "メモリ", ko: "메모리")
        case "storage": return l(currentLang, en: "Storage", zh: "储存", ja: "ストレージ", ko: "저장 공간")
        case "battery": return l(currentLang, en: "Battery", zh: "电池", ja: "バッテリー", ko: "배터리")
        case "network": return l(currentLang, en: "Network", zh: "网络", ja: "ネットワーク", ko: "네트워크")
        case "uptime": return l(currentLang, en: "Uptime", zh: "运行时间", ja: "稼働時間", ko: "가동 시간")
        case "temperature": return l(currentLang, en: "Temperature", zh: "温度", ja: "温度", ko: "온도")
        case "device_status": return l(currentLang, en: "Device status", zh: "设备状态", ja: "デバイス状態", ko: "기기 상태")
        case "live": return l(currentLang, en: "Live monitoring", zh: "实时监控", ja: "リアルタイム監視", ko: "실시간 모니터링")
        case "status_normal": return l(currentLang, en: "Normal", zh: "运行正常", ja: "正常", ko: "정상")
        case "status_elevated": return l(currentLang, en: "Elevated load", zh: "负载偏高", ja: "負荷上昇", ko: "부하 높음")
        case "status_attention": return l(currentLang, en: "Needs attention", zh: "需要关注", ja: "要確認", ko: "확인 필요")
        case "cores_unit": return l(currentLang, en: "cores", zh: "核", ja: "コア", ko: "코어")
        case "sensors": return l(currentLang, en: "sensors", zh: "传感器", ja: "センサー", ko: "센서")
        case "unavailable": return l(currentLang, en: "Unavailable", zh: "不可用", ja: "利用不可", ko: "사용 불가")
        case "temperature_unavailable": return l(currentLang, en: "Temperature sensors are unavailable on this device", zh: "当前设备无法读取温度传感器", ja: "このデバイスでは温度センサーを読み取れません", ko: "이 기기에서는 온도 센서를 읽을 수 없습니다")
        case "thermal_normal": return l(currentLang, en: "Thermals normal", zh: "温度正常", ja: "温度正常", ko: "온도 정상")
        case "thermal_warm": return l(currentLang, en: "Running warm", zh: "温度偏高", ja: "温度やや高め", ko: "온도 다소 높음")
        case "thermal_hot": return l(currentLang, en: "Running hot", zh: "温度过高", ja: "高温", ko: "온도 높음")
        case "expand_hint": return l(currentLang, en: "Show details", zh: "展开详情", ja: "詳細を表示", ko: "세부 정보 보기")
        case "collapse_hint": return l(currentLang, en: "Hide details", zh: "收起详情", ja: "詳細を閉じる", ko: "세부 정보 닫기")
        case "no_modules": return l(currentLang, en: "No monitor modules", zh: "未启用监控模块", ja: "監視モジュールなし", ko: "모니터링 모듈 없음")
        case "no_modules_hint": return l(currentLang, en: "Enable modules in Settings", zh: "请在设置中启用需要的模块", ja: "設定でモジュールを有効にしてください", ko: "설정에서 모듈을 활성화하세요")
        case "core_count": return l(currentLang, en: "Cores", zh: "核心数", ja: "コア数", ko: "코어 수")
        case "cpu_temp": return l(currentLang, en: "CPU Temp", zh: "CPU 温度", ja: "CPU 温度", ko: "CPU 온도")
        case "gpu_temp": return l(currentLang, en: "GPU Temp", zh: "GPU 温度", ja: "GPU 温度", ko: "GPU 온도")
        case "used": return l(currentLang, en: "Used", zh: "已用", ja: "使用済み", ko: "사용됨")
        case "total": return l(currentLang, en: "Total", zh: "总量", ja: "合計", ko: "전체")
        case "available": return l(currentLang, en: "Available", zh: "可用", ja: "利用可能", ko: "사용 가능")
        case "pressure": return l(currentLang, en: "Pressure", zh: "压力", ja: "負荷", ko: "압력")
        case "status": return l(currentLang, en: "Status", zh: "状态", ja: "状態", ko: "상태")
        case "low_power": return l(currentLang, en: "Low Power", zh: "低电量模式", ja: "低電力モード", ko: "저전력 모드")
        case "local_ip": return l(currentLang, en: "Local IP", zh: "本地 IP", ja: "ローカル IP", ko: "로컬 IP")
        case "interfaces": return l(currentLang, en: "Interfaces", zh: "接口", ja: "インターフェイス", ko: "인터페이스")
        case "download": return l(currentLang, en: "Download", zh: "下载", ja: "ダウンロード", ko: "다운로드")
        case "upload": return l(currentLang, en: "Upload", zh: "上传", ja: "アップロード", ko: "업로드")
        case "running_time": return l(currentLang, en: "Running", zh: "已运行", ja: "稼働中", ko: "실행 중")
        case "connected": return l(currentLang, en: "Connected", zh: "已连接", ja: "接続済み", ko: "연결됨")
        case "disconnected": return l(currentLang, en: "Disconnected", zh: "未连接", ja: "未接続", ko: "연결 안 됨")
        default: return key
        }
    }

    // MARK: - 菜单栏

    static func menuBar(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "gold_price": return l(currentLang, en: "Gold Price", zh: "金价", ja: "金価格", ko: "금 가격")
        case "date": return l(currentLang, en: "Date", zh: "日期", ja: "日付", ko: "날짜")
        case "settings": return l(currentLang, en: "Settings", zh: "设置", ja: "設定", ko: "설정")
        case "quit": return l(currentLang, en: "Quit", zh: "退出程序", ja: "終了", ko: "종료")
        case "open_coolrun": return l(currentLang, en: "Open coolRun", zh: "打开 coolRun", ja: "coolRun を開く", ko: "coolRun 열기")
        case "display_mode": return l(currentLang, en: "Menu Bar Display", zh: "菜单栏显示", ja: "メニューバー表示", ko: "메뉴 막대 표시")
        case "start_english": return l(currentLang, en: "Start English listening", zh: "开始英语听读", ja: "英語の聞き読みを開始", ko: "영어 듣기 시작")
        case "pause_english": return l(currentLang, en: "Pause English listening", zh: "暂停英语听读", ja: "英語の聞き読みを一時停止", ko: "영어 듣기 일시 정지")
        case "resume_english": return l(currentLang, en: "Resume English listening", zh: "继续英语听读", ja: "英語の聞き読みを再開", ko: "영어 듣기 계속")
        default: return key
        }
    }

    // MARK: - 电池状态

    static func batteryState(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "unknown": return l(currentLang, en: "Unknown", zh: "未知", ja: "不明", ko: "알 수 없음")
        case "unplugged": return l(currentLang, en: "Battery", zh: "电池供电", ja: "バッテリー駆動", ko: "배터리 사용")
        case "charging": return l(currentLang, en: "Charging", zh: "充电中", ja: "充電中", ko: "충전 중")
        case "full": return l(currentLang, en: "Full", zh: "已充满", ja: "満充電", ko: "완전 충전")
        case "no_battery": return l(currentLang, en: "No Battery", zh: "无电池", ja: "バッテリーなし", ko: "배터리 없음")
        default: return key
        }
    }

    // MARK: - 内存压力

    static func memoryPressure(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "low": return l(currentLang, en: "Low", zh: "轻", ja: "低", ko: "낮음")
        case "medium": return l(currentLang, en: "Medium", zh: "中", ja: "中", ko: "보통")
        case "high": return l(currentLang, en: "High", zh: "高", ja: "高", ko: "높음")
        default: return key
        }
    }

    // MARK: - 通用标签

    static func label(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "copy_hint": return l(currentLang, en: "Click to copy", zh: "点击复制", ja: "クリックしてコピー", ko: "클릭하여 복사")
        case "on": return l(currentLang, en: "On", zh: "开启", ja: "オン", ko: "켜짐")
        case "off": return l(currentLang, en: "Off", zh: "关闭", ja: "オフ", ko: "꺼짐")
        case "enabled": return l(currentLang, en: "Enabled", zh: "已启用", ja: "有効", ko: "활성화됨")
        case "disabled": return l(currentLang, en: "Disabled", zh: "已禁用", ja: "無効", ko: "비활성화됨")
        default: return key
        }
    }

    // MARK: - 日历

    static func calendar(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "monitor": return l(currentLang, en: "Monitor", zh: "监控", ja: "モニター", ko: "모니터")
        case "calendar": return l(currentLang, en: "Calendar", zh: "日历", ja: "カレンダー", ko: "달력")
        case "birthday": return l(currentLang, en: "Birthday", zh: "生日", ja: "誕生日", ko: "생일")
        case "birthday_manage": return l(currentLang, en: "Birthday Manage", zh: "生日管理", ja: "誕生日管理", ko: "생일 관리")
        case "add_birthday": return l(currentLang, en: "Add Birthday", zh: "添加生日", ja: "誕生日を追加", ko: "생일 추가")
        case "edit_birthday": return l(currentLang, en: "Edit Birthday", zh: "编辑生日", ja: "誕生日を編集", ko: "생일 편집")
        case "name": return l(currentLang, en: "Name", zh: "姓名", ja: "名前", ko: "이름")
        case "lunar_birthday": return l(currentLang, en: "Lunar Birthday", zh: "农历生日", ja: "旧暦の誕生日", ko: "음력 생일")
        case "leap_month": return l(currentLang, en: "Leap Month", zh: "闰月", ja: "閏月", ko: "윤달")
        case "note": return l(currentLang, en: "Note", zh: "备注", ja: "メモ", ko: "메모")
        case "note_placeholder": return l(currentLang, en: "e.g.: Mom, Friend", zh: "如：妈妈、朋友", ja: "例：母、友人", ko: "예: 엄마, 친구")
        case "select_year_month": return l(currentLang, en: "Select Year/Month", zh: "选择年月", ja: "年月を選択", ko: "연/월 선택")
        case "today": return l(currentLang, en: "Today", zh: "今天", ja: "今日", ko: "오늘")
        case "zodiac": return l(currentLang, en: "Zodiac", zh: "生肖", ja: "干支", ko: "띠")
        case "solar_term": return l(currentLang, en: "Solar Term", zh: "节气", ja: "二十四節気", ko: "절기")
        case "festival": return l(currentLang, en: "Festival", zh: "节日", ja: "祝日", ko: "명절")
        case "year": return l(currentLang, en: "Year", zh: "年份", ja: "年", ko: "연도")
        case "month": return l(currentLang, en: "Month", zh: "月份", ja: "月", ko: "월")
        case "date": return l(currentLang, en: "Date", zh: "日期", ja: "日付", ko: "날짜")
        case "holiday": return l(currentLang, en: "Off", zh: "休", ja: "休", ko: "휴")
        case "workday": return l(currentLang, en: "Work", zh: "班", ja: "出", ko: "근")
        case "lunar": return l(currentLang, en: "Lunar", zh: "农历", ja: "旧暦", ko: "음력")
        case "empty_birthday": return l(currentLang, en: "No birthdays recorded", zh: "还没有记录生日", ja: "誕生日はまだ登録されていません", ko: "등록된 생일이 없습니다")
        case "add_first_birthday": return l(currentLang, en: "Add your first birthday below", zh: "点击下方按钮添加第一个生日", ja: "下のボタンから最初の誕生日を追加", ko: "아래 버튼으로 첫 생일을 추가하세요")
        case "birthday_reminder": return l(currentLang, en: "Birthday Reminder", zh: "生日提醒", ja: "誕生日リマインダー", ko: "생일 알림")
        case "got_it": return l(currentLang, en: "Got it", zh: "知道了", ja: "了解", ko: "알겠습니다")
        case "select_year_month_help": return l(currentLang, en: "Click to select year/month", zh: "点击选择年月", ja: "クリックして年月を選択", ko: "클릭하여 연/월 선택")
        case "unnamed": return l(currentLang, en: "Unnamed", zh: "未命名", ja: "名称未設定", ko: "이름 없음")
        case "preview": return l(currentLang, en: "Preview", zh: "预览", ja: "プレビュー", ko: "미리보기")
        case "and_more": return l(currentLang, en: " etc.", zh: "等", ja: " ほか", ko: " 등")
        default: return key
        }
    }

    // MARK: - 数据管理

    static func data(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "holiday_data": return l(currentLang, en: "Holiday Data", zh: "节假日数据", ja: "祝日データ", ko: "공휴일 데이터")
        case "holiday_data_desc": return l(currentLang, en: "Manage holiday and workday arrangements", zh: "管理节假日和调休安排数据", ja: "祝日と振替出勤日のデータを管理", ko: "공휴일 및 대체 근무일 데이터 관리")
        case "data_version": return l(currentLang, en: "Data Version", zh: "数据版本", ja: "データバージョン", ko: "데이터 버전")
        case "record_count": return l(currentLang, en: "Records", zh: "条记录", ja: "件", ko: "개 기록")
        case "last_update": return l(currentLang, en: "Last Update", zh: "最后更新", ja: "最終更新", ko: "마지막 업데이트")
        case "update_data": return l(currentLang, en: "Update Data", zh: "更新数据", ja: "データを更新", ko: "데이터 업데이트")
        case "updating": return l(currentLang, en: "Updating...", zh: "更新中...", ja: "更新中...", ko: "업데이트 중...")
        case "update_success": return l(currentLang, en: "Data updated to latest version!", zh: "数据已更新到最新版本！", ja: "データを最新バージョンに更新しました！", ko: "데이터가 최신 버전으로 업데이트되었습니다!")
        case "update_failed": return l(currentLang, en: "Update failed", zh: "更新失败", ja: "更新に失敗しました", ko: "업데이트 실패")
        case "data_note": return l(currentLang, en: "Data Note", zh: "数据说明", ja: "データ説明", ko: "데이터 안내")
        case "data_note_content": return l(currentLang, en: "• Includes 2024-2026 statutory holidays\n• Includes workday arrangements\n• Data from State Council Office", zh: "• 包含2024-2026年法定节假日\n• 包含调休工作日安排\n• 数据来源于国务院办公厅通知", ja: "• 2024-2026年の法定祝日を含む\n• 振替出勤日を含む\n• データ元：国務院弁公庁通知", ko: "• 2024-2026년 법정 공휴일 포함\n• 대체 근무일 포함\n• 데이터 출처: 국무원 판공청 공지")
        default: return key
        }
    }

    // MARK: - 金价

    static func goldPrice(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "gold_price": return l(currentLang, en: "Gold", zh: "金价", ja: "金", ko: "금")
        case "loading": return l(currentLang, en: "Loading...", zh: "--", ja: "読み込み中...", ko: "불러오는 중...")
        case "rate_limited": return l(currentLang, en: "Rate Limited", zh: "限频", ja: "制限中", ko: "요청 제한")
        case "network_error": return l(currentLang, en: "Network Error", zh: "网络失败", ja: "ネットワークエラー", ko: "네트워크 오류")
        case "parse_error": return l(currentLang, en: "Parse Error", zh: "解析失败", ja: "解析エラー", ko: "파싱 오류")
        default: return key
        }
    }

    // MARK: - 金价分析

    /// 把数据时效秒数格式化为“X小时Y分前 / X分Y秒前 / X秒前”，避免出现七万多秒这种可读性差的显示。
    static func goldAge(_ seconds: TimeInterval, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        let total = max(Int(seconds), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return l(
                currentLang,
                en: "\(hours)h \(minutes)m ago",
                zh: "\(hours)小时\(minutes)分前",
                ja: "\(hours)時間\(minutes)分前",
                ko: "\(hours)시간 \(minutes)분 전"
            )
        }
        if minutes > 0 {
            return l(
                currentLang,
                en: "\(minutes)m \(secs)s ago",
                zh: "\(minutes)分\(secs)秒前",
                ja: "\(minutes)分\(secs)秒前",
                ko: "\(minutes)분 \(secs)초 전"
            )
        }
        return l(
            currentLang,
            en: "\(secs)s ago",
            zh: "\(secs)秒前",
            ja: "\(secs)秒前",
            ko: "\(secs)초 전"
        )
    }

    static func gold(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        // CandlePeriod
        case "5min": return l(currentLang, en: "5min", zh: "5分钟", ja: "5分", ko: "5분")
        case "15min": return l(currentLang, en: "15min", zh: "15分钟", ja: "15分", ko: "15분")
        case "1hour": return l(currentLang, en: "1H", zh: "1小时", ja: "1時間", ko: "1시간")
        case "1day": return l(currentLang, en: "Daily", zh: "日线", ja: "日足", ko: "일봉")
        // RSIState
        case "warming_up": return l(currentLang, en: "Warming Up", zh: "积累中", ja: "準備中", ko: "데이터 축적 중")
        case "extremely_oversold": return l(currentLang, en: "Extremely Oversold", zh: "极度超卖", ja: "極端な売られ過ぎ", ko: "극단적 과매도")
        case "oversold": return l(currentLang, en: "Oversold", zh: "超卖", ja: "売られ過ぎ", ko: "과매도")
        case "neutral": return l(currentLang, en: "Neutral", zh: "中性", ja: "中立", ko: "중립")
        case "overbought": return l(currentLang, en: "Overbought", zh: "超买", ja: "買われ過ぎ", ko: "과매수")
        case "extremely_overbought": return l(currentLang, en: "Extremely Overbought", zh: "极度超买", ja: "極端な買われ過ぎ", ko: "극단적 과매수")
        // MACDState
        case "bullish_strong": return l(currentLang, en: "Strong Bullish", zh: "强势看多", ja: "強い強気", ko: "강한 상승")
        case "bullish": return l(currentLang, en: "Bullish", zh: "看多", ja: "強気", ko: "상승")
        case "bearish": return l(currentLang, en: "Bearish", zh: "看空", ja: "弱気", ko: "하락")
        case "bearish_strong": return l(currentLang, en: "Strong Bearish", zh: "强势看空", ja: "強い弱気", ko: "강한 하락")
        // SignalDirection
        case "buy": return l(currentLang, en: "Bullish", zh: "偏多", ja: "強気寄り", ko: "상승 우세")
        case "sell": return l(currentLang, en: "Bearish", zh: "偏空", ja: "弱気寄り", ko: "하락 우세")
        case "hold": return l(currentLang, en: "Hold", zh: "观望", ja: "様子見", ko: "관망")
        // SignalStrength
        case "strong": return l(currentLang, en: "Strong", zh: "强", ja: "強", ko: "강함")
        case "medium": return l(currentLang, en: "Medium", zh: "中", ja: "中", ko: "보통")
        case "weak": return l(currentLang, en: "Weak", zh: "弱", ja: "弱", ko: "약함")
        // PriceStatistics
        case "strong_up": return l(currentLang, en: "Strong Rally", zh: "强势上涨", ja: "強い上昇", ko: "강한 상승")
        case "mild_up": return l(currentLang, en: "Mild Rally", zh: "温和上涨", ja: "緩やかな上昇", ko: "완만한 상승")
        case "strong_down": return l(currentLang, en: "Strong Decline", zh: "强势下跌", ja: "強い下落", ko: "강한 하락")
        case "mild_down": return l(currentLang, en: "Mild Decline", zh: "温和下跌", ja: "緩やかな下落", ko: "완만한 하락")
        case "sideways": return l(currentLang, en: "Sideways", zh: "横盘整理", ja: "横ばい", ko: "횡보")
        // MarketRegime
        case "strong_uptrend": return l(currentLang, en: "Strong Uptrend", zh: "强势上涨", ja: "強い上昇トレンド", ko: "강한 상승 추세")
        case "weak_uptrend": return l(currentLang, en: "Mild Uptrend", zh: "温和上涨", ja: "緩やかな上昇トレンド", ko: "완만한 상승 추세")
        case "ranging": return l(currentLang, en: "Ranging", zh: "震荡整理", ja: "レンジ相場", ko: "박스권")
        case "weak_downtrend": return l(currentLang, en: "Mild Downtrend", zh: "温和下跌", ja: "緩やかな下落トレンド", ko: "완만한 하락 추세")
        case "strong_downtrend": return l(currentLang, en: "Strong Downtrend", zh: "强势下跌", ja: "強い下落トレンド", ko: "강한 하락 추세")
        // MarketRegime strategyLabel
        case "trend_follow": return l(currentLang, en: "Trend Following", zh: "趋势跟随", ja: "トレンドフォロー", ko: "추세 추종")
        case "mean_reversion": return l(currentLang, en: "Mean Reversion / Grid", zh: "均值回归/网格观察", ja: "平均回帰/グリッド観察", ko: "평균회귀/그리드 관찰")
        case "defensive": return l(currentLang, en: "Defensive Watch", zh: "防守观察", ja: "防御的に様子見", ko: "방어적 관찰")
        // VolatilityRegime
        case "vol_low": return l(currentLang, en: "Low Volatility", zh: "低波动", ja: "低ボラティリティ", ko: "낮은 변동성")
        case "vol_normal": return l(currentLang, en: "Normal Volatility", zh: "正常波动", ja: "通常ボラティリティ", ko: "보통 변동성")
        case "vol_high": return l(currentLang, en: "High Volatility", zh: "高波动", ja: "高ボラティリティ", ko: "높은 변동성")
        case "vol_extreme": return l(currentLang, en: "Extreme Volatility", zh: "极端波动", ja: "極端なボラティリティ", ko: "극단적 변동성")
        case "volatility": return l(currentLang, en: "Volatility", zh: "波动", ja: "変動率", ko: "변동성")
        // UI labels
        case "high": return l(currentLang, en: "H", zh: "高", ja: "高", ko: "고")
        case "low": return l(currentLang, en: "L", zh: "低", ja: "安", ko: "저")
        case "avg": return l(currentLang, en: "Avg", zh: "均", ja: "平均", ko: "평균")
        case "sma": return l(currentLang, en: "MA", zh: "均线", ja: "移動平均", ko: "이동평균")
        case "annualized": return l(currentLang, en: "Ann.", zh: "年化", ja: "年率", ko: "연율")
        case "records": return l(currentLang, en: "records", zh: "条", ja: "件", ko: "개")
        case "waiting_candle": return l(currentLang, en: "Waiting for K-line", zh: "等待生成 K 线", ja: "Kライン生成待ち", ko: "K선 생성 대기")
        case "generating_analysis": return l(currentLang, en: "Generating gold analysis", zh: "正在生成金价分析", ja: "金価格分析を生成中", ko: "금 가격 분석 생성 중")
        case "analysis_hint": return l(currentLang, en: "Chart and strategy will appear automatically.", zh: "先切换进来，策略和图表稍后自动出现。", ja: "チャートと戦略は自動で表示されます。", ko: "차트와 전략이 자동으로 표시됩니다.")
        case "waiting_refresh": return l(currentLang, en: "Waiting for next price refresh", zh: "等待下一次金价刷新", ja: "次の金価格更新を待機中", ko: "다음 금 가격 새로 고침 대기")
        case "refresh_hint": return l(currentLang, en: "Recording and analysis will begin after data arrives.", zh: "获取到价格后会自动开始记录历史和生成分析。", ja: "価格データ取得後、履歴記録と分析を開始します。", ko: "가격 데이터가 도착하면 기록과 분석을 시작합니다.")
        case "beginner_conclusion": return l(currentLang, en: "Summary", zh: "新手结论", ja: "要約", ko: "요약")
        case "confidence": return l(currentLang, en: "confidence", zh: "把握", ja: "信頼度", ko: "신뢰도")
        case "suggested_position": return l(currentLang, en: "Position", zh: "建议仓位", ja: "推奨ポジション", ko: "권장 포지션")
        case "source_name": return l(currentLang, en: "ZheShang Gold", zh: "浙商积存金", ja: "浙商ゴールド", ko: "저상 골드")
        case "analysis_tab": return l(currentLang, en: "Gold Analysis", zh: "金价分析", ja: "金価格分析", ko: "금 가격 분석")
        case "review_tab": return l(currentLang, en: "Prediction Review", zh: "预测复盘", ja: "予測レビュー", ko: "예측 복기")
        case "seconds_ago_format": return l(currentLang, en: "%d seconds ago", zh: "%d秒前", ja: "%d秒前", ko: "%d초 전")
        case "refresh_interval_format": return l(currentLang, en: "Interval %@s", zh: "间隔 %@s", ja: "間隔 %@秒", ko: "간격 %@초")
        case "cost": return l(currentLang, en: "Cost", zh: "成本", ja: "コスト", ko: "원가")
        case "market_value": return l(currentLang, en: "Value", zh: "现值", ja: "評価額", ko: "현재 가치")
        case "profit": return l(currentLang, en: "Profit", zh: "赚了", ja: "利益", ko: "수익")
        case "loss": return l(currentLang, en: "Loss", zh: "亏了", ja: "損失", ko: "손실")
        case "check_input": return l(currentLang, en: "Check input", zh: "检查输入", ja: "入力を確認", ko: "입력 확인")
        case "not_filled": return l(currentLang, en: "Not filled", zh: "未填写", ja: "未入力", ko: "미입력")
        case "floating_profit": return l(currentLang, en: "Floating profit", zh: "浮盈", ja: "含み益", ko: "평가 이익")
        case "floating_loss": return l(currentLang, en: "Floating loss", zh: "浮亏", ja: "含み損", ko: "평가 손실")
        case "break_even": return l(currentLang, en: "Break-even", zh: "持平", ja: "損益なし", ko: "손익 없음")
        case "my_gold": return l(currentLang, en: "My Gold", zh: "我的黄金", ja: "保有ゴールド", ko: "내 금")
        case "holding_grams": return l(currentLang, en: "Holding grams", zh: "持有克数", ja: "保有グラム数", ko: "보유 그램")
        case "average_cost": return l(currentLang, en: "Average cost", zh: "买入均价", ja: "平均購入価格", ko: "평균 매수가")
        case "example_grams": return l(currentLang, en: "e.g. 12.5", zh: "如 12.5", ja: "例 12.5", ko: "예: 12.5")
        case "example_price": return l(currentLang, en: "e.g. 580", zh: "如 580", ja: "例 580", ko: "예: 580")
        case "position_input_invalid": return l(currentLang, en: "Enter grams and average cost greater than 0. Profit and loss will be calculated from the current gold price.", zh: "请输入大于 0 的克数和买入均价，系统会按当前金价计算盈亏。", ja: "0より大きいグラム数と平均購入価格を入力してください。現在の金価格で損益を計算します。", ko: "0보다 큰 그램 수와 평균 매수가를 입력하세요. 현재 금 가격으로 손익을 계산합니다.")
        case "position_input_hint": return l(currentLang, en: "Enter how many grams you hold and your average purchase price to see personalized position guidance.", zh: "填入你现在持有多少克、平均多少钱买入，就能看到专属持仓建议。", ja: "保有グラム数と平均購入価格を入力すると、あなた向けのポジション提案を表示します。", ko: "보유 그램 수와 평균 매수가를 입력하면 맞춤 포지션 제안을 볼 수 있습니다.")
        case "entry": return l(currentLang, en: "Entry", zh: "入场", ja: "エントリー", ko: "진입")
        case "stop_loss": return l(currentLang, en: "Stop", zh: "止损", ja: "損切り", ko: "손절")
        case "take_profit": return l(currentLang, en: "Target", zh: "止盈", ja: "利確", ko: "익절")
        case "evidence": return l(currentLang, en: "Evidence", zh: "判断依据", ja: "判断材料", ko: "판단 근거")
        case "reference_notice": return l(currentLang, en: "This analysis is based only on current data and rule logic. It is not investment advice. Please decide based on your own capital plan and risk tolerance.", zh: "以上内容仅基于当前数据和规则逻辑分析，不构成投资建议。请结合自身资金安排和风险承受能力自行判断。", ja: "この分析は現在のデータとルールに基づくもので、投資助言ではありません。資金計画とリスク許容度に合わせて判断してください。", ko: "이 분석은 현재 데이터와 규칙 로직에 기반한 것이며 투자 조언이 아닙니다. 자금 계획과 위험 감내 수준에 맞춰 판단하세요.")
        case "trend_strength": return l(currentLang, en: "Trend strength", zh: "趋势强度", ja: "トレンド強度", ko: "추세 강도")
        case "trend_stickiness": return l(currentLang, en: "Trend persistence", zh: "趋势黏性", ja: "トレンド持続性", ko: "추세 지속성")
        case "technical_score": return l(currentLang, en: "Technical score", zh: "技术机会分", ja: "テクニカル機会スコア", ko: "기술 기회 점수")
        case "mean_reversion_label": return l(currentLang, en: "Mean reversion", zh: "均值回归", ja: "平均回帰", ko: "평균회귀")
        case "simulation_steps": return l(currentLang, en: "7-step simulation", zh: "7步模拟", ja: "7ステップシミュレーション", ko: "7단계 시뮬레이션")
        case "grid_fit": return l(currentLang, en: "Grid fit", zh: "网格适配", ja: "グリッド適合", ko: "그리드 적합")
        case "grid_caution": return l(currentLang, en: "Grid caution", zh: "网格谨慎", ja: "グリッド慎重", ko: "그리드 주의")
        case "macro_news_analysis": return l(currentLang, en: "Macro News Analysis", zh: "宏观新闻分析", ja: "マクロニュース分析", ko: "매크로 뉴스 분석")
        case "macro": return l(currentLang, en: "Macro", zh: "宏观", ja: "マクロ", ko: "매크로")
        case "news": return l(currentLang, en: "News", zh: "新闻", ja: "ニュース", ko: "뉴스")
        case "items_count_format": return l(currentLang, en: "%d items", zh: "%d条", ja: "%d件", ko: "%d개")
        case "macro_loading": return l(currentLang, en: "Reading news and U.S. 10Y yield...", zh: "正在读取新闻和美债收益率...", ja: "ニュースと米10年債利回りを読み込み中...", ko: "뉴스와 미국 10년물 금리를 읽는 중...")
        case "macro_unavailable": return l(currentLang, en: "Macro news is unavailable. The strategy is using technicals and price history for now.", zh: "宏观新闻暂不可用，当前策略先按技术面和价格历史判断。", ja: "マクロニュースは現在利用できません。戦略は当面テクニカルと価格履歴で判断します。", ko: "매크로 뉴스는 현재 사용할 수 없습니다. 지금은 기술 지표와 가격 기록으로 판단합니다.")
        case "treasury_10y": return l(currentLang, en: "U.S. 10Y", zh: "美债10Y", ja: "米10年債", ko: "미국 10년물")
        case "cached_data_format": return l(currentLang, en: "Cached data: %@", zh: "缓存数据：%@", ja: "キャッシュデータ：%@", ko: "캐시 데이터: %@")
        case "partial_data_format": return l(currentLang, en: "Partial data: %@", zh: "数据不完整：%@", ja: "データ不足：%@", ko: "일부 데이터: %@")
        case "cached_15min": return l(currentLang, en: "Cached within 15 minutes", zh: "15分钟内缓存数据", ja: "15分以内のキャッシュデータ", ko: "15분 이내 캐시 데이터")
        case "macro_partial": return l(currentLang, en: "Some macro data is unavailable", zh: "部分宏观数据暂不可用", ja: "一部のマクロデータは利用できません", ko: "일부 매크로 데이터를 사용할 수 없습니다")
        case "prediction_learning": return l(currentLang, en: "Prediction Learning", zh: "预测学习", ja: "予測学習", ko: "예측 학습")
        case "validated": return l(currentLang, en: "Validated", zh: "已验证", ja: "検証済み", ko: "검증됨")
        case "pending": return l(currentLang, en: "Pending", zh: "待验证", ja: "検証待ち", ko: "대기 중")
        case "average_error": return l(currentLang, en: "Avg error", zh: "平均误差", ja: "平均誤差", ko: "평균 오차")
        case "bias": return l(currentLang, en: "Bias", zh: "偏差", ja: "バイアス", ko: "편향")
        case "prediction_minus_actual": return l(currentLang, en: "Predicted-actual", zh: "预测-实际", ja: "予測-実績", ko: "예측-실제")
        case "minutes_30": return l(currentLang, en: "30 minutes", zh: "30分钟", ja: "30分", ko: "30분")
        case "pending_count_format": return l(currentLang, en: "Pending %d", zh: "待验证 %d", ja: "検証待ち %d", ko: "대기 %d")
        case "calibration_applied_format": return l(currentLang, en: "Calibration applied: confidence ×%@, position ×%@", zh: "已应用校准：信心 ×%@，仓位 ×%@", ja: "補正を適用：信頼度 ×%@、ポジション ×%@", ko: "보정 적용: 신뢰도 ×%@, 포지션 ×%@")
        case "calibration_reason_format": return l(currentLang, en: "Based on %d validated predictions: hit rate %@, avg bias %@", zh: "调整依据：%d 条已验证预测，方向命中率 %@，平均预测偏差 %@", ja: "調整根拠：検証済み %d 件、的中率 %@、平均バイアス %@", ko: "조정 근거: 검증된 예측 %d건, 적중률 %@, 평균 편향 %@")
        case "calibration_off_note": return l(currentLang, en: "Auto calibration is off. History is observed only and does not change advice.", zh: "自动校准已关闭，历史表现仅观察，不影响建议。", ja: "自動補正はオフです。履歴は観察のみで提案に影響しません。", ko: "자동 보정이 꺼져 있습니다. 기록은 관찰만 되며 제안에 영향을 주지 않습니다.")
        case "calibration_observed_format": return l(currentLang, en: "If enabled would apply: confidence ×%@, position ×%@", zh: "若开启将应用：信心 ×%@，仓位 ×%@", ja: "オンにすると適用：信頼度 ×%@、ポジション ×%@", ko: "켜면 적용됨: 신뢰도 ×%@, 포지션 ×%@")
        case "group_stats": return l(currentLang, en: "Grouped Stats", zh: "分组统计", ja: "グループ統計", ko: "그룹 통계")
        case "by_strategy_version": return l(currentLang, en: "By strategy version", zh: "按策略版本", ja: "戦略バージョン別", ko: "전략 버전별")
        case "by_market_state": return l(currentLang, en: "By market state", zh: "按市场状态", ja: "市場状態別", ko: "시장 상태별")
        case "by_direction": return l(currentLang, en: "By direction", zh: "按预测方向", ja: "予測方向別", ko: "예측 방향별")
        case "hit_rate": return l(currentLang, en: "Hit rate", zh: "命中率", ja: "的中率", ko: "적중률")
        case "validated_count_format": return l(currentLang, en: "Validated %d", zh: "已验证 %d", ja: "検証済み %d", ko: "검증됨 %d")
        case "recent_prediction_review": return l(currentLang, en: "Recent Prediction Review", zh: "最近预测复盘", ja: "最近の予測レビュー", ko: "최근 예측 복기")
        case "actual_return_format": return l(currentLang, en: "Actual %@", zh: "实际 %@", ja: "実績 %@", ko: "실제 %@")
        case "waiting_result_format": return l(currentLang, en: "Waiting 30 min result · %@", zh: "等待 30 分钟结果 · %@", ja: "30分後の結果待ち · %@", ko: "30분 결과 대기 · %@")
        case "review_overview": return l(currentLang, en: "Prediction Learning Overview", zh: "预测学习总览", ja: "予測学習の概要", ko: "예측 학습 개요")
        case "total_predictions": return l(currentLang, en: "Total", zh: "总预测", ja: "総予測", ko: "전체 예측")
        case "prediction_bias": return l(currentLang, en: "Prediction bias", zh: "预测偏差", ja: "予測バイアス", ko: "예측 편향")
        case "filter": return l(currentLang, en: "Filter", zh: "筛选", ja: "フィルター", ko: "필터")
        case "clear": return l(currentLang, en: "Clear", zh: "清除", ja: "クリア", ko: "지우기")
        case "strategy_version": return l(currentLang, en: "Strategy version", zh: "策略版本", ja: "戦略バージョン", ko: "전략 버전")
        case "all_versions": return l(currentLang, en: "All versions", zh: "全部版本", ja: "全バージョン", ko: "전체 버전")
        case "market_state": return l(currentLang, en: "Market state", zh: "市场状态", ja: "市場状態", ko: "시장 상태")
        case "direction": return l(currentLang, en: "Direction", zh: "方向", ja: "方向", ko: "방향")
        case "status": return l(currentLang, en: "Status", zh: "状态", ja: "状態", ko: "상태")
        case "all": return l(currentLang, en: "All", zh: "全部", ja: "すべて", ko: "전체")
        case "hit": return l(currentLang, en: "Hit", zh: "命中", ja: "的中", ko: "적중")
        case "miss": return l(currentLang, en: "Miss", zh: "未命中", ja: "不的中", ko: "실패")
        case "no_prediction_records": return l(currentLang, en: "No prediction records", zh: "暂无预测记录", ja: "予測記録はまだありません", ko: "예측 기록이 없습니다")
        case "no_prediction_hint": return l(currentLang, en: "When the strategy generates buy/sell signals, prediction records will appear here automatically.", zh: "当策略生成买入/卖出信号时，预测记录会自动出现在这里。", ja: "戦略が売買シグナルを生成すると、予測記録がここに自動で表示されます。", ko: "전략이 매수/매도 신호를 만들면 예측 기록이 여기에 자동으로 표시됩니다.")
        case "source_summary": return l(currentLang, en: "Original Evidence Summary", zh: "原始依据摘要", ja: "元の判断材料の要約", ko: "원본 근거 요약")
        case "evidence_snapshot": return l(currentLang, en: "Evidence Snapshot", zh: "证据快照", ja: "判断材料スナップショット", ko: "근거 스냅샷")
        case "technicals": return l(currentLang, en: "Technicals", zh: "技术面", ja: "テクニカル", ko: "기술 지표")
        case "opportunity_score": return l(currentLang, en: "Opportunity", zh: "机会分", ja: "機会スコア", ko: "기회 점수")
        case "predicted_return": return l(currentLang, en: "Predicted return", zh: "预测收益", ja: "予測リターン", ko: "예측 수익률")
        case "macro_score": return l(currentLang, en: "Macro score", zh: "宏观分", ja: "マクロスコア", ko: "매크로 점수")
        case "news_score": return l(currentLang, en: "News score", zh: "新闻分", ja: "ニューススコア", ko: "뉴스 점수")
        case "none": return l(currentLang, en: "None", zh: "无", ja: "なし", ko: "없음")
        case "record_id": return l(currentLang, en: "Record ID", zh: "记录ID", ja: "記録ID", ko: "기록 ID")
        case "confidence_value": return l(currentLang, en: "Confidence", zh: "信心", ja: "信頼度", ko: "신뢰도")
        case "start_price": return l(currentLang, en: "Start price", zh: "开始价格", ja: "開始価格", ko: "시작 가격")
        case "created_at": return l(currentLang, en: "Created at", zh: "建仓时间", ja: "作成日時", ko: "생성 시간")
        case "resolved_at": return l(currentLang, en: "Resolved at", zh: "验证时间", ja: "検証日時", ko: "검증 시간")
        case "data_healthy": return l(currentLang, en: "Data healthy", zh: "数据正常", ja: "データ正常", ko: "데이터 정상")
        case "data_stale_format": return l(currentLang, en: "Data delayed %d seconds", zh: "数据延迟 %d秒", ja: "データ遅延 %d秒", ko: "데이터 지연 %d초")
        case "data_jump_format": return l(currentLang, en: "Price jump %@", zh: "价格跳变 %@", ja: "価格急変 %@", ko: "가격 급변 %@")
        case "data_invalid_format": return l(currentLang, en: "Invalid price ¥%@/g", zh: "价格异常 ¥%@/g", ja: "価格異常 ¥%@/g", ko: "비정상 가격 ¥%@/g")
        case "macro_bullish": return l(currentLang, en: "Macro news bullish", zh: "宏观新闻偏多", ja: "マクロニュースは強気寄り", ko: "매크로 뉴스 상승 우세")
        case "macro_neutral": return l(currentLang, en: "Macro news neutral", zh: "宏观新闻中性", ja: "マクロニュースは中立", ko: "매크로 뉴스 중립")
        case "macro_bearish": return l(currentLang, en: "Macro news bearish", zh: "宏观新闻偏空", ja: "マクロニュースは弱気寄り", ko: "매크로 뉴스 하락 우세")
        case "missing_macro_failed": return l(currentLang, en: "Macro news fetch failed; showing cached data", zh: "本次宏观新闻获取失败，暂显示上次缓存", ja: "マクロニュースの取得に失敗したため、前回のキャッシュを表示しています", ko: "매크로 뉴스 가져오기에 실패해 이전 캐시를 표시합니다")
        case "missing_treasury": return l(currentLang, en: "U.S. 10Y", zh: "美债10Y", ja: "米10年債", ko: "미국 10년물")
        case "missing_news_rss": return l(currentLang, en: "News RSS", zh: "新闻RSS", ja: "ニュースRSS", ko: "뉴스 RSS")
        case "missing_unavailable_format": return l(currentLang, en: "%@ unavailable", zh: "%@暂不可用", ja: "%@は利用できません", ko: "%@ 사용 불가")
        default: return key
        }
    }

    // MARK: - 小说

    static func novel(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "novel": return l(currentLang, en: "Novel", zh: "小说", ja: "小説", ko: "소설")
        case "novel_reader": return l(currentLang, en: "Novel Reader", zh: "小说阅读", ja: "小説リーダー", ko: "소설 리더")
        case "books_count": return l(currentLang, en: "books", zh: "本书", ja: "冊", ko: "권")
        case "chapters_count": return l(currentLang, en: "chapters", zh: "章", ja: "章", ko: "장")
        case "import_novel": return l(currentLang, en: "Import Novel", zh: "导入小说", ja: "小説をインポート", ko: "소설 가져오기")
        case "open_read": return l(currentLang, en: "Open", zh: "打开阅读", ja: "開く", ko: "열기")
        case "delete": return l(currentLang, en: "Delete", zh: "删除", ja: "削除", ko: "삭제")
        case "import_failed": return l(currentLang, en: "Import Failed", zh: "导入失败", ja: "インポートに失敗しました", ko: "가져오기 실패")
        case "confirm_delete": return l(currentLang, en: "Confirm Delete", zh: "确认删除", ja: "削除の確認", ko: "삭제 확인")
        case "delete_warning": return l(currentLang, en: "Are you sure to delete \"", zh: "确定要删除「", ja: "「", ko: "\"")
        case "delete_warning_suffix": return l(currentLang, en: "\"? This cannot be undone.", zh: "」吗？此操作不可恢复。", ja: "」を削除しますか？この操作は元に戻せません。", ko: "\"을(를) 삭제할까요? 이 작업은 되돌릴 수 없습니다.")
        case "empty_library": return l(currentLang, en: "Library is empty", zh: "书架空空如也", ja: "本棚は空です", ko: "책장이 비어 있습니다")
        case "empty_library_hint": return l(currentLang, en: "Import txt novels to track progress, chapters and bookmarks.", zh: "导入 txt 小说后，coolRun 会记住阅读进度、目录和书签。", ja: "txt 小説をインポートすると、進捗・章・しおりを記録できます。", ko: "txt 소설을 가져오면 진행률, 목차, 책갈피를 기록합니다.")
        case "book_not_found": return l(currentLang, en: "Book not found", zh: "书籍不存在", ja: "本が見つかりません", ko: "책을 찾을 수 없습니다")
        case "book_deleted_hint": return l(currentLang, en: "This book may have been deleted.", zh: "这本书可能已经被删除。", ja: "この本は削除された可能性があります。", ko: "이 책은 삭제되었을 수 있습니다.")
        case "no_content": return l(currentLang, en: "No readable content", zh: "没有可阅读的内容", ja: "読める内容がありません", ko: "읽을 수 있는 내용이 없습니다")
        case "no_chapter": return l(currentLang, en: "No chapter", zh: "无章节", ja: "章なし", ko: "챕터 없음")
        case "close": return l(currentLang, en: "Close", zh: "关闭", ja: "閉じる", ko: "닫기")
        case "toc": return l(currentLang, en: "Contents", zh: "目录", ja: "目次", ko: "목차")
        case "bookmark": return l(currentLang, en: "Bookmarks", zh: "书签", ja: "しおり", ko: "책갈피")
        case "add_bookmark": return l(currentLang, en: "Add bookmark", zh: "添加书签", ja: "しおりを追加", ko: "책갈피 추가")
        case "read_aloud": return l(currentLang, en: "Read aloud", zh: "从当前位置朗读", ja: "現在位置から読み上げ", ko: "현재 위치부터 읽기")
        case "reading_settings": return l(currentLang, en: "Reading settings", zh: "阅读设置", ja: "読書設定", ko: "읽기 설정")
        case "prev_chapter": return l(currentLang, en: "Previous", zh: "上一章", ja: "前の章", ko: "이전 장")
        case "next_chapter": return l(currentLang, en: "Next", zh: "下一章", ja: "次の章", ko: "다음 장")
        case "chapter_progress": return l(currentLang, en: "Chapter", zh: "本章", ja: "章", ko: "장")
        case "empty_bookmarks": return l(currentLang, en: "No bookmarks yet", zh: "暂无书签", ja: "しおりはまだありません", ko: "책갈피가 없습니다")
        case "jump": return l(currentLang, en: "Jump", zh: "跳转", ja: "移動", ko: "이동")
        case "unknown_chapter": return l(currentLang, en: "Unknown chapter", zh: "未知章节", ja: "不明な章", ko: "알 수 없는 장")
        case "default_menu_hint": return l(currentLang, en: "Import a txt novel and pin this panel in the menu bar to read while you work.", zh: "导入 txt 小说后，可以把这块固定在菜单栏里边看边工作。", ja: "txt 小説をインポートすると、このパネルをメニューバーに固定して作業中に読めます。", ko: "txt 소설을 가져오면 이 패널을 메뉴 막대에 고정해 작업하면서 읽을 수 있습니다.")
        case "import_txt_help": return l(currentLang, en: "Import txt novel", zh: "导入 txt 小说", ja: "txt 小説をインポート", ko: "txt 소설 가져오기")
        case "chapter_counter_format": return l(currentLang, en: "Chapter %d / %d", zh: "第 %d / %d 章", ja: "第 %d / %d 章", ko: "%d / %d장")
        case "paragraph_counter_format": return l(currentLang, en: "Paragraph %d", zh: "段落 %d", ja: "段落 %d", ko: "%d번째 단락")
        case "read_from_here_hint": return l(currentLang, en: "Start reading aloud from the current paragraph, useful with the pinned menu bar window.", zh: "可从当前段落开始朗读，适合把窗口固定后听书。", ja: "現在の段落から読み上げを開始できます。メニューバーに固定して聞く時に便利です。", ko: "현재 단락부터 읽을 수 있어 메뉴 막대 창을 고정해 들을 때 좋습니다.")
        case "empty_menu_title": return l(currentLang, en: "No novels imported", zh: "还没有导入小说", ja: "小説はまだインポートされていません", ko: "가져온 소설이 없습니다")
        case "empty_menu_hint": return l(currentLang, en: "Import txt files, then pin this menu bar window to read or listen while you work.", zh: "导入 txt 后，可以固定这个菜单栏窗口，一边工作一边看小说或听朗读。", ja: "txt をインポートすると、このメニューバーウィンドウを固定して作業中に読んだり聞いたりできます。", ko: "txt를 가져온 뒤 이 메뉴 막대 창을 고정해 작업하면서 읽거나 들을 수 있습니다.")
        case "import_txt": return l(currentLang, en: "Import txt", zh: "导入 txt", ja: "txt をインポート", ko: "txt 가져오기")
        case "reading_mode": return l(currentLang, en: "Reading Mode", zh: "阅读模式", ja: "読書モード", ko: "읽기 모드")
        case "font_size": return l(currentLang, en: "Font Size", zh: "字体大小", ja: "フォントサイズ", ko: "글자 크기")
        case "line_spacing": return l(currentLang, en: "Line Spacing", zh: "行间距", ja: "行間", ko: "줄 간격")
        case "reading_theme": return l(currentLang, en: "Reading Theme", zh: "阅读主题", ja: "読書テーマ", ko: "읽기 테마")
        case "preview_effect": return l(currentLang, en: "Preview", zh: "预览效果", ja: "プレビュー", ko: "미리보기")
        case "preview_title": return l(currentLang, en: "Chapter 1 Into the World", zh: "第一章 初入江湖", ja: "第一章 旅立ち", ko: "제1장 첫걸음")
        case "preview_body": return l(currentLang, en: "The young traveler carried a long sword and stepped onto the winding road. Faraway mountains rose through mist, with temple eaves faintly visible.", zh: "少年背负长剑，踏上了漫漫江湖路。远方群山连绵，云雾缭绕间隐约可见古寺的飞檐。", ja: "少年は長剣を背負い、長い旅路へ踏み出した。遠くの山々は霧に包まれ、古寺の軒がかすかに見えた。", ko: "소년은 긴 검을 메고 먼 여정에 올랐다. 멀리 산들이 안개에 잠기고, 오래된 절의 처마가 희미하게 보였다.")
        // ReadingMode
        case "scroll": return l(currentLang, en: "Scroll", zh: "滚动", ja: "スクロール", ko: "스크롤")
        case "page": return l(currentLang, en: "Page", zh: "翻页", ja: "ページ", ko: "페이지")
        // ReaderTheme
        case "theme_light": return l(currentLang, en: "Light", zh: "明亮", ja: "ライト", ko: "밝게")
        case "theme_warm": return l(currentLang, en: "Warm", zh: "暖色", ja: "ウォーム", ko: "따뜻하게")
        case "theme_sepia": return l(currentLang, en: "Sepia", zh: "复古", ja: "セピア", ko: "세피아")
        case "theme_dark": return l(currentLang, en: "Dark", zh: "暗夜", ja: "ダーク", ko: "어둡게")
        case "theme_ink": return l(currentLang, en: "Ink", zh: "水墨", ja: "墨", ko: "먹색")
        default: return key
        }
    }

    // MARK: - 英语学习

    static func english(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "english": return l(currentLang, en: "English", zh: "英语", ja: "英語", ko: "영어")
        // Category
        case "words": return l(currentLang, en: "Words", zh: "单词", ja: "単語", ko: "단어")
        case "sentences": return l(currentLang, en: "Sentences", zh: "句子", ja: "文", ko: "문장")
        case "passages": return l(currentLang, en: "Passages", zh: "短文", ja: "短文", ko: "지문")
        case "daily": return l(currentLang, en: "Daily", zh: "每日", ja: "毎日", ko: "매일")
        // Accent
        case "american": return l(currentLang, en: "American English", zh: "美式英语", ja: "アメリカ英語", ko: "미국 영어")
        case "british": return l(currentLang, en: "British English", zh: "英式英语", ja: "イギリス英語", ko: "영국 영어")
        case "american_short": return l(currentLang, en: "US", zh: "美音", ja: "米", ko: "미국")
        case "british_short": return l(currentLang, en: "UK", zh: "英音", ja: "英", ko: "영국")
        // Stage
        case "stage_daily": return l(currentLang, en: "Daily English", zh: "日常英语", ja: "日常英語", ko: "일상 영어")
        case "stage_primary": return l(currentLang, en: "Primary School", zh: "小学英语", ja: "小学校英語", ko: "초등학교 영어")
        case "stage_middle": return l(currentLang, en: "Middle School", zh: "初中英语", ja: "中学英語", ko: "중학교 영어")
        case "stage_high": return l(currentLang, en: "High School", zh: "高中英语", ja: "高校英語", ko: "고등학교 영어")
        case "stage_cet4": return l(currentLang, en: "CET-4", zh: "大学四级", ja: "CET-4", ko: "CET-4")
        case "stage_cet6": return l(currentLang, en: "CET-6", zh: "大学六级", ja: "CET-6", ko: "CET-6")
        case "stage_ielts": return l(currentLang, en: "IELTS", zh: "雅思", ja: "IELTS", ko: "IELTS")
        case "stage_toefl": return l(currentLang, en: "TOEFL", zh: "托福", ja: "TOEFL", ko: "TOEFL")
        case "stage_daily_short": return l(currentLang, en: "Daily", zh: "日常", ja: "日常", ko: "일상")
        case "stage_primary_short": return l(currentLang, en: "Primary", zh: "小学", ja: "小学", ko: "초등")
        case "stage_middle_short": return l(currentLang, en: "Middle", zh: "初中", ja: "中学", ko: "중학")
        case "stage_high_short": return l(currentLang, en: "High", zh: "高中", ja: "高校", ko: "고등")
        case "stage_cet4_short": return l(currentLang, en: "CET-4", zh: "四级", ja: "CET-4", ko: "CET-4")
        case "stage_cet6_short": return l(currentLang, en: "CET-6", zh: "六级", ja: "CET-6", ko: "CET-6")
        case "stage_ielts_short": return l(currentLang, en: "IELTS", zh: "雅思", ja: "IELTS", ko: "IELTS")
        case "stage_toefl_short": return l(currentLang, en: "TOEFL", zh: "托福", ja: "TOEFL", ko: "TOEFL")
        case "stage_daily_desc": return l(currentLang, en: "Everyday words for quick listening and review", zh: "日常场景词，适合快速听读和复习", ja: "日常場面の単語。短時間の聞き読みと復習向け", ko: "일상 단어, 빠른 듣기와 복습에 적합")
        case "stage_primary_desc": return l(currentLang, en: "Primary school basics plus a general expanded word list", zh: "小学基础词 + 通用扩展词表", ja: "小学校の基礎語彙 + 汎用拡張単語集", ko: "초등 기본 단어 + 일반 확장 단어장")
        case "stage_middle_desc": return l(currentLang, en: "Middle school core words plus a general expanded word list", zh: "初中核心词 + 通用扩展词表", ja: "中学校の重要語彙 + 汎用拡張単語集", ko: "중학교 핵심 단어 + 일반 확장 단어장")
        case "stage_high_desc": return l(currentLang, en: "High school core words plus a general expanded word list", zh: "高中核心词 + 通用扩展词表", ja: "高校の重要語彙 + 汎用拡張単語集", ko: "고등학교 핵심 단어 + 일반 확장 단어장")
        case "stage_cet4_desc": return l(currentLang, en: "CET-4 high-frequency words plus a general expanded word list", zh: "四级高频词 + 通用扩展词表", ja: "CET-4頻出語彙 + 汎用拡張単語集", ko: "CET-4 고빈도 단어 + 일반 확장 단어장")
        case "stage_cet6_desc": return l(currentLang, en: "CET-6 high-frequency words for advanced college study", zh: "六级高频词，适合大学进阶学习", ja: "CET-6頻出語彙。大学の応用学習向け", ko: "CET-6 고빈도 단어, 대학 심화 학습에 적합")
        case "stage_ielts_desc": return l(currentLang, en: "IELTS core academic and everyday vocabulary", zh: "雅思核心学术与生活词汇", ja: "IELTS重要アカデミー・日常語彙", ko: "IELTS 핵심 학술·일상 어휘")
        case "stage_toefl_desc": return l(currentLang, en: "TOEFL high-frequency academic vocabulary", zh: "托福高频学术词汇", ja: "TOEFL頻出アカデミック語彙", ko: "TOEFL 고빈도 학술 어휘")
        // MenuTextStyle
        case "english_only": return l(currentLang, en: "English Only", zh: "仅英文", ja: "英語のみ", ko: "영어만")
        case "english_and_chinese": return l(currentLang, en: "English + Chinese", zh: "英文 + 中文", ja: "英語 + 中国語", ko: "영어 + 중국어")
        // TTSBackend
        case "system_voice": return l(currentLang, en: "System Voice", zh: "系统语音", ja: "システム音声", ko: "시스템 음성")
        case "kokoro_experimental": return l(currentLang, en: "Kokoro (Experimental)", zh: "Kokoro（实验）", ja: "Kokoro（実験）", ko: "Kokoro(실험)")
        // MasteryLevel
        case "mastery_new": return l(currentLang, en: "New", zh: "未学习", ja: "未学習", ko: "새 항목")
        case "mastery_unfamiliar": return l(currentLang, en: "Unfamiliar", zh: "不熟悉", ja: "まだ不慣れ", ko: "익숙하지 않음")
        case "mastery_learning": return l(currentLang, en: "Learning", zh: "学习中", ja: "学習中", ko: "학습 중")
        case "mastery_familiar": return l(currentLang, en: "Recognized", zh: "已认识", ja: "認識済み", ko: "알아봄")
        case "mastery_mastered": return l(currentLang, en: "Mastered", zh: "已掌握", ja: "習得済み", ko: "익힘")
        // Settings labels
        case "tts_engine": return l(currentLang, en: "TTS Engine", zh: "朗读引擎", ja: "読み上げエンジン", ko: "TTS 엔진")
        case "learning_stage": return l(currentLang, en: "Stage", zh: "学习学段", ja: "学習段階", ko: "학습 단계")
        case "accent": return l(currentLang, en: "Accent", zh: "英语口音", ja: "アクセント", ko: "억양")
        case "voice_select": return l(currentLang, en: "System Voice", zh: "系统语音", ja: "システム音声", ko: "시스템 음성")
        case "auto_best_voice": return l(currentLang, en: "Auto select best voice", zh: "自动选择最佳语音", ja: "最適な音声を自動選択", ko: "최적 음성 자동 선택")
        case "normal_rate": return l(currentLang, en: "Normal Rate", zh: "正常语速", ja: "通常速度", ko: "보통 속도")
        case "slow_rate": return l(currentLang, en: "Slow Rate", zh: "慢速语速", ja: "低速", ko: "느린 속도")
        case "volume": return l(currentLang, en: "Volume", zh: "朗读音量", ja: "音量", ko: "읽기 음량")
        case "repeat_count": return l(currentLang, en: "Repeat", zh: "每条重复", ja: "繰り返し", ko: "반복")
        case "interval": return l(currentLang, en: "Interval", zh: "切换间隔", ja: "間隔", ko: "간격")
        case "menu_text": return l(currentLang, en: "Menu Text", zh: "菜单栏文字", ja: "メニュー文字", ko: "메뉴 텍스트")
        case "daily_goal": return l(currentLang, en: "Daily Goal", zh: "每日目标", ja: "毎日の目標", ko: "일일 목표")
        case "show_translation": return l(currentLang, en: "Show Translation", zh: "显示中文释义", ja: "中国語訳を表示", ko: "중국어 뜻 표시")
        case "speak_translation": return l(currentLang, en: "Speak Translation", zh: "朗读中文释义", ja: "中国語訳を読み上げ", ko: "중국어 뜻 읽기")
        case "times": return l(currentLang, en: "times", zh: "次", ja: "回", ko: "회")
        case "seconds": return l(currentLang, en: "s", zh: "秒", ja: "秒", ko: "초")
        case "items": return l(currentLang, en: "items", zh: "条", ja: "項目", ko: "개")
        case "days": return l(currentLang, en: "d", zh: "天", ja: "日", ko: "일")
        case "streak": return l(currentLang, en: "streak", zh: "天", ja: "連続", ko: "연속")
        // Voice hint
        case "download_voice": return l(currentLang, en: "Download Enhanced voice for better pronunciation", zh: "发音想更自然？下载 Enhanced 英语语音", ja: "より自然な発音には Enhanced 英語音声をダウンロード", ko: "더 자연스러운 발음을 위해 Enhanced 영어 음성을 다운로드하세요")
        case "download": return l(currentLang, en: "Download", zh: "下载", ja: "ダウンロード", ko: "다운로드")
        case "dismiss": return l(currentLang, en: "Dismiss", zh: "暂时隐藏", ja: "あとで", ko: "나중에")
        case "voice_better_title": return l(currentLang, en: "Better English Voices", zh: "让英语发音更好听", ja: "より自然な英語音声", ko: "더 좋은 영어 음성")
        case "voice_better_subtitle": return l(currentLang, en: "Download Apple Neural voices for natural speech", zh: "下载 Apple Neural 语音，读单词像真人", ja: "Apple Neural 音声をダウンロードして自然に読み上げ", ko: "Apple Neural 음성으로 더 자연스럽게 읽기")
        case "voice_step1": return l(currentLang, en: "Open System Settings → Accessibility → Spoken Content → System Voice → Manage Voices", zh: "打开系统设置 → 辅助功能 → 朗读内容 → 系统语音 → 管理语音", ja: "システム設定 → アクセシビリティ → 読み上げコンテンツ → システム音声 → 音声を管理 を開く", ko: "시스템 설정 → 손쉬운 사용 → 음성 콘텐츠 → 시스템 음성 → 음성 관리 열기")
        case "voice_step2": return l(currentLang, en: "Hover over an English voice and click the download icon", zh: "鼠标移到英语音色上，点击右侧的下载图标（ℹ︎ 感叹号）即可下载", ja: "英語音声にカーソルを合わせ、ダウンロードアイコンをクリック", ko: "영어 음성 위에 마우스를 올리고 다운로드 아이콘 클릭")
        case "voice_step3": return l(currentLang, en: "Come back and coolRun will auto-select the best voice", zh: "下载完回来，coolRun 会自动选中质量最高的那个音色", ja: "戻ると coolRun が最適な音声を自動選択します", ko: "돌아오면 coolRun이 가장 좋은 음성을 자동 선택합니다")
        case "voice_recommend": return l(currentLang, en: "Recommended voices (60–150MB, one-time download)", zh: "推荐音色（体积约 60–150MB，一次下载永久使用）", ja: "おすすめ音声（60-150MB、一度だけダウンロード）", ko: "추천 음성(60-150MB, 한 번만 다운로드)")
        case "later": return l(currentLang, en: "Later", zh: "以后再说", ja: "後で", ko: "나중에")
        case "go_download": return l(currentLang, en: "Open Settings", zh: "打开语音设置", ja: "設定を開く", ko: "설정 열기")
        // 语音质量已达标时的按钮文案（不再误导用户去"下载"）
        case "view_voice_settings": return l(currentLang, en: "View Voice Settings", zh: "查看语音设置", ja: "音声設定を見る", ko: "음성 설정 보기")
        case "download_now": return l(currentLang, en: "Download Now", zh: "立即前往下载", ja: "今すぐダウンロード", ko: "지금 다운로드")
        case "open_voice_download": return l(currentLang, en: "Open System Settings to download better English voices", zh: "打开系统设置，去下载更好听的英语语音", ja: "システム設定を開いてより自然な英語音声をダウンロード", ko: "시스템 설정을 열어 더 자연스러운 영어 음성 다운로드")
        case "close_hint": return l(currentLang, en: "Close for now", zh: "暂时关闭", ja: "いったん閉じる", ko: "일단 닫기")
        case "installed": return l(currentLang, en: "Downloaded", zh: "已下载", ja: "ダウンロード済み", ko: "다운로드됨")
        case "high_quality_on": return l(currentLang, en: "High quality voice enabled", zh: "已启用高质量语音", ja: "高品質音声が有効です", ko: "고품질 음성 사용 중")
        case "download_better_voice": return l(currentLang, en: "Download better voice", zh: "下载更好听的英语语音", ja: "より良い英語音声をダウンロード", ko: "더 좋은 영어 음성 다운로드")
        case "voice_current_quality": return l(currentLang, en: "Current:", zh: "当前是「", ja: "現在：", ko: "현재:")
        case "voice_guide_suffix": return l(currentLang, en: ". Go to System Settings → Accessibility → Spoken Content → System Voice → Manage Voices to download Enhanced or Premium English voices.", zh: "」。在系统设置 → 辅助功能 → 朗读内容 → 系统语音 → 管理语音，下载 Enhanced 或 Premium 英语语音后回来选中即可。", ja: "。システム設定 → アクセシビリティ → 読み上げコンテンツ → システム音声 → 音声を管理 で Enhanced または Premium の英語音声をダウンロードしてください。", ko: ". 시스템 설정 → 손쉬운 사용 → 음성 콘텐츠 → 시스템 음성 → 음성 관리에서 Enhanced 또는 Premium 영어 음성을 다운로드하세요.")
        case "voice_good_suffix": return l(currentLang, en: " voice — near human-level quality.", zh: "」语音，听感已经接近真人。", ja: "音声です。かなり自然な品質です。", ko: " 음성입니다. 거의 사람처럼 자연스럽습니다.")
        case "no_content": return l(currentLang, en: "No English content yet", zh: "暂无英语内容", ja: "英語コンテンツはまだありません", ko: "아직 영어 콘텐츠가 없습니다")
        case "goal_done": return l(currentLang, en: "Today's goal complete", zh: "今日目标完成", ja: "今日の目標を達成", ko: "오늘 목표 완료")
        case "today_learning": return l(currentLang, en: "Today", zh: "今日学习", ja: "今日の学習", ko: "오늘 학습")
        case "stage_picker": return l(currentLang, en: "Stage", zh: "学段", ja: "学習段階", ko: "학습 단계")
        case "switch_stage": return l(currentLang, en: "Switch learning stage", zh: "切换学习学段", ja: "学習段階を切り替え", ko: "학습 단계 전환")
        case "textbook_management": return l(currentLang, en: "Textbook Management", zh: "课本管理", ja: "教科書管理", ko: "교재 관리")
        case "textbook_source_hint": return l(currentLang, en: "Built-in lists are samples. Import your own textbook word list for real study.", zh: "内置词库只是示例。真实教材建议导入自己的课本词表。", ja: "内蔵リストはサンプルです。実際の学習には自分の教科書単語表をインポートしてください。", ko: "내장 목록은 샘플입니다. 실제 학습에는 교재 단어장을 가져오세요.")
        case "open_textbook_manager": return l(currentLang, en: "Open textbook management", zh: "打开课本管理", ja: "教科書管理を開く", ko: "교재 관리 열기")
        case "builtin_textbooks": return l(currentLang, en: "Built-in", zh: "内置课本", ja: "内蔵", ko: "내장")
        case "imported_textbooks": return l(currentLang, en: "Imported", zh: "已导入", ja: "インポート済み", ko: "가져옴")
        case "builtin": return l(currentLang, en: "Built-in", zh: "内置", ja: "内蔵", ko: "내장")
        case "imported": return l(currentLang, en: "Imported", zh: "导入", ja: "インポート", ko: "가져옴")
        case "import_textbook": return l(currentLang, en: "Import", zh: "导入课本", ja: "インポート", ko: "가져오기")
        case "import_stage_help": return l(currentLang, en: "Stage for imported words", zh: "导入词表归属学段", ja: "インポート語彙の学習段階", ko: "가져온 단어의 단계")
        case "use_this_textbook": return l(currentLang, en: "Use This Textbook", zh: "使用这本课本", ja: "この教科書を使う", ko: "이 교재 사용")
        case "words_count": return l(currentLang, en: "words", zh: "个词", ja: "語", ko: "단어")
        case "studied_count": return l(currentLang, en: "studied", zh: "已学", ja: "学習済み", ko: "학습")
        case "known_count": return l(currentLang, en: "Known", zh: "认识", ja: "覚えた", ko: "알아요")
        case "word_preview": return l(currentLang, en: "Word Preview", zh: "单词预览", ja: "単語プレビュー", ko: "단어 미리보기")
        case "import_format_title": return l(currentLang, en: "Import Format", zh: "导入格式", ja: "インポート形式", ko: "가져오기 형식")
        case "import_format_hint": return l(currentLang, en: "CSV/TXT columns: word, translation, pronunciation, part, example, example translation. A header row is optional.", zh: "CSV/TXT 每行：单词、释义、音标、词性、例句、例句翻译。可以带表头。", ja: "CSV/TXT 列：単語、訳、発音、品詞、例文、例文訳。ヘッダー行も使えます。", ko: "CSV/TXT 열: 단어, 뜻, 발음, 품사, 예문, 예문 번역. 머리글 행을 사용할 수 있습니다.")
        case "textbook_import_failed": return l(currentLang, en: "Import Failed", zh: "导入失败", ja: "インポートに失敗しました", ko: "가져오기 실패")
        case "textbook_import_unreadable": return l(currentLang, en: "Could not read this file as text.", zh: "无法按文本读取这个文件。", ja: "このファイルをテキストとして読めません。", ko: "이 파일을 텍스트로 읽을 수 없습니다.")
        case "textbook_import_no_words": return l(currentLang, en: "No valid words were found in this file.", zh: "文件里没有找到可用单词。", ja: "有効な単語が見つかりませんでした。", ko: "파일에서 유효한 단어를 찾지 못했습니다.")
        case "imported_textbook": return l(currentLang, en: "Imported Textbook", zh: "导入课本", ja: "インポート教科書", ko: "가져온 교재")
        case "imported_textbook_summary": return l(currentLang, en: "User-imported word list", zh: "用户导入的课本词表", ja: "ユーザーがインポートした単語表", ko: "사용자가 가져온 단어장")
        case "translation_missing": return l(currentLang, en: "No translation", zh: "暂无释义", ja: "訳なし", ko: "뜻 없음")
        case "study_category": return l(currentLang, en: "Study", zh: "学习", ja: "学習", ko: "학습")
        case "favorite": return l(currentLang, en: "Favorite", zh: "收藏", ja: "お気に入り", ko: "즐겨찾기")
        case "unfavorite": return l(currentLang, en: "Remove favorite", zh: "取消收藏", ja: "お気に入りを解除", ko: "즐겨찾기 해제")
        case "slow_read": return l(currentLang, en: "Read slowly", zh: "慢速朗读", ja: "ゆっくり読み上げ", ko: "느리게 읽기")
        case "read_once": return l(currentLang, en: "Read once", zh: "朗读一次", ja: "一度読み上げ", ko: "한 번 읽기")
        case "continuous_read": return l(currentLang, en: "Continuous reading", zh: "连续听读", ja: "連続読み上げ", ko: "연속 듣기")
        case "pause_read": return l(currentLang, en: "Pause reading", zh: "暂停听读", ja: "読み上げを一時停止", ko: "듣기 일시 정지")
        case "resume_read": return l(currentLang, en: "Resume reading", zh: "继续听读", ja: "読み上げを再開", ko: "듣기 계속")
        case "not_known": return l(currentLang, en: "Still learning", zh: "还不认识", ja: "まだ覚えていない", ko: "아직 몰라요")
        case "known": return l(currentLang, en: "I know it", zh: "认识了", ja: "覚えた", ko: "알아요")
        case "mastered": return l(currentLang, en: "Mastered", zh: "已经掌握", ja: "習得済み", ko: "이미 익힘")
        case "listening": return l(currentLang, en: "Listening", zh: "正在听读", ja: "読み上げ中", ko: "듣는 중")
        case "paused": return l(currentLang, en: "Paused", zh: "已暂停", ja: "一時停止中", ko: "일시 정지됨")
        case "daily_sentence": return l(currentLang, en: "Daily sentence", zh: "每日一句", ja: "今日の一文", ko: "오늘의 문장")
        default: return key
        }
    }

    // MARK: - 小说朗读

    static func speech(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "previous_sentence": return l(currentLang, en: "Previous sentence", zh: "上一句", ja: "前の文", ko: "이전 문장")
        case "next_sentence": return l(currentLang, en: "Next sentence", zh: "下一句", ja: "次の文", ko: "다음 문장")
        case "pause_reading": return l(currentLang, en: "Pause reading", zh: "暂停朗读", ja: "読み上げを一時停止", ko: "읽기 일시 정지")
        case "start_reading": return l(currentLang, en: "Start reading", zh: "开始朗读", ja: "読み上げ開始", ko: "읽기 시작")
        case "stop_reading": return l(currentLang, en: "Stop reading", zh: "停止朗读", ja: "読み上げ停止", ko: "읽기 중지")
        case "voice_settings": return l(currentLang, en: "Voice settings", zh: "语音设置", ja: "音声設定", ko: "음성 설정")
        case "start_hint": return l(currentLang, en: "Click play to start reading aloud", zh: "点击播放开始语音朗读", ja: "再生をクリックして読み上げを開始", ko: "재생을 눌러 음성 읽기 시작")
        case "system_voice_hint": return l(currentLang, en: "Read the current chapter with the system voice", zh: "使用系统语音合成朗读当前章节", ja: "システム音声で現在の章を読み上げ", ko: "시스템 음성으로 현재 장 읽기")
        case "chapter_sentence_format": return l(currentLang, en: "Chapter %d · Sentence %d/%d", zh: "第 %d 章 · 第 %d/%d 句", ja: "第 %d 章 · %d/%d 文", ko: "%d장 · %d/%d문장")
        case "voice_reading": return l(currentLang, en: "Read Aloud", zh: "语音朗读", ja: "読み上げ", ko: "음성 읽기")
        case "voice": return l(currentLang, en: "Voice", zh: "语音", ja: "音声", ko: "음성")
        case "default_chinese_voice": return l(currentLang, en: "System default Chinese", zh: "系统默认中文", ja: "システム既定の中国語", ko: "시스템 기본 중국어")
        case "rate": return l(currentLang, en: "Rate", zh: "语速", ja: "速度", ko: "속도")
        case "pitch": return l(currentLang, en: "Pitch", zh: "音调", ja: "ピッチ", ko: "음높이")
        case "volume": return l(currentLang, en: "Volume", zh: "音量", ja: "音量", ko: "음량")
        case "auto_scroll": return l(currentLang, en: "Auto-scroll while reading", zh: "朗读时自动滚动", ja: "読み上げ中に自動スクロール", ko: "읽는 동안 자동 스크롤")
        case "auto_continue": return l(currentLang, en: "Continue after chapter ends", zh: "章节结束后自动继续", ja: "章の終了後に自動で続行", ko: "장이 끝나면 자동 계속")
        case "pin_popover": return l(currentLang, en: "Pin floating window", zh: "固定悬浮窗", ja: "フローティングウィンドウを固定", ko: "플로팅 창 고정")
        case "unpin_popover": return l(currentLang, en: "Unpin floating window", zh: "取消固定悬浮窗", ja: "固定を解除", ko: "플로팅 창 고정 해제")
        default: return key
        }
    }

    // MARK: - 更新检查

    static func update(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "new_version": return l(currentLang, en: "New Version Available", zh: "发现新版本", ja: "新しいバージョンがあります", ko: "새 버전 사용 가능")
        case "go_download": return l(currentLang, en: "Download", zh: "前往下载", ja: "ダウンロード", ko: "다운로드")
        case "remind_later": return l(currentLang, en: "Later", zh: "稍后提醒", ja: "後で", ko: "나중에")
        case "up_to_date": return l(currentLang, en: "Already Up to Date", zh: "已是最新版本", ja: "最新バージョンです", ko: "최신 버전입니다")
        case "up_to_date_msg": return l(currentLang, en: "You are running the latest version.", zh: "当前版本已是最新。", ja: "現在のバージョンは最新です。", ko: "현재 최신 버전을 사용 중입니다.")
        case "check_failed": return l(currentLang, en: "Update Check Failed", zh: "检查更新失败", ja: "更新確認に失敗しました", ko: "업데이트 확인 실패")
        case "invalid_url": return l(currentLang, en: "Invalid update URL", zh: "无效的更新检查地址", ja: "更新確認 URL が無効です", ko: "업데이트 URL이 올바르지 않습니다")
        case "invalid_response": return l(currentLang, en: "Invalid server response", zh: "服务器响应格式错误", ja: "サーバー応答が無効です", ko: "서버 응답이 올바르지 않습니다")
        case "no_releases": return l(currentLang, en: "No releases found", zh: "暂无发布版本", ja: "リリースが見つかりません", ko: "릴리스를 찾을 수 없습니다")
        case "http_error": return l(currentLang, en: "Server error", zh: "服务器错误", ja: "サーバーエラー", ko: "서버 오류")
        default: return key
        }
    }

    // MARK: - 数据迁移

    static func migration(_ key: String, lang: AppLanguage? = nil) -> String {
        let currentLang = lang ?? AppSettings.shared.language
        switch key {
        case "export_title": return l(currentLang, en: "Export coolRun Data", zh: "导出 coolRun 数据", ja: "coolRun データをエクスポート", ko: "coolRun 데이터 내보내기")
        case "export_failed": return l(currentLang, en: "Export Failed", zh: "导出失败", ja: "エクスポートに失敗しました", ko: "내보내기 실패")
        case "import_title": return l(currentLang, en: "Import coolRun Data", zh: "导入 coolRun 数据", ja: "coolRun データをインポート", ko: "coolRun 데이터 가져오기")
        case "import_confirm": return l(currentLang, en: "Confirm Import", zh: "确认导入数据", ja: "インポートの確認", ko: "가져오기 확인")
        case "import_failed": return l(currentLang, en: "Import Failed", zh: "导入失败", ja: "インポートに失敗しました", ko: "가져오기 실패")
        case "import_corrupt": return l(currentLang, en: "File format is invalid or corrupted", zh: "文件格式不正确或已损坏", ja: "ファイル形式が無効、または破損しています", ko: "파일 형식이 올바르지 않거나 손상되었습니다")
        case "export_time": return l(currentLang, en: "Exported at:", zh: "导出时间：", ja: "エクスポート日時：", ko: "내보낸 시간:")
        case "source_version": return l(currentLang, en: "Source version:", zh: "来源版本：", ja: "元バージョン：", ko: "원본 버전:")
        case "merge_hint": return l(currentLang, en: "The following data will be imported (merge mode, won't overwrite existing):", zh: "将导入以下数据（合并模式，不会覆盖已有数据）：", ja: "次のデータをインポートします（統合モード、既存データは上書きしません）：", ko: "다음 데이터를 가져옵니다(병합 모드, 기존 데이터는 덮어쓰지 않음):")
        case "birthday_items": return l(currentLang, en: "Birthdays", zh: "生日", ja: "誕生日", ko: "생일")
        case "english_items": return l(currentLang, en: "English progress", zh: "英语学习进度", ja: "英語学習の進捗", ko: "영어 학습 진행도")
        case "gold_items": return l(currentLang, en: "Gold price history", zh: "金价历史", ja: "金価格履歴", ko: "금 가격 기록")
        case "gold_trade_items": return l(currentLang, en: "Gold trade records", zh: "黄金交易流水", ja: "金の取引履歴", ko: "금 거래 내역")
        case "novel_items": return l(currentLang, en: "Novel progress/bookmarks", zh: "小说进度/书签", ja: "小説の進捗/しおり", ko: "소설 진행도/책갈피")
        case "app_settings": return l(currentLang, en: "App settings", zh: "应用设置", ja: "アプリ設定", ko: "앱 설정")
        default: return key
        }
    }
}
