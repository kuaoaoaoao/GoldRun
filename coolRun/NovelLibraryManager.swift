import Foundation
import Combine

@MainActor
final class NovelLibraryManager: ObservableObject {
    static let shared = NovelLibraryManager()

    @Published private(set) var books: [NovelBook] = []

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var libraryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("coolRun/NovelLibrary", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private var metadataURL: URL {
        libraryURL.appendingPathComponent("library.json")
    }

    private init() {
        loadLibrary()
    }

    func book(id: NovelBook.ID) -> NovelBook? {
        books.first { $0.id == id }
    }

    func importNovel(from url: URL) throws -> NovelBook {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let sourceFileSize = fileSize(at: url)
        let sourceTitle = url.deletingPathExtension().lastPathComponent
        if let existing = books.first(where: { book in
            if book.filePath == url.path {
                return true
            }
            guard book.title == sourceTitle,
                  let sourceFileSize,
                  let existingFileSize = fileSize(at: URL(fileURLWithPath: book.filePath)) else {
                return false
            }
            return sourceFileSize == existingFileSize
        }) {
            return existing
        }

        let destination = availableDestinationURL(for: url)
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.copyItem(at: url, to: destination)
        }

        var book = try NovelFileParser.parseNovel(from: destination)
        book.filePath = destination.path

        books.append(book)
        saveLibrary()
        return book
    }

    func updateProgress(bookId: NovelBook.ID, chapterIndex: Int, paragraphIndex: Int) {
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        let chapterMax = max(books[index].chapters.count - 1, 0)
        let safeChapter = min(max(chapterIndex, 0), chapterMax)
        let paragraphMax = max((books[index].chapters[safe: safeChapter]?.paragraphs.count ?? 1) - 1, 0)
        let safeParagraph = min(max(paragraphIndex, 0), paragraphMax)

        books[index].lastReadChapterIndex = safeChapter
        books[index].lastReadParagraphIndex = safeParagraph
        books[index].lastReadAt = Date()
        saveLibrary()
    }

    func addBookmark(bookId: NovelBook.ID, chapterIndex: Int, paragraphIndex: Int, previewText: String) {
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        let exists = books[index].bookmarks.contains {
            $0.chapterIndex == chapterIndex && $0.paragraphIndex == paragraphIndex
        }
        guard !exists else { return }

        books[index].bookmarks.append(
            NovelBookmark(
                chapterIndex: chapterIndex,
                paragraphIndex: paragraphIndex,
                previewText: previewText
            )
        )
        saveLibrary()
    }

    func removeBookmark(bookId: NovelBook.ID, bookmarkId: NovelBookmark.ID) {
        guard let bookIndex = books.firstIndex(where: { $0.id == bookId }) else { return }
        books[bookIndex].bookmarks.removeAll { $0.id == bookmarkId }
        saveLibrary()
    }

    func removeBook(bookId: NovelBook.ID) {
        guard let index = books.firstIndex(where: { $0.id == bookId }) else { return }
        let book = books[index]
        try? fileManager.removeItem(atPath: book.filePath)
        books.remove(at: index)
        saveLibrary()
    }

    private func availableDestinationURL(for sourceURL: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "txt" : sourceURL.pathExtension
        var candidate = libraryURL.appendingPathComponent("\(baseName).\(ext)")
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = libraryURL.appendingPathComponent("\(baseName)-\(suffix).\(ext)")
            suffix += 1
        }

        return candidate
    }

    private func fileSize(at url: URL) -> UInt64? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size >= 0 else {
            return nil
        }
        return UInt64(size)
    }

    private func saveLibrary() {
        do {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(books)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            print("保存小说书库失败: \(error.localizedDescription)")
        }
    }

    private func loadLibrary() {
        do {
            let data = try Data(contentsOf: metadataURL)
            books = try decoder.decode([NovelBook].self, from: data)
        } catch {
            books = []
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
