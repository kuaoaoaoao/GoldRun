import Observation
import SwiftUI

@MainActor
@Observable
final class GoldAnalysisViewModel {
    private(set) var displayRecords: [GoldPriceRecord] = []
    private(set) var statistics: PriceStatistics?
    private(set) var snapshot: TechnicalSnapshot?
    private(set) var signal: TradingSignal?
    private(set) var advancedReport: GoldAdvancedStrategyReport?
    private(set) var candles: [GoldCandlestick] = []
    private(set) var isLoading = false

    private var analysisTask: Task<Void, Never>?
    private var lastRecordsSignature = ""

    func refresh(records: [GoldPriceRecord], candlePeriod: CandlePeriod) {
        let signature = makeSignature(records: records, candlePeriod: candlePeriod)
        guard signature != lastRecordsSignature else { return }

        lastRecordsSignature = signature
        analysisTask?.cancel()

        if statistics == nil {
            isLoading = true
        }

        let recordsSnapshot = Array(records)
        analysisTask = Task(priority: .userInitiated) { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.makeResult(records: recordsSnapshot, candlePeriod: candlePeriod)
            }.value

            guard !Task.isCancelled else { return }
            self?.apply(result)
        }
    }

    func cancel() {
        analysisTask?.cancel()
        analysisTask = nil
        lastRecordsSignature = ""
        isLoading = false
    }

    private func apply(_ result: GoldAnalysisResult) {
        displayRecords = result.displayRecords
        statistics = result.statistics
        snapshot = result.snapshot
        signal = result.signal
        advancedReport = result.advancedReport
        candles = result.candles
        isLoading = false
    }

    private func makeSignature(records: [GoldPriceRecord], candlePeriod: CandlePeriod) -> String {
        guard let last = records.last else {
            return "empty-\(candlePeriod.rawValue)"
        }
        return "\(records.count)-\(last.timestamp.timeIntervalSince1970)-\(last.price)-\(candlePeriod.rawValue)"
    }

    private nonisolated static func makeResult(
        records: [GoldPriceRecord],
        candlePeriod: CandlePeriod
    ) -> GoldAnalysisResult {
        let displayRecords = makeDisplayRecords(records: records)
        let statistics = GoldAnalysisEngine.makeStatistics(records: displayRecords)
        let snapshot = GoldAnalysisEngine.makeSnapshot(records: displayRecords)
        let signal: TradingSignal?

        if let snapshot, let currentPrice = displayRecords.last?.price {
            signal = TradingSignalEngine.generateSignal(
                prices: displayRecords.map(\.price),
                currentPrice: currentPrice,
                snapshot: snapshot
            )
        } else {
            signal = nil
        }

        let advancedReport: GoldAdvancedStrategyReport?
        if let snapshot {
            advancedReport = GoldAdvancedStrategy.analyze(
                records: displayRecords,
                snapshot: snapshot,
                signal: signal
            )
        } else {
            advancedReport = nil
        }

        return GoldAnalysisResult(
            displayRecords: displayRecords,
            statistics: statistics,
            snapshot: snapshot,
            signal: signal,
            advancedReport: advancedReport,
            candles: buildCandlesticks(records: records, period: candlePeriod)
        )
    }

    private nonisolated static func makeDisplayRecords(records: [GoldPriceRecord]) -> [GoldPriceRecord] {
        let dayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        let recent = records.filter { $0.timestamp >= dayAgo }
        let source = recent.count >= 2 ? recent : records
        return Array(source.suffix(2_000))
    }

    private nonisolated static func buildCandlesticks(
        records: [GoldPriceRecord],
        period: CandlePeriod
    ) -> [GoldCandlestick] {
        let dayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        let sourceRecords = records
            .filter { $0.timestamp >= dayAgo }
            .suffix(5_000)
        guard !sourceRecords.isEmpty else { return [] }

        let calendar = Calendar(identifier: .gregorian)
        let interval = period.intervalSeconds
        var buckets: [TimeInterval: (first: GoldPriceRecord, last: GoldPriceRecord, high: Double, low: Double, count: Int)] = [:]

        for record in sourceRecords {
            let seconds = record.timestamp.timeIntervalSince1970
            let bucketStart = floor(seconds / interval) * interval

            if var bucket = buckets[bucketStart] {
                if record.timestamp < bucket.first.timestamp {
                    bucket.first = record
                }
                if record.timestamp > bucket.last.timestamp {
                    bucket.last = record
                }
                bucket.high = max(bucket.high, record.price)
                bucket.low = min(bucket.low, record.price)
                bucket.count += 1
                buckets[bucketStart] = bucket
            } else {
                buckets[bucketStart] = (
                    first: record,
                    last: record,
                    high: record.price,
                    low: record.price,
                    count: 1
                )
            }
        }

        return buckets.keys.sorted().compactMap { start in
            guard let bucket = buckets[start] else { return nil }
            let startDate = Date(timeIntervalSince1970: start)
            let endDate = calendar.date(byAdding: .second, value: Int(interval), to: startDate) ?? bucket.last.timestamp

            return GoldCandlestick(
                open: bucket.first.price,
                close: bucket.last.price,
                high: bucket.high,
                low: bucket.low,
                volume: bucket.count,
                startDate: startDate,
                endDate: endDate,
                period: period
            )
        }
    }
}

