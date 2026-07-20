import AVFoundation
import SwiftUI

// MARK: - 设置分类

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "general"
    case monitors = "monitors"
    case menubar = "menubar"
    case english = "english"
    case data = "data"
    case about = "about"

    var id: String { rawValue }

    func displayName(lang: AppLanguage) -> String {
        switch self {
        case .general: return LocalizedString.l(lang, en: "General", zh: "通用", ja: "一般", ko: "일반")
        case .monitors: return LocalizedString.l(lang, en: "Monitors", zh: "监控", ja: "監視", ko: "모니터")
        case .menubar: return LocalizedString.l(lang, en: "Menu Bar", zh: "菜单栏", ja: "メニュー", ko: "메뉴 막대")
        case .english: return LocalizedString.l(lang, en: "English", zh: "英语", ja: "英語", ko: "영어")
        case .data: return LocalizedString.l(lang, en: "Data", zh: "数据", ja: "データ", ko: "데이터")
        case .about: return LocalizedString.l(lang, en: "About", zh: "关于", ja: "情報", ko: "정보")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .monitors: return "chart.bar.fill"
        case .menubar: return "menubar.rectangle"
        case .english: return "character.book.closed"
        case .data: return "icloud.and.arrow.down"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var textbookStore = EnglishTextbookStore.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @State private var selectedCategory: SettingsCategory = .general

    var body: some View {
        VStack(spacing: 0) {
            // 顶部 Header
            headerSection

            Divider()
                .padding(.horizontal, 20)

            // 分类标签栏
            categoryTabBar

            Divider()
                .padding(.horizontal, 20)

            // 内容区域
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedCategory {
                    case .general:
                        generalContent
                    case .monitors:
                        monitorsContent
                    case .menubar:
                        menubarContent
                    case .english:
                        englishContent
                    case .data:
                        dataContent
                    case .about:
                        aboutContent
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 520)
        .background(colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            // App Icon with shadow
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("coolRun")
                    .font(.title2.weight(.bold))

                Text("v\(AppVersion.current.displayText)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - 分类标签栏

    private var categoryTabBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsCategory.allCases) { category in
                CategoryTab(
                    category: category,
                    isSelected: selectedCategory == category,
                    lang: settings.language
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 通用设置内容

    private var generalContent: some View {
        VStack(spacing: 16) {
            // 语言选择
            SettingsCard(
                icon: "globe",
                title: LocalizedString.settings("language"),
                description: LocalizedString.settings("language_desc")
            ) {
                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases) { language in
                        LanguageRow(
                            language: language,
                            isSelected: settings.language == language
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.language = language
                            }
                            Analytics.capture(.languageChanged, properties: [
                                "language": language.rawValue,
                            ])
                        }

                        if language != AppLanguage.allCases.last {
                            Divider().padding(.horizontal, 14)
                        }
                    }
                }
            }

            SettingsCard(
                icon: "power",
                title: LocalizedString.settings("startup"),
                description: LocalizedString.settings("startup_desc")
            ) {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        Text(LocalizedString.settings("launch_at_login"))
                            .font(.system(size: 13))

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    if let statusMessage = launchAtLogin.statusMessage {
                        Divider().padding(.horizontal, 14)
                        Text(statusMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                }
            }

            SettingsCard(
                icon: "hand.raised.fill",
                title: LocalizedString.settings("privacy"),
                description: LocalizedString.settings("privacy_desc")
            ) {
                VStack(spacing: 0) {
                    MonitorToggleRow(
                        icon: "chart.bar.xaxis",
                        title: LocalizedString.settings("share_analytics"),
                        isOn: $settings.analyticsEnabled
                    )
                    Divider().padding(.horizontal, 14)
                    Text(LocalizedString.settings("privacy_note"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
            }
        }
        .onAppear { launchAtLogin.refresh() }
    }

    // MARK: - 监控设置内容

    private var monitorsContent: some View {
        VStack(spacing: 16) {
            SettingsCard(
                icon: "chart.bar.fill",
                title: LocalizedString.settings("monitor_modules"),
                description: LocalizedString.settings("monitor_modules_desc")
            ) {
                VStack(spacing: 0) {
                    MonitorToggleRow(
                        icon: "cpu",
                        title: LocalizedString.monitor("cpu"),
                        isOn: $settings.showCPU
                    )
                    Divider().padding(.horizontal, 14)

                    MonitorToggleRow(
                        icon: "memorychip",
                        title: LocalizedString.monitor("memory"),
                        isOn: $settings.showMemory
                    )
                    Divider().padding(.horizontal, 14)

                    MonitorToggleRow(
                        icon: "externaldrive",
                        title: LocalizedString.monitor("storage"),
                        isOn: $settings.showStorage
                    )
                    Divider().padding(.horizontal, 14)

                    MonitorToggleRow(
                        icon: "battery.100",
                        title: LocalizedString.monitor("battery"),
                        isOn: $settings.showBattery
                    )
                    Divider().padding(.horizontal, 14)

                    MonitorToggleRow(
                        icon: "network",
                        title: LocalizedString.monitor("network"),
                        isOn: $settings.showNetwork
                    )
                    Divider().padding(.horizontal, 14)

                    MonitorToggleRow(
                        icon: "clock",
                        title: LocalizedString.monitor("uptime"),
                        isOn: $settings.showUptime
                    )
                    Divider().padding(.horizontal, 14)

                    MonitorToggleRow(
                        icon: "thermometer",
                        title: LocalizedString.monitor("temperature"),
                        isOn: $settings.showTemperature
                    )
                }
            }

            SettingsCard(
                icon: "gauge.with.dots.needle.50percent",
                title: LocalizedString.settings("refresh_rate"),
                description: LocalizedString.settings("refresh_rate_desc")
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(LocalizedString.settings("system_sampling"))
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $settings.systemRefreshRate) {
                        ForEach(SystemRefreshRate.allCases) { rate in
                            Text(rate.displayName(lang: settings.language)).tag(rate)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - 菜单栏设置内容

    private var menubarContent: some View {
        VStack(spacing: 16) {
            SettingsCard(
                icon: "menubar.rectangle",
                title: LocalizedString.settings("menu_bar_display"),
                description: LocalizedString.settings("menu_bar_display_desc")
            ) {
                VStack(spacing: 0) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        MenuBarDisplayRow(
                            mode: mode,
                            isSelected: settings.menuBarDisplayMode == mode
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.menuBarDisplayMode = mode
                            }
                            Analytics.capture(.menuBarDisplayModeChanged, properties: [
                                "mode": mode.rawValue,
                            ])
                        }

                        if mode != MenuBarDisplayMode.allCases.last {
                            Divider().padding(.horizontal, 14)
                        }
                    }
                }
            }

            SettingsCard(
                icon: "sparkles",
                title: LocalizedString.settings("menubar_animation"),
                description: LocalizedString.settings("menubar_animation_desc")
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "circle.dotted.circle")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(LocalizedString.settings("coin_animation"))
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $settings.menuBarAnimationRate) {
                        ForEach(MenuBarAnimationRate.allCases) { rate in
                            Text(rate.displayName(lang: settings.language)).tag(rate)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            SettingsCard(
                icon: "arrow.triangle.2.circlepath",
                title: LocalizedString.settings("gold_updates"),
                description: LocalizedString.settings("gold_updates_desc")
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(LocalizedString.settings("refresh_every"))
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $settings.goldRefreshRate) {
                        ForEach(GoldRefreshRate.allCases) { rate in
                            Text(rate.displayName(lang: settings.language)).tag(rate)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - 英语学习设置内容

    private var englishContent: some View {
        VStack(spacing: 16) {
            SettingsCard(
                icon: "speaker.wave.2.fill",
                title: LocalizedString.settings("english_voice"),
                description: LocalizedString.settings("english_voice_desc")
            ) {
                VStack(spacing: 0) {
                    settingsPickerRow(icon: "waveform", title: LocalizedString.english("tts_engine")) {
                        Picker("", selection: $settings.englishTTSBackend) {
                            ForEach(EnglishTTSBackend.allCases) { backend in
                                Text(backend.title).tag(backend)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    if settings.englishTTSBackend == .kokoro {
                        Divider().padding(.horizontal, 14)
                        settingsTextFieldRow(
                            icon: "terminal",
                            title: LocalizedString.settings("kokoro_command"),
                            text: $settings.englishKokoroCommandPath,
                            placeholder: "/usr/local/bin/kokoro-tts"
                        )
                        Divider().padding(.horizontal, 14)
                        settingsTextFieldRow(
                            icon: "person.crop.circle.badge.waveform",
                            title: LocalizedString.settings("kokoro_voice"),
                            text: $settings.englishKokoroVoice,
                            placeholder: KokoroEnglishSpeechProvider.defaultVoice
                        )
                    }

                    Divider().padding(.horizontal, 14)

                    settingsPickerRow(icon: "books.vertical.fill", title: LocalizedString.english("learning_stage")) {
                        Picker("", selection: Binding(
                            get: { textbookStore.selectedTextbook.stage },
                            set: { textbookStore.selectBuiltin(stage: $0) }
                        )) {
                            ForEach(EnglishStage.allCases) { stage in
                                Text(stage.title).tag(stage)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    Text(textbookStore.selectedTextbook.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                        .padding(.horizontal, 14)
                        .padding(.top, -4)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().padding(.horizontal, 14)

                    settingsPickerRow(icon: "globe.americas.fill", title: LocalizedString.english("accent")) {
                        Picker("", selection: $settings.englishAccent) {
                            ForEach(EnglishAccent.allCases) { accent in
                                Text(accent.title).tag(accent)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        .onChange(of: settings.englishAccent) { _, _ in
                            settings.englishVoiceIdentifier = ""
                        }
                    }

                    Divider().padding(.horizontal, 14)

                    settingsPickerRow(icon: "person.wave.2.fill", title: LocalizedString.english("voice_select")) {
                        Picker("", selection: $settings.englishVoiceIdentifier) {
                            Text(LocalizedString.english("auto_best_voice")).tag("")
                            ForEach(englishVoices, id: \.identifier) { voice in
                                Text(voiceDisplayName(voice)).tag(voice.identifier)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 185)
                    }

                    Divider().padding(.horizontal, 14)

                    voiceQualityHintRow

                    Divider().padding(.horizontal, 14)
                    englishSliderRow(title: LocalizedString.english("normal_rate"), value: $settings.englishNormalRate, range: 0.25...0.60)
                    Divider().padding(.horizontal, 14)
                    englishSliderRow(title: LocalizedString.english("slow_rate"), value: $settings.englishSlowRate, range: 0.15...0.45)
                    Divider().padding(.horizontal, 14)
                    englishSliderRow(title: LocalizedString.english("volume"), value: $settings.englishVolume, range: 0.1...1.0)
                }
            }

            SettingsCard(
                icon: "repeat",
                title: LocalizedString.settings("continuous_learning"),
                description: LocalizedString.settings("continuous_learning_desc")
            ) {
                VStack(spacing: 0) {
                    settingsPickerRow(icon: "repeat.1", title: LocalizedString.english("repeat_count")) {
                        Picker("", selection: $settings.englishRepeatCount) {
                            ForEach(1...3, id: \.self) { count in
                                Text("\(count) \(LocalizedString.english("times"))").tag(count)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                    Divider().padding(.horizontal, 14)
                    settingsPickerRow(icon: "timer", title: LocalizedString.english("interval")) {
                        Picker("", selection: $settings.englishItemInterval) {
                            ForEach([3.0, 5.0, 7.0, 10.0, 15.0], id: \.self) { seconds in
                                Text("\(Int(seconds)) \(LocalizedString.english("seconds"))").tag(seconds)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                    Divider().padding(.horizontal, 14)
                    settingsPickerRow(icon: "menubar.rectangle", title: LocalizedString.english("menu_text")) {
                        Picker("", selection: $settings.englishMenuTextStyle) {
                            ForEach(EnglishMenuTextStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                }
            }

            SettingsCard(
                icon: "target",
                title: LocalizedString.settings("learning_plan"),
                description: LocalizedString.settings("learning_plan_desc")
            ) {
                VStack(spacing: 0) {
                    settingsPickerRow(icon: "checklist", title: LocalizedString.english("daily_goal")) {
                        Picker("", selection: $settings.englishDailyTarget) {
                            ForEach([5, 10, 15, 20, 30], id: \.self) { target in
                                Text("\(target) \(LocalizedString.english("items"))").tag(target)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                    Divider().padding(.horizontal, 14)
                    MonitorToggleRow(icon: "text.bubble", title: LocalizedString.english("show_translation"), isOn: $settings.englishShowTranslation)
                    Divider().padding(.horizontal, 14)
                    MonitorToggleRow(icon: "speaker.badge.exclamationmark", title: LocalizedString.english("speak_translation"), isOn: $settings.englishSpeakTranslation)
                }
            }
        }
    }

    private var englishVoices: [AVSpeechSynthesisVoice] {
        EnglishLearningManager.availableVoices(for: settings.englishAccent)
    }

    private func voiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium: quality = " · Premium"
        case .enhanced: quality = " · Enhanced"
        default: quality = ""
        }
        return "\(voice.name)\(quality)"
    }

    private var voiceQualityHintRow: some View {
        let manager = EnglishLearningManager.shared
        let voice = manager.currentEnglishVoice
        let quality = EnglishLearningManager.qualityLabel(for: voice)
        let needsUpgrade = manager.needsHigherQualityEnglishVoice
        return HStack(spacing: 10) {
            Image(systemName: needsUpgrade ? "sparkles" : "checkmark.seal.fill")
                .foregroundStyle(needsUpgrade ? AppTheme.warning : AppTheme.healthy)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(needsUpgrade ? LocalizedString.english("download_better_voice") : LocalizedString.english("high_quality_on"))
                    .font(.system(size: 13))
                Text(needsUpgrade
                    ? LocalizedString.english("voice_current_quality") + "\(quality)" + LocalizedString.english("voice_guide_suffix")
                    : LocalizedString.english("voice_current_quality") + "\(quality)" + LocalizedString.english("voice_good_suffix"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                EnglishLearningManager.openSystemVoiceDownloadSettings()
            } label: {
                Text(needsUpgrade ? LocalizedString.english("go_download") : LocalizedString.english("go_download"))
                    .font(.system(size: 12))
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .tint(needsUpgrade ? AppTheme.warning : AppTheme.healthy)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func settingsPickerRow<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13))
            Spacer()
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func settingsTextFieldRow(
        icon: String,
        title: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13))
            Spacer()
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 185)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func englishSliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12))
                .frame(width: 64, alignment: .leading)
            Slider(value: value, in: range, step: 0.01)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - 数据管理内容

    private var dataContent: some View {
        VStack(spacing: 16) {
            // 数据备份与迁移
            DataBackupCard()

            // 应用更新检查
            UpdateCheckCard()

            // 节假日数据更新
            HolidayUpdateCard()
        }
    }

    // MARK: - 关于内容

    private var aboutContent: some View {
        VStack(spacing: 16) {
            // 应用信息
            VStack(spacing: 0) {
                SettingsRow(icon: "person.fill", label: LocalizedString.settings("author"), value: "kuaoaoaoao")
                Divider().padding(.horizontal, 12)
                SettingsRow(icon: "tag.fill", label: LocalizedString.settings("version"), value: AppVersion.current.displayText)
                Divider().padding(.horizontal, 12)
                SettingsRow(icon: "hammer.fill", label: "Swift", value: "SwiftUI + AppKit")
                Divider().padding(.horizontal, 12)
                SettingsRow(icon: "desktopcomputer", label: LocalizedString.settings("platform"), value: "macOS 15.0+")
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(cardBorder, lineWidth: 0.5)
            )

            // 链接
            VStack(spacing: 0) {
                LinkRow(
                    icon: "globe",
                    label: LocalizedString.settings("project_home"),
                    url: AppLinks.repository
                )
                Divider().padding(.horizontal, 12)
                LinkRow(
                    icon: "arrow.down.circle.fill",
                    label: LocalizedString.settings("check_update"),
                    url: AppLinks.releases
                )
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(cardBorder, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Helpers

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.8)
    }

    private var cardBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }
}

// MARK: - 分类标签组件

private struct CategoryTab: View {
    let category: SettingsCategory
    let isSelected: Bool
    let lang: AppLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                Text(category.displayName(lang: lang))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.1))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 设置卡片组件

private struct SettingsCard<Content: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()
            }

            // 描述
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.leading, 28)

            // 内容
            content()
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.white.opacity(0.6))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - 数据备份卡片

private struct DataBackupCard: View {
    @State private var exportSuccess = false
    @State private var importSuccess = false
    @State private var statusMessage: String?
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SettingsCard(
            icon: "externaldrive.fill",
            title: LocalizedString.settings("data_backup"),
            description: LocalizedString.settings("data_backup_desc")
        ) {
            VStack(spacing: 0) {
                // 数据统计
                HStack(spacing: 6) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text(dataSummaryText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Divider().padding(.horizontal, 14)

                // 导出/导入按钮
                HStack(spacing: 12) {
                    Button {
                        let success = DataMigrationManager.shared.exportAllData()
                        if success {
                            statusMessage = LocalizedString.settings("export_success")
                            exportSuccess = true
                            clearMessageAfterDelay()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .medium))
                            Text(LocalizedString.settings("export"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.accentColor)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        let success = DataMigrationManager.shared.importData()
                        if success {
                            statusMessage = LocalizedString.settings("import_success")
                            importSuccess = true
                            clearMessageAfterDelay()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 12, weight: .medium))
                            Text(LocalizedString.settings("import_data"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                // 状态消息
                if let message = statusMessage {
                    Divider().padding(.horizontal, 14)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }

                Divider().padding(.horizontal, 14)

                // 说明
                Text(LocalizedString.settings("data_backup_note"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
        }
    }

    private var dataSummaryText: String {
        let birthdayCount = BirthdayManager.shared.getAllBirthdays().count
        let englishCount = EnglishProgressStore.shared.records.count
        let goldCount = GoldPriceStore.shared.records.count
        let novelCount = NovelLibraryManager.shared.books.count

        switch settings.language {
        case .chinese:
            return "\(birthdayCount) 条生日 · \(englishCount) 条进度 · \(goldCount) 条金价 · \(novelCount) 本小说"
        case .japanese:
            return "\(birthdayCount) 件の誕生日 · \(englishCount) 件の進捗 · \(goldCount) 件の価格 · \(novelCount) 冊の本"
        case .korean:
            return "\(birthdayCount) 생일 · \(englishCount) 학습 기록 · \(goldCount) 가격 기록 · \(novelCount) 권의 책"
        case .english:
            return "\(birthdayCount) birthdays · \(englishCount) words · \(goldCount) prices · \(novelCount) books"
        }
    }

    private func clearMessageAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            statusMessage = nil
        }
    }
}

// MARK: - 更新检查卡片

private struct UpdateCheckCard: View {
    @State private var updateChecker = UpdateChecker.shared
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        SettingsCard(
            icon: "arrow.triangle.2.circlepath.circle.fill",
            title: LocalizedString.settings("app_updates"),
            description: LocalizedString.settings("app_updates_desc")
        ) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: updateChecker.hasUpdate ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(updateChecker.hasUpdate ? AppTheme.warning : .green)

                            if updateChecker.hasUpdate {
                                Text("v\(updateChecker.latestVersion ?? "") \(LocalizedString.settings("available"))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.warning)
                            } else {
                                Text("v\(AppVersion.current.marketingVersion) \(LocalizedString.settings("up_to_date"))")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }

                        if let lastCheck = updateChecker.lastCheckDate {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("\(LocalizedString.settings("last_checked")) \(formatDate(lastCheck))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        Task {
                            await updateChecker.checkForUpdates(silent: false)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if updateChecker.isChecking {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            Text(updateChecker.isChecking
                                ? LocalizedString.settings("checking")
                                : LocalizedString.settings("check_now"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(updateChecker.isChecking ? Color.gray : Color.accentColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(updateChecker.isChecking)
                }
                .padding(12)

                if updateChecker.hasUpdate, let url = updateChecker.releaseURL {
                    Divider().padding(.horizontal, 14)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentColor)
                        Button(LocalizedString.settings("download_page")) {
                            NSWorkspace.shared.open(url)
                        }
                        .font(.system(size: 12))
                        .buttonStyle(.link)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            if updateChecker.lastCheckDate == nil {
                Task {
                    await updateChecker.checkForUpdates(silent: true)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 节假日更新卡片

private struct HolidayUpdateCard: View {
    @State private var isUpdating = false
    @State private var updateMessage: String?
    @State private var updateSuccess = false
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared

    private let holidayService = HolidayService.shared

    var body: some View {
        SettingsCard(
            icon: "calendar.badge.clock",
            title: LocalizedString.data("holiday_data", lang: settings.language),
            description: LocalizedString.data("holiday_data_desc", lang: settings.language)
        ) {
            VStack(spacing: 12) {
                // 状态信息
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        // 数据状态
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)

                            Text("\(LocalizedString.data("data_version", lang: settings.language)): v\(holidayService.getCurrentVersion())")
                                .font(.system(size: 12, weight: .medium))
                        }

                        // 数据条数
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            Text("\(holidayService.getCachedDataCount()) \(LocalizedString.data("record_count", lang: settings.language))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        // 最后更新时间
                        if let lastUpdate = holidayService.getLastUpdateTime() {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)

                                Text("\(LocalizedString.data("last_update", lang: settings.language)): \(formatDate(lastUpdate))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    // 更新按钮
                    Button(action: { updateData() }) {
                        HStack(spacing: 6) {
                            if isUpdating {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .medium))
                            }

                            Text(isUpdating ? LocalizedString.data("updating", lang: settings.language) : LocalizedString.data("update_data", lang: settings.language))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isUpdating ? Color.gray : Color.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating)
                }
                .padding(12)

                // 更新结果消息
                if let message = updateMessage {
                    HStack(spacing: 6) {
                        Image(systemName: updateSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(updateSuccess ? .green : .red)

                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(updateSuccess ? .green : .red)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }

                // 说明文字
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(LocalizedString.data("data_note", lang: settings.language)):")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(LocalizedString.data("data_note_content", lang: settings.language))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private func updateData() {
        isUpdating = true
        updateMessage = nil

        Task {
            do {
                try await holidayService.updateHolidayData()

                await MainActor.run {
                    isUpdating = false
                    updateSuccess = true
                    updateMessage = LocalizedString.data("update_success", lang: settings.language)
                    Analytics.capture(.holidayDataUpdated, properties: [
                        "success": true,
                    ])

                    // 3秒后清除消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        updateMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    updateSuccess = false
                    updateMessage = "\(LocalizedString.data("update_failed", lang: settings.language)): \(error.localizedDescription)"
                    Analytics.capture(.holidayDataUpdated, properties: [
                        "success": false,
                        "error_type": String(describing: type(of: error)),
                    ])

                    // 5秒后清除消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        updateMessage = nil
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.language.locale
        switch settings.language {
        case .chinese, .japanese:
            formatter.dateFormat = "yyyy年M月d日 HH:mm"
        case .korean:
            formatter.dateFormat = "yyyy년 M월 d일 HH:mm"
        case .english:
            formatter.dateFormat = "MMM d, yyyy HH:mm"
        }
        return formatter.string(from: date)
    }
}

// MARK: - 语言行

private struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(languageFlag)
                    .font(.system(size: 18))

                Text(language.displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var languageFlag: String {
        switch language {
        case .chinese: return "🇨🇳"
        case .english: return "🇺🇸"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        }
    }
}

// MARK: - 监控开关行

private struct MonitorToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(Color.accentColor)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - 菜单栏显示行

private struct MenuBarDisplayRow: View {
    let mode: MenuBarDisplayMode
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName(lang: settings.language))
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)

                    Text(modeDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var modeDescription: String {
        switch mode {
        case .goldPrice:
            return LocalizedString.menuBar("gold_price", lang: settings.language)
        case .date:
            return LocalizedString.menuBar("date", lang: settings.language)
        case .cpu:
            return LocalizedString.l(settings.language, en: "Live processor utilization", zh: "实时显示处理器占用率", ja: "プロセッサ使用率をリアルタイム表示", ko: "실시간 프로세서 사용률")
        case .memory:
            return LocalizedString.l(settings.language, en: "Live memory utilization", zh: "实时显示内存占用率", ja: "メモリ使用率をリアルタイム表示", ko: "실시간 메모리 사용률")
        case .network:
            return LocalizedString.l(settings.language, en: "Live download and upload speed", zh: "实时显示下载和上传速度", ja: "ダウンロードとアップロード速度をリアルタイム表示", ko: "실시간 다운로드 및 업로드 속도")
        case .novel:
            return LocalizedString.l(settings.language, en: "Compact novel reader entry", zh: "显示小说阅读入口", ja: "小説リーダーへの入口を表示", ko: "소설 읽기 입구 표시")
        case .english:
            return LocalizedString.l(settings.language, en: "Current word or spoken sentence", zh: "显示当前单词或正在朗读的句子", ja: "現在の単語または読み上げ中の文を表示", ko: "현재 단어나 읽는 문장 표시")
        }
    }
}

// MARK: - Components

private struct SettingsRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(label)
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct LinkRow: View {
    let icon: String
    let label: String
    let url: URL

    @Environment(\.openURL) private var openURL
    @State private var isHovering = false

    var body: some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.accentColor.opacity(0.08) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .cursor(.pointingHand)
    }
}

// MARK: - Cursor Modifier

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Data

private enum AppLinks {
    static let repository = URL(string: "https://github.com/kuaoaoaoao/coolRun")!
    static let releases = URL(string: "https://github.com/kuaoaoaoao/coolRun/releases")!
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
