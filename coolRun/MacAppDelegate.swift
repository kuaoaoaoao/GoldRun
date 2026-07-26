#if os(macOS)
import AppKit
import SwiftUI
import Combine

@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let contextPopover = NSPopover()
    private let viewModel = SystemMonitorViewModel()
    private let codexViewModel = CodexMonitorViewModel.shared
    private let goldPriceService = GoldPriceService()
    private let settings = AppSettings.shared
    private let englishLearning = EnglishLearningManager.shared
    private var windowCloseObserver: NSObjectProtocol?
    private var novelWindowController: NSWindowController?
    private var textbookWindowController: NSWindowController?
    private var iconTimer: Timer?
    private var goldPriceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var coinPhase = 0.0
    private var goldPriceText = "--"
    private let popoverPinState = PopoverPinState()
    private var allowsPopoverClose = false
    private var activeAnimationFramesPerSecond: Double?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.imagePosition = .imageLeft
            button.image = CoinIconRenderer.image(phase: coinPhase)
            button.font = Self.statusTitleFont
            button.lineBreakMode = .byTruncatingTail
            button.title = " \(goldPriceText)"
            button.action = #selector(handleStatusItemClick)
            button.target = self
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.toolTip = LocalizedString.menuBar("open_coolrun")
        }
        updateStatusItemLength()

        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentSize = NSSize(width: 336, height: 528)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarMonitorView(
                viewModel: viewModel,
                pinState: popoverPinState,
                onPinChange: { [weak self] pinned in
                    self?.setPopoverPinned(pinned)
                }
            )
        )

        contextPopover.behavior = .transient
        contextPopover.animates = false
        contextPopover.contentSize = NSSize(width: 216, height: 264)
        contextPopover.contentViewController = NSHostingController(
            rootView: StatusContextMenuView(
                toggleEnglishPlayback: { [weak self] in
                    self?.toggleEnglishPlaybackFromContextMenu()
                },
                previousEnglishItem: { [weak self] in
                    self?.englishLearning.previous()
                },
                nextEnglishItem: { [weak self] in
                    self?.englishLearning.next()
                },
                stopEnglishPlayback: { [weak self] in
                    self?.englishLearning.stop()
                },
                selectDisplayMode: { [weak self] mode in
                    self?.selectDisplayModeFromContextMenu(mode)
                },
                openNovelReader: { [weak self] in
                    self?.openNovelReaderFromContextMenu()
                },
                openSettings: { [weak self] in
                    self?.openSettingsFromContextMenu()
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )
        )

        observeSettingsWindowLifecycle()
        observeSettingsChanges()
        viewModel.start()
        startIconAnimation()
        startGoldPriceUpdates()

        Analytics.capture(.appLaunched, properties: AnalyticsDeviceProperties.launchProperties)

        // 启动后台自动检查更新
        UpdateChecker.shared.startAutoCheck()
    }

    // 监听设置变化
    private func observeSettingsChanges() {
        settings.$menuBarDisplayMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemLength()
                self?.refreshIcon()
            }
            .store(in: &cancellables)

        settings.$language
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusItem?.button?.toolTip = LocalizedString.menuBar("open_coolrun")
                self?.refreshIcon()
            }
            .store(in: &cancellables)

        settings.$menuBarAnimationRate
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.startIconAnimation()
            }
            .store(in: &cancellables)

        settings.$goldRefreshRate
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.startGoldPriceUpdates()
            }
            .store(in: &cancellables)

        settings.$englishMenuTextStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshIcon() }
            .store(in: &cancellables)

        englishLearning.$currentItem
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshIcon() }
            .store(in: &cancellables)

        englishLearning.$currentSpokenText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshIcon() }
            .store(in: &cancellables)

        englishLearning.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshIcon() }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        iconTimer?.invalidate()
        goldPriceTask?.cancel()
        englishLearning.stop()
        GoldPriceStore.shared.flushToDisk()
        UpdateChecker.shared.stopAutoCheck()
        if let windowCloseObserver {
            NotificationCenter.default.removeObserver(windowCloseObserver)
        }
        viewModel.stop()
        codexViewModel.stop()
    }

    @objc private func handleStatusItemClick() {
        switch NSApp.currentEvent?.type {
        case .rightMouseUp, .rightMouseDown:
            showContextMenu()
        default:
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if contextPopover.isShown {
            contextPopover.performClose(nil)
        }

        if popover.isShown {
            if popoverPinState.isPinned {
                // pin 状态下点图标也给反馈：解除 pin 并收起弹窗，而不是无响应
                closeMonitorPopover(unpin: true)
                return
            }
            closeMonitorPopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Analytics.capture(.popoverOpened)
        }
    }

    private func setPopoverPinned(_ pinned: Bool) {
        popoverPinState.isPinned = pinned
        popover.behavior = pinned ? .applicationDefined : .transient
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }

        // pin 状态下也先关掉主弹窗（临时解除 pin），避免两个弹窗重叠
        if popover.isShown {
            closeMonitorPopover(unpin: true)
        }
        if contextPopover.isShown {
            contextPopover.performClose(nil)
        } else {
            contextPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func prepareToOpenSettings() {
        closeMonitorPopover(unpin: true)
        contextPopover.performClose(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeMonitorPopover(unpin: Bool = false) {
        guard popover.isShown else {
            if unpin {
                setPopoverPinned(false)
            }
            return
        }

        if unpin {
            setPopoverPinned(false)
        }

        allowsPopoverClose = true
        popover.performClose(nil)
        allowsPopoverClose = false
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        guard popover === self.popover else { return true }
        return allowsPopoverClose || !popoverPinState.isPinned
    }

    func popoverDidClose(_ notification: Notification) {
        guard
            let closedPopover = notification.object as? NSPopover,
            closedPopover === popover,
            popoverPinState.isPinned
        else {
            return
        }

        setPopoverPinned(false)
    }

    private func openSettingsFromContextMenu() {
        prepareToOpenSettings()
        Analytics.capture(.settingsOpened)
    }

    private func openNovelReaderFromContextMenu() {
        prepareToOpenSettings()
        Analytics.capture(.novelReaderOpened)

        if let window = novelWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: NovelLibraryView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = LocalizedString.novel("novel_reader")
        window.setContentSize(NSSize(width: 820, height: 620))
        window.minSize = NSSize(width: 760, height: 560)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()

        let controller = NSWindowController(window: window)
        novelWindowController = controller
        controller.showWindow(nil)
    }

    // 课本管理面板 660x520，不能在 320pt 弹窗里用 sheet 弹出，改用独立窗口（同小说书库）
    func openEnglishTextbookManagerWindow() {
        prepareToOpenSettings()

        if let window = textbookWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: EnglishTextbookManagementView(onRequestClose: { [weak self] in
            self?.textbookWindowController?.window?.close()
        }))
        let window = NSWindow(contentViewController: hostingController)
        window.title = LocalizedString.english("textbook_management")
        window.setContentSize(NSSize(width: 660, height: 520))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()

        let controller = NSWindowController(window: window)
        textbookWindowController = controller
        controller.showWindow(nil)
    }

    private func toggleEnglishPlaybackFromContextMenu() {
        contextPopover.performClose(nil)
        englishLearning.toggleContinuousPlayback()
    }

    private func selectDisplayModeFromContextMenu(_ mode: MenuBarDisplayMode) {
        settings.menuBarDisplayMode = mode
        refreshIcon()
        Analytics.capture(.menuBarDisplayModeChanged, properties: [
            "mode": mode.rawValue,
            "source": "context_menu",
        ])
    }

    private func observeSettingsWindowLifecycle() {
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.hideDockIconIfNoWindowsRemain()
            }
        }
    }

    private func hideDockIconIfNoWindowsRemain() {
        DispatchQueue.main.async {
            let hasVisibleWindow = NSApp.windows.contains { window in
                window.isVisible && window.canBecomeKey
            }

            if !hasVisibleWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    private func startIconAnimation() {
        iconTimer?.invalidate()
        activeAnimationFramesPerSecond = settings.menuBarAnimationRate.framesPerSecond

        if activeAnimationFramesPerSecond == nil {
            coinPhase = 0
            statusItem?.button?.image = CoinIconRenderer.image(phase: coinPhase)
        }

        // 动画关闭时仍以 1Hz 更新日期、CPU、内存和网速文本。
        let timerFrequency = activeAnimationFramesPerSecond ?? 1
        let timer = Timer.scheduledTimer(withTimeInterval: 1 / timerFrequency, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshIcon()
            }
        }
        timer.tolerance = min(0.05, 0.25 / timerFrequency)
        iconTimer = timer
        refreshIcon()
    }

    @MainActor
    private func refreshIcon() {
        if let framesPerSecond = activeAnimationFramesPerSecond {
            let cpuUsage = min(max(viewModel.snapshot.cpu.usage, 0), 1)
            let revolutionsPerSecond = 0.35 + cpuUsage * 2.15
            coinPhase = (coinPhase + (.pi * 2 * revolutionsPerSecond / framesPerSecond))
                .truncatingRemainder(dividingBy: .pi * 2)
            statusItem?.button?.image = CoinIconRenderer.image(phase: coinPhase)
        }

        // 根据设置显示菜单栏标题，保持每种模式都有固定宽度上限。
        let nextTitle: String
        switch settings.menuBarDisplayMode {
        case .goldPrice:
            nextTitle = " \(goldPriceText)"
        case .date:
            nextTitle = " \(menuBarDateText)"
        case .cpu:
            nextTitle = " CPU \(percentageText(viewModel.snapshot.cpu.usage))"
        case .memory:
            nextTitle = " MEM \(percentageText(viewModel.snapshot.memory.usage))"
        case .network:
            let network = viewModel.snapshot.network
            nextTitle = " ↓\(compactNetworkSpeedText(network.downloadSpeed)) ↑\(compactNetworkSpeedText(network.uploadSpeed))"
        case .novel:
            nextTitle = " \(LocalizedString.novel("novel", lang: settings.language))"
        case .english:
            let playback = englishLearning.state == .playing ? " ▶" : ""
            nextTitle = " \(compactStatusText(englishLearning.menuBarText, limit: 12))\(playback)"
        case .codex:
            nextTitle = " \(codexMenuBarText)"
        }

        let compactTitle = compactStatusText(nextTitle, limit: statusTitleLimit)
        if statusItem?.button?.title != compactTitle {
            statusItem?.button?.title = compactTitle
        }
        updateStatusItemLength(for: compactTitle)
    }

    // 菜单栏日期文本
    private var menuBarDateText: String {
        let formatter = DateFormatter()
        formatter.locale = settings.language.locale
        switch settings.language {
        case .chinese:
            formatter.dateFormat = "M/d E"
        case .japanese:
            formatter.dateFormat = "M/d E"
        case .korean:
            formatter.dateFormat = "M/d E"
        case .english:
            formatter.dateFormat = "MMM d E"
        }
        return formatter.string(from: Date())
    }

    private func percentageText(_ value: Double) -> String {
        String(format: "%.0f%%", min(max(value, 0), 1) * 100)
    }

    private func networkSpeedText(_ bytesPerSecond: UInt64) -> String {
        Self.networkSpeedFormatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }

    private func compactNetworkSpeedText(_ bytesPerSecond: UInt64) -> String {
        let value = Double(bytesPerSecond)
        if value >= 1024 * 1024 {
            return String(format: "%.1fM", value / 1024 / 1024)
        }
        if value >= 1024 {
            return String(format: "%.0fK", value / 1024)
        }
        return "\(bytesPerSecond)B"
    }

    private func compactStatusText(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let prefix = text.prefix(max(limit - 1, 1))
        return "\(prefix)…"
    }

    private var statusTitleLimit: Int {
        switch settings.menuBarDisplayMode {
        case .goldPrice: return 18
        case .date: return 12
        case .cpu, .memory: return 8
        case .network: return 14
        case .novel: return 5
        case .english: return 14
        case .codex: return 10
        }
    }

    private func updateStatusItemLength(for title: String? = nil) {
        guard let button = statusItem?.button else { return }
        let displayTitle = title ?? button.title
        let titleWidth = displayTitle.size(withAttributes: [.font: button.font ?? Self.statusTitleFont]).width
        let imageWidth = button.image.map { $0.size.width + 4 } ?? 0
        let measuredLength = ceil(titleWidth + imageWidth + 14)
        let length = min(max(measuredLength, minimumStatusItemLength), maximumStatusItemLength)
        statusItem?.length = length
    }

    private var minimumStatusItemLength: CGFloat {
        switch settings.menuBarDisplayMode {
        case .goldPrice: return 76
        case .date: return 82
        case .cpu, .memory: return 72
        case .network: return 116
        case .novel: return 56
        case .english: return 92
        case .codex: return 76
        }
    }

    private var maximumStatusItemLength: CGFloat {
        switch settings.menuBarDisplayMode {
        case .goldPrice: return 132
        case .date: return 124
        case .cpu, .memory: return 84
        case .network: return 136
        case .novel: return 68
        case .english: return 142
        case .codex: return 104
        }
    }

    private var codexMenuBarText: String {
        guard case let .ready(snapshot) = codexViewModel.state,
              let window = snapshot.limits.first?.windows.first,
              let remaining = window.remainingPercent else {
            return "Codex"
        }
        return "Codex \(remaining)%"
    }

    private static let statusTitleFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize(for: .small),
        weight: .regular
    )

    private static let networkSpeedFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private func startGoldPriceUpdates() {
        goldPriceTask?.cancel()
        goldPriceTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshGoldPrice()
                let refreshInterval = self?.settings.goldRefreshRate.duration ?? .seconds(60)
                try? await Task.sleep(for: refreshInterval)
            }
        }
    }

    private func refreshGoldPrice() async {
        do {
            let quote = try await goldPriceService.fetchCNYPerGram()
            goldPriceText = Self.menuBarGoldText(for: quote)
            GoldPriceStore.shared.latestQuote = quote
            GoldPriceStore.shared.addPrice(quote.cnyPerGram, timestamp: quote.updatedAt, source: quote.source)
            GoldPriceStore.shared.checkFreshness()
            GoldPriceStore.shared.lastFetchFailed = false
            GoldPriceAlertManager.shared.handle(quote: quote)
            Analytics.capture(.goldPriceFetched, properties: [
                "price_cny_per_gram": quote.cnyPerGram,
            ], minimumInterval: 60 * 60)
        } catch {
            if goldPriceText == "--" {
                goldPriceText = goldPriceFallbackText(for: error)
            }
            // 失败路径也要刷新数据健康状态，避免旧数据一直显示"健康"
            GoldPriceStore.shared.checkFreshness()
            GoldPriceStore.shared.lastFetchFailed = true
            Analytics.capture(.goldPriceFetchFailed, properties: [
                "error_type": String(describing: type(of: error)),
            ])
        }
        refreshIcon()
    }

    // 分析页手动刷新入口（金价模块头部按钮调用）
    func refreshGoldPriceNow() async {
        await refreshGoldPrice()
    }

    private func goldPriceFallbackText(for error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("frequency") || message.contains("rate") || message.contains("call") {
            return LocalizedString.goldPrice("rate_limited")
        }
        if message.contains("internet") || message.contains("network") || message.contains("offline") {
            return LocalizedString.goldPrice("network_error")
        }
        return LocalizedString.goldPrice("parse_error")
    }
}