private struct GoldAnalysisResult: Sendable {
    let displayRecords: [GoldPriceRecord]
    let statistics: PriceStatistics?
    let snapshot: TechnicalSnapshot?
    let signal: TradingSignal?
    let advancedReport: GoldAdvancedStrategyReport?
    let candles: [GoldCandlestick]
}

struct GoldAnalysisView: View {
    @State private var store = GoldPriceStore.shared
    @State private var viewModel = GoldAnalysisViewModel()
    @State private var candlePeriod: CandlePeriod = .minute5
    @AppStorage("goldHoldingGramsText") private var holdingGramsText = ""
    @AppStorage("goldHoldingAverageCostText") private var holdingAverageCostText = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                if let statistics = viewModel.statistics {
                    let positionAdvice = makePositionAdvice(currentPrice: statistics.currentPrice)
                    header(statistics: statistics)
                    GoldPositionCard(
                        gramsText: $holdingGramsText,
                        averageCostText: $holdingAverageCostText,
                        advice: positionAdvice,
                        hasInput: hasPositionInput
                    )
                    PriceLineChart(records: viewModel.displayRecords)
                        .frame(height: 82)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(panelBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    periodPicker
                    candleStrip

                    if let snapshot = viewModel.snapshot {
                        indicatorGrid(snapshot: snapshot)
                    }

                    if let signal = viewModel.signal {
                        SignalCardView(signal: signal)
                    }

                    if viewModel.isLoading {
                        loadingCard
                    } else if let advancedReport = viewModel.advancedReport {
                        BeginnerGuidanceCard(report: advancedReport)
                        AdvancedStrategyCard(report: advancedReport)
                        BeginnerGlossaryCard()
                    }

                    dataFooter(statistics: statistics)
                } else if viewModel.isLoading {
                    loadingCard
                } else {
                    emptyState
                }
            }
            .padding(.vertical, 6)
        }
        .task {
            viewModel.refresh(records: store.records, candlePeriod: candlePeriod)
        }
        .onChange(of: store.records) { _, records in
            viewModel.refresh(records: records, candlePeriod: candlePeriod)
        }
        .onChange(of: candlePeriod) { _, period in
            viewModel.refresh(records: store.records, candlePeriod: period)
        }
        .onChange(of: holdingGramsText) { _, _ in capturePositionIfValid() }
        .onChange(of: holdingAverageCostText) { _, _ in capturePositionIfValid() }
        .onDisappear {
            viewModel.cancel()
        }
    }

    private func capturePositionIfValid() {
        guard let statistics = viewModel.statistics,
              let advice = makePositionAdvice(currentPrice: statistics.currentPrice) else { return }
        Analytics.capture(.goldPositionAnalyzed, properties: [
            "profit_state": profitState(for: advice.profitLoss),
            "profit_percent_bucket": profitPercentBucket(for: advice.profitPercent),
            "tone": advice.tone == .positive ? "positive" : advice.tone == .cautious ? "cautious" : "defensive",
        ], minimumInterval: 30)
    }

    private func profitState(for profitLoss: Double) -> String {
        if profitLoss > 0 { return "profit" }
        if profitLoss < 0 { return "loss" }
        return "break_even"
    }

    private func profitPercentBucket(for profitPercent: Double) -> String {
        let percent = abs(profitPercent)
        switch percent {
        case 0..<1:
            return "0_1"
        case 1..<3:
            return "1_3"
        case 3..<5:
            return "3_5"
        case 5..<10:
            return "5_10"
        default:
            return "10_plus"
        }
    }

    private func header(statistics: PriceStatistics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("浙商积存金")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    Text("¥\(statistics.currentPrice.goldPriceNumber)/g")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.textPrimary(colorScheme))
                }

                Spacer(minLength: 8)

                ChangeBadge(change: statistics.change, percent: statistics.changePercent)
            }

            HStack(spacing: 8) {
                GoldMetric(label: "高", value: statistics.periodHigh.goldPriceNumber)
                GoldMetric(label: "低", value: statistics.periodLow.goldPriceNumber)
                GoldMetric(label: "均", value: statistics.periodAverage.goldPriceNumber)
            }
        }
        .padding(10)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(CandlePeriod.allCases, id: \.self) { period in
                Button {
                    candlePeriod = period
                } label: {
                    Text(period.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .foregroundStyle(candlePeriod == period ? amber : AppTheme.textSecondary(colorScheme))
                        .background {
                            if candlePeriod == period {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(amber.opacity(colorScheme == .dark ? 0.18 : 0.14))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.035))
        }
    }

    private var candleStrip: some View {
        HStack(spacing: 3) {
            let visibleCandles = viewModel.candles.suffix(28)
            let maximumChange = max(visibleCandles.map { abs($0.changePercent) }.max() ?? 0.01, 0.01)
            if visibleCandles.isEmpty {
                Text("等待生成 K 线")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 42)
            } else {
                ForEach(Array(visibleCandles)) { candle in
                    Capsule()
                        .fill(candle.isUp ? AppTheme.healthy : AppTheme.critical)
                        .frame(width: 4, height: candleHeight(candle, maximumChange: maximumChange))
                        .frame(maxHeight: 42, alignment: candle.isUp ? .bottom : .top)
                        .opacity(0.85)
                        .help("\(candle.period.rawValue) \(candle.changePercent.signedPercentText)")
                }
            }
        }
        .frame(height: 46)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var loadingCard: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("正在生成金价分析")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary(colorScheme))
                Text("先切换进来，策略和图表稍后自动出现。")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func indicatorGrid(snapshot: TechnicalSnapshot) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                IndicatorPill(title: "RSI", value: snapshot.rsi14?.shortNumber ?? "--", detail: snapshot.rsiState.rawValue)
                IndicatorPill(title: "MACD", value: snapshot.macdHistogram?.signedShortNumber ?? "--", detail: snapshot.macdState.rawValue)
            }
            HStack(spacing: 6) {
                IndicatorPill(title: "SMA20", value: snapshot.sma20?.goldPriceNumber ?? "--", detail: "均线")
                IndicatorPill(title: "波动", value: snapshot.volatility?.percentNumber ?? "--", detail: "年化")
            }
        }
    }

    private func dataFooter(statistics: PriceStatistics) -> some View {
        HStack {
            Label("\(statistics.recordCount) 条", systemImage: "tray.full")
            Spacer()
            if let lastUpdateDate = statistics.lastUpdateDate {
                Text(lastUpdateDate, style: .time)
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(AppTheme.textSecondary(colorScheme))
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(amber)
            Text("等待下一次金价刷新")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
            Text("获取到价格后会自动开始记录历史和生成分析。")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .padding(12)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var panelBackground: some ShapeStyle {
        colorScheme == .dark ? Color.black.opacity(0.30) : Color.white.opacity(0.55)
    }

    private var amber: Color {
        Color(red: 0.88, green: 0.57, blue: 0.16)
    }

    private func candleHeight(_ candle: GoldCandlestick, maximumChange: Double) -> CGFloat {
        8 + CGFloat(min(abs(candle.changePercent) / maximumChange, 1)) * 32
    }

    private var hasPositionInput: Bool {
        !holdingGramsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !holdingAverageCostText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func makePositionAdvice(currentPrice: Double) -> GoldHoldingAdvice? {
        guard let grams = parseInputNumber(holdingGramsText),
              let averageCost = parseInputNumber(holdingAverageCostText) else {
            return nil
        }

        return GoldPositionAdvisor.analyze(
            currentPrice: currentPrice,
            grams: grams,
            averageCost: averageCost,
            report: viewModel.advancedReport,
            signal: viewModel.signal
        )
    }

    private func parseInputNumber(_ text: String) -> Double? {
        var normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "．", with: ".")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: "元", with: "")
            .replacingOccurrences(of: "克", with: "")
            .replacingOccurrences(of: "g", with: "")
            .replacingOccurrences(of: "G", with: "")
            .replacingOccurrences(of: " ", with: "")

        if normalized.contains(","), normalized.contains(".") {
            normalized.removeAll { $0 == "," }
        } else if normalized.contains(",") {
            let parts = normalized.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count == 2, (1...2).contains(parts[1].count) {
                normalized = parts.joined(separator: ".")
            } else {
                normalized.removeAll { $0 == "," }
            }
        }

        return Double(normalized)
    }
}

private struct PriceLineChart: View {
    let records: [GoldPriceRecord]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            guard records.count >= 2 else { return }

            let prices = records.map(\.price)
            guard let minPrice = prices.min(), let maxPrice = prices.max() else { return }
            let range = max(maxPrice - minPrice, 0.01)

            var path = Path()
            for (index, price) in prices.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(max(prices.count - 1, 1))
                let y = size.height - (CGFloat((price - minPrice) / range) * size.height)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            let lineColor = (prices.last ?? 0) >= (prices.first ?? 0)
                ? NSColor.systemGreen
                : NSColor.systemRed
            context.stroke(path, with: .color(Color(nsColor: lineColor)), lineWidth: 2)

            var fillPath = path
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(Color(nsColor: lineColor).opacity(colorScheme == .dark ? 0.18 : 0.12)))
        }
    }
}

