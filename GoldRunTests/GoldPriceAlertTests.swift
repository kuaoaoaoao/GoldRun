import XCTest
@testable import GoldRun

final class GoldPriceAlertTests: XCTestCase {

    private typealias State = GoldPriceAlertManager.State

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - 上穿触发

    func testUpperCrossFiresOnce() {
        // 上穿上限触发一次
        let first = GoldPriceAlertManager.evaluate(
            price: 901, upper: 900, lower: nil, state: State(), now: now
        )
        XCTAssertEqual(first.alert, .upper)
        XCTAssertTrue(first.newState.upperFired)

        // 价格继续在上限之上：已锁定，不重复触发
        let second = GoldPriceAlertManager.evaluate(
            price: 905, upper: 900, lower: nil, state: first.newState, now: now.addingTimeInterval(60)
        )
        XCTAssertNil(second.alert)
        XCTAssertTrue(second.newState.upperFired)
    }

    func testUpperNotFiredBelowThreshold() {
        let result = GoldPriceAlertManager.evaluate(
            price: 899.99, upper: 900, lower: nil, state: State(), now: now
        )
        XCTAssertNil(result.alert)
        XCTAssertFalse(result.newState.upperFired)
    }

    // MARK: - 下穿触发

    func testLowerCrossFiresOnce() {
        let first = GoldPriceAlertManager.evaluate(
            price: 799, upper: nil, lower: 800, state: State(), now: now
        )
        XCTAssertEqual(first.alert, .lower)
        XCTAssertTrue(first.newState.lowerFired)

        let second = GoldPriceAlertManager.evaluate(
            price: 795, upper: nil, lower: 800, state: first.newState, now: now.addingTimeInterval(60)
        )
        XCTAssertNil(second.alert)
    }

    func testLowerWinsWhenBothCrossed() {
        // 上下限同轮都满足（上限设得比下限低的极端配置）时优先报下限
        let result = GoldPriceAlertManager.evaluate(
            price: 850, upper: 800, lower: 900, state: State(), now: now
        )
        XCTAssertEqual(result.alert, .lower)
        XCTAssertTrue(result.newState.upperFired)
        XCTAssertTrue(result.newState.lowerFired)
    }

    // MARK: - 回落重新武装

    func testUpperRearmsAfterPriceFallsBackInside() {
        var state = State()
        state.upperFired = true
        state.lastUpperFiredAt = now.addingTimeInterval(-3600)

        // 未回落到 900×(1−0.5%)=895.5 以下：保持锁定
        let stillLocked = GoldPriceAlertManager.evaluate(
            price: 897, upper: 900, lower: nil, state: state, now: now
        )
        XCTAssertNil(stillLocked.alert)
        XCTAssertTrue(stillLocked.newState.upperFired)

        // 回落到阈值内侧 0.5% 以下：重新武装
        let rearmed = GoldPriceAlertManager.evaluate(
            price: 895, upper: 900, lower: nil, state: state, now: now
        )
        XCTAssertNil(rearmed.alert)
        XCTAssertFalse(rearmed.newState.upperFired)

        // 再次上穿：可再触发
        let fired = GoldPriceAlertManager.evaluate(
            price: 901, upper: 900, lower: nil, state: rearmed.newState, now: now.addingTimeInterval(60)
        )
        XCTAssertEqual(fired.alert, .upper)
    }

    func testLowerRearmsAfterPriceRisesBackInside() {
        var state = State()
        state.lowerFired = true
        state.lastLowerFiredAt = now.addingTimeInterval(-3600)

        // 回升到 800×(1+0.5%)=804 以上：重新武装
        let rearmed = GoldPriceAlertManager.evaluate(
            price: 805, upper: nil, lower: 800, state: state, now: now
        )
        XCTAssertFalse(rearmed.newState.lowerFired)

        let fired = GoldPriceAlertManager.evaluate(
            price: 799, upper: nil, lower: 800, state: rearmed.newState, now: now.addingTimeInterval(60)
        )
        XCTAssertEqual(fired.alert, .lower)
    }

    // MARK: - 最短间隔抑制

    func testMinimumIntervalSuppressesRefire() {
        // 触发后快速回落又上穿：距上次触发不足 30 分钟，静默锁定
        let first = GoldPriceAlertManager.evaluate(
            price: 901, upper: 900, lower: nil, state: State(), now: now
        )
        XCTAssertEqual(first.alert, .upper)

        let rearmed = GoldPriceAlertManager.evaluate(
            price: 895, upper: 900, lower: nil, state: first.newState, now: now.addingTimeInterval(300)
        )
        XCTAssertFalse(rearmed.newState.upperFired)

        let suppressed = GoldPriceAlertManager.evaluate(
            price: 902, upper: 900, lower: nil, state: rearmed.newState, now: now.addingTimeInterval(600)
        )
        XCTAssertNil(suppressed.alert)
        // 仍锁定，避免下一轮重复判定
        XCTAssertTrue(suppressed.newState.upperFired)

        // 超过 30 分钟后再上穿（先回落重新武装）：可再触发
        let rearmedAgain = GoldPriceAlertManager.evaluate(
            price: 895, upper: 900, lower: nil, state: suppressed.newState, now: now.addingTimeInterval(700)
        )
        let refired = GoldPriceAlertManager.evaluate(
            price: 903, upper: 900, lower: nil, state: rearmedAgain.newState,
            now: now.addingTimeInterval(GoldPriceAlertManager.minimumInterval + 60)
        )
        XCTAssertEqual(refired.alert, .upper)
    }

    // MARK: - 阈值解析与空阈值

    func testNoThresholdsNeverFires() {
        let result = GoldPriceAlertManager.evaluate(
            price: 900, upper: nil, lower: nil, state: State(), now: now
        )
        XCTAssertNil(result.alert)
        XCTAssertEqual(result.newState, State())
    }

    func testClearingThresholdResetsFiredFlag() {
        var state = State()
        state.upperFired = true

        let result = GoldPriceAlertManager.evaluate(
            price: 950, upper: nil, lower: nil, state: state, now: now
        )
        XCTAssertFalse(result.newState.upperFired)
    }

    func testParseThreshold() {
        XCTAssertEqual(GoldPriceAlertManager.parseThreshold(" 880.5 "), 880.5)
        XCTAssertNil(GoldPriceAlertManager.parseThreshold(""))
        XCTAssertNil(GoldPriceAlertManager.parseThreshold("abc"))
        XCTAssertNil(GoldPriceAlertManager.parseThreshold("0"))
        XCTAssertNil(GoldPriceAlertManager.parseThreshold("-10"))
    }
}
