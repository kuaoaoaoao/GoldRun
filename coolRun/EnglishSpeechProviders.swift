import AVFoundation
import CryptoKit
import Foundation

struct EnglishSpeechRequest {
    let text: String
    let rate: Double
    let volume: Double
    let language: String
    let voice: AVSpeechSynthesisVoice?
    let kokoroVoice: String
}

@MainActor
protocol EnglishSpeechProviding: AnyObject {
    func speak(_ request: EnglishSpeechRequest) async -> Bool
    func pause()
    func resume()
    func stop()
}

@MainActor
final class SystemEnglishSpeechProvider: NSObject, EnglishSpeechProviding {
    private let synthesizer = AVSpeechSynthesizer()
    private var utteranceContinuation: CheckedContinuation<Bool, Never>?
    private var activeUtteranceID: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ request: EnglishSpeechRequest) async -> Bool {
        guard !request.text.isEmpty else { return true }
        return await withCheckedContinuation { continuation in
            let utterance = AVSpeechUtterance(string: request.text)
            utterance.voice = request.voice
            utterance.rate = Float(min(max(request.rate, 0.1), 0.65))
            utterance.volume = EnglishLearningManager.playbackVolume(request.volume)
            utterance.pitchMultiplier = 1
            utterance.preUtteranceDelay = 0.08
            utterance.postUtteranceDelay = 0.15
            utteranceContinuation = continuation
            activeUtteranceID = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        }
    }

    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }

    func stop() {
        finishUtterance(id: activeUtteranceID, success: false)
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func finishUtterance(id: ObjectIdentifier?, success: Bool) {
        guard id == activeUtteranceID else { return }
        let continuation = utteranceContinuation
        utteranceContinuation = nil
        activeUtteranceID = nil
        continuation?.resume(returning: success)
    }
}

extension SystemEnglishSpeechProvider: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.finishUtterance(id: id, success: true)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.finishUtterance(id: id, success: false)
        }
    }
}

@MainActor
final class KokoroEnglishSpeechProvider: NSObject, EnglishSpeechProviding {
    static let defaultVoice = "af_heart"
    static let providerVersion = "kokoro-command-v1"
    static let timeout: TimeInterval = 12

    private let settings: AppSettings
    private let cacheDirectory: URL?
    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Bool, Never>?

    init(
        settings: AppSettings,
        cacheDirectory: URL?
    ) {
        self.settings = settings
        self.cacheDirectory = cacheDirectory
        super.init()
    }

    static func canAttempt(commandPath: String) -> Bool {
        let path = commandPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return !path.isEmpty && FileManager.default.isExecutableFile(atPath: path)
    }

    static func speed(for rate: Double) -> Double {
        rate <= 0.35 ? 0.82 : 1.0
    }

    static func commandArguments(
        text: String,
        voice: String,
        speed: Double,
        outputURL: URL
    ) -> [String] {
        [
            "--text", text,
            "--voice", voice,
            "--speed", String(format: "%.2f", speed),
            "--output", outputURL.path
        ]
    }

    static func cacheFileName(text: String, voice: String, speed: Double) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = "\(providerVersion)|\(voice)|\(String(format: "%.2f", speed))|\(normalized)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".wav"
    }

    func speak(_ request: EnglishSpeechRequest) async -> Bool {
        guard request.language.hasPrefix("en"),
              Self.canAttempt(commandPath: settings.englishKokoroCommandPath),
              let outputURL = cacheURL(for: request) else {
            return false
        }

        if !FileManager.default.fileExists(atPath: outputURL.path) {
            let speed = Self.speed(for: request.rate)
            let arguments = Self.commandArguments(
                text: request.text,
                voice: request.kokoroVoice,
                speed: speed,
                outputURL: outputURL
            )
            let didSynthesize = await Self.runCommand(
                commandPath: settings.englishKokoroCommandPath,
                arguments: arguments,
                timeout: Self.timeout
            )
            guard didSynthesize,
                  !Task.isCancelled,
                  FileManager.default.fileExists(atPath: outputURL.path) else {
                return false
            }
        }

        return await playAudio(at: outputURL, volume: request.volume)
    }

    func pause() {
        audioPlayer?.pause()
    }

    func resume() {
        audioPlayer?.play()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        finishPlayback(success: false)
    }

    private func cacheURL(for request: EnglishSpeechRequest) -> URL? {
        guard let cacheDirectory else { return nil }
        do {
            try FileManager.default.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            return nil
        }
        let speed = Self.speed(for: request.rate)
        return cacheDirectory.appendingPathComponent(
            Self.cacheFileName(text: request.text, voice: request.kokoroVoice, speed: speed)
        )
    }

    private func playAudio(at url: URL, volume: Double) async -> Bool {
        await withCheckedContinuation { continuation in
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                playbackContinuation = continuation
                audioPlayer = player
                player.delegate = self
                player.volume = EnglishLearningManager.playbackVolume(volume)
                player.prepareToPlay()
                if !player.play() {
                    finishPlayback(success: false)
                }
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    private func finishPlayback(success: Bool) {
        let continuation = playbackContinuation
        playbackContinuation = nil
        audioPlayer = nil
        continuation?.resume(returning: success)
    }

    private static func runCommand(
        commandPath: String,
        arguments: [String],
        timeout: TimeInterval
    ) async -> Bool {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: commandPath)
            process.arguments = arguments

            do {
                try process.run()
            } catch {
                return false
            }

            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                try? await Task.sleep(for: .milliseconds(50))
            }

            if process.isRunning {
                process.terminate()
                return false
            }

            return process.terminationStatus == 0
        }.value
    }

    static func defaultCacheDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("coolRun", isDirectory: true)
            .appendingPathComponent("kokoro-cache", isDirectory: true)
    }
}

extension KokoroEnglishSpeechProvider: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.finishPlayback(success: flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.finishPlayback(success: false)
        }
    }
}
