import SwiftUI

// MARK: - 视图模式

enum ViewMode: String, CaseIterable {
    case monitor
    case gold
    case calendar
    case novel
    case english

    var icon: String {
        switch self {
        case .monitor: return "chart.bar.fill"
        case .gold: return "chart.line.uptrend.xyaxis"
        case .calendar: return "calendar"
        case .novel: return "book.pages"
        case .english: return "character.book.closed"
        }
    }

    var displayName: String {
        switch self {
        case .monitor: return LocalizedString.calendar("monitor")
        case .gold: return LocalizedString.goldPrice("gold_price")
        case .calendar: return LocalizedString.calendar("calendar")
        case .novel: return LocalizedString.novel("novel")
        case .english: return LocalizedString.english("english")
        }
    }
}

struct ContentView: View {
    @State private var viewModel = SystemMonitorViewModel()
    @State private var viewMode: ViewMode = .monitor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // 视图切换标签
            viewModePicker

            // 内容区域
            switch viewMode {
            case .monitor:
                MonitorPanel(
                    snapshot: viewModel.snapshot,
                    cpuHistory: viewModel.cpuHistory,
                    memoryHistory: viewModel.memoryHistory,
                    downloadHistory: viewModel.downloadHistory,
                    uploadHistory: viewModel.uploadHistory,
                    cpuTempHistory: viewModel.cpuTempHistory,
                    gpuTempHistory: viewModel.gpuTempHistory
                )
            case .gold:
                GoldAnalysisView()
            case .calendar:
                CalendarView()
            case .novel:
                MenuBarNovelReaderView()
            case .english:
                EnglishLearningView()
            }
        }
        .padding(8)
        .background {
            ZStack {
                VisualEffectBlur(material: colorScheme == .dark ? .hudWindow : .menu, blendingMode: .behindWindow)
                if colorScheme == .light {
                    Color.white.opacity(0.3)
                } else {
                    Color.black.opacity(0.2)
                }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - 视图切换标签

    private var viewModePicker: some View {
        HStack(spacing: 4) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = mode
                    }
                    Analytics.capture(.viewTabSwitched, properties: [
                        "tab": mode.rawValue,
                    ])
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(mode.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(viewMode == mode ? AppTheme.healthy : AppTheme.textSecondary(colorScheme))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background {
                        if viewMode == mode {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppTheme.healthy.opacity(0.15))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        }
        .padding(.bottom, 6)
    }
}

struct MonitorPanel: View {
    let snapshot: SystemSnapshot
    var cpuHistory: MetricHistory = MetricHistory()
    var memoryHistory: MetricHistory = MetricHistory()
    var downloadHistory: MetricHistory = MetricHistory()
    var uploadHistory: MetricHistory = MetricHistory()
    var cpuTempHistory: MetricHistory = MetricHistory()
    var gpuTempHistory: MetricHistory = MetricHistory()
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            if settings.showCPU {
                CPUSection(
                    metrics: snapshot.cpu,
                    temperature: snapshot.temperature,
                    history: cpuHistory
                )
            }

            if settings.showMemory {
                if settings.showCPU { Separator() }
                MemorySection(
                    metrics: snapshot.memory,
                    history: memoryHistory
                )
            }

            if settings.showStorage {
                if settings.showCPU || settings.showMemory { Separator() }
                StorageSection(metrics: snapshot.storage)
            }

            if settings.showBattery {
                if settings.showCPU || settings.showMemory || settings.showStorage { Separator() }
                BatterySection(metrics: snapshot.battery)
            }

            if settings.showNetwork {
                if settings.showCPU || settings.showMemory || settings.showStorage || settings.showBattery { Separator() }
                NetworkSection(
                    metrics: snapshot.network,
                    downloadHistory: downloadHistory,
                    uploadHistory: uploadHistory
                )
            }

            if settings.showUptime {
                if settings.showCPU || settings.showMemory || settings.showStorage || settings.showBattery || settings.showNetwork { Separator() }
                UptimeSection(metrics: snapshot.uptime)
            }
        }
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: colorScheme == .dark ? .black.opacity(0.2) : .black.opacity(0.08), radius: 10, y: 4)
    }
}

// MARK: - 可折叠的 Section 组件

private struct CollapsibleSection<Header: View, Content: View>: View {
    let icon: String
    let title: String
    let value: String
    var healthColor: Color? = nil
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // 标题行 - 整行可点击
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(healthColor ?? AppTheme.icon(colorScheme))
                    .frame(width: 20)

                Text(title)
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    .font(.system(size: 11, weight: .medium))
                    .layoutPriority(1)

                Spacer(minLength: 4)

