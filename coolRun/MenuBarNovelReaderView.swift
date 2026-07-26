import SwiftUI
import UniformTypeIdentifiers

struct MenuBarNovelReaderView: View {
    @ObservedObject private var library = NovelLibraryManager.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @ObservedObject private var settings = ReaderSettings.shared
    @ObservedObject private var speech = NovelSpeechManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("menuBarNovelBookID") private var selectedBookIDText = ""
    @State private var currentChapterIndex = 0
    @State private var currentParagraphIndex = 0
    @State private var showingImporter = false
    @State private var showImportError = false
    @State private var importError: String?

    private var selectedBook: NovelBook? {
        if let id = UUID(uuidString: selectedBookIDText),
           let book = library.book(id: id) {
            return book
        }
        return library.books.first
    }

    private var currentChapter: NovelChapter? {
        selectedBook?.chapters[safe: currentChapterIndex]
    }

    private var currentParagraph: String {
        guard let currentChapter else { return LocalizedString.novel("default_menu_hint", lang: appSettings.language) }
        return currentChapter.paragraphs[safe: currentParagraphIndex] ?? currentChapter.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if library.books.isEmpty {
                emptyState
            } else if let selectedBook {
                header(book: selectedBook)
                progressStrip(book: selectedBook)
                chapterControls(book: selectedBook)
                paragraphCard(book: selectedBook)
                speechControls(book: selectedBook)
            } else {
                emptyState
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appCardSurface(cornerRadius: 12)
        .onAppear(perform: restoreSelection)
        .onChange(of: selectedBook?.id) { _, _ in
            restoreSelection()
        }
        .onChange(of: speech.currentChapterIndex) { _, newValue in
            guard let selectedBook,
                  speech.currentBookID == selectedBook.id,
                  speech.autoScroll,
                  newValue >= 0 else { return }
            currentChapterIndex = newValue
            currentParagraphIndex = speech.currentParagraphIndex
        }
        .onChange(of: speech.currentParagraphIndex) { _, newValue in
            guard let selectedBook,
                  speech.currentBookID == selectedBook.id,
                  speech.autoScroll else { return }
            currentParagraphIndex = newValue
        }
        .onDisappear(perform: saveProgress)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "txt") ?? .plainText],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .alert(LocalizedString.novel("import_failed", lang: appSettings.language), isPresented: $showImportError) {
            Button(LocalizedString.common("ok", lang: appSettings.language)) {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
    }

    private func header(book: NovelBook) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: "book.pages")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                Picker(LocalizedString.novel("novel", lang: appSettings.language), selection: selectedBookBinding) {
                    ForEach(library.books) { book in
                        Text(book.title)
                            .tag(book.id.uuidString)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Button(action: { showingImporter = true }) {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .help(LocalizedString.novel("import_txt_help", lang: appSettings.language))
            }

            Text(book.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func progressStrip(book: NovelBook) -> some View {
        VStack(spacing: 5) {
            ProgressView(value: readingProgress(book: book))
                .tint(AppTheme.accent)

            HStack {
                Text(String(
                    format: LocalizedString.novel("chapter_counter_format", lang: appSettings.language),
                    min(currentChapterIndex + 1, max(book.chapters.count, 1)),
                    max(book.chapters.count, 1)
                ))
                Spacer()
                Text("\(Int(readingProgress(book: book) * 100))%")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(AppTheme.textSecondary(colorScheme))
        }
    }

    private func chapterControls(book: NovelBook) -> some View {
        HStack(spacing: 6) {
            compactButton("chevron.left", help: LocalizedString.novel("prev_chapter", lang: appSettings.language)) {
                moveChapter(by: -1, book: book)
            }
            .disabled(currentChapterIndex <= 0)

            // 章节标题可点击，弹出章节列表直接跳转
            Menu {
                chapterMenuItems(book: book)
            } label: {
                HStack(spacing: 3) {
                    Text(currentChapter?.title ?? LocalizedString.novel("no_chapter", lang: appSettings.language))
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                }
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .help(LocalizedString.novel("toc", lang: appSettings.language))

            compactButton("chevron.right", help: LocalizedString.novel("next_chapter", lang: appSettings.language)) {
                moveChapter(by: 1, book: book)
            }
            .disabled(currentChapterIndex >= book.chapters.count - 1)
        }
    }

    private func paragraphCard(book: NovelBook) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ScrollView {
                Text(currentParagraph)
                    .font(.system(size: min(settings.fontSize, 15), design: .serif))
                    .lineSpacing(min(settings.lineSpacing, 7))
                    .foregroundStyle(AppTheme.textPrimary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 142)

            HStack(spacing: 6) {
                compactButton("arrow.up", help: LocalizedString.common("previous", lang: appSettings.language)) {
                    moveParagraph(by: -1, book: book)
                }
                .disabled(currentParagraphIndex <= 0 && currentChapterIndex <= 0)

                Text(String(format: LocalizedString.novel("paragraph_counter_format", lang: appSettings.language), currentParagraphIndex + 1))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    .frame(maxWidth: .infinity)

                compactButton("arrow.down", help: LocalizedString.common("next", lang: appSettings.language)) {
                    moveParagraph(by: 1, book: book)
                }
                .disabled(isAtEnd(of: book))
            }
        }
        .padding(8)
        .background(AppTheme.progressBg(colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func speechControls(book: NovelBook) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if speech.currentBookID == book.id, !speech.currentSentenceText.isEmpty {
                Text(speech.currentSentenceText)
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(LocalizedString.novel("read_from_here_hint", lang: appSettings.language))
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
            }

            HStack(spacing: 8) {
                compactButton("backward.end.fill", help: LocalizedString.speech("previous_sentence", lang: appSettings.language)) {
                    speech.skipBackward()
                }
                .disabled(!speech.isActive(for: book.id))

                Button(action: { playPause(book: book) }) {
                    Image(systemName: playPauseIcon(book: book))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 28)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .help(speech.currentBookID == book.id && speech.state == .playing ? LocalizedString.speech("pause_reading", lang: appSettings.language) : LocalizedString.speech("start_reading", lang: appSettings.language))

                compactButton("forward.end.fill", help: LocalizedString.speech("next_sentence", lang: appSettings.language)) {
                    speech.skipForward()
                }
                .disabled(!speech.isActive(for: book.id))

                compactButton("stop.fill", help: LocalizedString.speech("stop_reading", lang: appSettings.language)) {
                    speech.stop()
                }
                .disabled(!speech.isActive(for: book.id))

                Spacer(minLength: 4)

                Toggle(isOn: $speech.autoScroll) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 11, weight: .medium))
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help(LocalizedString.speech("auto_scroll", lang: appSettings.language))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppTheme.accent)

            Text(LocalizedString.novel("empty_menu_title", lang: appSettings.language))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary(colorScheme))

            Text(LocalizedString.novel("empty_menu_hint", lang: appSettings.language))
                .font(.system(size: 10))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { showingImporter = true }) {
                Label(LocalizedString.novel("import_txt", lang: appSettings.language), systemImage: "plus")
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var selectedBookBinding: Binding<String> {
        Binding(
            get: {
                if let selectedBook {
                    return selectedBook.id.uuidString
                }
                return selectedBookIDText
            },
            set: { newValue in
                saveProgress()
                selectedBookIDText = newValue
                restoreSelection()
            }
        )
    }

    private func compactButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .frame(width: 32, height: 30)
                .background(AppTheme.progressBg(colorScheme), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .help(help)
    }

    private func restoreSelection() {
        guard let book = selectedBook else { return }
        selectedBookIDText = book.id.uuidString
        currentChapterIndex = min(max(book.lastReadChapterIndex, 0), max(book.chapters.count - 1, 0))
        currentParagraphIndex = min(
            max(book.lastReadParagraphIndex, 0),
            max((book.chapters[safe: currentChapterIndex]?.paragraphs.count ?? 1) - 1, 0)
        )
    }

    private func saveProgress() {
        guard let selectedBook else { return }
        library.updateProgress(
            bookId: selectedBook.id,
            chapterIndex: currentChapterIndex,
            paragraphIndex: currentParagraphIndex
        )
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let book = try library.importNovel(from: url)
            selectedBookIDText = book.id.uuidString
            restoreSelection()
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }

    // 章节跳转菜单：长书只列当前章节附近 ±50 章，头尾另提供快捷跳转
    @ViewBuilder
    private func chapterMenuItems(book: NovelBook) -> some View {
        let total = book.chapters.count
        if total > 0 {
            // 防御：currentChapterIndex 可能瞬时超出新书范围，先 clamp 避免构造非法 Range
            let safeIndex = min(max(currentChapterIndex, 0), total - 1)
            let lower = max(safeIndex - 50, 0)
            let upper = min(safeIndex + 50, total - 1)

            if lower > 0 {
                Button("1. \(book.chapters[0].title)") {
                    jumpToChapter(0, book: book)
                }
                Divider()
            }

            ForEach(lower...upper, id: \.self) { index in
                Button {
                    jumpToChapter(index, book: book)
                } label: {
                    if index == currentChapterIndex {
                        Label("\(index + 1). \(book.chapters[index].title)", systemImage: "checkmark")
                    } else {
                        Text("\(index + 1). \(book.chapters[index].title)")
                    }
                }
            }

            if upper < total - 1 {
                Divider()
                Button("\(total). \(book.chapters[total - 1].title)") {
                    jumpToChapter(total - 1, book: book)
                }
            }
        }
    }

    private func jumpToChapter(_ index: Int, book: NovelBook) {
        guard index != currentChapterIndex else { return }
        saveProgress()
        currentChapterIndex = min(max(index, 0), max(book.chapters.count - 1, 0))
        currentParagraphIndex = 0
        saveProgress()
    }

    private func moveChapter(by offset: Int, book: NovelBook) {
        saveProgress()
        currentChapterIndex = min(max(currentChapterIndex + offset, 0), max(book.chapters.count - 1, 0))
        currentParagraphIndex = 0
    }

    private func moveParagraph(by offset: Int, book: NovelBook) {
        guard let chapter = book.chapters[safe: currentChapterIndex] else { return }
        let next = currentParagraphIndex + offset

        if next < 0, currentChapterIndex > 0 {
            currentChapterIndex -= 1
            currentParagraphIndex = max((book.chapters[safe: currentChapterIndex]?.paragraphs.count ?? 1) - 1, 0)
        } else if next >= chapter.paragraphs.count, currentChapterIndex < book.chapters.count - 1 {
            currentChapterIndex += 1
            currentParagraphIndex = 0
        } else {
            currentParagraphIndex = min(max(next, 0), max(chapter.paragraphs.count - 1, 0))
        }
        saveProgress()
    }

    private func isAtEnd(of book: NovelBook) -> Bool {
        guard let chapter = book.chapters[safe: currentChapterIndex] else { return true }
        return currentChapterIndex >= book.chapters.count - 1 &&
            currentParagraphIndex >= chapter.paragraphs.count - 1
    }

    private func readingProgress(book: NovelBook) -> Double {
        guard !book.chapters.isEmpty else { return 0 }
        let chapterWeight = Double(currentChapterIndex) / Double(max(book.chapters.count, 1))
        let paragraphCount = Double(max(currentChapter?.paragraphs.count ?? 1, 1))
        let paragraphWeight = Double(currentParagraphIndex) / paragraphCount / Double(max(book.chapters.count, 1))
        return min(max(chapterWeight + paragraphWeight, 0), 1)
    }

    private func playPause(book: NovelBook) {
        if speech.currentBookID == book.id {
            switch speech.state {
            case .playing:
                speech.pause()
            case .paused:
                speech.resume()
            case .idle:
                speech.startReading(book: book, chapterIndex: currentChapterIndex, paragraphIndex: currentParagraphIndex)
            }
        } else {
            speech.startReading(book: book, chapterIndex: currentChapterIndex, paragraphIndex: currentParagraphIndex)
        }
    }

    private func playPauseIcon(book: NovelBook) -> String {
        speech.currentBookID == book.id && speech.state == .playing ? "pause.fill" : "play.fill"
    }
}
