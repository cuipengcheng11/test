import Foundation

// ---------- 猫源协议 ----------
// 两种源（CMS JSON、nnyy HTML）都实现同一个协议，
// 首页 / 搜索 / 详情 / 播放都不用知道背后是 JSON 还是 HTML。
// 以后加远程包（Node 服务）或 js.js 蜘蛛（JavaScriptCore），
// 只要再加一个遵守这个协议的类型，再在 SourceStore 里注册就行，UI 不用改。

enum SourceKind: String, Codable {
    case cms    // AppleCMS JSON：ac=videolist / ac=detail
    case nnyy   // HTML：nnyy.in，URLSession + 正则解析
}

struct SourceConfig: Identifiable, Codable, Hashable {
    var id: String { key }
    var key: String
    var name: String
    var kind: SourceKind
    /// CMS 是 API 地址（https://360zy.com/api.php/provide/vod/）；
    /// nnyy 是站首页（https://nnyy.in）。
    var api: String
    var enabled: Bool
}

protocol CatSource: AnyObject {
    var key: String { get }
    var name: String { get }
    var kind: SourceKind { get }

    /// 首页“最新”列表
    func homeVod() async throws -> [Vod]
    /// 分类列表（CMS 的分类 id 是 type_id；nnyy 是 dianying / dianshiju / zongyi / dongman）
    func category(id: String, page: Int) async throws -> [Vod]
    /// 详情，含线路 + 集数
    func detail(id: String) async throws -> VodDetail
    /// 搜索
    func search(keyword: String, page: Int) async throws -> [Vod]
    /// 把一集的播放 id 解析成可播地址。CMS 的播放 id 本身就是直链；
    /// nnyy 的是“影片号:ep_slug”，这里再请求 /_gp/ 取 m3u8。
    func resolvePlay(playID: String) async throws -> PlayResult
}

// ---------- 网络小工具：都在后台线程做，不占主线程 ----------

enum SourceError: Error, LocalizedError {
    case badURL
    case badResponse
    case emptyResult
    case notPlayable

    var errorDescription: String? {
        switch self {
        case .badURL: return "地址不对"
        case .badResponse: return "源站没返回数据"
        case .emptyResult: return "这个源没有结果"
        case .notPlayable: return "这集暂时播不了"
        }
    }
}

extension CatSource {
    /// GET 一个 URL，返回 Data。URLSession 的 async API 本身就在后台跑，
    /// 解析 JSON / HTML 也在调用方的 async 函数里做，不要 dispatch 到主线程。
    func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SourceError.badResponse
        }
        return data
    }

    func fetchJSON<T: Decodable>(from url: URL) async throws -> T {
        let data = try await fetchData(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func fetchHTML(from url: URL) async throws -> String {
        let data = try await fetchData(from: url)
        // 站点多半是 UTF-8，解不出来再试 GBK
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .init(rawValue: 0x80000632)) { return s }
        return String(decoding: data, as: UTF8.self)
    }

    /// 用正则在 HTML 里找所有匹配的第 1 组。正则在后台线程跑，不在主线程。
    func regexGroups(_ pattern: String, in text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return re.matches(in: text, range: range).map { m in
            (0..<m.numberOfRanges).map { i in
                let r = m.range(at: i)
                guard r.location != NSNotFound, let sr = Range(r, in: text) else { return "" }
                return String(text[sr])
            }
        }
    }
}
