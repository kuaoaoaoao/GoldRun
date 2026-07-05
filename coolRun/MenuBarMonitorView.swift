import SwiftUI

struct MenuBarMonitorView: View {
    @State private var viewModel = SystemMonitorViewModel()
    @State private var viewMode: ViewMode = .monitor
    @Binding var isPinned: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(isPinned: Binding<Bool> = .constant(false)) {
        _isPinned = isPinned
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                viewModePicker

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isPinned.toggle()
                    }
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isPinned ? AppTheme.warning : AppTheme.textSecondary(colorScheme))
                        .frame(width: 28, height: 28)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(isPinned ? AppTheme.warning.opacity(0.14) : Color.clear)
                        }
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .help(isPinned ? "取消固定悬浮窗" : "固定悬浮窗")
            }
            .padding(.bottom, 6)

            // 内容区域
            switch viewMode {
            case .monitor:
                MonitorPanel(
                    snapshot: viewModel.snapshot,
                    cpuHistory: viewModel.cpuHistory,
                    memoryHistory: viewModel.memoryHistory,
                    downloadHistory: viewModel.downloadHistory,
                    uploadHistory: viewModel.uploadHistory,
                    cpuTempHistory: viewModel.cpuTempHistory,
                    gpuTempHistory: viewModel.gpuTempHistory
                )
            case .gold:
                GoldAnalysisView()
            case .calendar:
                CalendarView()
            case .novel:
                MenuBarNovelReaderView()
            }
        }
        .frame(width: 268)
        .padding(8)
        .background {
            ZStack {
                VisualEffectBlur(material: colorScheme == .dark ? .hudWindow : .menu, blendingMode: .behindWindow)
                if colorScheme == .light {
                    Color.white.opacity(0.3)
                } else {
                    Color.black.opacity(0.2)
                }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - 视图切换标签

    private var viewModePicker: some View {
        HStack(spacing: 4) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = mode
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(mode.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(viewMode == mode ? AppTheme.healthy : AppTheme.textSecondary(colorScheme))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .background {
                        if viewMode == mode {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppTheme.healthy.opacity(0.15))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        }
    }
}
