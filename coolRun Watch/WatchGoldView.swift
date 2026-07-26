import SwiftUI

/// 手表端黄金盯盘主界面：大字号显示实时金价 + 持仓盈亏，抬手即可查看。
struct WatchGoldView: View {
    @StateObject private var store = WatchGoldStore()
    @State private var showEditor = false
    @State private var draftGrams = ""
    @State private var draftCost = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                priceSection
                Divider()
                holdingSection
                actionButtons
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("金价")
        .task {
            await store.refresh()
        }
        .sheet(isPresented: $showEditor) {
            holdingEditor
        }
    }

    // MARK: - 金价

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("实时金价")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if store.quote?.isMarketClosed == true {
                    Text("休市")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.orange.opacity(0.25), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }

            if let quote = store.quote {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(currency(quote.cnyPerGram))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    // 当日涨跌幅（京东主源提供，回退源无）
                    if let rate = quote.changeRatePercent {
                        Text(String(format: "%+.2f%%", rate))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(rate >= 0 ? .green : .red)
                    }
                }
                if let yesterday = quote.yesterdayPrice {
                    Text("昨收 \(currency(yesterday)) · \(timeText(quote.updatedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("元/克 · \(timeText(quote.updatedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if store.isLoading {
                ProgressView()
            } else {
                Text(store.errorMessage ?? "—")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 持仓盈亏

    @ViewBuilder
    private var holdingSection: some View {
        if store.hasHolding {
            VStack(alignment: .leading, spacing: 6) {
                if let profit = store.profit {
                    let positive = profit >= 0
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(positive ? "浮盈" : "浮亏")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(signedCurrency(profit))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(positive ? .green : .red)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    if let percent = store.profitPercent {
                        Text(String(format: "%+.2f%%", percent))
                            .font(.caption)
                            .foregroundStyle(positive ? .green : .red)
                    }
                }
                if let value = store.marketValue {
                    metricRow("市值", currency(value))
                }
                if let grams = store.grams {
                    metricRow("持仓", String(format: "%.2f 克", grams))
                }
                if let cost = store.averageCost {
                    metricRow("成本", currency(cost))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("未设置持仓\n在 Mac 端填写后自动同步")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 6) {
            Button {
                Task { await store.refresh() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
                    .font(.footnote)
            }
            .disabled(store.isLoading)

            Button {
                draftGrams = store.gramsText
                draftCost = store.averageCostText
                showEditor = true
            } label: {
                Label("编辑持仓", systemImage: "square.and.pencil")
                    .font(.footnote)
            }
            .tint(.orange)
        }
        .padding(.top, 4)
    }

    // MARK: - 持仓编辑器

    private var holdingEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("编辑持仓")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 3) {
                    Text("持仓克数")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("如 10.5", text: $draftGrams)
                        .textContentType(.none)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("成本价（元/克）")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("如 820", text: $draftCost)
                        .textContentType(.none)
                }

                Button {
                    store.saveHoldings(gramsText: draftGrams, averageCostText: draftCost)
                    showEditor = false
                } label: {
                    Label("保存并同步", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
                .padding(.top, 2)

                Text("保存后会通过 iCloud 同步到 Mac。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - 格式化

    private func currency(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func signedCurrency(_ value: Double) -> String {
        String(format: "%+.2f", value)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    WatchGoldView()
}
