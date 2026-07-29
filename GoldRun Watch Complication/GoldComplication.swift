import SwiftUI
import WidgetKit

// MARK: - 表盘 Complication：抬手即见实时金价

/// 时间线条目：某一时刻的金价快照。
struct GoldEntry: TimelineEntry {
    let date: Date
    let cnyPerGram: Double?   // nil 表示暂无数据（占位/取价失败）
    let updatedAt: Date?
    var changeRatePercent: Double? = nil   // 当日涨跌幅（京东主源提供）
}

/// 时间线提供者：直接调用公开 API 拉取实时金价，供表盘小组件展示。
///
/// 说明：Complication 扩展是独立 target，无法直接复用手表 App 目录下的
/// `WatchGoldService`，故此处内置一份精简取价逻辑（与其保持一致）。
struct GoldProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoldEntry {
        GoldEntry(date: Date(), cnyPerGram: 888.00, updatedAt: Date(), changeRatePercent: 0.25)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoldEntry) -> Void) {
        Task {
            let quote = try? await ComplicationGoldService.fetchCNYPerGram()
            completion(GoldEntry(
                date: Date(),
                cnyPerGram: quote?.price,
                updatedAt: quote?.time,
                changeRatePercent: quote?.changeRatePercent
            ))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoldEntry>) -> Void) {
        Task {
            let quote = try? await ComplicationGoldService.fetchCNYPerGram()
            let now = Date()
            let entry = GoldEntry(
                date: now,
                cnyPerGram: quote?.price,
                updatedAt: quote?.time,
                changeRatePercent: quote?.changeRatePercent
            )
            // 约 30 分钟后请求系统刷新时间线。
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

// MARK: - 视图

/// 金价文本（无小数保留整数，节省表盘空间）。
private func priceText(_ value: Double?) -> String {
    guard let value else { return "--" }
    return String(format: "%.0f", value)
}

/// 涨跌幅文本（带符号，保留两位小数）。
private func changeText(_ value: Double?) -> String? {
    guard let value else { return nil }
    return String(format: "%+.2f%%", value)
}

struct GoldComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GoldEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryInline:
            inline
        case .accessoryRectangular:
            rectangular
        case .accessoryCorner:
            corner
        default:
            inline
        }
    }

    private var circular: some View {
        VStack(spacing: 0) {
            Image(systemName: "chineseyuanrenminbisign.circle")
                .font(.system(size: 12))
                .foregroundStyle(.yellow)
            Text(priceText(entry.cnyPerGram))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder
    private var inline: some View {
        if let change = changeText(entry.changeRatePercent) {
            Text("金 \(priceText(entry.cnyPerGram)) \(change)")
        } else {
            Text("金 \(priceText(entry.cnyPerGram)) 元/克")
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "chineseyuanrenminbisign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("实时金价")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                if let change = changeText(entry.changeRatePercent) {
                    Text(change)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle((entry.changeRatePercent ?? 0) >= 0 ? .green : .red)
                }
            }
            Text("\(priceText(entry.cnyPerGram)) 元/克")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .containerBackground(.clear, for: .widget)
    }

    private var corner: some View {
        Text(priceText(entry.cnyPerGram))
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .widgetLabel("金价 元/克")
            .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widget 声明

struct GoldComplication: Widget {
    let kind = "GoldComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoldProvider()) { entry in
            GoldComplicationView(entry: entry)
        }
        .configurationDisplayName("实时金价")
        .description("抬手即见浙商银行积存金实时价（元/克）。")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
            .accessoryCorner,
        ])
    }
}

@main
struct GoldRunWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        GoldComplication()
    }
}
