import AVFoundation
import Combine
import Foundation

enum SpeechState: Equatable {
    case idle
    case playing
    case paused
}

struct SpeechProgress: Equatable {
    var sentenceIndex: Int
    var totalSentences: Int
    var chapterIndex: Int
    var totalChapters: Int
    var sentenceProgress: Double

    var chapterProgress: Double {
        guard totalSentences > 0 else { return 0 }
        return (Double(sentenceIndex) + sentenceProgress) / Double(totalSentences)
    }
}

@MainActor
final class NovelSpeechManager: NSObject, ObservableObject {
    static let shared = NovelSpeechManager()

    @Published private(set) var state: SpeechState = .idle
    @Published private(set) var currentBookID: NovelBook.ID?
    @Published private(set) var currentChapterIndex = -1
    @Published private(set) var currentSentenceIndex = -1
    @Published private(set) var currentParagraphIndex = 0
    @Published private(set) var currentSentenceText = ""
    @Published private(set) var sentenceProgress = 0.0

    @Published var rate: Double {
        didSet { defaults.set(rate, forKey: Keys.rate) }
    }

    @Published var pitch: Double {
        didSet { defaults.set(pitch, forKey: Keys.pitch) }
    }

    @Published var volume: Double {
        didSet { defaults.set(volume, forKey: Keys.volume) }
    }

    @Published var voiceIdentifier: String {
        didSet { defaults.set(voiceIdentifier, forKey: Keys.voiceIdentifier) }
    }

    @Published var autoScroll: Bool {
        didSet { defaults.set(autoScroll, forKey: Keys.autoScroll) }
    }

    @Published var autoContinue: Bool {
        didSet { defaults.set(autoContinue, forKey: Keys.autoContinue) }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let defaults = UserDefaults.standard
    private var currentBook: NovelBook?
    private var sentences: [String] = []
    private var sentenceParagraphIndices: [Int] = []
    private var progressTimer: Timer?
    private var utteranceStartedAt: Date?
    private var utteranceDuration: TimeInterval = 0
    private var isStoppingForSeek = false
    private var isPausedByUser = false
    private var shouldRestartAfterPause = false

    var progressInfo: SpeechProgress? {
        guard !sentences.isEmpty else { return nil }
        return SpeechProgress(
            sentenceIndex: max(currentSentenceIndex, 0),
            totalSentences: sentences.count,
            chapterIndex: max(currentChapterIndex, 0),
            totalChapters: currentBook?.chapters.count ?? 0,
            sentenceProgress: sentenceProgress
        )
    }

    var currentVoice: AVSpeechSynthesisVoice? {
        if !voiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            return voice
        }

        let chineseVoices = Self.availableChineseVoices
        return chineseVoices.first { $0.quality == .enhanced }
            ?? chineseVoices.first
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
    }

