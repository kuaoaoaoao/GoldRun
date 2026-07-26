import XCTest
@testable import coolRun

final class GoldTradeStoreTests: XCTestCase {

    private func record(
        daysAgo: Double,
        grams: Double,
        price: Double,
        note: String = ""
    ) -> GoldTradeRecord {
        GoldTradeRecord(
            date: Date(timeIntervalSinceNow: -daysAgo * 86400),
            grams: grams,
            pricePerGram: price,
            note: note
        )
    }

    // MARK: - 持仓汇总

    func testHoldingSummaryEmpty() {
        let result = GoldTradeStore.holdingSummary(records: [])
        XCTAssertEqual(result.grams, 0)
        XCTAssertEqual(result.averageCost, 0)
    }

    func testHoldingSummaryBuysOnly() {
        // 10g × 800 + 10g × 900 → 20g，均价 850
        let records = [
            record(daysAgo: 10, grams: 10, price: 800),
            record(daysAgo: 5, grams: 10, price: 900)
        ]
        let result = GoldTradeStore.holdingSummary(records: records)
        XCTAssertEqual(result.grams, 20, accuracy: 0.0001)
        XCTAssertEqual(result.averageCost, 850, accuracy: 0.0001)
    }

    func testHoldingSummaryWithSellKeepsAverageCost() {
        // 买 20g 均价 850，卖 5g：剩 15g，均价不变（按均价减持不摊薄）
        let records = [
            record(daysAgo: 10, grams: 10, price: 800),
            record(daysAgo: 5, grams: 10, price: 900),
            record(daysAgo: 2, grams: -5, price: 950)
        ]
        let result = GoldTradeStore.holdingSummary(records: records)
        XCTAssertEqual(result.grams, 15, accuracy: 0.0001)
        XCTAssertEqual(result.averageCost, 850, accuracy: 0.0001)
    }

    func testHoldingSummaryOversellClampsToZero() {
        // 卖出超过持仓按清仓处理
        let records = [
            record(daysAgo: 10, grams: 10, price: 800),
            record(daysAgo: 5, grams: -15, price: 900)
        ]
        let result = GoldTradeStore.holdingSummary(records: records)
        XCTAssertEqual(result.grams, 0)
        XCTAssertEqual(result.averageCost, 0)
    }

    func testHoldingSummaryReplaysInDateOrder() {
        // 传入乱序也按时间回放：先买 10g@800，再卖 5g，再买 5g@900
        let records = [
            record(daysAgo: 1, grams: 5, price: 900),
            record(daysAgo: 10, grams: 10, price: 800),
            record(daysAgo: 5, grams: -5, price: 850)
        ]
        let result = GoldTradeStore.holdingSummary(records: records)
        // 卖后剩 5g@800（成本 4000），再买 5g@900（成本 4500）→ 10g 均价 850
        XCTAssertEqual(result.grams, 10, accuracy: 0.0001)
        XCTAssertEqual(result.averageCost, 850, accuracy: 0.0001)
    }

    // MARK: - CSV

    func testCSVHeaderAndRows() {
        let records = [
            record(daysAgo: 2, grams: 10, price: 800.5),
            record(daysAgo: 1, grams: -2.5, price: 900)
        ]
        let csv = GoldTradeStore.csvText(records: records)
        let lines = csv.split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], "date,type,grams,price_per_gram,amount,note")
        // 按时间升序：先买后卖
        XCTAssertTrue(lines[1].contains(",buy,10.0000,800.50,8005.00,"))
        XCTAssertTrue(lines[2].contains(",sell,2.5000,900.00,2250.00,"))
    }

    func testCSVEscapesNoteWithComma() {
        let records = [
            record(daysAgo: 1, grams: 1, price: 800, note: "first, batch \"A\"")
        ]
        let csv = GoldTradeStore.csvText(records: records)
        XCTAssertTrue(csv.contains("\"first, batch \"\"A\"\"\""))
    }

    func testCSVEmptyRecordsOnlyHeader() {
        let csv = GoldTradeStore.csvText(records: [])
        XCTAssertEqual(csv, "date,type,grams,price_per_gram,amount,note")
    }
}
