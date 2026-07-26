import AVFoundation
import Foundation

/// 手表端英语朗读：用系统 `AVSpeechSynthesizer` 朗读今日单词，
/// 口音（en-US / en-GB）与 macOS 端保持一致（由 iCloud 同步）。
@MainActor
final class WatchEnglishSpeech: ObservableObject {
    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private let delegateProxy = DelegateProxy()

    init() {
        delegateProxy.owner = self
        synthesizer.delegate = delegateProxy
    }

    func speak(_ text: String, accent: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        let language = accent.isEmpty ? "en-US" : accent
        utterance.voice = AVSpeechSynthesisVoice(language: language)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.0
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    fileprivate func markFinished() {
        isSpeaking = false
    }

    /// `AVSpeechSynthesizerDelegate` 的回调是 nonisolated，用代理桥接回 MainActor。
    private final class DelegateProxy: NSObject, AVSpeechSynthesizerDelegate {
        weak var owner: WatchEnglishSpeech?

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            Task { @MainActor [weak owner] in owner?.markFinished() }
        }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            Task { @MainActor [weak owner] in owner?.markFinished() }
        }
    }
}
