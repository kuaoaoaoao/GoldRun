import SwiftUI

struct NovelReaderView: View {
    let bookId: NovelBook.ID

    @ObservedObject private var library = NovelLibraryManager.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @ObservedObject private var settings = ReaderSettings.shared
    @ObservedObject private var speech = NovelSpeechManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var currentChapterIndex = 0
    @State private var currentParagraphIndex = 0
    @State private var speechScrollTarget: Int?
    @State private var currentPageIndex = 0
    @State private var pageCacheKey = ""
    @State private var cachedPages: [String] = [""]
    @State private var showChapters = false
    @State private var showBookmarks = false
    @State private var showSettings = false

    private var book: NovelBook? {
        library.book(id: bookId)
    }

    private var currentChapter: NovelChapter? {
        book?.chapters[safe: currentChapterIndex]
    }

    var body: some View {
        Group {
            if let book {
                ZStack {
                    settings.theme.backgroundColor.ignoresSafeArea()

                    HStack(spacing: 0) {
                        if showChapters {
                            chapterSidebar(book: book)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        VStack(spacing: 0) {
                            header(book: book)
                            Divider().opacity(0.15)
                            readingContent
                            SpeechControlBar(
                                speech: speech,
                                book: book,
                                theme: settings.theme,
                                startAction: { startSpeech(book: book) }
                            )
                            footer(book: book)
                        }
                    }

                    if showBookmarks {
                        bookmarksPanel(book: book)
                    }
                }
                .foregroundStyle(settings.theme.textColor)
                .onAppear {
                    restoreReadingPosition(from: book)
                }
                .onDisappear {
                    saveReadingPosition()
                }
                .onChange(of: speech.currentChapterIndex) { _, newValue in
                    guard speech.currentBookID == book.id,
                          speech.autoScroll,
                          newValue >= 0,
                          newValue != currentChapterIndex else { return }
                    currentChapterIndex = newValue
                    currentParagraphIndex = 0
                    currentPageIndex = 0
                }
                .onChange(of: speech.currentParagraphIndex) { _, newValue in
                    guard speech.currentBookID == book.id,
                          speech.autoScroll,
                          speech.state != .idle else { return }
                    currentParagraphIndex = newValue
                    speechScrollTarget = newValue
                }
                .sheet(isPresented: $showSettings) {
                    ReaderSettingsSheet()
                }
            } else {
                ContentUnavailableView(LocalizedString.novel("book_not_found"), systemImage: "book.closed", description: Text(LocalizedString.novel("book_deleted_hint")))
            }
        }
    }

    private func header(book: NovelBook) -> some View {
        HStack(spacing: 14) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle")
            }
            .help(LocalizedString.novel("close"))

            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showChapters.toggle() } }) {
                Image(systemName: showChapters ? "sidebar.left.close" : "sidebar.left")
            }
            .help(LocalizedString.novel("toc"))

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(currentChapter?.title ?? LocalizedString.novel("no_chapter"))
                    .font(.caption)
                    .foregroundStyle(settings.theme.secondaryColor)
                    .lineLimit(1)
            }

            Spacer()

            if !book.chapters.isEmpty {
                Text("\(currentChapterIndex + 1) / \(book.chapters.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(settings.theme.secondaryColor)
            }

            Button(action: addBookmark) {
                Image(systemName: "bookmark.badge.plus")
            }
            .help(LocalizedString.novel("add_bookmark"))

            Button(action: { startSpeech(book: book) }) {
                Image(systemName: speech.currentBookID == book.id && speech.state == .playing ? "speaker.wave.2.fill" : "speaker.wave.2")
            }
            .help(LocalizedString.novel("read_aloud"))

            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showBookmarks.toggle() } }) {
                Image(systemName: showBookmarks ? "bookmark.fill" : "bookmark")
            }
            .help(LocalizedString.novel("bookmark"))

            Button(action: { showSettings = true }) {
                Image(systemName: "textformat.size")
            }
            .help(LocalizedString.novel("reading_settings"))
        }
        .buttonStyle(.plain)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(settings.theme.secondaryColor)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var readingContent: some View {
        if let chapter = currentChapter {
            switch settings.mode {
            case .scroll:
                scrollReadingView(chapter: chapter)
            case .page:
                pageReadingView(chapter: chapter)
            }
        } else {
            ContentUnavailableView(LocalizedString.novel("no_content"), systemImage: "doc.text")
                .foregroundStyle(settings.theme.secondaryColor)
        }
    }

    private func scrollReadingView(chapter: NovelChapter) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(chapter.paragraphs.indices, id: \.self) { index in
                        Text(chapter.paragraphs[index])
                            .font(.system(size: settings.fontSize, design: .serif))
                            .lineSpacing(settings.lineSpacing)
                            .foregroundStyle(settings.theme.textColor)
                            .padding(.horizontal, 76)
                            .padding(.vertical, max(settings.lineSpacing / 2, 4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                            .background {
                                if isSpeakingParagraph(index) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(AppTheme.healthy.opacity(0.12))
                                        .padding(.horizontal, 56)
                                }
                            }
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: NovelParagraphPositionKey.self,
                                        value: [NovelParagraphPosition(index: index, minY: geometry.frame(in: .named("readerScroll")).minY)]
                                    )
                                }
                            )
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.top, 24)
            }
            .coordinateSpace(name: "readerScroll")
            .onAppear {
                proxy.scrollTo(min(currentParagraphIndex, max(chapter.paragraphs.count - 1, 0)), anchor: .top)
            }
            .onChange(of: currentChapterIndex) { _, _ in
                proxy.scrollTo(0, anchor: .top)
            }
            .onChange(of: speechScrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(target, anchor: .center)
                }
                speechScrollTarget = nil
            }
            .onPreferenceChange(NovelParagraphPositionKey.self, perform: updateVisibleParagraph)
        }
    }

    private func pageReadingView(chapter: NovelChapter) -> some View {
        GeometryReader { geometry in
            let charsPerPage = estimateCharsPerPage(
                width: geometry.size.width - 140,
                height: geometry.size.height - 48
            )
            let cacheKey = makePageCacheKey(chapter: chapter, charsPerPage: charsPerPage)
            let pages = cachedPages.isEmpty ? [""] : cachedPages

            VStack(spacing: 0) {
                ScrollView {
                    Text(pages[safe: currentPageIndex] ?? "")
                        .font(.system(size: settings.fontSize, design: .serif))
                        .lineSpacing(settings.lineSpacing)
                        .foregroundStyle(settings.theme.textColor)
                        .padding(.horizontal, 76)
                        .padding(.vertical, 30)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 14) {
                    Button(action: { previousPage(pageCount: pages.count) }) {
                        Image(systemName: "chevron.left.circle")
                    }
                    .disabled(currentPageIndex <= 0)
                    .keyboardShortcut(.leftArrow, modifiers: [])

                    Text("\(min(currentPageIndex + 1, max(pages.count, 1))) / \(max(pages.count, 1))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(settings.theme.secondaryColor)

                    Button(action: { nextPage(pageCount: pages.count) }) {
                        Image(systemName: "chevron.right.circle")
                    }
                    .disabled(currentPageIndex >= pages.count - 1)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
                .buttonStyle(.plain)
                .font(.system(size: 18))
                .foregroundStyle(settings.theme.secondaryColor)
                .padding(.bottom, 10)
            }
            .task(id: cacheKey) {
                rebuildPageCacheIfNeeded(chapter: chapter, charsPerPage: charsPerPage, cacheKey: cacheKey)
            }
            .onChange(of: currentChapterIndex) { _, _ in
                currentPageIndex = 0
                pageCacheKey = ""
            }
        }
    }

    private func footer(book: NovelBook) -> some View {
        HStack(spacing: 12) {
            Text(progressText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(settings.theme.secondaryColor.opacity(0.75))

            Spacer()

            Button(action: previousChapter) {
                Label(LocalizedString.novel("prev_chapter"), systemImage: "chevron.left")
            }
            .disabled(currentChapterIndex <= 0)

            Button(action: nextChapter) {
                Label(LocalizedString.novel("next_chapter"), systemImage: "chevron.right")
            }
            .disabled(currentChapterIndex >= book.chapters.count - 1)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .foregroundStyle(settings.theme.secondaryColor)
    }

    private var progressText: String {
        guard let chapter = currentChapter else { return "0%" }
        let progress = Double(currentParagraphIndex) / Double(max(chapter.paragraphs.count - 1, 1))
        return "\(LocalizedString.novel("chapter_progress")) \(Int(progress * 100))%"
    }

    private func chapterSidebar(book: NovelBook) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(LocalizedString.novel("toc"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(settings.theme.textColor)
                Spacer()
                Text("\(book.chapters.count) \(LocalizedString.novel("chapters_count"))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(settings.theme.secondaryColor)
            }
            .padding(.leading, 22)
            .padding(.trailing, 18)
            .padding(.vertical, 12)

            Divider().opacity(0.15)
                .padding(.leading, 18)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(book.chapters) { chapter in
                            Button {
                                selectChapter(chapter.index)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(chapter.title)
                                        .font(.system(size: 13, weight: chapter.index == currentChapterIndex ? .semibold : .regular))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .foregroundStyle(chapter.index == currentChapterIndex ? AppTheme.healthy : settings.theme.textColor)

                                    Spacer(minLength: 8)

                                    if chapter.index == currentChapterIndex {
                                        Circle()
                                            .fill(AppTheme.healthy)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                                .padding(.leading, 22)
                                .padding(.trailing, 18)
                                .background {
                                    if chapter.index == currentChapterIndex {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(AppTheme.healthy.opacity(0.10))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 3)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .id(chapter.index)

                            Divider()
                                .opacity(0.10)
                                .padding(.leading, 22)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                }
                .onAppear {
                    proxy.scrollTo(currentChapterIndex, anchor: .center)
                }
            }
        }
        .frame(width: 286)
        .background(settings.theme.backgroundColor.opacity(0.97))
        .overlay(alignment: .trailing) {
            Divider().opacity(0.18)
        }
    }

    private func bookmarksPanel(book: NovelBook) -> some View {
        HStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(LocalizedString.novel("bookmark"))
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button(action: addBookmark) {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().opacity(0.15)

                if book.bookmarks.isEmpty {
                    ContentUnavailableView(LocalizedString.novel("empty_bookmarks", lang: appSettings.language), systemImage: "bookmark.slash")
                        .foregroundStyle(settings.theme.secondaryColor)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(book.bookmarks) { bookmark in
                                BookmarkRowView(book: book, bookmark: bookmark, theme: settings.theme)
                                    .onTapGesture {
                                        jumpToBookmark(bookmark)
                                    }
                                    .contextMenu {
                                        Button(LocalizedString.novel("jump", lang: appSettings.language)) {
                                            jumpToBookmark(bookmark)
                                        }
                                        Button(LocalizedString.common("delete", lang: appSettings.language), role: .destructive) {
                                            library.removeBookmark(bookId: book.id, bookmarkId: bookmark.id)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .frame(width: 250)
            .background(settings.theme.backgroundColor.opacity(0.97))
            .shadow(color: .black.opacity(0.15), radius: 10, x: -3)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private func restoreReadingPosition(from book: NovelBook) {
        currentChapterIndex = min(max(book.lastReadChapterIndex, 0), max(book.chapters.count - 1, 0))
        currentParagraphIndex = min(
            max(book.lastReadParagraphIndex, 0),
            max((book.chapters[safe: currentChapterIndex]?.paragraphs.count ?? 1) - 1, 0)
        )
        currentPageIndex = 0
    }

    private func saveReadingPosition() {
        library.updateProgress(
            bookId: bookId,
            chapterIndex: currentChapterIndex,
            paragraphIndex: currentParagraphIndex
        )
    }

    private func selectChapter(_ index: Int) {
        saveReadingPosition()
        withAnimation(.easeInOut(duration: 0.2)) {
            currentChapterIndex = index
            currentParagraphIndex = 0
            currentPageIndex = 0
            showChapters = false
        }
    }

    private func nextChapter() {
        guard let book, currentChapterIndex < book.chapters.count - 1 else { return }
        selectChapter(currentChapterIndex + 1)
    }

    private func previousChapter() {
        guard currentChapterIndex > 0 else { return }
        selectChapter(currentChapterIndex - 1)
    }

    private func previousPage(pageCount: Int) {
        currentPageIndex = max(currentPageIndex - 1, 0)
        syncParagraphFromPage(pageCount: pageCount)
    }

    private func nextPage(pageCount: Int) {
        currentPageIndex = min(currentPageIndex + 1, max(pageCount - 1, 0))
        syncParagraphFromPage(pageCount: pageCount)
    }

    private func addBookmark() {
        guard let chapter = currentChapter else { return }
        let preview = chapter.paragraphs[safe: currentParagraphIndex] ?? chapter.title
        library.addBookmark(
            bookId: bookId,
            chapterIndex: currentChapterIndex,
            paragraphIndex: currentParagraphIndex,
            previewText: String(preview.prefix(60))
        )
        Analytics.capture(.bookmarkAdded, properties: [
            "chapter_index": currentChapterIndex,
        ])
    }

    private func startSpeech(book: NovelBook) {
        speech.startReading(
            book: book,
            chapterIndex: currentChapterIndex,
            paragraphIndex: currentParagraphIndex
        )
        Analytics.capture(.novelSpeechStarted, properties: [
            "chapter_index": currentChapterIndex,
        ])
    }

    private func jumpToBookmark(_ bookmark: NovelBookmark) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentChapterIndex = bookmark.chapterIndex
            currentParagraphIndex = bookmark.paragraphIndex
            currentPageIndex = 0
            showBookmarks = false
        }
    }

    private func updateVisibleParagraph(_ positions: [NovelParagraphPosition]) {
        guard settings.mode == .scroll else { return }
        guard !(speech.currentBookID == bookId && speech.state == .playing && speech.autoScroll) else { return }
        let candidates = positions.filter { $0.minY > -40 && $0.minY < 240 }
        guard let nearest = candidates.min(by: { abs($0.minY) < abs($1.minY) }) else { return }
        if nearest.index != currentParagraphIndex {
            currentParagraphIndex = nearest.index
        }
    }

    private func isSpeakingParagraph(_ index: Int) -> Bool {
        speech.currentBookID == bookId
            && speech.state != .idle
            && speech.currentChapterIndex == currentChapterIndex
            && speech.currentParagraphIndex == index
    }

    private func estimateCharsPerPage(width: CGFloat, height: CGFloat) -> Int {
        let readableWidth = max(width, 260)
        let readableHeight = max(height, 260)
        let lineHeight = settings.fontSize + settings.lineSpacing
        let linesPerPage = max(Int(readableHeight / lineHeight), 6)
        let charsPerLine = max(Int(readableWidth / (settings.fontSize * 0.56)), 12)
        return max(linesPerPage * charsPerLine, 180)
    }

    private func buildPages(paragraphs: [String], charsPerPage: Int) -> [String] {
        var pages: [String] = []
        var currentPage = ""
        var currentCount = 0

        for paragraph in paragraphs {
            let nextCount = currentCount + paragraph.count
            if nextCount > charsPerPage, !currentPage.isEmpty {
                pages.append(currentPage)
                currentPage = ""
                currentCount = 0
            }
            currentPage += paragraph + "\n\n"
            currentCount += paragraph.count
        }

        if !currentPage.isEmpty {
            pages.append(currentPage)
        }

        return pages.isEmpty ? [""] : pages
    }

    private func makePageCacheKey(chapter: NovelChapter, charsPerPage: Int) -> String {
        "\(chapter.id.uuidString)-\(charsPerPage)-\(settings.fontSize)-\(settings.lineSpacing)"
    }

    private func rebuildPageCacheIfNeeded(chapter: NovelChapter, charsPerPage: Int, cacheKey: String) {
        guard cacheKey != pageCacheKey else { return }
        let pages = buildPages(paragraphs: chapter.paragraphs, charsPerPage: charsPerPage)
        cachedPages = pages
        pageCacheKey = cacheKey
        currentPageIndex = min(currentPageIndex, max(pages.count - 1, 0))
    }

    private func syncParagraphFromPage(pageCount: Int?) {
        guard let chapter = currentChapter else { return }
        let safePageCount = max(pageCount ?? 1, 1)
        let estimated = Int(Double(max(chapter.paragraphs.count - 1, 0)) * Double(currentPageIndex) / Double(max(safePageCount - 1, 1)))
        currentParagraphIndex = min(max(estimated, 0), max(chapter.paragraphs.count - 1, 0))
    }
}

private struct BookmarkRowView: View {
    let book: NovelBook
    let bookmark: NovelBookmark
    let theme: ReaderTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(book.chapters[safe: bookmark.chapterIndex]?.title ?? LocalizedString.novel("unknown_chapter"))
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.healthy)
                .lineLimit(1)

            Text(bookmark.previewText)
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(theme.textColor.opacity(0.75))
                .lineLimit(2)

            Text(bookmark.createdAt, style: .relative)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.secondaryColor.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct NovelParagraphPosition: Equatable {
    let index: Int
    let minY: CGFloat
}

private struct NovelParagraphPositionKey: PreferenceKey {
    static var defaultValue: [NovelParagraphPosition] = []

    static func reduce(value: inout [NovelParagraphPosition], nextValue: () -> [NovelParagraphPosition]) {
        value.append(contentsOf: nextValue())
    }
}
