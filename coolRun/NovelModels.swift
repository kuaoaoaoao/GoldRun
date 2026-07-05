import Foundation
import SwiftUI
import Combine

struct NovelBook: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var filePath: String
    var chapters: [NovelChapter]
    var lastReadChapterIndex: Int
    var lastReadParagraphIndex: Int
    var bookmarks: [NovelBookmark]
    var createdAt: Date
    var lastReadAt: Date?
    var totalLength: Int

    init(title: String, filePath: String, chapters: [NovelChapter]) {
        self.id = UUID()
        self.title = title
        self.filePath = filePath
        self.chapters = chapters
        self.lastReadChapterIndex = 0
        self.lastReadParagraphIndex = 0
        self.bookmarks = []
        self.createdAt = Date()
        self.lastReadAt = nil
        self.totalLength = chapters.reduce(0) { $0 + $1.content.count }
    }
}

struct NovelChapter: Identifiable, Codable, Equatable {
    let id: UUID
    var index: Int
    var title: String
    var content: String
    var paragraphs: [String]
    var startOffset: Int

    init(index: Int, title: String, content: String, startOffset: Int = 0) {
        self.id = UUID()
        self.index = index
        self.title = title
        self.content = content
        self.paragraphs = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.startOffset = startOffset
    }
}

struct NovelBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    var chapterIndex: Int
    var paragraphIndex: Int
    var previewText: String
    var createdAt: Date

    init(chapterIndex: Int, paragraphIndex: Int, previewText: String) {
        self.id = UUID()
        self.chapterIndex = chapterIndex
        self.paragraphIndex = paragraphIndex
        self.previewText = previewText
        self.createdAt = Date()
    }
}

enum ReadingMode: String, CaseIterable, Identifiable, Codable {
    case scroll
    case page

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scroll: return "滚动"
        case .page: return "翻页"
        }
    }

    var icon: String {
        switch self {
        case .scroll: return "text.alignleft"
        case .page: return "rectangle.split.2x1"
        }
    }
}

enum ReaderTheme: String, CaseIterable, Identifiable, Codable {
    case light
    case warm
    case sepia
    case dark
    case ink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "明亮"
        case .warm: return "暖色"
        case .sepia: return "复古"
        case .dark: return "暗夜"
        case .ink: return "水墨"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .light: return Color(red: 0.98, green: 0.98, blue: 0.97)
        case .warm: return Color(red: 0.96, green: 0.93, blue: 0.85)
        case .sepia: return Color(red: 0.94, green: 0.89, blue: 0.79)
        case .dark: return Color(red: 0.11, green: 0.11, blue: 0.12)
        case .ink: return Color(red: 0.15, green: 0.17, blue: 0.20)
        }
    }

    var textColor: Color {
        switch self {
        case .light: return Color(red: 0.15, green: 0.15, blue: 0.15)
        case .warm: return Color(red: 0.25, green: 0.20, blue: 0.15)
        case .sepia: return Color(red: 0.30, green: 0.22, blue: 0.12)
        case .dark: return Color(red: 0.75, green: 0.73, blue: 0.70)
        case .ink: return Color(red: 0.70, green: 0.72, blue: 0.75)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .light: return Color(red: 0.55, green: 0.55, blue: 0.55)
        case .warm: return Color(red: 0.55, green: 0.48, blue: 0.38)
        case .sepia: return Color(red: 0.50, green: 0.42, blue: 0.30)
        case .dark: return Color(red: 0.45, green: 0.43, blue: 0.42)
        case .ink: return Color(red: 0.40, green: 0.45, blue: 0.50)
        }
    }
}

@MainActor
final class ReaderSettings: ObservableObject {
    static let shared = ReaderSettings()

    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }

    @Published var lineSpacing: Double {
        didSet { defaults.set(lineSpacing, forKey: Keys.lineSpacing) }
    }

    @Published var theme: ReaderTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }

    @Published var mode: ReadingMode {
        didSet { defaults.set(mode.rawValue, forKey: Keys.mode) }
    }

    private let defaults = UserDefaults.standard

    private init() {
        let themeRaw = defaults.string(forKey: Keys.theme) ?? ReaderTheme.warm.rawValue
        let modeRaw = defaults.string(forKey: Keys.mode) ?? ReadingMode.scroll.rawValue

        self.fontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? 18
        self.lineSpacing = defaults.object(forKey: Keys.lineSpacing) as? Double ?? 8
        self.theme = ReaderTheme(rawValue: themeRaw) ?? .warm
        self.mode = ReadingMode(rawValue: modeRaw) ?? .scroll
    }

    private enum Keys {
        static let fontSize = "readerFontSize"
        static let lineSpacing = "readerLineSpacing"
        static let theme = "readerTheme"
        static let mode = "readerMode"
    }
}
