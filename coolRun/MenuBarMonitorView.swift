import SwiftUI
import Observation

@MainActor
@Observable
final class PopoverPinState {
    var isPinned = false
}

struct MenuBarMonitorView: View {
    @State private var viewModel: SystemMonitorViewModel
    // 重启后回到上次使用的模块
    @State private var viewMode: ViewMode = ViewMode(rawValue: AppSettings.shared.lastViewModeRaw) ?? .monitor
    @Bindable private var pinState: PopoverPinState
    private let onPinChange: (Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme

    init(
        viewModel: SystemMonitorViewModel,
        pinState: PopoverPinState,
        onPinChange: @escaping (Bool) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        _pinState = Bindable(wrappedValue: pinState)
        self.onPinChange = onPinChange
    }

    var body: some View {
        VStack(spacing: 0) {
            ModuleNavigationRail(selection: $viewMode) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        pinState.isPinned.toggle()
                    }
                    onPinChange(pinState.isPinned)
                } label: {
                    Image(systemName: pinState.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(pinState.isPinned ? AppTheme.warning : AppTheme.textSecondary(colorScheme))
                        .frame(width: 28, height: 28)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(pinState.isPinned ? AppTheme.warning.opacity(0.14) : Color.clear)
                        }
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .help(pinState.isPinned ? LocalizedString.speech("unpin_popover") : LocalizedString.speech("pin_popover"))
            }
            .padding(.bottom, 8)

            Group {
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
                case .codex:
                    CodexMonitorView()
                }
            }
            .id(viewMode)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
        .frame(width: 320, height: 512, alignment: .top)
        .padding(8)
        .onChange(of: viewMode) { _, newValue in
            AppSettings.shared.lastViewModeRaw = newValue.rawValue
        }
        .background {
            ZStack {
                VisualEffectBlur(material: colorScheme == .dark ? .hudWindow : .menu, blendingMode: .behindWindow)
                AppTheme.canvas(colorScheme)
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(colorScheme == .dark ? 0.08 : 0.055),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            }
        }
    }
}
