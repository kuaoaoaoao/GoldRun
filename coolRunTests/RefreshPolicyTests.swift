import XCTest
@testable import coolRun

final class RefreshPolicyTests: XCTestCase {
    func testSystemRefreshDurations() {
        XCTAssertEqual(SystemRefreshRate.realtime.duration, .seconds(1))
        XCTAssertEqual(SystemRefreshRate.balanced.duration, .seconds(2))
        XCTAssertEqual(SystemRefreshRate.energySaving.duration, .seconds(5))
    }

    func testAnimationRatesStayBelowPreviousThirtyFPSDefault() {
        XCTAssertNil(MenuBarAnimationRate.off.framesPerSecond)
        XCTAssertEqual(MenuBarAnimationRate.energySaving.framesPerSecond, 8)
        XCTAssertEqual(MenuBarAnimationRate.smooth.framesPerSecond, 20)
    }

    func testGoldRefreshDurations() {
        XCTAssertEqual(GoldRefreshRate.seconds30.duration, .seconds(30))
        XCTAssertEqual(GoldRefreshRate.minute.duration, .seconds(60))
        XCTAssertEqual(GoldRefreshRate.minutes5.duration, .seconds(300))
    }

    func testLocalizedStringSupportsJapaneseAndKoreanOverrides() {
        XCTAssertEqual(
            LocalizedString.settings("startup", lang: .japanese),
            "起動"
        )
        XCTAssertEqual(
            LocalizedString.speech("voice_reading", lang: .korean),
            "음성 읽기"
        )
        XCTAssertEqual(
            LocalizedString.l(.japanese, en: "Fallback", zh: "回退"),
            "Fallback"
        )
    }
}