private struct StatusContextMenuView: View {
    let toggleEnglishPlayback: () -> Void
    let previousEnglishItem: () -> Void
    let nextEnglishItem: () -> Void
    let stopEnglishPlayback: () -> Void
    let selectDisplayMode: (MenuBarDisplayMode) -> Void
    let openNovelReader: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void
    @ObservedObject private var englishLearning = EnglishLearningManager.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            displayModePicker

            Divider()

            Button(action: toggleEnglishPlayback) {
                Label(
                    englishPlaybackTitle,
                    systemImage: englishLearning.state == .playing ? "pause.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: 32)

            Divider()

            HStack(spacing: 0) {
                contextButton(LocalizedString.common("previous", lang: settings.language), systemImage: "backward.end.fill", action: previousEnglishItem)
                contextButton(LocalizedString.common("next", lang: settings.language), systemImage: "forward.end.fill", action: nextEnglishItem)
                contextButton(LocalizedString.common("stop", lang: settings.language), systemImage: "stop.fill", action: stopEnglishPlayback)
            }
            .frame(height: 32)

            Divider()

            Button(action: openNovelReader) {
                Label(LocalizedString.novel("novel_reader", lang: settings.language), systemImage: "books.vertical")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: 32)

            Divider()

            SettingsLink()
                .simultaneousGesture(TapGesture().onEnded(openSettings))
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)

            Divider()

            Button(action: quit) {
                Label(LocalizedString.menuBar("quit"), systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: 32)
        }
        .padding(.vertical, 4)
        .frame(width: 216)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var displayModePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedString.menuBar("display_mode", lang: settings.language))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)

            LazyVGrid(columns: displayModeColumns, alignment: .leading, spacing: 4) {
                ForEach(MenuBarDisplayMode.allCases) { mode in
                    Button {
                        selectDisplayMode(mode)
                    } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(settings.menuBarDisplayMode == mode ? Color.accentColor : .secondary)
                            .frame(width: 28, height: 24)
                            .background {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(settings.menuBarDisplayMode == mode ? Color.accentColor.opacity(0.14) : Color.clear)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(mode.displayName(lang: settings.language))
                }
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 6)
    }

    private var displayModeColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(28), spacing: 4), count: 4)
    }

    private var englishPlaybackTitle: String {
        switch englishLearning.state {
        case .idle: return LocalizedString.menuBar("start_english", lang: settings.language)
        case .playing: return LocalizedString.menuBar("pause_english", lang: settings.language)
        case .paused: return LocalizedString.menuBar("resume_english", lang: settings.language)
        }
    }

    private func contextButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private enum CoinIconRenderer {
    static func image(phase: Double) -> NSImage {
        let size = NSSize(width: 24, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        let rotation = CGFloat(phase)
        let faceAmount = abs(cos(rotation))
        let width = 2.8 + 14.2 * faceAmount
        let height = 13.2
        let coinRect = NSRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )

        let coin = NSBezierPath(ovalIn: coinRect)
        NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.18, alpha: 1).setFill()
        coin.fill()

        NSColor(calibratedRed: 0.86, green: 0.48, blue: 0.05, alpha: 1).setStroke()
        coin.lineWidth = 1.4
        coin.stroke()

        if width > 6.6 {
            let inner = NSBezierPath(ovalIn: coinRect.insetBy(dx: 2.1, dy: 2.1))
            NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.08, alpha: 0.55).setStroke()
            inner.lineWidth = 0.9
            inner.stroke()

            let shine = NSBezierPath()
            shine.lineWidth = 1.0
            shine.lineCapStyle = .round
            NSColor.white.withAlphaComponent(0.75).setStroke()
            let shineOffset = sin(rotation) * width * 0.14
            shine.move(to: NSPoint(x: coinRect.midX - width * 0.20 + shineOffset, y: coinRect.midY + 3.1))
            shine.line(to: NSPoint(x: coinRect.midX + width * 0.10 + shineOffset, y: coinRect.midY + 3.8))
            shine.stroke()

            let symbol = "¥" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8.5, weight: .bold),
                .foregroundColor: NSColor(calibratedRed: 0.82, green: 0.42, blue: 0.02, alpha: 1)
            ]
            let symbolSize = symbol.size(withAttributes: attributes)
            symbol.draw(
                at: NSPoint(x: coinRect.midX - symbolSize.width / 2, y: coinRect.midY - symbolSize.height / 2),
                withAttributes: attributes
            )
        } else {
            let edge = NSBezierPath()
            edge.lineWidth = 1.8
            edge.lineCapStyle = .round
            NSColor(calibratedRed: 0.82, green: 0.42, blue: 0.02, alpha: 1).setStroke()
            edge.move(to: NSPoint(x: coinRect.midX, y: coinRect.minY + 1.4))
            edge.line(to: NSPoint(x: coinRect.midX, y: coinRect.maxY - 1.4))
            edge.stroke()
        }

        image.isTemplate = false
        return image
    }
}

private extension Double {
    var goldPriceText: String {
        "¥" + formatted(.number.precision(.fractionLength(2))) + "/g"
    }
}

private extension MacAppDelegate {
    // 金价模式菜单栏文本：有官方涨跌幅时附带展示，如 "¥886.16 -0.25%"
    static func menuBarGoldText(for quote: GoldPriceQuote) -> String {
        guard let rate = quote.changeRatePercent else {
            return quote.cnyPerGram.goldPriceText
        }
        let price = "¥" + quote.cnyPerGram.formatted(.number.precision(.fractionLength(2)))
        let percent = rate.formatted(.number.sign(strategy: .always()).precision(.fractionLength(2))) + "%"
        return "\(price) \(percent)"
    }
}
#endif
