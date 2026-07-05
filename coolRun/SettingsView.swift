import SwiftUI

// MARK: - 设置分类

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "general"
    case monitors = "monitors"
    case menubar = "menubar"
    case data = "data"
    case about = "about"

    var id: String { rawValue }

    func displayName(lang: AppLanguage) -> String {
        switch self {
        case .general: return lang == .english ? "General" : "通用"
        case .monitors: return lang == .english ? "Monitors" : "监控"
        case .menubar: return lang == .english ? "Menu Bar" : "菜单栏"
        case .data: return lang == .english ? "Data" : "数据"
        case .about: return lang == .english ? "About" : "关于"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .monitors: return "chart.bar.fill"
        case .menubar: return "menubar.rectangle"
        case .data: return "icloud.and.arrow.down"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared
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
        }
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
        }
    }

    // MARK: - 数据管理内容

    private var dataContent: some View {
        VStack(spacing: 16) {
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
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
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
