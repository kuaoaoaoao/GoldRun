import XCTest
@testable import GoldRun

@MainActor
final class EnglishLearningTests: XCTestCase {
    func testDailyContentIsStableWithinDayAndChangesAcrossDays() {
        let repository = EnglishContentRepository()
        let calendar = Self.utcCalendar
        let dayOneMorning = Self.date(year: 2026, month: 7, day: 14, hour: 8)
        let dayOneEvening = Self.date(year: 2026, month: 7, day: 14, hour: 22)
        let dayTwo = Self.date(year: 2026, month: 7, day: 15, hour: 8)

        XCTAssertEqual(
            repository.dailyQuote(on: dayOneMorning, calendar: calendar),
            repository.dailyQuote(on: dayOneEvening, calendar: calendar)
        )
        XCTAssertNotEqual(
            repository.dailyQuote(on: dayOneMorning, calendar: calendar).id,
            repository.dailyQuote(on: dayTwo, calendar: calendar).id
        )
    }

    func testDailyCategoryRefreshesAfterLocalDateChanges() {
        let repository = EnglishContentRepository()
        let store = EnglishProgressStore(persistenceURL: nil)
        let textbookStore = EnglishTextbookStore(persistenceURL: nil, settings: .shared)
        let manager = EnglishLearningManager(
            repository: repository,
            textbookStore: textbookStore,
            progressStore: store,
            settings: .shared
        )
        let calendar = Self.utcCalendar
        let dayOne = Self.date(year: 2026, month: 7, day: 14)
        let dayTwo = Self.date(year: 2026, month: 7, day: 15)

        manager.selectCategory(.daily)
        manager.refreshQueue(on: dayOne, calendar: calendar)
        XCTAssertEqual(manager.currentItem, repository.dailyQuote(on: dayOne, calendar: calendar))

        manager.refreshQueue(on: dayTwo, calendar: calendar)
        XCTAssertEqual(manager.currentItem, repository.dailyQuote(on: dayTwo, calendar: calendar))
    }

    func testQueueFilteringKeepsSelectedCategoryOnly() {
        let repository = EnglishContentRepository()

        let words = repository.orderedItems(for: .words, progress: [:])
        let sentences = repository.orderedItems(for: .sentences, progress: [:])
        let passages = repository.orderedItems(for: .passages, progress: [:])

        XCTAssertFalse(words.isEmpty)
        XCTAssertTrue(words.allSatisfy { $0.category == .words })
        XCTAssertTrue(sentences.allSatisfy { $0.category == .sentences })
        XCTAssertTrue(passages.allSatisfy { $0.category == .passages })
    }

    func testContentCanBeFilteredByDifficulty() {
        let beginner = EnglishLearningItem(
            id: "word.beginner",
            category: .words,
            difficulty: .beginner,
            title: "hello",
            translation: "你好"
        )
        let intermediate = EnglishLearningItem(
            id: "word.intermediate",
            category: .words,
            difficulty: .intermediate,
            title: "significant",
            translation: "重要的"
        )
        let repository = EnglishContentRepository(
            words: [beginner, intermediate],
            sentences: [],
            passages: [],
            quotes: [beginner]
        )

        XCTAssertEqual(repository.items(for: .words, difficulty: .beginner), [beginner])
        XCTAssertEqual(repository.items(for: .words, difficulty: .intermediate), [intermediate])
    }

    func testBundledContentIsCompleteAndUsesUniqueIdentifiers() {
        let repository = EnglishContentRepository()
        let allItems = repository.allItems

        XCTAssertFalse(repository.words.isEmpty)
        XCTAssertFalse(repository.sentences.isEmpty)
        XCTAssertFalse(repository.passages.isEmpty)
        XCTAssertFalse(repository.quotes.isEmpty)
        XCTAssertGreaterThanOrEqual(repository.sentences.count, 60)
        XCTAssertGreaterThanOrEqual(repository.passages.count, 18)
        XCTAssertEqual(Set(allItems.map(\.id)).count, allItems.count)
        XCTAssertTrue(allItems.allSatisfy { $0.difficulty == .beginner })

        for word in repository.words {
            XCTAssertFalse(word.title.isEmpty)
            XCTAssertFalse(word.pronunciation?.isEmpty ?? true)
            XCTAssertFalse(word.partOfSpeech?.isEmpty ?? true)
            XCTAssertFalse(word.translation.isEmpty)
            XCTAssertFalse(word.example?.isEmpty ?? true)
            XCTAssertFalse(word.exampleTranslation?.isEmpty ?? true)
        }

        for passage in repository.passages {
            XCTAssertFalse(passage.translation.isEmpty)
            XCTAssertFalse(passage.passageSentences.isEmpty)
            XCTAssertEqual(passage.speechSegments, passage.passageSentences)
        }
    }

