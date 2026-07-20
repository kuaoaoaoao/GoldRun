import SwiftUI

struct MenuBarMonitorView: View {
    @State private var viewModel: SystemMonitorViewModel
    @State private var viewMode: ViewMode = .monitor
    @Binding var isPinned: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(
        viewModel: SystemMonitorViewModel,
        isPinned: Binding<Bool> = .constant(false)
    ) {
        _viewModel = State(initialValue: viewModel)
        _isPinned = isPinned
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                viewModeCarousel

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
                .help(isPinned ? LocalizedString.speech("unpin_popover") : LocalizedString.speech("pin_popover"))
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
            case .english:
                EnglishLearningView()
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
    }

    // MARK: - 视图切换

    private var viewModeCarousel: some View {
        HStack(spacing: 4) {
            carouselStepButton(systemName: "chevron.left") {
                selectAdjacentViewMode(offset: -1)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            viewModeButton(mode)
                                .id(mode)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(height: 28)
                .onAppear {
                    proxy.scrollTo(viewMode, anchor: .center)
                }
                .onChange(of: viewMode) { _, newMode in
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo(newMode, anchor: .center)
                    }
                }
            }

            carouselStepButton(systemName: "chevron.right") {
                selectAdjacentViewMode(offset: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        }
        .help(viewMode.displayName)
    }

    private func viewModeButton(_ mode: ViewMode) -> some View {
        Button {
            selectViewMode(mode)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 10, weight: .semibold))

                Text(mode.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(height: 24)
            .padding(.horizontal, 7)
            .foregroundStyle(viewMode == mode ? AppTheme.healthy : AppTheme.textSecondary(colorScheme))
            .background {
                if viewMode == mode {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.healthy.opacity(0.15))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(mode.displayName)
    }

    private func carouselStepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .frame(width: 22, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.035))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(systemName == "chevron.left" ? "Previous" : "Next")
    }

    private func selectAdjacentViewMode(offset: Int) {
        let modes = Array(ViewMode.allCases)
        guard let currentIndex = modes.firstIndex(of: viewMode), !modes.isEmpty else { return }
        let nextIndex = (currentIndex + offset + modes.count) % modes.count
        selectViewMode(modes[nextIndex])
    }

    private func selectViewMode(_ mode: ViewMode) {
        guard viewMode != mode else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            viewMode = mode
        }
        Analytics.capture(.viewTabSwitched, properties: [
            "tab": mode.rawValue,
        ])
    }
}
