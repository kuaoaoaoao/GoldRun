import XCTest
@testable import coolRun

final class NovelFileParserTests: XCTestCase {
    func testSplitsChineseChapterTitles() {
        let content = """
        第1章 相遇
        第一章正文。
        第2章 重逢
        第二章正文。
        """

        let chapters = NovelFileParser.splitIntoChapters(content: content)

        XCTAssertEqual(chapters.count, 2)
        XCTAssertEqual(chapters[0].title, "第1章 相遇")
        XCTAssertEqual(chapters[0].paragraphs, ["第一章正文。"])
        XCTAssertEqual(chapters[1].title, "第2章 重逢")
    }

    func testKeepsUnsectionedTextReadable() {
        let chapters = NovelFileParser.splitIntoChapters(content: "只有一段正文。")

        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters[0].content, "只有一段正文。")
    }
}
