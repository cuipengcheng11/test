import Foundation
import SwiftUI

// ---------- 播放历史 ----------
// 存在 UserDefaults 里（JSON），最多 50 条，按时间倒序。
// 播一集就记一次：片名、海报、源、线路、集名、时间。

struct HistoryItem: Identifiable, Codable, Hashable {
    var id: String { vodID + "|" + episodeName }
    var vodID: String
    var vodName: String
    var vodPic: String
    var sourceKey: String
    var sourceName: String
    var lineName: String
    var episodeName: String
    var date: Date
}

final class HistoryStore: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []
    private let key = "catplayer.history"
    private let maxCount = 50

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = list
        }
    }

    func record(vod: VodDetail, sourceKey: String, sourceName: String,
                lineName: String, episodeName: String) {
        let item = HistoryItem(vodID: vod.vod_id, vodName: vod.vod_name, vodPic: vod.vod_pic,
                               sourceKey: sourceKey, sourceName: sourceName,
                               lineName: lineName, episodeName: episodeName, date: Date())
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        if items.count > maxCount { items = Array(items.prefix(maxCount)) }
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
