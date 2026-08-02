import XCTest
@testable import CoolRun

final class DiagnosticsTests: XCTestCase {
    func testPowerAssertionParserExtractsBlockingProcesses() {
        let text = #"""
        Listed by owning process:
           pid 678(NeteaseMusic): [0x00032527000195a2] 00:22:51 PreventUserIdleSystemSleep named: "NetEase CloudMusic is playing music"
           pid 404(WindowServer): [0x0003201e000993eb] 00:00:00 UserIsActive named: "input"
        """#

        let blockers = SleepDiagnosticParser.parseAssertions(text)

        XCTAssertEqual(blockers.count, 1)
        XCTAssertEqual(blockers.first?.processID, 678)
        XCTAssertEqual(blockers.first?.owner, "NeteaseMusic")
        XCTAssertEqual(blockers.first?.assertionType, "PreventUserIdleSystemSleep")
        XCTAssertEqual(blockers.first?.reason, "NetEase CloudMusic is playing music")
    }

    func testSleepLogParserUsesRecentEventsAndBatteryEndpoints() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        let now = formatter.date(from: "2026-08-01 10:00:00 +0800")!
        let text = """
        2026-07-30 09:00:00 +0800 Sleep Entering Sleep state due to 'Idle Sleep' Using Batt (Charge:90%)
        2026-08-01 01:00:00 +0800 Sleep Entering Sleep state due to 'Clamshell Sleep' Using Batt (Charge:80%)
        2026-08-01 02:00:00 +0800 DarkWake DarkWake from Deep Idle Using Batt (Charge:75%)
        2026-08-01 08:00:00 +0800 Wake DarkWake to FullWake from Deep Idle Using Batt (Charge:70%)
        """

        let result = SleepDiagnosticParser.parseLog(text, now: now)

        XCTAssertEqual(result.sleepCount, 1)
        XCTAssertEqual(result.darkWakeCount, 1)
        XCTAssertEqual(result.wakeCount, 1)
        XCTAssertEqual(result.batteryStartPercent, 80)
        XCTAssertEqual(result.batteryEndPercent, 70)
    }

    func testNetworkParsersExtractRouteLatencyAndLoss() {
        let route = NetworkDiagnosticParser.parseDefaultRoute("""
           route to: default
        destination: default
            gateway: 192.168.1.1
          interface: en0
        """)
        let ping = NetworkDiagnosticParser.parsePing("""
        4 packets transmitted, 3 packets received, 25.0% packet loss
        round-trip min/avg/max/stddev = 11.100/18.250/31.000/4.000 ms
        """)

        XCTAssertEqual(route.gateway, "192.168.1.1")
        XCTAssertEqual(route.interfaceName, "en0")
        XCTAssertEqual(ping.packetLossPercent, 25)
        XCTAssertEqual(ping.latencyMilliseconds, 18.25)
    }

    func testDiagnosticHistoryRetentionDropsOldSummaries() {
        let now = Date(timeIntervalSince1970: 10_000_000)
        let recentSleep = sleepSummary(at: now.addingTimeInterval(-60))
        let oldSleep = sleepSummary(at: now.addingTimeInterval(-31 * 24 * 60 * 60))
        let recentNetwork = networkSummary(at: now.addingTimeInterval(-60))
        let oldNetwork = networkSummary(at: now.addingTimeInterval(-15 * 24 * 60 * 60))

        XCTAssertEqual(DiagnosticsHistoryStore.retainedSleep([oldSleep, recentSleep], now: now), [recentSleep])
        XCTAssertEqual(DiagnosticsHistoryStore.retainedNetwork([oldNetwork, recentNetwork], now: now), [recentNetwork])
    }

    func testDirectorySizerSkipsSymbolicLinks() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outside = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: outside, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: outside)
        }
        try Data(repeating: 1, count: 4_096).write(to: root.appendingPathComponent("local.bin"))
        try Data(repeating: 2, count: 128_000).write(to: outside.appendingPathComponent("outside.bin"))
        try fileManager.createSymbolicLink(
            at: root.appendingPathComponent("outside-link"),
            withDestinationURL: outside
        )

        let measurement = DiagnosticDirectorySizer.measure(url: root)

        XCTAssertGreaterThan(measurement.allocatedBytes, 0)
        XCTAssertLessThan(measurement.allocatedBytes, 128_000)
        XCTAssertFalse(measurement.reachedEntryLimit)
    }

    func testDirectorySizerStopsAtLimitAndReportsProgress() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }
        for index in 0..<6 {
            try Data(repeating: UInt8(index), count: 512).write(
                to: root.appendingPathComponent("file-\(index).bin")
            )
        }
        var progressValues: [Int] = []

        let measurement = DiagnosticDirectorySizer.measure(
            url: root,
            maxEntries: 3,
            progressBatchSize: 1,
            progress: { progressValues.append($0) }
        )

        XCTAssertEqual(measurement.visitedEntryCount, 3)
        XCTAssertTrue(measurement.reachedEntryLimit)
        XCTAssertEqual(progressValues.last, 3)
        XCTAssertEqual(progressValues, progressValues.sorted())
    }

    func testResidueRulesProtectAppleInstalledAndNestedPaths() {
        XCTAssertEqual(
            AppResidueService.inferredIdentifier(from: "com.example.oldapp.plist"),
            "com.example.oldapp"
        )
        XCTAssertNil(AppResidueService.inferredIdentifier(from: "Human Readable Folder"))
        XCTAssertFalse(AppResidueService.isIdentifierEligible("com.apple.Safari", installedIdentifiers: []))
        XCTAssertFalse(AppResidueService.isIdentifierEligible(
            "com.example.current.helper",
            installedIdentifiers: ["com.example.current"]
        ))
        XCTAssertTrue(AppResidueService.isIdentifierEligible(
            "com.example.removed",
            installedIdentifiers: ["com.example.current"]
        ))

        let root = URL(fileURLWithPath: "/Users/test/Library/Caches", isDirectory: true)
        XCTAssertTrue(AppResidueService.isDirectChild(
            root.appendingPathComponent("com.example.removed"),
            ofAny: [root]
        ))
        XCTAssertFalse(AppResidueService.isDirectChild(
            root.appendingPathComponent("nested/com.example.removed"),
            ofAny: [root]
        ))
    }

    private func sleepSummary(at timestamp: Date) -> SleepDiagnosticSummary {
        SleepDiagnosticSummary(
            id: UUID(),
            timestamp: timestamp,
            severity: .healthy,
            blockers: [],
            windowStart: nil,
            windowEnd: nil,
            sleepCount: 0,
            wakeCount: 0,
            darkWakeCount: 0,
            batteryStartPercent: nil,
            batteryEndPercent: nil,
            unavailableChecks: []
        )
    }

    private func networkSummary(at timestamp: Date) -> NetworkDiagnosticSummary {
        NetworkDiagnosticSummary(
            id: UUID(),
            timestamp: timestamp,
            severity: .healthy,
            interfaceName: "en0",
            localAddress: "192.168.1.2",
            gateway: "192.168.1.1",
            vpnActive: false,
            latencyMilliseconds: 10,
            packetLossPercent: 0,
            likelyCause: .none,
            checks: []
        )
    }
}