private struct GoldPositionCard: View {
    @Binding var gramsText: String
    @Binding var averageCostText: String
    let advice: GoldHoldingAdvice?
    let hasInput: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        guard let advice else {
            return Color(red: 0.88, green: 0.57, blue: 0.16)
        }

        switch advice.tone {
        case .positive:
            return AppTheme.healthy
        case .cautious:
            return Color(red: 0.88, green: 0.57, blue: 0.16)
        case .defensive:
            return AppTheme.critical
        }
    }

    private var statusText: String {
        guard let advice else {
            return hasInput ? "检查输入" : "未填写"
        }

        if advice.profitLoss > 0 { return "浮盈" }
        if advice.profitLoss < 0 { return "浮亏" }
        return "持平"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("我的黄金", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary(colorScheme))
                Spacer(minLength: 6)
                Text(statusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.14), in: Capsule())
            }

            HStack(spacing: 6) {
                PositionInputField(
                    title: "持有克数",
                    placeholder: "如 12.5",
                    suffix: "g",
                    text: $gramsText
                )
                PositionInputField(
                    title: "买入均价",
                    placeholder: "如 580",
                    suffix: "¥/g",
                    text: $averageCostText
                )
            }

            if let advice {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        PositionMetric(title: "成本", value: "¥\(advice.costBasis.moneyNumber)")
                        PositionMetric(title: "现值", value: "¥\(advice.marketValue.moneyNumber)")
                        PositionMetric(
                            title: advice.profitLoss >= 0 ? "赚了" : "亏了",
                            value: "\(advice.profitLoss.signedMoneyNumber)"
                        )
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(advice.actionTitle)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary(colorScheme))
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)

                            Text(advice.reason)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 4)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(advice.profitPercent.signedCompactPercentText)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(advice.referenceLine)
                                .font(.system(size: 8, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(tint)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(advice.actionItems, id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                Text(hasInput ? "请输入大于 0 的克数和买入均价，系统会按当前金价计算盈亏。" : "填入你现在持有多少克、平均多少钱买入，就能看到专属持仓建议。")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(tint.opacity(colorScheme == .dark ? 0.12 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 1)
        }
    }
}

private struct PositionInputField: View {
    let title: String
    let placeholder: String
    let suffix: String
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))

            HStack(spacing: 3) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Text(suffix)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(AppTheme.progressBg(colorScheme), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PositionMetric: View {
    let title: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(AppTheme.progressBg(colorScheme), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct SignalCardView: View {
    let signal: TradingSignal
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        switch signal.direction {
        case .buy: AppTheme.healthy
        case .sell: AppTheme.critical
        case .hold: Color(red: 0.88, green: 0.57, blue: 0.16)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(signal.direction.label, systemImage: signal.direction == .hold ? "pause.circle" : "arrow.up.arrow.down.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
                Text(signal.strength.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.14), in: Capsule())
            }

            ForEach(signal.reasons, id: \.self) { reason in
                Text(reason)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let entry = signal.suggestedEntry,
               let stopLoss = signal.suggestedStopLoss,
               let takeProfit = signal.suggestedTakeProfit {
                HStack(spacing: 6) {
                    GoldMetric(label: "入场", value: entry.goldPriceNumber)
                    GoldMetric(label: "止损", value: stopLoss.goldPriceNumber)
                    GoldMetric(label: "止盈", value: takeProfit.goldPriceNumber)
                }
            }
        }
        .padding(10)
        .background(colorScheme == .dark ? Color.black.opacity(0.30) : Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct BeginnerGuidanceCard: View {
    let report: GoldAdvancedStrategyReport
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        switch report.beginnerTone {
        case .positive: AppTheme.healthy
        case .cautious: Color(red: 0.88, green: 0.57, blue: 0.16)
        case .defensive: AppTheme.critical
        }
    }

    private var iconName: String {
        switch report.beginnerTone {
        case .positive: "checkmark.seal"
        case .cautious: "pause.circle"
        case .defensive: "hand.raised"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("新手结论", systemImage: iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Spacer(minLength: 6)
                Text("\(Int(report.confidence * 100))%把握")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            Text(report.beginnerAction)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text(report.beginnerReason)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                PlainLanguageChip(text: "建议仓位 \(report.risk.suggestedExposure.percentNumber)", tint: tint)
                PlainLanguageChip(text: report.regime.regime.rawValue, tint: tint)
            }
        }
        .padding(10)
        .background(tint.opacity(colorScheme == .dark ? 0.13 : 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct PlainLanguageChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

private struct AdvancedStrategyCard: View {
    let report: GoldAdvancedStrategyReport
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        switch report.compositeDirection {
        case .buy: AppTheme.healthy
        case .sell: AppTheme.critical
        case .hold: Color(red: 0.88, green: 0.57, blue: 0.16)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AdvancedStrategyHeader(
                title: report.regime.regime.rawValue,
                strategy: report.regime.regime.strategyLabel,
                tint: tint
            )

            Text(report.summary)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))

            HStack(spacing: 6) {
                StrategyMetric(
                    title: "趋势强度",
                    value: report.regime.adx.shortNumber,
                    detail: report.regime.volatilityRegime.rawValue,
                    help: "越高说明价格越像沿着一个方向走。"
                )
                StrategyMetric(
                    title: "趋势黏性",
                    value: report.regime.hurstExponent.threeDigitNumber,
                    detail: "Hurst",
                    help: "接近 0.5 表示方向不明显，高于 0.5 更容易延续趋势。"
                )
                StrategyMetric(
                    title: "建议仓位",
                    value: report.risk.suggestedExposure.percentNumber,
                    detail: report.risk.riskLevel,
                    help: "不是让你必须买，而是如果要参与，建议资金占比别超过这个量级。"
                )
            }

            if let meanReversion = report.meanReversion {
                StrategyRow(
                    title: "均值回归",
                    value: meanReversion.zScore.signedShortNumber,
                    detail: meanReversion.summary,
                    help: "可以理解成价格离最近平均价有多远。离得太远时，可能会往平均价靠。"
                )
            }

            if let forecast = report.forecast {
                StrategyRow(
                    title: "7步模拟",
                    value: forecast.probabilityAboveCurrent.percentNumber,
                    detail: "中位 \(forecast.p50.goldPriceNumber)，区间 \(forecast.p10.goldPriceNumber)-\(forecast.p90.goldPriceNumber)",
                    help: "用历史波动随机跑很多次，看看短期大概落在哪个价格区间。不是预测承诺。"
                )
            }

            if let grid = report.grid {
                StrategyRow(
                    title: grid.isSuitable ? "网格适配" : "网格谨慎",
                    value: "\(grid.gridCount)格",
                    detail: "\(grid.lowerPrice.goldPriceNumber)-\(grid.upperPrice.goldPriceNumber)，间距 \(grid.spacing.goldPriceNumber)",
                    help: "网格适合价格来回震荡时分批买卖；单边大涨大跌时容易失效。"
                )
            }

            if let warning = report.risk.warning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.warning)
            }
        }
        .padding(10)
        .background(colorScheme == .dark ? Color.black.opacity(0.30) : Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct AdvancedStrategyHeader: View {
    let title: String
    let strategy: String
    let tint: Color

    var body: some View {
        HStack {
            Label(title, systemImage: "waveform.path.ecg")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            Text(strategy)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background {
                    Capsule()
                        .fill(tint.opacity(0.14))
                }
        }
    }
}

private struct StrategyMetric: View {
    let title: String
    let value: String
    let detail: String
    let help: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme).opacity(0.75))
                    .help(help)
            }

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary(colorScheme))

            Text(detail)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary(colorScheme).opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .help(help)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(AppTheme.progressBg(colorScheme), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct StrategyRow: View {
    let title: String
    let value: String
    let detail: String
    let help: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary(colorScheme))
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary(colorScheme).opacity(0.8))
                        .help(help)
                }

                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .help(help)
    }
}