    func testSupplementalVocabularyLoadsFromJson() {
        let primarySupplement = EnglishVocabulary.supplementalWords(for: .primarySchool)
        let middleSupplement = EnglishVocabulary.supplementalWords(for: .middleSchool)
        let highSupplement = EnglishVocabulary.supplementalWords(for: .highSchool)
        let cet4Supplement = EnglishVocabulary.supplementalWords(for: .cet4)
        let allItems = EnglishVocabulary.all

        XCTAssertGreaterThan(primarySupplement.count, 300)
        XCTAssertGreaterThan(middleSupplement.count, 450)
        XCTAssertGreaterThan(highSupplement.count, 350)
        XCTAssertGreaterThan(cet4Supplement.count, 350)
        XCTAssertEqual(Set(allItems.map(\.id)).count, allItems.count)
        XCTAssertTrue(primarySupplement.contains { $0.title == "a" && $0.translation.contains("一个") })
        XCTAssertTrue(primarySupplement.contains { $0.title == "where" && $0.translation.contains("哪里") })
        XCTAssertTrue(primarySupplement.contains { $0.title == "breakfast" && $0.translation.contains("早餐") })
        XCTAssertTrue(middleSupplement.contains { $0.title == "dictionary" && $0.translation.contains("词典") })
        XCTAssertTrue(highSupplement.contains { $0.title == "hypothesis" && $0.translation.contains("假设") })
        XCTAssertTrue(cet4Supplement.contains { $0.title == "criterion" && $0.translation.contains("标准") })

        for item in primarySupplement + middleSupplement + highSupplement + cet4Supplement {
            XCTAssertEqual(item.category, .words)
            XCTAssertFalse(item.title.isEmpty)
            XCTAssertFalse(item.translation.isEmpty)
            XCTAssertFalse(item.partOfSpeech?.isEmpty ?? true)
            if let example = item.example {
                XCTAssertFalse(example.isEmpty)
            }
            if let exampleTranslation = item.exampleTranslation {
                XCTAssertFalse(exampleTranslation.isEmpty)
            }
        }
    }

    func testOrderedQueuePrioritizesDueAndLowerMasteryItems() {
        let dueWord = EnglishLearningItem(
            id: "word.due",
            category: .words,
            title: "due",
            pronunciation: "/duː/",
            partOfSpeech: "adj.",
            translation: "到期的"
        )
        let futureWord = EnglishLearningItem(
            id: "word.future",
            category: .words,
            title: "future",
            pronunciation: "/ˈfjuːtʃər/",
            partOfSpeech: "n.",
            translation: "未来"
        )
        let repository = EnglishContentRepository(
            words: [futureWord, dueWord],
            sentences: [],
            passages: [],
            quotes: [dueWord]
        )
        let now = Self.date(year: 2026, month: 7, day: 14)

        var progress: [String: EnglishItemProgress] = [:]
        progress[futureWord.id] = EnglishItemProgress(
            viewCount: 1,
            listenCount: 1,
            mastery: .mastered,
            isFavorite: false,
            lastStudiedAt: now,
            nextReviewAt: Self.date(year: 2026, month: 8, day: 14)
        )
        progress[dueWord.id] = EnglishItemProgress(
            viewCount: 1,
            listenCount: 1,
            mastery: .unfamiliar,
            isFavorite: false,
            lastStudiedAt: now,
            nextReviewAt: Self.date(year: 2026, month: 7, day: 14)
        )

        let ordered = repository.orderedItems(
            for: .words,
            progress: progress,
            on: now,
            calendar: Self.utcCalendar
        )

        XCTAssertEqual(ordered.map(\.id), [dueWord.id, futureWord.id])
    }

