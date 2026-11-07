import SwiftUI

// ---------- 我的 / 源管理 + TMDB 设置 ----------
// TMDB Key 存在 UserDefaults 里，代码里没有任何真实 Key；
// 代理默认是用户自己的 https://cuilove.ccwu.cc，也可以自己改。
// 源存在 Documents/sources.json 里，开关、删除、新增都在这里改。

struct SourcesView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: SourceStore
    @State private var newName = ""
    @State private var newKind: SourceKind = .cms
    @State private var newAPI = ""
    @State private var tmdbTestResult: String?
    @State private var isTestingTMDB = false

    var body: some View {
        NavigationView {
            List {
                // ---- TMDB 设置 ----
                Section(header: Text("TMDB 设置").foregroundColor(Theme.secondaryText)) {
                    HStack {
                        Text("代理域名")
                            .font(Theme.bodyFont)
                        Spacer()
                        TextField("https://cuilove.ccwu.cc", text: $settings.tmdbProxy)
                            .font(Theme.bodyFont)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    HStack {
                        Text("API Key")
                            .font(Theme.bodyFont)
                        Spacer()
                        SecureField("在这里填你自己的 Key", text: $settings.tmdbKey)
                            .font(Theme.bodyFont)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    HStack {
                        Button(isTestingTMDB ? "测试中…" : "测试 TMDB") {
                            Task { await testTMDB() }
                        }
                        .disabled(isTestingTMDB || !settings.hasTMDBKey)
                        Spacer()
                        if let result = tmdbTestResult {
                            Text(result)
                                .font(Theme.captionFont)
                                .foregroundColor(Theme.secondaryText)
                        } else if !settings.hasTMDBKey {
                            Text("先填 Key 再测试")
                                .font(Theme.captionFont)
                                .foregroundColor(Theme.secondaryText)
                        }
                    }
                    Text("Key 只存在这台手机上，不会上传。没填 Key 时首页轮播会显示提示，不会崩。")
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.secondaryText)
                }

                // ---- 源列表 ----
                Section(header: Text("猫源").foregroundColor(Theme.secondaryText)) {
                    ForEach(store.configs) { cfg in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cfg.name)
                                    .font(Theme.bodyFont)
                                Text(cfg.kind == .cms ? "AppleCMS" : "nnyy HTML")
                                    .font(Theme.captionFont)
                                    .foregroundColor(Theme.secondaryText)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { cfg.enabled },
                                set: { store.setEnabled(key: cfg.key, enabled: $0) }
                            ))
                            .labelsHidden()
                        }
                    }
                    .onDelete { offsets in store.deleteSource(at: offsets) }
                }

                // ---- 新增源 ----
                Section(header: Text("新增源").foregroundColor(Theme.secondaryText)) {
                    TextField("源名字，比如 量子资源", text: $newName)
                        .font(Theme.bodyFont)
                    Picker("类型", selection: $newKind) {
                        Text("AppleCMS").tag(SourceKind.cms)
                        Text("nnyy HTML").tag(SourceKind.nnyy)
                    }
                    .pickerStyle(.segmented)
                    TextField("API 地址 / 站首页", text: $newAPI)
                        .font(Theme.bodyFont)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("添加") {
                        guard !newName.isEmpty, !newAPI.isEmpty else { return }
                        store.addSource(name: newName, kind: newKind, api: newAPI)
                        newName = ""
                        newAPI = ""
                    }
                    .disabled(newName.isEmpty || newAPI.isEmpty)
                    Text("AppleCMS 填 API 地址，如 https://360zy.com/api.php/provide/vod/；nnyy 这类 HTML 源填站首页。")
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.secondaryText)
                }

                // ---- 关于 ----
                Section(header: Text("关于").foregroundColor(Theme.secondaryText)) {
                    Text("CatPlayer 1.0（最小可用版）\n目标：iPhone 13 Pro / iOS 15+，Xcode 14.2 可开。\n播放器第一版用 AVPlayer，换 KSPlayer 见 PlayerViewModel 注释。\n远程包（Node 服务）和 js.js 蜘蛛（JavaScriptCore）是下一步，见 README。")
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.secondaryText)
                }
            }
            .listStyle(.insetGrouped)
            .darkPage()
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }

    private func testTMDB() async {
        isTestingTMDB = true
        defer { isTestingTMDB = false }
        do {
            let list = try await TMDBService(settings: settings).trending()
            tmdbTestResult = "通了，共 \(list.count) 条"
        } catch {
            tmdbTestResult = (error as? LocalizedError)?.errorDescription ?? "不通"
        }
    }
}