private struct BeginnerGlossaryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 7) {
                GlossaryLine(term: "RSI", explanation: "看价格是不是涨太快或跌太快。70 以上偏贵，30 以下偏便宜。")
                GlossaryLine(term: "MACD", explanation: "看短期和中期力量谁更强。为正偏强，为负偏弱。")
                GlossaryLine(term: "趋势强度", explanation: "数值越高，说明价格越像在沿一个方向走。")
                GlossaryLine(term: "均值回归", explanation: "价格离平均价太远时，可能会慢慢靠回去。")
                GlossaryLine(term: "网格", explanation: "适合震荡行情，分成很多小格，低一点买、高一点卖。")
                GlossaryLine(term: "建议仓位", explanation: "如果要参与，建议用多少比例资金；不是一定要买。")
                GlossaryLine(term: "买入均价", explanation: "你每克黄金平均花了多少钱。它是判断赚亏和回本价的基础。")
                GlossaryLine(term: "浮盈浮亏", explanation: "按当前金价临时算出来的赚亏；没卖出前还会变化。")
            }
            .padding(.top, 6)
        } label: {
            Label("看不懂这些词？", systemImage: "book")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
        }
        .padding(10)
        .background(colorScheme == .dark ? Color.black.opacity(0.25) : Color.white.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GlossaryLine: View {
    let term: String
    let explanation: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(term)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
            Text(explanation)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct IndicatorPill: View {
    let title: String
    let value: String
    let detail: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme).opacity(0.8))
            }
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? Color.black.opacity(0.30) : Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GoldMetric: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ChangeBadge: View {
    let change: Double
    let percent: Double

    private var tint: Color {
        change >= 0 ? AppTheme.healthy : AppTheme.critical
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(change.signedPriceText)
            Text(percent.signedPercentText)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private extension Double {
    var goldPriceNumber: String {
        formatted(.number.precision(.fractionLength(2)))
    }

    var shortNumber: String {
        formatted(.number.precision(.fractionLength(1)))
    }

    var threeDigitNumber: String {
        formatted(.number.precision(.fractionLength(3)))
    }

    var signedShortNumber: String {
        formatted(.number.sign(strategy: .always()).precision(.fractionLength(2)))
    }

    var signedPriceText: String {
        formatted(.number.sign(strategy: .always()).precision(.fractionLength(2)))
    }

    var signedPercentText: String {
        formatted(.number.sign(strategy: .always()).precision(.fractionLength(2))) + "%"
    }

    var percentNumber: String {
        formatted(.percent.precision(.fractionLength(1)))
    }

    var moneyNumber: String {
        formatted(.number.precision(.fractionLength(2)))
    }

    var signedMoneyNumber: String {
        "¥" + formatted(.number.sign(strategy: .always()).precision(.fractionLength(2)))
    }

    var signedCompactPercentText: String {
        formatted(.percent.sign(strategy: .always()).precision(.fractionLength(1)))
    }
}
