import XCTest
@testable import CoolRun

final class GoldSignalEngineTests: XCTestCase {
    func testStrongUptrendIsNotCancelledByOverboughtRSI() {
        let prices = (0..<40).map { 580.0 + Double($0) * 0.5 }
        let snapshot = TechnicalIndicators.buildSnapshot(prices: prices, currentPrice: prices.last!)

        let signal = TradingSignalEngine.generateSignal(
            prices: prices,
            currentPrice: prices.last!,
            snapshot: snapshot
        )

        XCTAssertEqual(signal.direction, .buy)
        XCTAssertGreaterThanOrEqual(signal.score, 0.12)
    }

    func testStrongDowntrendIsNotCancelledByOversoldRSI() {
        let prices = (0..<40).map { 600.0 - Double($0) * 0.4 }
        let snapshot = TechnicalIndicators.buildSnapshot(prices: prices, currentPrice: prices.last!)

        let signal = TradingSignalEngine.generateSignal(
            prices: prices,
            currentPrice: prices.last!,
            snapshot: snapshot
        )

        XCTAssertEqual(signal.direction, .sell)
        XCTAssertGreaterThanOrEqual(signal.score, 0.12)
    }

    func testAdvancedStrategyGivesPositiveGuidanceForClearUptrend() throws {
        let records = (0..<40).map {
            GoldPriceRecord(
                price: 580.0 + Double($0) * 0.5,
                timestamp: Date(timeIntervalSince1970: Double($0) * 60)
            )
        }
        let prices = records.map(\.price)
        let snapshot = TechnicalIndicators.buildSnapshot(prices: prices, currentPrice: prices.last!)
        let signal = TradingSignalEngine.generateSignal(
            prices: prices,
            currentPrice: prices.last!,
            snapshot: snapshot
        )

        let report = try XCTUnwrap(GoldAdvancedStrategy.analyze(
            records: records,
            snapshot: snapshot,
            signal: signal
        ))

        XCTAssertEqual(report.compositeDirection, .buy)
        XCTAssertEqual(report.beginnerTone, .positive)
        XCTAssertGreaterThanOrEqual(report.risk.suggestedExposure, 0.06)
    }

    func testGoldNewsSentimentScoresBullishAndBearishKeywords() {
        let bullish = GoldMarketContextScorer.scoreNewsText("Fed rate cut hopes lift gold as yields fall")
        let bearish = GoldMarketContextScorer.scoreNewsText("Gold pressured as strong dollar and higher yields weigh")

        XCTAssertGreaterThan(bullish, 0)
        XCTAssertLessThan(bearish, 0)
    }

    func testMarketContextChangesSuggestedExposure() throws {
        let records = (0..<40).map {
            GoldPriceRecord(
                price: 580.0 + Double($0) * 0.5,
                timestamp: Date(timeIntervalSince1970: Double($0) * 60)
            )
        }
        let prices = records.map(\.price)
        let snapshot = TechnicalIndicators.buildSnapshot(prices: prices, currentPrice: prices.last!)
        let signal = TradingSignalEngine.generateSignal(
            prices: prices,
            currentPrice: prices.last!,
            snapshot: snapshot
        )
        let bullishContext = GoldMarketContext(
            macroScore: 45,
            newsScore: 35,
            overallScore: 40,
            macro: nil,
            newsItems: [],
            reasons: ["宏观新闻偏多"],
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let bearishContext = GoldMarketContext(
            macroScore: -45,
            newsScore: -35,
            overallScore: -40,
            macro: nil,
            newsItems: [],
            reasons: ["宏观新闻偏空"],
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        let bullishReport = try XCTUnwrap(GoldAdvancedStrategy.analyze(
            records: records,
            snapshot: snapshot,
            signal: signal,
            marketContext: bullishContext
        ))
        let bearishReport = try XCTUnwrap(GoldAdvancedStrategy.analyze(
            records: records,
            snapshot: snapshot,
            signal: signal,
            marketContext: bearishContext
        ))

        XCTAssertGreaterThan(bullishReport.risk.suggestedExposure, bearishReport.risk.suggestedExposure)
        XCTAssertEqual(bullishReport.marketContext?.tone, .bullish)
        XCTAssertEqual(bearishReport.marketContext?.tone, .bearish)
    }

    func testPredictionLearningValidatesMaturedBuyPrediction() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let prediction = GoldPredictionLearningRecord(
            createdAt: createdAt,
            horizonSeconds: 30 * 60,
            startPrice: 600,
            predictedDirection: "buy",
            predictedReturn: 0.004,
            confidence: 0.5,
            suggestedExposure: 0.12,
            technicalOpportunity: 28,
            marketContextScore: 20,
            macroScore: 10,
            newsScore: 30,
            regime: "温和上涨",
            sourceSummary: "测试预测"
        )
        let prices = [
            GoldPriceRecord(price: 600, timestamp: createdAt),
            GoldPriceRecord(price: 604, timestamp: createdAt.addingTimeInterval(30 * 60 + 5))
        ]

        let validated = GoldPredictionLearningEngine.validate(records: prices, prediction: prediction)

        XCTAssertEqual(validated.status, .validated)
        XCTAssertEqual(validated.wasDirectionalHit, true)
        XCTAssertEqual(validated.actualReturn ?? 0, 4 / 600, accuracy: 0.000_001)
        XCTAssertEqual(validated.absoluteError ?? 0, abs(0.004 - 4 / 600), accuracy: 0.000_001)
    }

    func testPredictionLearningSummaryTracksHitRateAndBias() {
        let first = GoldPredictionLearningRecord(
            createdAt: Date(timeIntervalSince1970: 1),
            horizonSeconds: 1,
            startPrice: 600,
            predictedDirection: "buy",
            predictedReturn: 0.004,
            confidence: 0.5,
            suggestedExposure: 0.1,
            technicalOpportunity: 20,
            marketContextScore: nil,
            macroScore: nil,
            newsScore: nil,
            regime: "温和上涨",
            sourceSummary: "测试",
            status: .validated,
            resolvedAt: Date(timeIntervalSince1970: 2),
            endPrice: 604,
            actualReturn: 0.006,
            wasDirectionalHit: true,
            absoluteError: 0.002
        )
        let second = GoldPredictionLearningRecord(
            createdAt: Date(timeIntervalSince1970: 3),
            horizonSeconds: 1,
            startPrice: 604,
            predictedDirection: "sell",
            predictedReturn: -0.003,
            confidence: 0.4,
            suggestedExposure: 0.08,
            technicalOpportunity: -15,
            marketContextScore: nil,
            macroScore: nil,
            newsScore: nil,
            regime: "温和下跌",
            sourceSummary: "测试",
            status: .validated,
            resolvedAt: Date(timeIntervalSince1970: 4),
            endPrice: 606,
            actualReturn: 0.003,
            wasDirectionalHit: false,
            absoluteError: 0.006
        )

        let summary = GoldPredictionLearningEngine.makeSummary(records: [first, second])

        XCTAssertEqual(summary.validatedCount, 2)
        XCTAssertEqual(summary.pendingCount, 0)
        XCTAssertEqual(summary.hitRate ?? 0, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(summary.averageAbsoluteError ?? 0, 0.004, accuracy: 0.000_001)
        XCTAssertEqual(summary.averagePredictionBias ?? 0, -0.004, accuracy: 0.000_001)
    }
}
