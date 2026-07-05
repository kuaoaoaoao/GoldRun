#if os(macOS)
import AppKit
import SwiftUI
import Combine

@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let contextPopover = NSPopover()
    private let viewModel = SystemMonitorViewModel()
    private let goldPriceService = GoldPriceService()
    private let settings = AppSettings.shared
    private var windowCloseObserver: NSObjectProtocol?
    private var novelWindowController: NSWindowController?
    private var iconTimer: Timer?
    private var goldPriceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var coinPhase = 0.0
    private var goldPriceText = "--"
    private var isPopoverPinned = false
    private let goldPriceRefreshInterval: Duration = .seconds(30)
    private let iconFramesPerSecond = 30.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.imagePosition = .imageLeft
            button.image = CoinIconRenderer.image(phase: coinPhase)
            button.title = " \(goldPriceText)"
            button.action = #selector(handleStatusItemClick)
            button.target = self
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.toolTip = "打开 coolRun"
        }

        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: 284, height: 430)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarMonitorView(
                isPinned: Binding(
                    get: { [weak self] in self?.isPopoverPinned ?? false },
                    set: { [weak self] pinned in
                        self?.setPopoverPinned(pinned)
                    }
                )
            )
        )

        contextPopover.behavior = .transient
        contextPopover.animates = false
        contextPopover.contentSize = NSSize(width: 150, height: 112)
        contextPopover.contentViewController = NSHostingController(
            rootView: StatusContextMenuView(
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
    }

    // 监听设置变化
    private func observeSettingsChanges() {
        settings.$menuBarDisplayMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshIcon()
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        iconTimer?.invalidate()
        goldPriceTask?.cancel()
        GoldPriceStore.shared.flushToDisk()
        if let windowCloseObserver {
            NotificationCenter.default.removeObserver(windowCloseObserver)
        }
        viewModel.stop()
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
            if isPopoverPinned {
                setPopoverPinned(false)
            }
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Analytics.capture(.popoverOpened)
        }
    }

    private func setPopoverPinned(_ pinned: Bool) {
        isPopoverPinned = pinned
        popover.behavior = pinned ? .applicationDefined : .transient
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        }
        if contextPopover.isShown {
            contextPopover.performClose(nil)
        } else {
            contextPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func prepareToOpenSettings() {
        popover.performClose(nil)
        contextPopover.performClose(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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
        window.title = "小说阅读"
        window.setContentSize(NSSize(width: 820, height: 620))
        window.minSize = NSSize(width: 760, height: 560)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()

        let controller = NSWindowController(window: window)
        novelWindowController = controller
        controller.showWindow(nil)
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
        let timer = Timer.scheduledTimer(withTimeInterval: 1 / iconFramesPerSecond, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshIcon()
            }
        }
        timer.tolerance = 0.01
        iconTimer = timer
    }

    @MainActor
    private func refreshIcon() {
        let cpuUsage = min(max(viewModel.snapshot.cpu.usage, 0), 1)
        let revolutionsPerSecond = 0.35 + cpuUsage * 2.15
        coinPhase = (coinPhase + (.pi * 2 * revolutionsPerSecond / iconFramesPerSecond))
            .truncatingRemainder(dividingBy: .pi * 2)

        statusItem?.button?.image = CoinIconRenderer.image(phase: coinPhase)

        // 根据设置显示金价或日期
        let nextTitle: String
        switch settings.menuBarDisplayMode {
        case .goldPrice:
            nextTitle = " \(goldPriceText)"
        case .date:
            nextTitle = " \(menuBarDateText)"
        }

        if statusItem?.button?.title != nextTitle {
            statusItem?.button?.title = nextTitle
        }
    }

    // 菜单栏日期文本
    private var menuBarDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: settings.language == .english ? "en_US" : "zh_CN")
        return formatter.string(from: Date())
    }

    private func startGoldPriceUpdates() {
        goldPriceTask?.cancel()
        goldPriceTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshGoldPrice()
                try? await Task.sleep(for: self?.goldPriceRefreshInterval ?? .seconds(24 * 60 * 60))
            }
        }
    }

    private func refreshGoldPrice() async {
        do {
            let quote = try await goldPriceService.fetchCNYPerGram()
            goldPriceText = quote.cnyPerGram.goldPriceText
            GoldPriceStore.shared.addPrice(quote.cnyPerGram, timestamp: quote.updatedAt)
            Analytics.capture(.goldPriceFetched, properties: [
                "price_cny_per_gram": quote.cnyPerGram,
            ], minimumInterval: 60 * 60)
        } catch {
            if goldPriceText == "--" {
                goldPriceText = goldPriceFallbackText(for: error)
            }
            Analytics.capture(.goldPriceFetchFailed, properties: [
                "error_type": String(describing: type(of: error)),
            ])
        }
        refreshIcon()
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
    let openNovelReader: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: openNovelReader) {
                Label("小说阅读", systemImage: "books.vertical")
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
        .frame(width: 150)
        .background(Color(nsColor: .windowBackgroundColor))
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
#endif
