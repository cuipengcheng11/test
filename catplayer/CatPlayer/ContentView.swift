import SwiftUI

// ---------- Tab 结构 ----------
// 首页 / 搜索 / 历史 / 我的（源管理 + TMDB 设置）。
// 用 NavigationView（iOS 15 可用），不用 iOS 16 才有的 NavigationStack。

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
            SearchView()
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }
            HistoryView()
                .tabItem { Label("历史", systemImage: "clock.fill") }
            SourcesView()
                .tabItem { Label("我的", systemImage: "person.fill") }
        }
        .accentColor(Theme.accent)
        .preferredColorScheme(.dark)
    }
}
