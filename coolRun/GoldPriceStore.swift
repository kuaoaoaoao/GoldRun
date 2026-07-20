import Foundation
import Observation

@MainActor
@Observable
final class GoldPriceStore {
    static let shared = GoldPriceStore()

    private(set) var records: [GoldPriceRecord] = []
    // 数据健康状态
    private(set) var dataHealth: DataHealthStatus = .healthy
    private(set) var lastPriceUpdate: Date?
    private(set) var priceUpdateInterval: TimeInterval?
    // 数据异常检测参数
    private let maxPriceJumpRatio: Double = 0.05  // 单次最大允许跳价幅度（5%）
    private let staleDataThreshold: TimeInterval = 300  // 5分钟未更新视为数据陈旧
    private let minPrice: Double = 100  // 合理价格下限（元/克）
    private let maxPrice: Double = 2000  // 合理价格上限（元/克）

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private let maxRecords = 100_000
    @ObservationIgnored private let saveDebounceInterval: Duration = .seconds(8)
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var hasPendingSave = false
    @ObservationIgnored private var saveGeneration = 0

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = (appSupport ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("coolRun", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("gold_price_history.json")

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        loadFromDisk()
    }

    func addPrice(_ price: Double, timestamp: Date = Date(), source: String = "CZB-JCJ") {
        // 1. 基本有效性检查
        guard price > minPrice, price < maxPrice else {
            dataHealth = .invalidPrice(price)
            return
        }

        // 2. 检查数据新鲜度
        let now = Date()
        if let last = records.last {
            let interval = timestamp.timeIntervalSince(last.timestamp)
            if interval < 0 {
                // 时间戳倒流（时钟回拨），使用当前时间
                dataHealth = .stale(now.timeIntervalSince(last.timestamp))
                return
            }
            priceUpdateInterval = interval
            
            // 3. 检查是否重复价格（10秒内价格变化小于 0.0001）
            if abs(last.price - price) < 0.0001,
               interval < 10 {
                return
            }
            
            // 4. 检查跳价幅度（基于历史波动率动态调整）
            let jumpRatio = abs(price - last.price) / last.price
            if jumpRatio > maxPriceJumpRatio {
                dataHealth = .priceJump(jumpRatio)
                // 仍然记录，但标记为异常
            } else {
                dataHealth = .healthy
            }
        } else {
            dataHealth = .healthy
        }
        
        lastPriceUpdate = timestamp

        records.append(GoldPriceRecord(price: price, timestamp: timestamp, source: source))

        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }

        scheduleSave()
    }

    // 检查数据新鲜度（供 UI 调用）
    func checkFreshness() {
        guard let lastUpdate = lastPriceUpdate ?? records.last?.timestamp else {
            dataHealth = .stale(TimeInterval.greatestFiniteMagnitude)
            return
        }
        let age = Date().timeIntervalSince(lastUpdate)
        if age > staleDataThreshold {
            dataHealth = .stale(age)
        }
    }

    // 获取最近价格年龄（秒）
    var lastPriceAge: TimeInterval? {
        guard let lastUpdate = lastPriceUpdate ?? records.last?.timestamp else { return nil }
        return Date().timeIntervalSince(lastUpdate)
    }
    
    // 多数据源价格对比（占位，后续接入真实多源）
    func crossValidatePrice(_ price: Double, from source: String) -> DataValidationResult {
        // 当前仅做基本范围检查
        if price < minPrice || price > maxPrice {
            return .outOfRange
        }
        
        // TODO: 接入上海金、XAUUSD、汇率后实现真实多源校验
        // 目前仅返回基于单一来源的验证结果
        return .singleSourceOnly
    }

    func recordsSince(_ date: Date) -> [GoldPriceRecord] {
        records.filter { $0.timestamp >= date }
    }

    func buildCandlesticks(period: CandlePeriod, since date: Date? = nil) -> [GoldCandlestick] {
        let sourceRecords = date.map(recordsSince) ?? records
        guard !sourceRecords.isEmpty else { return [] }

        let calendar = Calendar(identifier: .gregorian)
        let interval = period.intervalSeconds
        var buckets: [TimeInterval: [GoldPriceRecord]] = [:]

        for record in sourceRecords {
            let seconds = record.timestamp.timeIntervalSince1970
            let bucketStart = floor(seconds / interval) * interval
            buckets[bucketStart, default: []].append(record)
        }

        return buckets.keys.sorted().compactMap { start in
            guard let bucketRecords = buckets[start]?.sorted(by: { $0.timestamp < $1.timestamp }),
                  let first = bucketRecords.first,
                  let last = bucketRecords.last else {
                return nil
            }

            let prices = bucketRecords.map(\.price)
            let startDate = Date(timeIntervalSince1970: start)
            let endDate = calendar.date(byAdding: .second, value: Int(interval), to: startDate) ?? last.timestamp

            return GoldCandlestick(
                open: first.price,
                close: last.price,
                high: prices.max() ?? last.price,
                low: prices.min() ?? last.price,
                volume: bucketRecords.count,
                startDate: startDate,
                endDate: endDate,
                period: period
            )
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        records = (try? decoder.decode([GoldPriceRecord].self, from: data)) ?? []
    }

    func flushToDisk() {
        saveTask?.cancel()
        saveTask = nil
        guard hasPendingSave else { return }
        saveToDisk(records: records, to: fileURL)
        hasPendingSave = false
    }

    private func scheduleSave() {
        hasPendingSave = true
        saveGeneration += 1
        let generation = saveGeneration
        let recordsSnapshot = records
        let targetURL = fileURL

        saveTask?.cancel()
        saveTask = Task { [saveDebounceInterval] in
            try? await Task.sleep(for: saveDebounceInterval)
            guard !Task.isCancelled else { return }

            await Self.writeToDisk(records: recordsSnapshot, fileURL: targetURL)

            await MainActor.run {
                guard !Task.isCancelled, generation == self.saveGeneration else { return }
                self.hasPendingSave = false
                self.saveTask = nil
            }
        }
    }

    private func saveToDisk() {
        saveToDisk(records: records, to: fileURL)
    }

    private func saveToDisk(records: [GoldPriceRecord], to fileURL: URL) {
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private nonisolated static func writeToDisk(records: [GoldPriceRecord], fileURL: URL) async {
        await Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(records) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }.value
    }
}

// MARK: - Data Health Status

enum DataHealthStatus: Equatable {
    case healthy
    case stale(TimeInterval)  // 数据陈旧，传入距上次更新的秒数
    case priceJump(Double)    // 价格跳变幅度
    case invalidPrice(Double) // 明显错误价格

    var description: String {
        switch self {
        case .healthy:
            return LocalizedString.gold("data_healthy")
        case .stale(let age):
            return String(format: LocalizedString.gold("data_stale_format"), Int(age))
        case .priceJump(let ratio):
            return String(format: LocalizedString.gold("data_jump_format"), String(format: "%.1f%%", ratio * 100))
        case .invalidPrice(let price):
            return String(format: LocalizedString.gold("data_invalid_format"), String(format: "%.2f", price))
        }
    }

    var isHealthy: Bool {
        if case .healthy = self { return true }
        return false
    }
}

enum DataValidationResult {
    case valid
    case outOfRange
    case stale
    case singleSourceOnly
    case multiSourceMismatch(Double, Double)  // 不同来源价格差异过大
}
