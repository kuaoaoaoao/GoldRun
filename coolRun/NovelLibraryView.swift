import SwiftUI
import UniformTypeIdentifiers

struct NovelLibraryView: View {
    @ObservedObject private var library = NovelLibraryManager.shared
    @State private var showingImporter = false
    @State private var selectedBook: NovelBook?
    @State private var hoveredBookID: NovelBook.ID?
    @State private var bookToDelete: NovelBook?
    @State private var importError: String?
    @State private var showDeleteConfirm = false
    @State private var showImportError = false
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 18)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if library.books.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(library.books) { book in
                            BookCardView(book: book, isHovering: hoveredBookID == book.id)
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        hoveredBookID = hovering ? book.id : nil
                                    }
                                }
                                .onTapGesture {
                                    selectedBook = book
                                    Analytics.capture(.novelOpened, properties: [
                                        "chapter_count": book.chapters.count,
                                    ])
                                }
                                .contextMenu {
                                    Button(LocalizedString.novel("open_read")) {
                                        selectedBook = book
                                    }
                                    Button(LocalizedString.novel("delete"), role: .destructive) {
                                        bookToDelete = book
                                        showDeleteConfirm = true
                                    }
                                }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                AppTheme.canvas(colorScheme)
                LinearGradient(
                    colors: [AppTheme.accent.opacity(0.07), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "txt") ?? .plainText],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .sheet(item: $selectedBook) { book in
            NovelReaderView(bookId: book.id)
                .frame(minWidth: 760, minHeight: 580)
        }
        .alert(LocalizedString.novel("import_failed"), isPresented: $showImportError) {
            Button(LocalizedString.common("ok")) {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
        .alert(LocalizedString.novel("confirm_delete"), isPresented: $showDeleteConfirm) {
            Button(LocalizedString.common("cancel"), role: .cancel) {
                bookToDelete = nil
            }
            Button(LocalizedString.novel("delete"), role: .destructive) {
                if let bookToDelete {
                    library.removeBook(bookId: bookToDelete.id)
                }
                bookToDelete = nil
            }
        } message: {
            Text(LocalizedString.novel("delete_warning") + (bookToDelete?.title ?? "") + LocalizedString.novel("delete_warning_suffix"))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(
                    AppTheme.accent.opacity(colorScheme == .dark ? 0.18 : 0.11),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedString.novel("novel_reader"))
                    .font(.title3.weight(.semibold))
                Text("\(library.books.count) \(LocalizedString.novel("books_count"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { showingImporter = true }) {
                Label(LocalizedString.novel("import_novel"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut("o", modifiers: [.command])
        }
        .padding(.horizontal, 22)
        .frame(height: 68)
        .background(AppTheme.chromeSurface(colorScheme))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(LocalizedString.novel("empty_library"), systemImage: "book.closed")
        } description: {
            Text(LocalizedString.novel("empty_library_hint"))
        } actions: {
            Button(action: { showingImporter = true }) {
                Label(LocalizedString.novel("import_novel"), systemImage: "plus")
            }
            .keyboardShortcut("o", modifiers: [.command])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let book = try library.importNovel(from: url)
            selectedBook = book
            Analytics.capture(.novelImported, properties: [
                "chapter_count": book.chapters.count,
            ])
        } catch {
            importError = error.localizedDescription
            showImportError = true
            Analytics.capture(.novelImportFailed, properties: [
                "error_type": String(describing: type(of: error)),
            ])
        }
    }
}

private struct BookCardView: View {
    let book: NovelBook
    let isHovering: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard !book.chapters.isEmpty else { return 0 }
        let chapterCount = Double(book.chapters.count)
        return min(Double(book.lastReadChapterIndex + 1) / chapterCount, 1)
    }

    private var accentColor: Color {
        let palette: [Color] = [
            Color(red: 0.34, green: 0.65, blue: 0.46),
            Color(red: 0.52, green: 0.48, blue: 0.78),
            Color(red: 0.76, green: 0.42, blue: 0.48),
            Color(red: 0.36, green: 0.58, blue: 0.76),
            Color(red: 0.70, green: 0.57, blue: 0.32)
        ]
        return palette[abs(book.title.hashValue) % palette.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.62), Color.black.opacity(0.30)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    Rectangle()
                        .fill(.white.opacity(0.28))
                        .frame(width: 42, height: 1)
                    Text(book.title)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                    Rectangle()
                        .fill(.white.opacity(0.28))
                        .frame(width: 42, height: 1)
                }
            }
            .aspectRatio(0.70, contentMode: .fit)
            .shadow(color: .black.opacity(isHovering ? 0.24 : 0.12), radius: isHovering ? 10 : 5, y: isHovering ? 6 : 2)

            Text(book.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 5) {
                ProgressView(value: progress)
                    .tint(accentColor)
                HStack {
                    Text("\(book.chapters.count) 章")
                    Spacer()
                    Text("\(Int(progress * 100))%")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .padding(11)
        .appCardSurface(cornerRadius: 12, showsShadow: false)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isHovering ? AppTheme.accent.opacity(0.42) : Color.clear,
                    lineWidth: 1
                )
        }
        .shadow(color: isHovering ? AppTheme.shadow(colorScheme) : .clear, radius: 10, y: 4)
        .scaleEffect(isHovering ? 1.018 : 1)
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .contentShape(Rectangle())
    }
}
