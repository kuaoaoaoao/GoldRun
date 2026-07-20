import SwiftUI
import UniformTypeIdentifiers

struct EnglishTextbookManagementView: View {
    @ObservedObject private var textbookStore = EnglishTextbookStore.shared
    @ObservedObject private var progressStore = EnglishProgressStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var showingImporter = false
    @State private var importStage = AppSettings.shared.englishStage
    @State private var importError: String?
    @State private var showImportError = false

    private var selectedTextbook: EnglishTextbook {
        textbookStore.selectedTextbook
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                textbookList
                    .frame(width: 220)

                Divider()

                textbookDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 660, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .alert(LocalizedString.english("textbook_import_failed"), isPresented: $showImportError) {
            Button(LocalizedString.common("ok")) {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.healthy)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedString.english("textbook_management"))
                    .font(.system(size: 17, weight: .bold))
                Text(LocalizedString.english("textbook_source_hint"))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            Picker("", selection: $importStage) {
                ForEach(EnglishStage.allCases) { stage in
                    Text(stage.shortTitle).tag(stage)
                }
            }
            .labelsHidden()
            .frame(width: 112)
            .help(LocalizedString.english("import_stage_help"))

            Button {
                showingImporter = true
            } label: {
                Label(LocalizedString.english("import_textbook"), systemImage: "square.and.arrow.down")
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
            }
            .buttonStyle(.plain)
            .help(LocalizedString.common("close"))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var textbookList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                textbookGroup(
                    title: LocalizedString.english("builtin_textbooks"),
                    textbooks: textbookStore.builtinTextbooks
                )

                if !textbookStore.customTextbooks.isEmpty {
                    textbookGroup(
                        title: LocalizedString.english("imported_textbooks"),
                        textbooks: textbookStore.customTextbooks
                    )
                }
            }
            .padding(12)
        }
        .background(AppTheme.progressBg(colorScheme).opacity(colorScheme == .dark ? 0.55 : 0.7))
    }

    private func textbookGroup(title: String, textbooks: [EnglishTextbook]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            ForEach(textbooks) { textbook in
                textbookRow(textbook)
            }
        }
    }

    private func textbookRow(_ textbook: EnglishTextbook) -> some View {
        let progress = textbookStore.progressSummary(for: textbook, progress: progressStore.records)
        let isSelected = textbook.id == textbookStore.selectedTextbookID

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                textbookStore.selectTextbook(textbook)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: textbook.stage.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(textbook.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }

                Text("\(textbook.wordCount) \(LocalizedString.english("words_count")) · \(progress.viewedCount) \(LocalizedString.english("studied_count"))")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? AppTheme.healthy.opacity(0.9) : AppTheme.textSecondary(colorScheme))

                ProgressView(value: progress.studiedRatio(total: textbook.wordCount))
                    .tint(isSelected ? AppTheme.healthy : AppTheme.textSecondary(colorScheme))
                    .scaleEffect(y: 0.7)
            }
            .padding(9)
            .foregroundStyle(isSelected ? AppTheme.healthy : AppTheme.textPrimary(colorScheme))
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AppTheme.healthy.opacity(0.13) : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if textbook.isImported {
                Button(LocalizedString.novel("delete"), role: .destructive) {
                    textbookStore.removeTextbook(textbook)
                }
            }
        }
    }

    private var textbookDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                detailTitle
                statsGrid
                formatHint
                wordPreview
            }
            .padding(18)
        }
    }

    private var detailTitle: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(selectedTextbook.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary(colorScheme))
                Text(selectedTextbook.source == .builtin ? LocalizedString.english("builtin") : LocalizedString.english("imported"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(selectedTextbook.source == .builtin ? AppTheme.healthy : AppTheme.warning)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((selectedTextbook.source == .builtin ? AppTheme.healthy : AppTheme.warning).opacity(0.13), in: Capsule())
            }

            Text(selectedTextbook.summary)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    textbookStore.selectTextbook(selectedTextbook)
                    settings.englishStage = selectedTextbook.stage
                }
            } label: {
                Label(LocalizedString.english("use_this_textbook"), systemImage: "checkmark.circle")
                    .font(.system(size: 12, weight: .semibold))
            }
            .disabled(textbookStore.selectedTextbookID == selectedTextbook.id)
        }
    }

    private var statsGrid: some View {
        let progress = textbookStore.progressSummary(for: selectedTextbook, progress: progressStore.records)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            statTile(title: LocalizedString.english("words_count"), value: "\(selectedTextbook.wordCount)", icon: "textformat.abc")
            statTile(title: LocalizedString.english("studied_count"), value: "\(progress.viewedCount)", icon: "eye")
            statTile(title: LocalizedString.english("known_count"), value: "\(progress.familiarOrBetterCount)", icon: "checkmark")
            statTile(title: LocalizedString.english("mastered"), value: "\(progress.masteredCount)", icon: "seal.fill")
        }
    }

    private func statTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.healthy)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.progressBg(colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var formatHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedString.english("import_format_title"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
            Text(LocalizedString.english("import_format_hint"))
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .background(AppTheme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var wordPreview: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(LocalizedString.english("word_preview"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary(colorScheme))

            LazyVStack(spacing: 0) {
                ForEach(selectedTextbook.items.prefix(160)) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary(colorScheme))
                            .frame(width: 112, alignment: .leading)
                            .lineLimit(1)
                        Text(item.translation)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary(colorScheme))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(progressStore.progress(for: item.id).mastery.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.healthy)
                    }
                    .padding(.vertical, 6)
                    Divider().opacity(0.45)
                }
            }
            .padding(.horizontal, 10)
            .background(AppTheme.progressBg(colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var allowedContentTypes: [UTType] {
        [
            .plainText,
            .commaSeparatedText,
            UTType(filenameExtension: "csv") ?? .commaSeparatedText,
            UTType(filenameExtension: "tsv") ?? .plainText
        ]
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            _ = try textbookStore.importTextbook(from: url, stage: importStage)
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }
}
