import Foundation

// ---------- AppleCMS JSON 源 ----------
// 接口（360zy 实测可用）：
//   最新：?ac=videolist&pg=1
//   分类：?ac=videolist&t={type_id}&pg={page}
//   搜索：?ac=videolist&wd={关键词}&pg={page}
//   详情：?ac=detail&ids={vod_id}
// 返回都是 {"code":1,"list":[...]}，播放地址在 vod_play_url 里，
// 多数站第一组是分享页、第二组才是 m3u8，所以详情里按 m3u8 集数降序排，
// 播放器默认播第一组就不会点到分享页上。

final class CmsSource: CatSource {
    let key: String
    let name: String
    let kind: SourceKind = .cms
    private let base: String

    init(config: SourceConfig) {
        self.key = config.key
        self.name = config.name
        self.base = config.api.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    private func url(query: [String: String]) throws -> URL {
        var comps = URLComponents(string: base)
        comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps?.url else { throw SourceError.badURL }
        return url
    }

    func homeVod() async throws -> [Vod] {
        let resp: CmsListResponse = try await fetchJSON(from: try url(query: ["ac": "videolist", "pg": "1"]))
        return resp.list.map { $0.toVod() }
    }

    func category(id: String, page: Int) async throws -> [Vod] {
        // CMS 的父分类 id（1/2/3/4）直接查经常是空的，首页只用“最新”，
        // 分类靠详情里的真实 type_id；这里原样透传，空了也不崩。
        let resp: CmsListResponse = try await fetchJSON(from: try url(query: ["ac": "videolist", "t": id, "pg": "\(page)"]))
        return resp.list.map { $0.toVod() }
    }

    func detail(id: String) async throws -> VodDetail {
        let resp: CmsListResponse = try await fetchJSON(from: try url(query: ["ac": "detail", "ids": id]))
        guard let v = resp.list.first else { throw SourceError.emptyResult }
        var lines = VodDetail.parseLines(from: v.vod_play_from ?? "", url: v.vod_play_url ?? "")
        // m3u8 最多的组排前面，其他组保留可切换
        lines.sort { a, b in
            let sa = a.episodes.filter { $0.playID.lowercased().contains(".m3u8") }.count
            let sb = b.episodes.filter { $0.playID.lowercased().contains(".m3u8") }.count
            return sa > sb
        }
        return VodDetail(
            vod_id: String(v.vod_id), vod_name: v.vod_name ?? "", vod_pic: v.vod_pic ?? "",
            vod_year: v.vod_year ?? "", vod_area: v.vod_area ?? "",
            vod_actor: v.vod_actor ?? "", vod_director: v.vod_director ?? "",
            vod_content: (v.vod_content ?? "").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression),
            lines: lines
        )
    }

    func search(keyword: String, page: Int) async throws -> [Vod] {
        let resp: CmsListResponse = try await fetchJSON(from: try url(query: ["ac": "videolist", "wd": keyword, "pg": "\(page)"]))
        return resp.list.map { $0.toVod() }
    }

    func resolvePlay(playID: String) async throws -> PlayResult {
        // CMS 的播放 id 本身就是直链（m3u8 / mp4），直接可播
        guard playID.hasPrefix("http") else { throw SourceError.notPlayable }
        return PlayResult(parse: 0, url: playID, headers: [:])
    }
}

// ---------- CMS 返回结构 ----------

private struct CmsListResponse: Decodable {
    var list: [CmsVod] = []
}

private struct CmsVod: Decodable {
    var vod_id: Int
    var vod_name: String?
    var vod_pic: String?
    var vod_remarks: String?
    var vod_year: String?
    var vod_area: String?
    var type_name: String?
    var vod_play_from: String?
    var vod_play_url: String?
    var vod_content: String?
    var vod_actor: String?
    var vod_director: String?

    func toVod() -> Vod {
        Vod(vod_id: String(vod_id), vod_name: vod_name ?? "", vod_pic: vod_pic ?? "",
            vod_remarks: vod_remarks ?? "", vod_year: vod_year ?? "",
            vod_area: vod_area ?? "", vod_type: type_name ?? "")
    }
}