    static var availableChineseVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("yue") }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static var availableVoices: [AVSpeechSynthesisVoice] {
        let preferred = availableChineseVoices
        if !preferred.isEmpty {
            return preferred
        }
        return AVSpeechSynthesisVoice.speechVoices()
            .sorted { "\($0.language)-\($0.name)".localizedStandardCompare("\($1.language)-\($1.name)") == .orderedAscending }
    }

    private var effectiveRate: Float {
        let minRate: Float = 0.10
        let maxRate: Float = 0.62
        return minRate + Float(rate) * (maxRate - minRate)
    }

    private override init() {
        self.rate = defaults.object(forKey: Keys.rate) as? Double ?? 0.45
        self.pitch = defaults.object(forKey: Keys.pitch) as? Double ?? 0.50
        self.volume = defaults.object(forKey: Keys.volume) as? Double ?? 0.85
        self.voiceIdentifier = defaults.string(forKey: Keys.voiceIdentifier) ?? ""
        self.autoScroll = defaults.object(forKey: Keys.autoScroll) as? Bool ?? true
        self.autoContinue = defaults.object(forKey: Keys.autoContinue) as? Bool ?? true

        super.init()
        synthesizer.delegate = self
    }

    func isActive(for bookID: NovelBook.ID) -> Bool {
        currentBookID == bookID && state != .idle
    }

    func toggle(book: NovelBook, chapterIndex: Int, paragraphIndex: Int) {
        if currentBookID == book.id {
            switch state {
            case .playing:
                pause()
            case .paused:
                resume()
            case .idle:
                startReading(book: book, chapterIndex: chapterIndex, paragraphIndex: paragraphIndex)
            }
        } else {
            startReading(book: book, chapterIndex: chapterIndex, paragraphIndex: paragraphIndex)
        }
    }

    func startReading(book: NovelBook, chapterIndex: Int, paragraphIndex: Int = 0) {
        EnglishLearningManager.shared.stop()
        stop()

        isPausedByUser = false
        shouldRestartAfterPause = false
        currentBook = book
        currentBookID = book.id
        currentChapterIndex = min(max(chapterIndex, 0), max(book.chapters.count - 1, 0))
        prepareChapter(at: currentChapterIndex)

        guard !sentences.isEmpty else {
            state = .idle
            return
        }

        let startSentence = firstSentenceIndex(forParagraph: paragraphIndex)
        speakFrom(index: startSentence)
    }

    func pause() {
        guard state == .playing else { return }

        isPausedByUser = true
        stopProgressTimer()

        if synthesizer.isSpeaking {
            let didPause = synthesizer.pauseSpeaking(at: .immediate)
            shouldRestartAfterPause = !didPause

            if !didPause {
                isStoppingForSeek = true
                synthesizer.stopSpeaking(at: .immediate)
            }
        } else {
            shouldRestartAfterPause = true
        }

        state = .paused
    }

    func resume() {
        guard state == .paused else { return }

        isPausedByUser = false

        if shouldRestartAfterPause || !synthesizer.isPaused {
            shouldRestartAfterPause = false
            speakFrom(index: max(currentSentenceIndex, 0))
            return
        }

        synthesizer.continueSpeaking()
        restartTimerFromCurrentProgress()
        state = .playing
    }

    func stop() {
        isPausedByUser = false
        shouldRestartAfterPause = false
        isStoppingForSeek = false
        synthesizer.stopSpeaking(at: .immediate)
        stopProgressTimer()
        state = .idle
        currentSentenceIndex = -1
        currentSentenceText = ""
        sentenceProgress = 0
    }

    func skipForward() {
        guard state != .idle else { return }
        seekTo(sentenceIndex: currentSentenceIndex + 1)
    }

    func skipBackward() {
        guard state != .idle else { return }
        seekTo(sentenceIndex: max(currentSentenceIndex - 1, 0))
    }

    func seekTo(sentenceIndex: Int) {
        guard !sentences.isEmpty else { return }
        let safeIndex = min(max(sentenceIndex, 0), sentences.count - 1)
        isPausedByUser = false
        shouldRestartAfterPause = false
        isStoppingForSeek = true
        synthesizer.stopSpeaking(at: .immediate)
        speakFrom(index: safeIndex)
    }

    func jumpToChapter(_ chapterIndex: Int) {
        guard let book = currentBook else { return }
        currentChapterIndex = min(max(chapterIndex, 0), max(book.chapters.count - 1, 0))
        prepareChapter(at: currentChapterIndex)
        seekTo(sentenceIndex: 0)
    }

    private func prepareChapter(at chapterIndex: Int) {
        guard let book = currentBook,
              let chapter = book.chapters[safe: chapterIndex] else {
            sentences = []
            sentenceParagraphIndices = []
            return
        }

        let result = Self.splitParagraphsIntoSentences(chapter.paragraphs)
        sentences = result.sentences
        sentenceParagraphIndices = result.paragraphIndices
    }

    private func speakFrom(index: Int) {
        guard index < sentences.count else {
            handleChapterFinished()
            return
        }

        let sentence = sentences[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentence.isEmpty else {
            speakFrom(index: index + 1)
            return
        }

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = currentVoice
        utterance.rate = effectiveRate
        utterance.pitchMultiplier = 0.8 + Float(pitch) * 0.4
        utterance.volume = Float(volume)
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.12

        currentSentenceIndex = index
        currentParagraphIndex = sentenceParagraphIndices[safe: index] ?? 0
        currentSentenceText = sentence
        sentenceProgress = 0
        state = .playing
        isPausedByUser = false
        shouldRestartAfterPause = false
        isStoppingForSeek = false

        utteranceStartedAt = Date()
        utteranceDuration = estimateDuration(for: sentence)
        startProgressTimer()
        synthesizer.speak(utterance)
    }

    private func handleChapterFinished() {
        stopProgressTimer()

        guard let book = currentBook,
              autoContinue,
              currentChapterIndex + 1 < book.chapters.count else {
            state = .idle
            currentSentenceIndex = -1
            currentSentenceText = ""
            sentenceProgress = 0
            return
        }

        currentChapterIndex += 1
        prepareChapter(at: currentChapterIndex)
        speakFrom(index: 0)
    }

    private func estimateDuration(for text: String) -> TimeInterval {
        let charsPerSecond = 2.5 + Double(effectiveRate) * 8.0
        return max(Double(text.count) / charsPerSecond, 0.4)
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      let startedAt = self.utteranceStartedAt else { return }
                let elapsed = Date().timeIntervalSince(startedAt)
                self.sentenceProgress = min(elapsed / max(self.utteranceDuration, 0.1), 1.0)
            }
        }
    }

    private func restartTimerFromCurrentProgress() {
        let elapsed = utteranceDuration * sentenceProgress
        utteranceStartedAt = Date().addingTimeInterval(-elapsed)
        startProgressTimer()
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func firstSentenceIndex(forParagraph paragraphIndex: Int) -> Int {
        sentenceParagraphIndices.firstIndex { $0 >= paragraphIndex } ?? 0
    }

    static func splitParagraphsIntoSentences(_ paragraphs: [String]) -> (sentences: [String], paragraphIndices: [Int]) {
        var sentences: [String] = []
        var paragraphIndices: [Int] = []
        let delimiters: Set<Character> = ["。", "！", "？", "…", "；", "!", "?", ".", ":", "："]

        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            var buffer = ""
            for character in trimmed {
                buffer.append(character)
                if delimiters.contains(character) {
                    appendSentence(buffer, paragraphIndex: paragraphIndex, sentences: &sentences, paragraphIndices: &paragraphIndices)
                    buffer = ""
                }
            }
            appendSentence(buffer, paragraphIndex: paragraphIndex, sentences: &sentences, paragraphIndices: &paragraphIndices)
        }

        return (sentences, paragraphIndices)
    }

    private static func appendSentence(
        _ text: String,
        paragraphIndex: Int,
        sentences: inout [String],
        paragraphIndices: inout [Int]
    ) {
        let sentence = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentence.isEmpty else { return }
        sentences.append(sentence)
        paragraphIndices.append(paragraphIndex)
    }

    private enum Keys {
        static let rate = "speechRate"
        static let pitch = "speechPitch"
        static let volume = "speechVolume"
        static let voiceIdentifier = "speechVoiceID"
        static let autoScroll = "speechAutoScroll"
        static let autoContinue = "speechAutoContinue"
    }
}

extension NovelSpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self,
                  !self.isStoppingForSeek,
                  !self.isPausedByUser,
                  self.state == .playing else { return }
            self.speakFrom(index: self.currentSentenceIndex + 1)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isStoppingForSeek = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.stopProgressTimer()
            self?.state = .paused
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.state = .playing
        }
    }
}
