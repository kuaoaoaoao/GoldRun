import SwiftUI

/// 手表端“今日”界面：公历 + 农历 + 节日/节气，以及近期生日提醒（从 Mac 同步）。
struct WatchTodayView: View {
    @StateObject private var store = WatchTodayStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                dateSection
                Divider()
                birthdaySection
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("今日")
        .onAppear { store.reload() }
    }

    // MARK: - 日期

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.solarMonthText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(store.solarDayNumber)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text(store.weekdayText)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text("\(store.lunarText) · \(store.lunarYearText)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let badge = store.todayBadge {
                Text(badge)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.red.opacity(0.25), in: Capsule())
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 近期生日

    @ViewBuilder
    private var birthdaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("近期生日")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if store.upcoming.isEmpty {
                Text("在 Mac 端添加生日后自动同步")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.upcoming.prefix(5)) { item in
                    birthdayRow(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func birthdayRow(_ item: WatchTodayStore.UpcomingBirthday) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.lunarText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            countdownLabel(item.daysUntil)
        }
    }

    @ViewBuilder
    private func countdownLabel(_ days: Int) -> some View {
        if days == 0 {
            Text("今天")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.pink)
        } else {
            HStack(spacing: 2) {
                Text("\(days)")
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(days <= 7 ? .orange : .primary)
                Text("天")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack { WatchTodayView() }
}
