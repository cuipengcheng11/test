import SwiftUI

// ---------- App 入口 ----------
// 目标：iPhone 13 Pro / iOS 15+，Xcode 14.2（macOS 12，Swift 5.7）能打开，
// 不用 iOS 17+ 才有的 API（没有 NavigationStack，没有 @Observable，没有 TipKit）。

@main
struct CatPlayerApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var store = SourceStore()
    @StateObject private var history = HistoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(history)
                .preferredColorScheme(.dark)
        }
    }
}
