import SwiftUI

/// 手表端“英语打卡”界面：连续天数、今日进度、今日单词（从 Mac 同步）。
struct WatchEnglishView: View {
    @StateObject private var store = WatchEnglishStore()
    @StateObject private var speech = WatchEnglishSpeech()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if store.hasData {
                    streakSection
                    Divider()
                    wordSection
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("英语")
        .onAppear { store.reload() }
    }

    // MARK: - 打卡进度

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(store.streak > 0 ? .orange : .secondary)
                Text("\(store.streak)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(store.streak > 0 ? .orange : .primary)
                Text("天连续打卡")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if store.dailyTarget > 0 {
                HStack {
                    Text(store.isGoalComplete ? "今日目标已完成" : "今日 \(store.learnedToday)/\(store.dailyTarget)")
                        .font(.footnote)
                        .foregroundStyle(store.isGoalComplete ? .green : .primary)
                    Spacer()
                    if store.isGoalComplete {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }
                ProgressView(value: store.progress)
                    .tint(store.isGoalComplete ? .green : .blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 今日单词

    @ViewBuilder
    private var wordSection: some View {
        if !store.word.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日单词")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(store.word)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                if !store.translation.isEmpty {
                    Text(store.translation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                speakButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var speakButton: some View {
        Button {
            if speech.isSpeaking {
                speech.stop()
            } else {
                speech.speak(store.word, accent: store.accent)
            }
        } label: {
            Label(speech.isSpeaking ? "停止" : "朗读", systemImage: speech.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                .font(.footnote)
        }
        .tint(.blue)
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "character.book.closed")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("暂无打卡数据")
                .font(.footnote)
            Text("在 Mac 端打开英语学习后自动同步")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

#Preview {
    NavigationStack { WatchEnglishView() }
}
