import SwiftUI

/// watchOS 独立 App 入口。
/// 采用分页 TabView，左右滑动切换：金价盯盘 / 今日（农历+生日）/ 英语打卡。
@main
struct GoldRunWatchApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { WatchGoldView() }
                NavigationStack { WatchTodayView() }
                NavigationStack { WatchEnglishView() }
            }
            .tabViewStyle(.verticalPage)
        }
    }
}