                header()
                    .layoutPriority(2)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme).opacity(0.6))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // 展开内容
            if isExpanded {
                VStack(spacing: 2) {
                    content()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - 各个监控区域

private struct CPUSection: View {
    let metrics: CPUMetrics
    let temperature: TemperatureMetrics
    var history: MetricHistory = MetricHistory()
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        CollapsibleSection(
            icon: "cpu",
            title: LocalizedString.monitor("cpu", lang: settings.language),
            value: metrics.usage.percentText,
            healthColor: AppTheme.healthColor(for: metrics.usage)
        ) {
            // 标题行右侧内容
            HStack(spacing: 6) {
                MiniBar(value: metrics.usage, tint: AppTheme.healthColor(for: metrics.usage))
                    .frame(width: 40, height: 10)
                Text(metrics.usage.percentText)
                    .foregroundStyle(AppTheme.healthColor(for: metrics.usage))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        } content: {
            MetricRow(label: LocalizedString.monitor("core_count", lang: settings.language), value: "\(metrics.coreCount)")
            if let temp = temperature.cpuTemperature {
                MetricRow(label: LocalizedString.monitor("cpu_temp", lang: settings.language), value: String(format: "%.1f°C", temp))
            }
            if let gpuTemp = temperature.gpuTemperature {
                MetricRow(label: LocalizedString.monitor("gpu_temp", lang: settings.language), value: String(format: "%.1f°C", gpuTemp))
            }
            SparklineChart(values: history.values, color: AppTheme.healthColor(for: metrics.usage))
                .frame(height: 20)
                .padding(.top, 2)
        }
    }
}

private struct MemorySection: View {
    let metrics: MemoryMetrics
    var history: MetricHistory = MetricHistory()
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        CollapsibleSection(
            icon: "memorychip",
            title: LocalizedString.monitor("memory", lang: settings.language),
            value: metrics.usage.percentText,
            healthColor: AppTheme.healthColor(for: metrics.usage)
        ) {
            HStack(spacing: 6) {
                MiniBar(value: metrics.usage, tint: AppTheme.healthColor(for: metrics.usage))
                    .frame(width: 40, height: 10)
                Text(metrics.usage.percentText)
                    .foregroundStyle(AppTheme.healthColor(for: metrics.usage))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        } content: {
            MetricRow(label: LocalizedString.monitor("used", lang: settings.language), value: metrics.used.memoryText)
            MetricRow(label: LocalizedString.monitor("total", lang: settings.language), value: metrics.total.memoryText)
            MetricRow(label: LocalizedString.monitor("pressure", lang: settings.language), value: memoryPressureText)
            SparklineChart(values: history.values, color: AppTheme.healthColor(for: metrics.usage))
                .frame(height: 20)
                .padding(.top, 2)
        }
    }

    private var memoryPressureText: String {
        switch metrics.usage {
        case 0..<0.6: LocalizedString.memoryPressure("low", lang: settings.language)
        case 0..<0.82: LocalizedString.memoryPressure("medium", lang: settings.language)
        default: LocalizedString.memoryPressure("high", lang: settings.language)
        }
    }
}

private struct StorageSection: View {
    let metrics: StorageMetrics
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        CollapsibleSection(icon: "externaldrive", title: LocalizedString.monitor("storage", lang: settings.language), value: metrics.usage.percentText) {
            HStack(spacing: 6) {
                ProgressPill(value: metrics.usage, tint: .blue)
                    .frame(width: 40, height: 4)
                Text(metrics.usage.percentText)
                    .foregroundStyle(AppTheme.textPrimary(colorScheme))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
        } content: {
            MetricRow(label: LocalizedString.monitor("used", lang: settings.language), value: metrics.used.storageText)
            MetricRow(label: LocalizedString.monitor("available", lang: settings.language), value: metrics.available.storageText)
        }
    }
}

private struct BatterySection: View {
    let metrics: BatteryMetrics
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        CollapsibleSection(icon: batteryIcon, title: LocalizedString.monitor("battery", lang: settings.language), value: levelText) {
            Text(levelText)
                .foregroundStyle(batteryColor)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        } content: {
            MetricRow(label: LocalizedString.monitor("status", lang: settings.language), value: batteryStateText)
            MetricRow(label: LocalizedString.monitor("low_power", lang: settings.language), value: metrics.isLowPowerModeEnabled ? LocalizedString.label("on", lang: settings.language) : LocalizedString.label("off", lang: settings.language))
        }
    }

    private var batteryStateText: String {
        switch metrics.state {
        case .unknown: return LocalizedString.batteryState("unknown", lang: settings.language)
        case .unplugged: return LocalizedString.batteryState("unplugged", lang: settings.language)
        case .charging: return LocalizedString.batteryState("charging", lang: settings.language)
        case .full: return LocalizedString.batteryState("full", lang: settings.language)
        case .noBattery: return LocalizedString.batteryState("no_battery", lang: settings.language)
        }
    }

    private var levelText: String {
        guard let level = metrics.level else { return "--" }
        return level.percentText
    }

    @Environment(\.colorScheme) private var colorScheme

    private var batteryColor: Color {
        guard let level = metrics.level else { return AppTheme.textSecondary(colorScheme) }
        if metrics.state == .charging { return .blue }
        return level < 0.2 ? AppTheme.critical : AppTheme.healthy
    }

    private var batteryIcon: String {
        switch metrics.state {
        case .charging: "battery.100.bolt"
        case .full: "battery.100"
        case .unplugged: "battery.50"
        case .noBattery, .unknown: "battery.0"
        }
    }
}

private struct NetworkSection: View {
    let metrics: NetworkMetrics
    var downloadHistory: MetricHistory = MetricHistory()
    var uploadHistory: MetricHistory = MetricHistory()
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        CollapsibleSection(icon: "network", title: LocalizedString.monitor("network", lang: settings.language), value: networkName) {
            if metrics.downloadSpeed > 0 || metrics.uploadSpeed > 0 {
                Text("↓\(formatSpeed(metrics.downloadSpeed))")
                    .foregroundStyle(.blue)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
        } content: {
            MetricRow(label: LocalizedString.monitor("local_ip", lang: settings.language), value: localAddressText)
            MetricRow(label: LocalizedString.monitor("interfaces", lang: settings.language), value: metrics.activeInterfaceCount > 0 ? "\(metrics.activeInterfaceCount)" : "--")
            if metrics.downloadSpeed > 0 || metrics.uploadSpeed > 0 {
                MetricRow(label: "↓ \(LocalizedString.monitor("download", lang: settings.language))", value: formatSpeed(metrics.downloadSpeed))
                MetricRow(label: "↑ \(LocalizedString.monitor("upload", lang: settings.language))", value: formatSpeed(metrics.uploadSpeed))
                DualSparklineChart(
                    values1: downloadHistory.values,
                    values2: uploadHistory.values,
                    color1: .blue,
                    color2: .green
                )
                .frame(height: 20)
                .padding(.top, 2)
            }
        }
    }

    private var networkName: String {
        metrics.activeInterfaceCount > 0 ? LocalizedString.monitor("connected", lang: settings.language) : LocalizedString.monitor("disconnected", lang: settings.language)
    }

    private var localAddressText: String {
        metrics.primaryAddress ?? "--"
    }

    private func formatSpeed(_ bytesPerSecond: UInt64) -> String {
        if bytesPerSecond < 1024 {
            return "\(bytesPerSecond) B/s"
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", Double(bytesPerSecond) / 1024.0)
        } else {
            return String(format: "%.1f MB/s", Double(bytesPerSecond) / (1024.0 * 1024.0))
        }
    }
}

private struct UptimeSection: View {
    let metrics: UptimeMetrics
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        CollapsibleSection(icon: "clock", title: LocalizedString.monitor("uptime", lang: settings.language), value: metrics.compactFormatted) {
            Text(metrics.compactFormatted)
                .foregroundStyle(AppTheme.textPrimary(colorScheme).opacity(0.8))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 50, alignment: .trailing)
        } content: {
            MetricRow(label: LocalizedString.monitor("running_time", lang: settings.language), value: metrics.formatted)
        }
    }
}

