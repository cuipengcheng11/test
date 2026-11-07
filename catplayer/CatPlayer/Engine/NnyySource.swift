import Foundation

// ---------- nnyy.in HTML 源 ----------
// 站点结构（2026-10-30 实测，后续站改版要按新结构改选择器）：
//   分类：/dianying/ /dianshiju/ /zongyi/ /dongman/，每页 24 条，分页 ?page=N
//   搜索：GET /so?q={关键词}
//   详情页：标题在 h1.product-title，集在 <li class="...play-btn..." ep_slug="ep1">集名</a>
//   播放：GET /_gp/{影片号}/{ep_slug} -> {"video_plays":[{"play_data":"<m3u8>","src_site":"..."}]}
// 全部用 URLSession + 正则解析，不引第三方 HTML 库。
// 注意：正则解析在 async 函数里跑（后台线程），不要放到主线程。

final class NnyySource: CatSource {
    let key: String
    let name: String
    let kind: SourceKind = .nnyy
    private let host: String

    init(config: SourceConfig) {
        self.key = config.key
        self.name = config.name
        self.host = config.api.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    }

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: host + path) else { throw SourceError.badURL }
        return url
    }

    func homeVod() async throws -> [Vod] {
        let html = try await fetchHTML(from: try url("/dianying/?page=1"))
        return parseList(html: html)
    }

    func category(id: String, page: Int) async throws -> [Vod] {
        let cat = ["dianying", "dianshiju", "zongyi", "dongman"].contains(id) ? id : "dianying"
        let html = try await fetchHTML(from: try url("/\(cat)/?page=\(page)"))
        return parseList(html: html)
    }

    func detail(id: String) async throws -> VodDetail {
        // id 是详情页相对地址，如 /voddetail/20300834.html，也可能是绝对地址
        let pageURL: URL
        if id.hasPrefix("http"), let u = URL(string: id) {
            pageURL = u
        } else {
            pageURL = try url(id.hasPrefix("/") ? id : "/" + id)
        }
        let html = try await fetchHTML(from: pageURL)

        var name = ""
        var year = ""
        if let m = regexGroups("<h1[^>]*class=\"[^\"]*product-title[^\"]*\"[^>]*>(.*?)</h1>", in: html).first {
            let raw = m.count > 1 ? m[1] : ""
            year = regexGroups("<span[^>]*>(.*?)</span>", in: raw).first?.dropFirst().first ?? ""
            name = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var pic = ""
        for m in regexGroups("<img[^>]*>", in: html) {
            guard let tag = m.first, tag.contains("detail-img") else { continue }
            if let src = regexGroups("src=\"([^\"]+)\"", in: tag).first?.dropFirst().first {
                pic = src.hasPrefix("http") ? src : host + src
                break
            }
        }
        // 影片号：/voddetail/20300834.html -> 20300834
        let num = regexGroups("(\\d+)\\.html", in: id).first?.dropFirst().first ?? ""
        // 集：<li ... play-btn ... ep_slug="ep1">第1集</a>
        var episodes: [PlayEpisode] = []
        for m in regexGroups("<li[^>]*play-btn[^>]*ep_slug=\"([^\"]+)\"[^>]*>.*?<a[^>]*>(.*?)</a>", in: html) {
            guard m.count >= 3 else { continue }
            let slug = m[1]
            let epName = m[2].replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            episodes.append(PlayEpisode(name: epName.isEmpty ? slug : epName, playID: "\(num):\(slug)"))
        }
        // 站内 ep1、ep2……是倒序排的，翻回正序
        if episodes.count > 1 {
            episodes.reverse()
        }
        let line = episodes.isEmpty ? [] : [PlayLine(name: "默认", episodes: episodes)]
        return VodDetail(vod_id: id, vod_name: name, vod_pic: pic, vod_year: year,
                         vod_area: "", vod_actor: "", vod_director: "",
                         vod_content: "", lines: line)
    }

    func search(keyword: String, page: Int) async throws -> [Vod] {
        let q = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let html = try await fetchHTML(from: try url("/so?q=\(q)&page=\(page)"))
        return parseList(html: html)
    }

    func resolvePlay(playID: String) async throws -> PlayResult {
        // playID 形如 "20300834:ep1"，去 /_gp/ 取第一条直链
        let parts = playID.split(separator: ":")
        guard parts.count == 2 else { throw SourceError.notPlayable }
        let plays: GpResponse = try await fetchJSON(from: try url("/_gp/\(parts[0])/\(parts[1])"))
        guard let first = plays.video_plays?.first, !first.play_data.isEmpty else {
            throw SourceError.notPlayable
        }
        return PlayResult(parse: 0, url: first.play_data, headers: [:])
    }

    // ---------- 列表解析：<li> 里找 thumbnail 链接 + img + 标题 ----------
    private func parseList(html: String) -> [Vod] {
        var out: [Vod] = []
        var seen = Set<String>()
        for m in regexGroups("<li[\\s\\S]*?</li>", in: html) {
            guard let li = m.first else { continue }
            let href = regexGroups("<a[^>]*thumbnail[^>]*href=\"([^\"]+)\"", in: li).first?.dropFirst().first
                ?? regexGroups("<a[^>]*href=\"([^\"]+)\"", in: li).first?.dropFirst().first ?? ""
            if href.isEmpty || seen.contains(href) { continue }
            seen.insert(href)
            let img = regexGroups("<img[^>]*>", in: li).first ?? ""
            let pic = regexGroups("(?:data-src|src)=\"([^\"]+)\"", in: img).first?.dropFirst().first ?? ""
            let alt = regexGroups("alt=\"([^\"]*)\"", in: img).first?.dropFirst().first ?? ""
            var title = alt
            if let h2 = regexGroups("<h2[\\s\\S]*?</h2>", in: li).first {
                if let a = regexGroups("<a[^>]*>([\\s\\S]*?)</a>", in: h2).first?.dropFirst().first {
                    title = a.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            if title.isEmpty { continue }
            let fullPic = pic.hasPrefix("http") ? pic : (pic.hasPrefix("/") ? host + pic : pic)
            out.append(Vod(vod_id: href, vod_name: title, vod_pic: fullPic))
        }
        return out
    }
}

private struct GpResponse: Decodable {
    struct Play: Decodable {
        var play_data: String
        var src_site: String?
    }
    var video_plays: [Play]?
}