    func testMenuTextTruncatesLongSentences() {
        let item = EnglishLearningItem(
            id: "sentence.long",
            category: .sentences,
            title: "Please speak a little more slowly so I can understand every word.",
            translation: "请说慢一点。"
        )

        let text = item.menuBarText(style: .englishOnly, limit: 18)

        XCTAssertLessThanOrEqual(text.count, 18)
        XCTAssertTrue(text.hasSuffix("…"))
    }

    func testPlaybackVolumeNeverProducesSilentUtterance() {
        XCTAssertEqual(EnglishLearningManager.playbackVolume(0), 0.1)
        XCTAssertEqual(EnglishLearningManager.playbackVolume(0.75), 0.75)
        XCTAssertEqual(EnglishLearningManager.playbackVolume(2), 1)
    }

    func testKokoroBackendDefaultsAreSafe() {
        XCTAssertEqual(AppSettings.shared.englishTTSBackend.id.isEmpty, false)
        XCTAssertEqual(EnglishTTSBackend.system.title, "系统语音")
        XCTAssertEqual(KokoroEnglishSpeechProvider.defaultVoice, "af_heart")
    }

    func testKokoroCacheFileNameIsStableAndWav() {
        let first = KokoroEnglishSpeechProvider.cacheFileName(
            text: "Hello, nice to meet you.",
            voice: "af_heart",
            speed: 1.0
        )
        let second = KokoroEnglishSpeechProvider.cacheFileName(
            text: "Hello, nice to meet you.",
            voice: "af_heart",
            speed: 1.0
        )
        let differentVoice = KokoroEnglishSpeechProvider.cacheFileName(
            text: "Hello, nice to meet you.",
            voice: "bf_emma",
            speed: 1.0
        )

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, differentVoice)
        XCTAssertTrue(first.hasSuffix(".wav"))
    }

    func testKokoroCommandArgumentsMatchLocalWrapperContract() {
        let outputURL = URL(fileURLWithPath: "/tmp/kokoro-output.wav")
        let arguments = KokoroEnglishSpeechProvider.commandArguments(
            text: "hello",
            voice: "af_heart",
            speed: 0.82,
            outputURL: outputURL
        )

        XCTAssertEqual(arguments, [
            "--text", "hello",
            "--voice", "af_heart",
            "--speed", "0.82",
            "--output", "/tmp/kokoro-output.wav"
        ])
    }

    func testKokoroFallbackEligibilityRequiresExecutableCommand() {
        XCTAssertFalse(KokoroEnglishSpeechProvider.canAttempt(commandPath: ""))
        XCTAssertFalse(KokoroEnglishSpeechProvider.canAttempt(commandPath: "/definitely/missing/kokoro"))
        XCTAssertTrue(KokoroEnglishSpeechProvider.canAttempt(commandPath: "/bin/echo"))
    }

    func testIdleMenuBarReturnsToDailyWordAfterNavigation() {
        let repository = EnglishContentRepository()
        let store = EnglishProgressStore(persistenceURL: nil)
        let settings = AppSettings.shared
        let previousStyle = settings.englishMenuTextStyle
        let previousStage = settings.englishStage
        settings.englishMenuTextStyle = .englishOnly
        settings.englishStage = .daily
        defer {
            settings.englishMenuTextStyle = previousStyle
            settings.englishStage = previousStage
        }
        let textbookStore = EnglishTextbookStore(persistenceURL: nil, settings: settings)
        textbookStore.selectBuiltin(stage: .daily)

        let manager = EnglishLearningManager(
            repository: repository,
            textbookStore: textbookStore,
            progressStore: store,
            settings: settings
        )
        manager.next()

        XCTAssertEqual(
            manager.menuBarText,
            textbookStore.dailyWord().menuBarText(style: .englishOnly)
        )
    }

    func testTextbookStoreImportsCsvWordsAndSelectsImportedBook() throws {
        let settings = AppSettings.shared
        let previousStage = settings.englishStage
        defer { settings.englishStage = previousStage }
        let textbookStore = EnglishTextbookStore(persistenceURL: nil, settings: settings)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoldRun-EnglishTextbookTests-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("My Words.csv")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try """
        word,translation,pronunciation,part,example,example translation
        river,河流,/ˈrɪvər/,n.,The river is long.,这条河很长。
        mountain,山,/ˈmaʊntən/,n.,The mountain is high.,这座山很高。
        """.data(using: .utf8)?.write(to: url)

        let textbook = try textbookStore.importTextbook(from: url, stage: .primarySchool)

        XCTAssertEqual(textbook.title, "My Words")
        XCTAssertEqual(textbook.stage, .primarySchool)
        XCTAssertEqual(textbook.wordCount, 2)
        XCTAssertEqual(textbookStore.selectedTextbookID, textbook.id)
        XCTAssertEqual(textbookStore.selectedTextbook.items.map(\.title), ["river", "mountain"])
        XCTAssertEqual(settings.englishStage, .primarySchool)
    }

    func testManagerUsesSelectedImportedTextbookForWords() throws {
        let repository = EnglishContentRepository()
        let progressStore = EnglishProgressStore(persistenceURL: nil)
        let settings = AppSettings.shared
        let previousStage = settings.englishStage
        defer { settings.englishStage = previousStage }
        let textbookStore = EnglishTextbookStore(persistenceURL: nil, settings: settings)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoldRun-EnglishManagerTextbookTests-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("Imported.txt")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try """
        word\ttranslation
        galaxy\t星系
        orbit\t轨道
        """.data(using: .utf8)?.write(to: url)
        _ = try textbookStore.importTextbook(from: url, stage: .highSchool)

        let manager = EnglishLearningManager(
            repository: repository,
            textbookStore: textbookStore,
            progressStore: progressStore,
            settings: settings
        )

        XCTAssertTrue(["galaxy", "orbit"].contains(manager.currentItem?.title ?? ""))
        XCTAssertEqual(manager.queueCount, 2)
    }

    func testProgressPersistsAndReloadsFromDisk() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoldRun-EnglishLearningTests-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("progress.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = EnglishProgressStore(persistenceURL: url)
        store.recordShown("word.hello")
        store.recordListened("word.hello")
        store.setMastery(.mastered, for: "word.hello")
        store.toggleFavorite("word.hello")

        let reloaded = EnglishProgressStore(persistenceURL: url)
        let progress = reloaded.progress(for: "word.hello")

        XCTAssertEqual(progress.viewCount, 1)
        XCTAssertEqual(progress.listenCount, 1)
        XCTAssertEqual(progress.mastery, .mastered)
        XCTAssertTrue(progress.isFavorite)
        XCTAssertNotNil(progress.nextReviewAt)
    }

    func testMasterySchedulingAndDailySummary() throws {
        let store = EnglishProgressStore(persistenceURL: nil)
        let calendar = Self.utcCalendar
        let yesterday = Self.date(year: 2026, month: 7, day: 13)
        let today = Self.date(year: 2026, month: 7, day: 14)

        store.recordShown("word.hello", at: yesterday, calendar: calendar)
        store.recordShown("word.hello", at: today, calendar: calendar)
        store.recordShown("sentence.nice-to-meet-you", at: today, calendar: calendar)
        store.recordShown("sentence.nice-to-meet-you", at: today, calendar: calendar)
        store.setMastery(.unfamiliar, for: "word.hello", at: today, calendar: calendar)
        store.setMastery(.mastered, for: "sentence.nice-to-meet-you", at: today, calendar: calendar)

        let unfamiliarReview = try XCTUnwrap(store.progress(for: "word.hello").nextReviewAt)
        let masteredReview = try XCTUnwrap(store.progress(for: "sentence.nice-to-meet-you").nextReviewAt)
        let summary = store.summary(dailyTarget: 2, on: today, calendar: calendar)

        XCTAssertLessThan(unfamiliarReview, masteredReview)
        XCTAssertEqual(summary.learnedCount, 2)
        XCTAssertTrue(summary.isGoalComplete)
        XCTAssertEqual(summary.masteredCount, 1)
        XCTAssertEqual(summary.streak, 2)
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12
    ) -> Date {
        DateComponents(
            calendar: utcCalendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour
        ).date!
    }
}