// MARK: - 基础组件

private struct MetricRow: View {
    let label: String
    let value: String
    @State private var isCopied = false
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .font(.system(size: 10, weight: .medium))
            Spacer(minLength: 4)
            Text(value)
                .foregroundStyle(isCopied ? AppTheme.healthy : AppTheme.textPrimary(colorScheme).opacity(0.85))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { copyToClipboard() }
        .help(LocalizedString.label("copy_hint", lang: settings.language))
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(label): \(value)", forType: .string)
        withAnimation(.easeInOut(duration: 0.3)) { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) { isCopied = false }
        }
    }
}

struct Separator: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(AppTheme.separator(colorScheme))
            .frame(height: 0.5)
            .padding(.horizontal, 12)
    }
}

// MARK: - 趋势图表

private struct SparklineChart: View {
    let values: [Double]
    var color: Color = .blue
    var showGradient: Bool = true

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }

            let maxValue = values.max() ?? 1.0
            let minValue = values.min() ?? 0.0
            let range = maxValue - minValue
            let normalizedMax = range > 0 ? range : 1.0

            let stepX = size.width / CGFloat(values.count - 1)
            let padding: CGFloat = 1
            let drawHeight = size.height - padding * 2

            var path = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let normalized = (value - minValue) / normalizedMax
                let y = size.height - padding - CGFloat(normalized) * drawHeight
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            if showGradient {
                var fillPath = path
                fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                fillPath.addLine(to: CGPoint(x: 0, y: size.height))
                fillPath.closeSubpath()
                let gradient = Gradient(colors: [color.opacity(0.25), color.opacity(0.02)])
                context.fill(fillPath, with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
            }

            context.stroke(path, with: .color(color), lineWidth: 1.2)

            if let lastValue = values.last {
                let lastX = size.width
                let normalized = (lastValue - minValue) / normalizedMax
                let lastY = size.height - padding - CGFloat(normalized) * drawHeight
                let pointRect = CGRect(x: lastX - 2, y: lastY - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: pointRect), with: .color(color))
            }
        }
    }
}

