import Foundation
import SwiftUI

// ---------- 源管理：JSON 配置文件 ----------
// 首次启动：读 Bundle 里的 Sources.json（内置 360zy + nnyy），
// 拷一份到 Documents/sources.json，之后一切增删改都改那份文件，
// 用户在“我的 → 源管理”里加的源，下次打开还在。
// 文件本身就是 JSON，懂 JSON 的用户也可以直接改文件再重启 App。

final class SourceStore: ObservableObject {
    @Published private(set) var configs: [SourceConfig] = []
    @Published private(set) var sources: [any CatSource] = []

    static let fileName = "sources.json"

    var enabledSources: [any CatSource] {
        sources.filter { s in configs.first(where: { $0.key == s.key })?.enabled ?? true }
    }

    init() { load() }

    func source(forKey key: String) -> (any CatSource)? {
        sources.first { $0.key == key }
    }

    // ---------- 读 ----------
    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.fileName)
    }

    private func load() {
        let docURL = documentsURL()
        // Documents 里没有，就从 Bundle 拷一份
        if !FileManager.default.fileExists(atPath: docURL.path),
           let bundleURL = Bundle.main.url(forResource: "Sources", withExtension: "json") {
            try? FileManager.default.copyItem(at: bundleURL, to: docURL)
        }
        // 先读 Documents，再读 Bundle，都读不到就用内置默认值（App 不会因此打不开）
        var data: Data?
        if let d = try? Data(contentsOf: docURL) { data = d }
        else if let bundleURL = Bundle.main.url(forResource: "Sources", withExtension: "json") {
            data = try? Data(contentsOf: bundleURL)
        }
        if let data = data, let list = try? JSONDecoder().decode([SourceConfig].self, from: data) {
            configs = list
        } else {
            configs = Self.builtIn()
        }
        rebuildSources()
    }

    static func builtIn() -> [SourceConfig] {
        [
            SourceConfig(key: "cms360", name: "360资源", kind: .cms,
                         api: "https://360zy.com/api.php/provide/vod/", enabled: true),
            SourceConfig(key: "nnyy", name: "努努影院", kind: .nnyy,
                         api: "https://nnyy.in", enabled: true),
        ]
    }

    // ---------- 写 ----------
    private func save() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        try? data.write(to: documentsURL(), options: .atomic)
        rebuildSources()
    }

    private func rebuildSources() {
        sources = configs.map { cfg -> any CatSource in
            switch cfg.kind {
            case .cms: return CmsSource(config: cfg)
            case .nnyy: return NnyySource(config: cfg)
            }
        }
    }

    func addSource(name: String, kind: SourceKind, api: String) {
        let key = "user\(Int(Date().timeIntervalSince1970))"
        configs.append(SourceConfig(key: key, name: name, kind: kind,
                                    api: api.trimmingCharacters(in: .whitespaces), enabled: true))
        save()
    }

    func deleteSource(at offsets: IndexSet) {
        configs.remove(atOffsets: offsets)
        save()
    }

    func deleteSource(key: String) {
        configs.removeAll { $0.key == key }
        save()
    }

    func setEnabled(key: String, enabled: Bool) {
        guard let i = configs.firstIndex(where: { $0.key == key }) else { return }
        configs[i].enabled = enabled
        save()
    }
}
