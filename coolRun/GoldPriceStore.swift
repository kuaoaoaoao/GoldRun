import Foundation
import Observation

@MainActor
@Observable
final class GoldPriceStore {
    static let shared = GoldPriceStore()

    private(set) var records: [GoldPriceRecord] = []

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
        guard price > 0 else { return }

        if let last = records.last,
           abs(last.price - price) < 0.0001,
           timestamp.timeIntervalSince(last.timestamp) < 10 {
            return
        }

        records.append(GoldPriceRecord(price: price, timestamp: timestamp, source: source))

        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }

        scheduleSave()
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