private struct DualSparklineChart: View {
    let values1: [Double]
    let values2: [Double]
    var color1: Color = .blue
    var color2: Color = .green

    var body: some View {
        Canvas { context, size in
            let allValues = values1 + values2
            guard allValues.count >= 2 else { return }

            let maxValue = allValues.max() ?? 1.0
            let minValue = allValues.min() ?? 0.0
            let range = maxValue - minValue
            let normalizedMax = range > 0 ? range : 1.0
            let padding: CGFloat = 1
            let drawHeight = size.height - padding * 2

            if values1.count >= 2 {
                drawLine(context: context, size: size, values: values1, color: color1, minValue: minValue, normalizedMax: normalizedMax, padding: padding, drawHeight: drawHeight)
            }
            if values2.count >= 2 {
                drawLine(context: context, size: size, values: values2, color: color2, minValue: minValue, normalizedMax: normalizedMax, padding: padding, drawHeight: drawHeight)
            }
        }
    }

    private func drawLine(context: GraphicsContext, size: CGSize, values: [Double], color: Color, minValue: Double, normalizedMax: Double, padding: CGFloat, drawHeight: CGFloat) {
        let stepX = size.width / CGFloat(values.count - 1)
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * stepX
            let normalized = (value - minValue) / normalizedMax
            let y = size.height - padding - CGFloat(normalized) * drawHeight
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.2)
    }
}

// MARK: - 进度条组件

private struct MiniBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                let columns = 16
                for index in 0..<columns {
                    let phase = Double(index) / Double(columns)
                    let dynamic = 0.3 + abs(sin((phase + value) * .pi * 2.2)) * 0.7
                    let barHeight = max(1.5, height * dynamic * max(0.2, value))
                    let x = width * Double(index) / Double(columns)
                    path.addRect(CGRect(x: x, y: height - barHeight, width: max(1.5, width / Double(columns) - 1.5), height: barHeight))
                }
            }
            .fill(tint.opacity(0.7))
        }
    }
}

private struct ProgressPill: View {
    let value: Double
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.progressBg(colorScheme))
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(2, proxy.size.width * min(max(value, 0), 1)))
            }
        }
    }
}

// MARK: - 毛玻璃效果

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - 主题

enum AppTheme {
    // 健康状态颜色 - 深浅模式通用
    static let healthy = Color(red: 0.2, green: 0.78, blue: 0.4)
    static let warning = Color(red: 0.95, green: 0.65, blue: 0.15)
    static let critical = Color(red: 0.95, green: 0.3, blue: 0.3)

    static func healthColor(for usage: Double) -> Color {
        switch usage {
        case ..<0.6: return healthy
        case ..<0.85: return warning
        default: return critical
        }
    }

    // 根据 colorScheme 返回对应颜色
    static func icon(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.7)
    }

    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white : Color.black.opacity(0.9)
    }

    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.65) : Color.black.opacity(0.55)
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.08)
    }

    static func progressBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
}

// MARK: - 格式化扩展

private extension Double {
    var percentText: String {
        (self * 100).formatted(.number.precision(.fractionLength(1))) + "%"
    }
}

private extension UInt64 {
    var memoryText: String {
        ByteCountFormatter.memoryFormatter.string(fromByteCount: Int64(self))
    }
    var storageText: String {
        ByteCountFormatter.storageFormatter.string(fromByteCount: Int64(self))
    }
}

private extension ByteCountFormatter {
    static let memoryFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB]
        f.countStyle = .memory
        f.includesUnit = true
        f.isAdaptive = true
        return f
    }()
    static let storageFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB, .useKB]
        f.countStyle = .file
        f.includesUnit = true
        f.isAdaptive = true
        return f
    }()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 220, height: 360)
    }
}
