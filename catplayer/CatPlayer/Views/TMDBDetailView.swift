import SwiftUI

// ---------- TMDB 详情页 ----------
// 上面是 TMDB 的横图 + 海报 + 简介（TMDB 自己的数据），
// 下面是“在猫源里搜同名”：用片名去所有启用的猫源搜，搜到了点进去就是
// 猫源的详情页（DetailView），再点集数就能播。
// 这样 TMDB 只负责“发现片子”，播放还是走猫源，不混在一起。

struct TMDBDetailView: View {
    var movie: TMDBMovie
    @EnvironmentObject var store: SourceStore
    @State private var results: [(source: any CatSource, vods: [Vod])] = []
    @State private var isSearching = false
    @State private var searched = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                // 横图 + 一层渐变遮罩
                ZStack(alignment: .bottomLeading) {
                    CachedImageView(urlString: movie.backdropURL?.absoluteString ?? movie.posterURL?.absoluteString ?? "", aspectRatio: 16.0 / 9.0)
                    LinearGradient(colors: [.clear, Theme.background],
                                   startPoint: .center, endPoint: .bottom)
                }
                .frame(maxWidth: .infinity)

                // 海报 + 标题 + 评分
                HStack(alignment: .top, spacing: Theme.spacingSmall) {
                    CachedImageView(urlString: movie.posterURL?.absoluteString ?? "")
                        .frame(width: 110)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(movie.title)
                            .font(Theme.titleFont)
                            .foregroundColor(Theme.primaryText)
                        Text("\(movie.yearText)  ★ \(movie.ratingText)（\(movie.vote_count) 人评）")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.secondaryText)
                        if let orig = movie.original_title, orig != movie.title {
                            Text(orig)
                                .font(Theme.captionFont)
                                .foregroundColor(Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, Theme.spacing)

                // 简介
                if !movie.overview.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.spacingTiny) {
                        Text("简介")
                            .font(Theme.sectionFont)
                        Text(movie.overview)
                            .font(Theme.bodyFont)
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                    .padding(.horizontal, Theme.spacing)
                }

                // 在猫源里搜同名
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text("在猫源里找播放源")
                        .font(Theme.sectionFont)
                    Button(action: { Task { await searchInSources() } }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text(isSearching ? "正在搜…" : "搜《\(movie.title)》")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent)
                        .cornerRadius(Theme.cornerSmall)
                    }
                    .disabled(isSearching)
                    if isSearching {
                        ProgressView().progressViewStyle(.circular)
                    }
                    if searched && results.isEmpty && !isSearching {
                        Text("猫源里没搜到这部片，换个名字或换个源再试")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.secondaryText)
                    }
                    // 元组不能用 key path 当 id，改用下标
                    ForEach(Array(results.enumerated()), id: \.offset) { _, entry in
                        if !entry.vods.isEmpty {
                            Text(entry.source.name)
                                .font(.system(size: 15, weight: .semibold))
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                      spacing: Theme.spacingSmall) {
                                ForEach(entry.vods) { vod in
                                    NavigationLink(destination: DetailView(source: entry.source, vod: vod)) {
                                        PosterCard(vod: vod, width: 110)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.spacing)
            }
            .padding(.bottom, 20)
        }
        .darkPage()
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func searchInSources() async {
        isSearching = true
        defer { isSearching = false }
        var out: [(source: any CatSource, vods: [Vod])] = []
        // 逐个源搜，搜到就留；以后源多了可以改成 TaskGroup 并行
        for source in store.enabledSources {
            do {
                let vods = try await source.search(keyword: movie.title, page: 1)
                if !vods.isEmpty { out.append((source, Array(vods.prefix(6)))) }
            } catch {
                continue
            }
        }
        results = out
        searched = true
    }
}
