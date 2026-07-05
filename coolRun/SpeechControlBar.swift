import AVFoundation
import SwiftUI

struct SpeechControlBar: View {
    @ObservedObject var speech: NovelSpeechManager
    let book: NovelBook
    let theme: ReaderTheme
    let startAction: () -> Void

    @State private var showVoiceSettings = false

    var body: some View {
        VStack(spacing: 0) {
            progressBar

            HStack(spacing: 16) {
                sentenceInfo

                Spacer()

                HStack(spacing: 14) {
                    iconButton("backward.end.fill", help: "上一句", action: speech.skipBackward)
                        .disabled(!speech.isActive(for: book.id))

                    Button(action: playPauseTapped) {
                        Image(systemName: playPauseIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background {
                                Circle()
                                    .fill(AppTheme.healthy)
                            }
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .help(speech.state == .playing ? "暂停朗读" : "开始朗读")

                    iconButton("forward.end.fill", help: "下一句", action: speech.skipForward)
                        .disabled(!speech.isActive(for: book.id))

                    if speech.isActive(for: book.id) {
                        iconButton("stop.fill", help: "停止朗读", action: speech.stop)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Text(rateLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.secondaryColor)

                    iconButton("waveform", help: "语音设置") {
                        showVoiceSettings = true
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.backgroundColor.opacity(0.92))
                .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.secondaryColor.opacity(0.18), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .sheet(isPresented: $showVoiceSettings) {
            VoiceSettingsSheet(speech: speech)
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.secondaryColor.opacity(0.14))
                    .frame(height: 3)

                if speech.currentBookID == book.id,
                   let info = speech.progressInfo {
                    Capsule()
                        .fill(AppTheme.healthy)
                        .frame(width: geometry.size.width * min(max(info.chapterProgress, 0), 1), height: 3)
                }
            }
        }
        .frame(height: 3)
    }

    private var sentenceInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(displaySentence)
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(theme.textColor)
                .lineLimit(1)

            Text(displayDetail)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.secondaryColor)
                .lineLimit(1)
        }
        .frame(width: 230, alignment: .leading)
    }

    private var displaySentence: String {
        guard speech.currentBookID == book.id,
              !speech.currentSentenceText.isEmpty else {
            return "点击播放开始语音朗读"
        }

        let text = speech.currentSentenceText
        return text.count > 36 ? "\(text.prefix(36))..." : text
    }

    private var displayDetail: String {
        guard speech.currentBookID == book.id,
              let info = speech.progressInfo else {
            return "使用系统语音合成朗读当前章节"
        }

        return "第 \(info.chapterIndex + 1) 章 · 第 \(info.sentenceIndex + 1)/\(info.totalSentences) 句"
    }

    private var playPauseIcon: String {
        speech.currentBookID == book.id && speech.state == .playing ? "pause.fill" : "play.fill"
    }

    private var rateLabel: String {
        switch speech.rate {
        case ..<0.25: return "0.5x"
        case ..<0.45: return "0.75x"
        case ..<0.60: return "1.0x"
        case ..<0.78: return "1.25x"
        default: return "1.5x"
        }
    }

    private func playPauseTapped() {
        if speech.currentBookID == book.id {
            switch speech.state {
            case .playing:
                speech.pause()
            case .paused:
                speech.resume()
            case .idle:
                startAction()
            }
        } else {
            startAction()
        }
    }

    private func iconButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryColor)
                .frame(width: 30, height: 30)
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .help(help)
    }
}

struct VoiceSettingsSheet: View {
    @ObservedObject var speech: NovelSpeechManager
    @Environment(\.dismiss) private var dismiss

    private var voices: [AVSpeechSynthesisVoice] {
        NovelSpeechManager.availableVoices
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("语音朗读")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("完成") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            Form {
                Picker("语音", selection: $speech.voiceIdentifier) {
                    Text("系统默认中文").tag("")
                    ForEach(voices, id: \.identifier) { voice in
                        Text("\(voice.name) · \(voice.language)").tag(voice.identifier)
                    }
                }

                LabeledContent("语速") {
                    HStack {
                        Slider(value: $speech.rate, in: 0...1, step: 0.05)
                        Text(rateLabel)
                            .font(.caption.monospacedDigit())
                            .frame(width: 42, alignment: .trailing)
                    }
                }

                LabeledContent("音调") {
                    Slider(value: $speech.pitch, in: 0...1, step: 0.05)
                }

                LabeledContent("音量") {
                    Slider(value: $speech.volume, in: 0...1, step: 0.05)
                }

                Toggle("朗读时自动滚动", isOn: $speech.autoScroll)
                Toggle("章节结束后自动继续", isOn: $speech.autoContinue)
            }
            .formStyle(.grouped)
            .padding(16)
        }
        .frame(width: 440, height: 430)
    }

    private var rateLabel: String {
        switch speech.rate {
        case ..<0.25: return "0.5x"
        case ..<0.45: return "0.75x"
        case ..<0.60: return "1.0x"
        case ..<0.78: return "1.25x"
        default: return "1.5x"
        }
    }
}
