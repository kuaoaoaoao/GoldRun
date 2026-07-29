import XCTest
import SwiftUI
import AppKit
@testable import GoldRun

final class CodexMonitorTests: XCTestCase {
    func testQuotaPaceDetectsBalancedAndFastConsumption() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reset = now.addingTimeInterval(4 * 60 * 60)

        let balanced = CodexQuotaWindow(
            id: "balanced",
            title: "主额度",
            remainingPercent: 80,
            resetsAt: reset,
            durationMinutes: 5 * 60
        )
        let fast = CodexQuotaWindow(
            id: "fast",
            title: "主额度",
            remainingPercent: 60,
            resetsAt: reset,
            durationMinutes: 5 * 60
        )

        XCTAssertEqual(balanced.pace(at: now)?.status, .balanced)
        XCTAssertEqual(fast.pace(at: now)?.status, .fast)
        XCTAssertEqual(balanced.pace(at: now)?.expectedRemainingPercent ?? -1, 80, accuracy: 0.001)
    }

    func testQuotaPaceMarksLowRemainingAsCritical() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let window = CodexQuotaWindow(
            id: "critical",
            title: "次额度",
            remainingPercent: 8,
            resetsAt: now.addingTimeInterval(60 * 60),
            durationMinutes: 5 * 60
        )

        XCTAssertEqual(window.pace(at: now)?.status, .critical)
    }

    func testSessionMetadataUsesIndexTitleAndDetectsDesktopSource() throws {
        let json = """
        {"type":"session_meta","payload":{"id":"session-123","cwd":"/Users/test/Projects/GoldRun","originator":"codex_desktop"}}
        {"type":"event_msg","payload":{}}
        """
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let session = CodexLocalSessionScanner.parseSessionMetadata(
            Data(json.utf8),
            transcriptPath: "/tmp/session-123.jsonl",
            modifiedAt: now.addingTimeInterval(-30),
            now: now,
            titleIndex: ["session-123": "优化监控界面"]
        )

        let unwrapped = try XCTUnwrap(session)
        XCTAssertEqual(unwrapped.id, "session-123")
        XCTAssertEqual(unwrapped.title, "优化监控界面")
        XCTAssertEqual(unwrapped.projectName, "GoldRun")
        XCTAssertEqual(unwrapped.source, "桌面端")
        XCTAssertTrue(unwrapped.isActive)
    }

    func testSessionMetadataRejectsNonMetadataLine() {
        let data = Data(#"{"type":"event_msg","payload":{}}"#.utf8)

        XCTAssertNil(
            CodexLocalSessionScanner.parseSessionMetadata(
                data,
                transcriptPath: "/tmp/event.jsonl",
                modifiedAt: .now,
                now: .now
            )
        )
    }

    func testCodexMonitorRendersAtMenuBarSize() throws {
        let now = Date()
        let viewModel = CodexMonitorViewModel(autoStart: false)
        viewModel.state = .ready(
            CodexMonitorSnapshot(
                account: "codex@example.com",
                plan: "Plus",
                limits: [
                    CodexQuotaLimit(
                        id: "codex",
                        title: "Codex",
                        windows: [
                            CodexQuotaWindow(
                                id: "primary",
                                title: "主额度",
                                remainingPercent: 68,
                                resetsAt: now.addingTimeInterval(3 * 60 * 60),
                                durationMinutes: 5 * 60
                            ),
                            CodexQuotaWindow(
                                id: "secondary",
                                title: "次额度",
                                remainingPercent: 84,
                                resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60),
                                durationMinutes: 7 * 24 * 60
                            ),
                        ]
                    ),
                ],
                resetCreditsAvailableCount: 1,
                usage: CodexUsageSummary(
                    lifetimeTokens: 1_240_000,
                    peakDailyTokens: 94_000,
                    currentStreakDays: 6,
                    longestStreakDays: 18,
                    longestRunningTurnSec: 1_842
                ),
                dailyUsage: [
                    CodexDailyUsage(date: now.formatted(.iso8601.year().month().day()), tokens: 12_800),
                ],
                sessions: [
                    CodexSessionSummary(
                        id: "active",
                        title: "优化监控页面与固定逻辑",
                        projectName: "GoldRun",
                        source: "桌面端",
                        isActive: true,
                        updatedAt: now.addingTimeInterval(-25),
                        transcriptPath: "/tmp/active.jsonl"
                    ),
                    CodexSessionSummary(
                        id: "recent",
                        title: "修正额度状态解析",
                        projectName: "GoldRun",
                        source: "CLI",
                        isActive: false,
                        updatedAt: now.addingTimeInterval(-1_500),
                        transcriptPath: "/tmp/recent.jsonl"
                    ),
                ],
                isRateLimitsStale: false,
                isUsageStale: false,
                updatedAt: now
            )
        )

        let hostingView = NSHostingView(
            rootView: CodexMonitorView(viewModel: viewModel)
                .frame(width: 304, height: 464)
                .environment(\.colorScheme, .light)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 304, height: 464)
        hostingView.layoutSubtreeIfNeeded()
        let representation = try XCTUnwrap(
            hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        let pngData = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        let output = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("goldrun-codex-monitor-preview.png")
        try pngData.write(to: output)

        XCTAssertEqual(representation.size.width, 304)
        XCTAssertEqual(representation.size.height, 464)
    }

    func testAIOverviewRendersBothProvidersAtMenuBarSize() throws {
        let defaults = UserDefaults.standard
        let previousTab = defaults.string(forKey: "ai_monitor_tab")
        defaults.set("overview", forKey: "ai_monitor_tab")
        defer {
            if let previousTab {
                defaults.set(previousTab, forKey: "ai_monitor_tab")
            } else {
                defaults.removeObject(forKey: "ai_monitor_tab")
            }
        }

        let now = Date()
        let codexViewModel = CodexMonitorViewModel(autoStart: false)
        codexViewModel.state = .ready(
            CodexMonitorSnapshot(
                account: "codex@example.com",
                plan: "Plus",
                limits: [
                    CodexQuotaLimit(
                        id: "codex",
                        title: "Codex",
                        windows: [
                            CodexQuotaWindow(
                                id: "codex-primary",
                                title: "主额度",
                                remainingPercent: 72,
                                resetsAt: now.addingTimeInterval(3_600),
                                durationMinutes: 300
                            ),
                        ]
                    ),
                ],
                resetCreditsAvailableCount: nil,
                usage: nil,
                dailyUsage: [],
                sessions: [],
                isRateLimitsStale: false,
                isUsageStale: false,
                updatedAt: now
            )
        )

        let claudeViewModel = ClaudeMonitorViewModel(autoStart: false)
        claudeViewModel.state = .ready(
            ClaudeMonitorSnapshot(
                account: "Claude Code",
                plan: "max",
                windows: [
                    CodexQuotaWindow(
                        id: "claude-weekly",
                        title: "周额度",
                        remainingPercent: 38,
                        resetsAt: now.addingTimeInterval(86_400),
                        durationMinutes: 10_080
                    ),
                ],
                extraUsage: nil,
                updatedAt: now
            )
        )

        let hostingView = NSHostingView(
            rootView: AIMonitorView(
                codexViewModel: codexViewModel,
                claudeViewModel: claudeViewModel
            )
            .frame(width: 304, height: 464)
            .environment(\.colorScheme, .light)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 304, height: 464)
        hostingView.layoutSubtreeIfNeeded()
        let representation = try XCTUnwrap(
            hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        let pngData = try XCTUnwrap(
            representation.representation(using: .png, properties: [:])
        )
        let output = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("goldrun-ai-overview-preview.png")
        try pngData.write(to: output)

        XCTAssertEqual(representation.size.width, 304)
        XCTAssertEqual(representation.size.height, 464)
    }
}
