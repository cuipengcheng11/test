import Foundation

// ---------- 通用数据模型 ----------
// 字段名沿用猫源（CatVod / js.js 蜘蛛）约定的 vod_* 命名，
// 这样 CMS / nnyy / 以后接 js.js 蜘蛛返回的数据都不用再转一层。

/// 列表里的一个影片
struct Vod: Identifiable, Codable, Hashable {
    var id: String { vod_id }
    var vod_id: String
    var vod_name: String
    var vod_pic: String
    var vod_remarks: String
    var vod_year: String
    var vod_area: String
    var vod_type: String

    init(vod_id: String, vod_name: String, vod_pic: String = "", vod_remarks: String = "",
         vod_year: String = "", vod_area: String = "", vod_type: String = "") {
        self.vod_id = vod_id
        self.vod_name = vod_name
        self.vod_pic = vod_pic
        self.vod_remarks = vod_remarks
        self.vod_year = vod_year
        self.vod_area = vod_area
        self.vod_type = vod_type
    }
}

/// 一集：集名 + 播放 id（CMS 是直链，nnyy 是 "影片号:ep_slug"，播放时再解析）
struct PlayEpisode: Identifiable, Hashable {
    var id: String { playID }
    var name: String
    var playID: String
}

/// 一条线路：vod_play_from 用 $$$ 分，vod_play_url 用 $$$ 分，两边顺序一一对应；
/// 同一条线路内的集用 # 分，每集是“集名$播放id”。
struct PlayLine: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var episodes: [PlayEpisode]
}

/// 详情
struct VodDetail: Identifiable, Hashable {
    var id: String { vod_id }
    var vod_id: String
    var vod_name: String
    var vod_pic: String
    var vod_year: String
    var vod_area: String
    var vod_actor: String
    var vod_director: String
    var vod_content: String
    var lines: [PlayLine]

    /// 把 vod_play_from / vod_play_url 解析成线路 + 集数。
    /// 注意：集名里可能有 $，所以只按第一个 $ 切；没有 $ 的按整段当集名。
    static func parseLines(from: String, url: String) -> [PlayLine] {
        let fromParts = from.components(separatedBy: "$$$")
        let urlParts = url.components(separatedBy: "$$$")
        var lines: [PlayLine] = []
        for i in 0..<urlParts.count {
            let raw = urlParts[i]
            if raw.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            var episodes: [PlayEpisode] = []
            for part in raw.components(separatedBy: "#") {
                if part.isEmpty { continue }
                if let idx = part.firstIndex(of: "$") {
                    let name = String(part[..<idx]).trimmingCharacters(in: .whitespaces)
                    let playID = String(part[part.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                    if !playID.isEmpty {
                        episodes.append(PlayEpisode(name: name.isEmpty ? "正片" : name, playID: playID))
                    }
                } else {
                    episodes.append(PlayEpisode(name: part, playID: part))
                }
            }
            if episodes.isEmpty { continue }
            let lineName = i < fromParts.count && !fromParts[i].isEmpty ? fromParts[i] : "线路\(i + 1)"
            lines.append(PlayLine(name: lineName, episodes: episodes))
        }
        return lines
    }
}

/// 播放解析结果：parse 0 = 直链可播；parse 1 = 需要嗅探，AVPlayer 播不了，
/// 本项目第一版只接受 parse 0，parse 1 一律当作解析失败，不假装成功。
struct PlayResult {
    var parse: Int
    var url: String
    var headers: [String: String]
}
