import Combine
import Foundation

/// 手表端黄金盯盘的视图模型：
/// - 实时价：直接调用 `WatchGoldService` 拉取（无需与 Mac 同步）。
/// - 持仓：从 iCloud 键值存储读取 macOS 端写入的克数/成本价，本地计算盈亏。
@MainActor
final class WatchGoldStore: ObservableObject {
    @Published private(set) var quote: WatchGoldQuote?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var grams: Double?
    @Published private(set) var averageCost: Double?

    private let kvStore = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?

    /// 与 macOS / CloudSyncStore 保持一致的键名。
    private let gramsKey = "goldHoldingGramsText"
    private let averageCostKey = "goldHoldingAverageCostText"

    init() {
        loadHoldings()
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.loadHoldings()
            }
        }
        kvStore.synchronize()
    }

    // MARK: - 计算属性

    var hasHolding: Bool {
        grams != nil && averageCost != nil
    }

    /// 持仓市值（元）。
    var marketValue: Double? {
        guard let quote, let grams else { return nil }
        return quote.cnyPerGram * grams
    }

    /// 浮动盈亏（元）。
    var profit: Double? {
        guard let quote, let grams, let averageCost else { return nil }
        return (quote.cnyPerGram - averageCost) * grams
    }

    /// 盈亏百分比。
    var profitPercent: Double? {
        guard let quote, let averageCost, averageCost > 0 else { return nil }
        return (quote.cnyPerGram - averageCost) / averageCost * 100
    }

    // MARK: - 动作

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            quote = try await WatchGoldService.fetchCNYPerGram()
        } catch {
            errorMessage = "获取金价失败"
        }
    }

    /// 当前持仓文本（供编辑器预填）。
    var gramsText: String {
        guard let grams else { return "" }
        return String(format: "%g", grams)
    }

    var averageCostText: String {
        guard let averageCost else { return "" }
        return String(format: "%g", averageCost)
    }

    /// 手表端编辑持仓：写入 iCloud 键值存储（与 Mac 同键），会反向同步回 macOS。
    func saveHoldings(gramsText: String, averageCostText: String) {
        let trimmedGrams = gramsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCost = averageCostText.trimmingCharacters(in: .whitespacesAndNewlines)
        kvStore.set(trimmedGrams, forKey: gramsKey)
        kvStore.set(trimmedCost, forKey: averageCostKey)
        kvStore.synchronize()
        loadHoldings()
    }

    // MARK: - 私有

    private func loadHoldings() {
        grams = parseNumber(kvStore.string(forKey: gramsKey))
        averageCost = parseNumber(kvStore.string(forKey: averageCostKey))
    }

    private func parseNumber(_ text: String?) -> Double? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return Double(text)
    }
}
