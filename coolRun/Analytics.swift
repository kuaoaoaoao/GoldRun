import Foundation
import OSLog
import PostHog

enum AnalyticsEvent: String {
    case appLaunched = "app_launched"
    case popoverOpened = "popover_opened"
    case settingsOpened = "settings_opened"
    case novelReaderOpened = "novel_reader_opened"
    case goldPriceFetched = "gold_price_fetched"
    case goldPriceFetchFailed = "gold_price_fetch_failed"
    case viewTabSwitched = "view_tab_switched"
    case novelOpened = "novel_opened"
    case novelImported = "novel_imported"
    case novelImportFailed = "novel_import_failed"
    case bookmarkAdded = "bookmark_added"
    case novelSpeechStarted = "novel_speech_started"
    case languageChanged = "language_changed"
    case menuBarDisplayModeChanged = "menu_bar_display_mode_changed"
    case holidayDataUpdated = "holiday_data_updated"
    case goldPositionAnalyzed = "gold_position_analyzed"
}

enum Analytics {
    private static let logger = Logger(subsystem: "coolRun", category: "Analytics")
    private static let state = AnalyticsState()
    private static let disabledEnvironmentKey = "POSTHOG_DISABLED"
    private static let sensitivePropertyKeys: Set<String> = [
        "book_title",
        "chapter_title",
        "error_message",
        "profit_loss",
        "profit_percent",
    ]

    static func configure(projectToken: String, host: String) {
        guard isEnabled else {
            logger.info("PostHog analytics disabled by environment")
            return
        }

        let trimmedProjectToken = projectToken.trimmingCharacters(in: .whitespacesAndNewlines)
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
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
        state.markConfigured()
    }

    static func capture(
        _ event: AnalyticsEvent,
        properties: [String: Any] = [:],
        minimumInterval: TimeInterval? = nil
    ) {
        guard isEnabled, state.isConfigured else { return }
        guard state.shouldCapture(event, minimumInterval: minimumInterval) else { return }

        PostHogSDK.shared.capture(event.rawValue, properties: sanitized(properties))
    }

    private static var isEnabled: Bool {
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
