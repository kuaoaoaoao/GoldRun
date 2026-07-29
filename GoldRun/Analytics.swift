import Foundation
import OSLog
import PostHog

enum AnalyticsEvent: String {
    case appLaunched = "app_launched"
    case popoverOpened = "popover_opened"
    case settingsOpened = "settings_opened"
    case goldPriceFetched = "gold_price_fetched"
    case goldPriceFetchFailed = "gold_price_fetch_failed"
    case viewTabSwitched = "view_tab_switched"
    case languageChanged = "language_changed"
    case menuBarDisplayModeChanged = "menu_bar_display_mode_changed"
    case holidayDataUpdated = "holiday_data_updated"
    case goldPositionAnalyzed = "gold_position_analyzed"
}

enum Analytics {
    private static let logger = Logger(subsystem: "GoldRun", category: "Analytics")
    private static let state = AnalyticsState()
    private static let disabledEnvironmentKey = "POSTHOG_DISABLED"
    private static let sensitivePropertyKeys: Set<String> = [
        "error_message",
        "profit_loss",
        "profit_percent",
    ]

    static var isConfigured: Bool {
        isEnvironmentEnabled && state.isConfigured
    }

    static func configure(projectToken: String, host: String, enabled: Bool) {
        guard isEnvironmentEnabled else {
            logger.info("PostHog analytics disabled by environment")
            return
        }

        let trimmedProjectToken = projectToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProjectToken.isEmpty else {
            logger.info("PostHog analytics not configured for this build")
            return
        }
        guard trimmedProjectToken.hasPrefix("phc_") else {
            logger.error("PostHog setup skipped because the project token format is invalid")
            return
        }

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let hostURL = URL(string: trimmedHost),
              let scheme = hostURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              hostURL.host?.isEmpty == false else {
            logger.error("PostHog setup skipped because the host URL is invalid")
            return
        }

        let config = PostHogConfig(projectToken: trimmedProjectToken, host: trimmedHost)
        // 只发送本文件中明确列出的事件，避免 SDK 自动采集超出隐私说明的生命周期数据。
        config.captureApplicationLifecycleEvents = false
        config.optOut = !enabled
        PostHogSDK.shared.setup(config)
        state.markConfigured()

        if enabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }

    static func setEnabled(_ enabled: Bool) {
        guard isConfigured else { return }
        if enabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }

    static func capture(
        _ event: AnalyticsEvent,
        properties: [String: Any] = [:],
        minimumInterval: TimeInterval? = nil
    ) {
        guard isEnvironmentEnabled,
              AppSettings.shared.analyticsEnabled,
              state.isConfigured else { return }
        guard state.shouldCapture(event, minimumInterval: minimumInterval) else { return }

        PostHogSDK.shared.capture(event.rawValue, properties: sanitized(properties))
    }

    private static var isEnvironmentEnabled: Bool {
        ProcessInfo.processInfo.environment[disabledEnvironmentKey] != "1"
    }

    private static func sanitized(_ properties: [String: Any]) -> [String: Any] {
        properties.reduce(into: [:]) { result, pair in
            guard !sensitivePropertyKeys.contains(pair.key),
                  let value = sanitizedValue(pair.value) else { return }
            result[pair.key] = value
        }
    }

    private static func sanitizedValue(_ value: Any) -> Any? {
        switch value {
        case let string as String:
            return string
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let double as Double:
            return double.isFinite ? double : nil
        case let float as Float:
            return float.isFinite ? float : nil
        default:
            return nil
        }
    }
}

private final class AnalyticsState: @unchecked Sendable {
    private let lock = NSLock()
    private var configured = false
    private var lastCapturedAt: [AnalyticsEvent: Date] = [:]

    var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return configured
    }

    func markConfigured() {
        lock.lock()
        configured = true
        lock.unlock()
    }

    func shouldCapture(_ event: AnalyticsEvent, minimumInterval: TimeInterval?) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        if let minimumInterval,
           let lastCaptured = lastCapturedAt[event],
           now.timeIntervalSince(lastCaptured) < minimumInterval {
            return false
        }

        lastCapturedAt[event] = now
        return true
    }
}
