import SwiftUI

// ---------- 历史页 ----------
// 按时间倒序，点一行进详情页，再点集数继续播。

struct HistoryView: View {
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var store: SourceStore

    var body: some View {
        NavigationView {
            Group {
                if history.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.secondaryText)
                        Text("还没有播放记录")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.secondaryText)
                    }
                } else {
                    List {
                        ForEach(history.items) { item in
                            if let source = store.source(forKey: item.sourceKey) {
                                NavigationLink(destination: DetailView(
                                    source: source,
                                    vod: Vod(vod_id: item.vodID, vod_name: item.vodName, vod_pic: item.vodPic)
                                )) {
                                    HStack(spacing: Theme.spacingSmall) {
                                        CachedImageView(urlString: item.vodPic)
                                            .frame(width: 56)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.vodName)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Theme.primaryText)
                                                .lineLimit(1)
                                            Text("\(item.sourceName) · \(item.lineName) · \(item.episodeName)")
                                                .font(Theme.captionFont)
                                                .foregroundColor(Theme.secondaryText)
                                                .lineLimit(1)
                                            Text(item.date, style: .relative)
                                                .font(Theme.captionFont)
                                                .foregroundColor(Theme.secondaryText)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Theme.background)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .darkPage()
            .navigationTitle("历史")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !history.items.isEmpty {
                    Button("清空") { history.clear() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
