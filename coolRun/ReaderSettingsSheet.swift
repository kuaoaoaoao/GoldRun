import SwiftUI

struct ReaderSettingsSheet: View {
    @ObservedObject private var settings = ReaderSettings.shared
    @ObservedObject private var speech = NovelSpeechManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("阅读设置")
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

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingsSection("阅读模式") {
                        HStack(spacing: 10) {
                            ForEach(ReadingMode.allCases) { mode in
                                modeButton(mode)
                            }
                        }
                    }

                    settingsSection("字体大小") {
                        HStack(spacing: 14) {
                            Text("A")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Slider(value: $settings.fontSize, in: 12...30, step: 1)
                            Text("A")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                            Text("\(Int(settings.fontSize))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                        }
                    }

                    settingsSection("行间距") {
                        HStack(spacing: 14) {
                            Image(systemName: "text.justify")
                                .foregroundStyle(.secondary)
                            Slider(value: $settings.lineSpacing, in: 2...22, step: 1)
                            Text("\(Int(settings.lineSpacing))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                        }
                    }

                    settingsSection("阅读主题") {
                        HStack(spacing: 14) {
                            ForEach(ReaderTheme.allCases) { theme in
                                themeButton(theme)
                            }
                        }
                    }

                    settingsSection("语音朗读") {
                        VStack(spacing: 12) {
                            LabeledContent("语速") {
                                HStack {
                                    Slider(value: $speech.rate, in: 0...1, step: 0.05)
                                    Text(speechRateLabel)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 42, alignment: .trailing)
                                }
                            }

                            LabeledContent("音量") {
                                Slider(value: $speech.volume, in: 0...1, step: 0.05)
                            }

                            Toggle("朗读时自动滚动", isOn: $speech.autoScroll)
                            Toggle("章节结束后自动继续", isOn: $speech.autoContinue)
                        }
                    }

                    settingsSection("预览效果") {
                        previewCard
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 430, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func modeButton(_ mode: ReadingMode) -> some View {
        Button {
            settings.mode = mode
        } label: {
            Label(mode.displayName, systemImage: mode.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(settings.mode == mode ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(settings.mode == mode ? AppTheme.healthy : Color.secondary.opacity(0.12))
                }
        }
        .buttonStyle(.plain)
    }

    private func themeButton(_ theme: ReaderTheme) -> some View {
        Button {
            settings.theme = theme
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(theme.backgroundColor)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Circle()
                                .stroke(settings.theme == theme ? AppTheme.healthy : Color.secondary.opacity(0.25), lineWidth: settings.theme == theme ? 2.5 : 1)
                        }
                    if settings.theme == theme {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.healthy)
                    }
                }

                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("第一章 初入江湖")
                .font(.system(size: max(settings.fontSize - 2, 12), weight: .semibold, design: .serif))
            Text("少年背负长剑，踏上了漫漫江湖路。远方群山连绵，云雾缭绕间隐约可见古寺的飞檐。")
                .font(.system(size: max(settings.fontSize - 2, 12), design: .serif))
                .lineSpacing(settings.lineSpacing)
        }
        .foregroundStyle(settings.theme.textColor)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(settings.theme.backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }

    private var speechRateLabel: String {
        switch speech.rate {
        case ..<0.25: return "0.5x"
        case ..<0.45: return "0.75x"
        case ..<0.60: return "1.0x"
        case ..<0.78: return "1.25x"
        default: return "1.5x"
        }
    }
}
