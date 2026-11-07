import SwiftUI

// ---------- 动漫分类页 ----------
// 优先用 nnyy 的 dongman 分类（/dongman/?page=N），没有 nnyy 就用第一个启用的源。
// 流畅：LazyVStack + 分页加载（滑到底自动加一页），图片走缓存、后台解码，
// 行里不加模糊和阴影，圆角只用一次，60Hz 和 120Hz 都由系统调度，不写死帧率。

struct AnimeView: View {
    @EnvironmentObject var store: SourceStore
    @State private var items: [Vod] = []
    @State private var page = 1
    @State private var isLoading = false
    @State private var hasMore = true

    private var source: (any CatSource)? {
        store.enabledSources.first { $0.key == "nnyy" } ?? store.enabledSources.first
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Theme.spacingSmall) {
                ForEach(items) { vod in
                    if let source = source {
                        NavigationLink(destination: DetailView(source: source, vod: vod)) {
                            AnimeRow(vod: vod)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // 滑到最后一条就加一页
                            if vod.id == items.last?.id { Task { await loadMore() } }
                        }
                    }
                }
                if isLoading {
                    ProgressView().progressViewStyle(.circular).padding()
                }
                if !hasMore && !items.isEmpty {
                    Text("到底了")
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.secondaryText)
                        .padding()
                }
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.top, Theme.spacingSmall)
        }
        .darkPage()
        .navigationTitle("动漫")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if items.isEmpty { Task { await loadMore() } }
        }
    }

    private func loadMore() async {
        guard let source = source, !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // nnyy 的分类 id 是 dongman；CMS 源没有这个分类时会返回空，hasMore 置 false
            let list = try await source.category(id: "dongman", page: page)
            if list.isEmpty {
                hasMore = false
            } else {
                items.append(contentsOf: list)
                page += 1
            }
        } catch {
            hasMore = false
        }
    }
}

/// 动漫行：小海报 + 标题 + 备注，一行一个样式，全 App 统一
private struct AnimeRow: View {
    var vod: Vod

    var body: some View {
        HStack(spacing: Theme.spacingSmall) {
            CachedImageView(urlString: vod.vod_pic)
                .frame(width: 72)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(vod.vod_name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(2)
                if !vod.vod_remarks.isEmpty {
                    Text(vod.vod_remarks)
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                }
                if !vod.vod_year.isEmpty {
                    Text(vod.vod_year)
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.secondaryText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.secondaryText)
        }
        .padding(Theme.spacingSmall)
        .background(Theme.card)
        .cornerRadius(Theme.corner)
    }
}
