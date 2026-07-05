import CoreFoundation
import Foundation

enum NovelParserError: LocalizedError {
    case encodingError
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .encodingError:
            return "无法识别文件编码，请使用 UTF-8、GBK 或 GB18030 编码的 txt 文件"
        case .emptyContent:
            return "文件内容为空"
        }
    }
}

enum NovelFileParser {
    private static let chapterPatterns = [
        #"^第[零一二三四五六七八九十百千万\d]+[章节回卷集部篇]"#,
        #"^Chapter\s+\d+"#,
        #"^CHAPTER\s+\d+"#,
        #"^第\d+章"#,
        #"^(序章|序幕|前言|楔子|引子|尾声|后记)"#,
        #"^\d+\.\s+"#,
        #"^【第.+章】"#,
        #"^={3,}.+"#
    ]

    static func parseNovel(from url: URL) throws -> NovelBook {
        let rawContent = try readTextFile(from: url)
        let normalizedContent = normalize(content: rawContent)

        guard !normalizedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NovelParserError.emptyContent
        }

        let title = url.deletingPathExtension().lastPathComponent
        let chapters = splitIntoChapters(content: normalizedContent)
        return NovelBook(title: title, filePath: url.path, chapters: chapters)
    }

    static func splitIntoChapters(content: String) -> [NovelChapter] {
        let lines = content.components(separatedBy: .newlines)
        let regexes = chapterPatterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }

        var chapters: [NovelChapter] = []
        var currentTitle = "开始阅读"
        var currentLines: [String] = []
        var chapterIndex = 0
        var currentOffset = 0
        var chapterStartOffset = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let isTitle = isChapterTitle(trimmed, regexes: regexes)

            if isTitle {
                appendChapter(
                    title: currentTitle,
                    lines: currentLines,
                    index: &chapterIndex,
                    startOffset: chapterStartOffset,
                    chapters: &chapters
                )
                currentTitle = trimmed
                currentLines = []
                chapterStartOffset = currentOffset
            } else {
                currentLines.append(line)
            }

            currentOffset += line.count + 1
        }

        appendChapter(
            title: currentTitle,
            lines: currentLines,
            index: &chapterIndex,
            startOffset: chapterStartOffset,
            chapters: &chapters
        )

        if chapters.isEmpty {
            return [
                NovelChapter(
                    index: 0,
                    title: "全文",
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            ]
        }

        return chapters
    }

    private static func readTextFile(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)

        if let content = String(data: data, encoding: .utf8) {
            return content
        }

        let fallbackEncodings = [
            textEncoding(.GB_18030_2000),
            textEncoding(.GBK_95),
            textEncoding(.GB_2312_80),
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian
        ]

        for encoding in fallbackEncodings {
            if let content = String(data: data, encoding: encoding) {
                return content
            }
        }

        throw NovelParserError.encodingError
    }

    private static func textEncoding(_ encoding: CFStringEncodings) -> String.Encoding {
        String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(encoding.rawValue)
            )
        )
    }

    private static func normalize(content: String) -> String {
        content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{feff}", with: "")
    }

    private static func isChapterTitle(_ text: String, regexes: [NSRegularExpression]) -> Bool {
        guard !text.isEmpty, text.count <= 60 else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regexes.contains { regex in
            regex.firstMatch(in: text, options: [], range: range) != nil
        }
    }

    private static func appendChapter(
        title: String,
        lines: [String],
        index: inout Int,
        startOffset: Int,
        chapters: inout [NovelChapter]
    ) {
        let content = lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !content.isEmpty else { return }

        chapters.append(
            NovelChapter(
                index: index,
                title: title,
                content: content,
                startOffset: startOffset
            )
        )
        index += 1
    }
}
