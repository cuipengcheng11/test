import SwiftUI

// ---------- 搜索页 ----------
// 上面是输入框；下面分两段：TMDB 搜电影（要填了 Key 才有），
// 猫源搜片（所有启用的源都搜）。结果都用 LazyVGrid 海报墙，样式和首页统一。

struct SearchView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: SourceStore
    @State private var keyword = ""
    @State private var tmdbResults: [TMDBMovie] = []
    @State private var catResults: [(source: any CatSource, vods: [Vod])] = []
    @State private var isSearching = false
    @State private var searched = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // 输入框
                    HStack(spacing: Theme.spacingTiny) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.secondaryText)
                        TextField("搜片名…", text: $keyword)
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.primaryText)
                            .submitLabel(.search)
                            .onSubmit { Task { await doSearch() } }
                        if !keyword.isEmpty {
                            Button(action: { keyword = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.secondaryText)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.card)
                    .cornerRadius(Theme.cornerSmall)
                    .padding(.horizontal, Theme.spacing)

                    if isSearching {
                        ProgressView().progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                    }

                    // TMDB 结果
                    if settings.hasTMDBKey && !tmdbResults.isEmpty {
                        sectionTitle("TMDB")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                  spacing: Theme.spacingSmall) {
                            ForEach(tmdbResults) { movie in
                                NavigationLink(destination: TMDBDetailView(movie: movie)) {
                                    TMDBPosterCard(movie: movie, width: 110)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.spacing)
                    }

                    // 猫源结果（元组不能用 key path 当 id，改用下标）
                    ForEach(Array(catResults.enumerated()), id: \.offset) { _, entry in
                        if !entry.vods.isEmpty {
                            sectionTitle(entry.source.name)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                      spacing: Theme.spacingSmall) {
                                ForEach(entry.vods) { vod in
                                    NavigationLink(destination: DetailView(source: entry.source, vod: vod)) {
                                        PosterCard(vod: vod, width: 110)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Theme.spacing)
                        }
                    }

                    if searched && tmdbResults.isEmpty && catResults.allSatisfy({ $0.vods.isEmpty }) && !isSearching {
                        Text("没搜到，换个关键词试试")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    }
                }
                .padding(.bottom, 20)
            }
            .darkPage()
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.sectionFont)
            .padding(.horizontal, Theme.spacing)
    }

    private func doSearch() async {
        let kw = keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        tmdbResults = []
        catResults = []

        // TMDB（有 Key 才搜）
        if settings.hasTMDBKey {
            do {
                tmdbResults = try await TMDBService(settings: settings).searchMovies(query: kw)
            } catch {
                tmdbResults = []
            }
        }
        // 猫源：逐个源搜
        var out: [(source: any CatSource, vods: [Vod])] = []
        for source in store.enabledSources {
            do {
                let vods = try await source.search(keyword: kw, page: 1)
                if !vods.isEmpty { out.append((source, vods)) }
            } catch {
                continue
            }
        }
        catResults = out
        searched = true
    }
}
