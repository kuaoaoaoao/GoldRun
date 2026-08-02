import XCTest
@testable import CoolRun

final class GoldGlobalMarketServiceTests: XCTestCase {

    // 真实响应样本（GB18030 解码后文本，2026-07-25 抓取固化）
    private let sampleText = """
    var hq_str_hf_XAU="4053.29,4049.260,4053.29,4053.87,4081.95,4022.01,04:54:00,4049.26,4050.43,0,0,0,2026-07-25,伦敦金（现货黄金）";
    var hq_str_fx_susdcny="02:59:01,6.7702000000,6.7720000000,6.7702000000,71.0000000000,6.7760000000,6.7773000000,6.7702000000,6.7702000000,在岸人民币,0.0000,0.0000,0.0071,此行情由新浪财经计算得出,0.0000,0.0000,,2026-07-25";
    var hq_str_DINIW="05:06:46,101.4647,101.4647,101.4469,2865,101.4337,101.5312,101.2447,101.4647,美元指数,2026-07-25";
    """

    // MARK: - 解析

    func testParseSinaQuotes() throws {
        let snapshot = try XCTUnwrap(GoldGlobalMarketService.parseSinaQuotes(text: sampleText))

        // hf_XAU：[0] 现价、[7] 昨收
        XCTAssertEqual(snapshot.xauUsd, 4053.29, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.xauPrevClose), 4049.26, accuracy: 0.001)
        // fx_susdcny：[3] 最新价
        XCTAssertEqual(snapshot.usdCny, 6.7702, accuracy: 0.0001)
        // DINIW：[1] 现值
        XCTAssertEqual(try XCTUnwrap(snapshot.dollarIndex), 101.4647, accuracy: 0.0001)
    }

    func testParseMissingXauReturnsNil() {
        let text = """
        var hq_str_fx_susdcny="02:59:01,6.7702,6.7720,6.7702";
        """
        XCTAssertNil(GoldGlobalMarketService.parseSinaQuotes(text: text))
    }

    func testParseMissingFxReturnsNil() {
        let text = """
        var hq_str_hf_XAU="4053.29,4049.260,4053.29,4053.87,4081.95,4022.01,04:54:00,4049.26";
        """
        XCTAssertNil(GoldGlobalMarketService.parseSinaQuotes(text: text))
    }

    func testParseWithoutDollarIndexStillSucceeds() throws {
        let text = """
        var hq_str_hf_XAU="4053.29,4049.260,4053.29,4053.87,4081.95,4022.01,04:54:00,4049.26,4050.43,0,0,0,2026-07-25,伦敦金（现货黄金）";
        var hq_str_fx_susdcny="02:59:01,6.7702,6.7720,6.7702,71,6.7760,6.7773,6.7702,6.7702,在岸人民币";
        """
        let snapshot = try XCTUnwrap(GoldGlobalMarketService.parseSinaQuotes(text: text))
        XCTAssertNil(snapshot.dollarIndex)
        XCTAssertEqual(snapshot.xauUsd, 4053.29, accuracy: 0.001)
    }

    // MARK: - 折算克价与涨跌

    func testConvertedCnyPerGram() throws {
        let snapshot = try XCTUnwrap(GoldGlobalMarketService.parseSinaQuotes(text: sampleText))

        // 4053.29 美元/盎司 ÷ 31.1034768 克/盎司 × 6.7702 ≈ 882.24 元/克
        let expected = 4053.29 / 31.1034768 * 6.7702
        XCTAssertEqual(snapshot.convertedCnyPerGram, expected, accuracy: 0.01)
        XCTAssertEqual(snapshot.convertedCnyPerGram, 882.24, accuracy: 0.5)
    }

    func testXauChangePercent() throws {
        let snapshot = try XCTUnwrap(GoldGlobalMarketService.parseSinaQuotes(text: sampleText))

        let expected = (4053.29 - 4049.26) / 4049.26 * 100
        XCTAssertEqual(try XCTUnwrap(snapshot.xauChangePercent), expected, accuracy: 0.0001)
    }

    func testXauChangePercentNilWithoutPrevClose() {
        let snapshot = GoldGlobalSnapshot(
            xauUsd: 4000,
            xauPrevClose: nil,
            usdCny: 7.0,
            dollarIndex: nil,
            updatedAt: Date()
        )
        XCTAssertNil(snapshot.xauChangePercent)
    }
}
