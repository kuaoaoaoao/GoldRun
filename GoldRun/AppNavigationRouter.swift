import Combine
import Foundation

enum GoldRunQuickAction: String, Sendable {
    case addCountdown
    case recordGoldTrade
    case showSystemHistory
}

struct GoldRunNavigationRequest: Equatable, Sendable {
    let id: UUID
    let mode: ViewMode
    let quickAction: GoldRunQuickAction?

    init(mode: ViewMode, quickAction: GoldRunQuickAction? = nil) {
        id = UUID()
        self.mode = mode
        self.quickAction = quickAction
    }
}

extension Notification.Name {
    static let goldRunPresentNavigationRequest = Notification.Name("GoldRunPresentNavigationRequest")
    static let goldRunRefreshGold = Notification.Name("GoldRunRefreshGold")
}

@MainActor
final class AppNavigationRouter: ObservableObject {
    static let shared = AppNavigationRouter()

    @Published private(set) var request: GoldRunNavigationRequest?

    private init() {}

    func open(_ mode: ViewMode, quickAction: GoldRunQuickAction? = nil) {
        request = GoldRunNavigationRequest(mode: mode, quickAction: quickAction)
        NotificationCenter.default.post(name: .goldRunPresentNavigationRequest, object: nil)
    }

    func consumeQuickAction(_ id: UUID) {
        guard request?.id == id, request?.quickAction != nil else { return }
        request = GoldRunNavigationRequest(mode: request?.mode ?? .today)
    }
}
