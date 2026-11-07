import SwiftUI

// ---------- 详情页 ----------
// 顶部：海报大图 + 一层毛玻璃背景（就一层 ultraThinMaterial，不叠多层模糊），
// 下面：简介、线路分组（$$$）、集数（#），点集数进播放页。
// 毛玻璃只用在详情页顶部这一处，其他地方不用，保持流畅。

struct DetailView: View {
    var source: any CatSource
    var vod: Vod
    @EnvironmentObject var history: HistoryStore
    @State private var detail: VodDetail?
    @State private var selectedLine = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPlayer = false
    @State private var playLine = 0
    @State private var playEpisode = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                // 海报大图 + 毛玻璃信息区
                ZStack(alignment: .bottomLeading) {
                    CachedImageView(urlString: vod.vod_pic, aspectRatio: 16.0 / 9.0)
                    // 一层渐变 + 一层毛玻璃，标题区才看得清；不叠第二层模糊
                    LinearGradient(colors: [.clear, .black.opacity(0.85)],
                                   startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(vod.vod_name)
                            .font(Theme.titleFont)
                            .foregroundColor(.white)
                        HStack(spacing: 8) {
                            if !vod.vod_year.isEmpty { Text(vod.vod_year) }
                            if !vod.vod_area.isEmpty { Text(vod.vod_area) }
                            if !vod.vod_remarks.isEmpty { Text(vod.vod_remarks) }
                            Text(source.name)
                        }
                        .font(Theme.captionFont)
                        .foregroundColor(Color.white.opacity(0.8))
                    }
                    .padding(Theme.spacing)
                }
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial) // 详情页唯一一处毛玻璃

                if isLoading {
                    ProgressView().progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                }
                if let err = errorMessage {
                    Text(err)
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, Theme.spacing)
                }

                if let detail = detail {
                    // 简介
                    if !detail.vod_content.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.spacingTiny) {
                            Text("简介")
                                .font(Theme.sectionFont)
                            Text(detail.vod_content)
                                .font(Theme.bodyFont)
                                .foregroundColor(Color.white.opacity(0.85))
                        }
                        .padding(.horizontal, Theme.spacing)
                    }
                    if !detail.vod_actor.isEmpty {
                        Text("主演：\(detail.vod_actor)")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.secondaryText)
                            .padding(.horizontal, Theme.spacing)
                    }
                    if !detail.vod_director.isEmpty {
                        Text("导演：\(detail.vod_director)")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.secondaryText)
                            .padding(.horizontal, Theme.spacing)
                    }

                    // 线路 + 集数
                    if detail.lines.isEmpty {
                        Text("这个源没有给播放线路")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.secondaryText)
                            .padding(.horizontal, Theme.spacing)
                    } else {
                        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                            // 选线路
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: Theme.spacingTiny) {
                                    ForEach(Array(detail.lines.enumerated()), id: \.element.id) { i, line in
                                        Button(line.name) { selectedLine = i }
                                            .font(Theme.captionFont)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(i == selectedLine ? Theme.accent : Theme.card)
                                            .foregroundColor(.white)
                                            .cornerRadius(Theme.cornerSmall)
                                    }
                                }
                                .padding(.horizontal, Theme.spacing)
                            }
                            // 选集
                            let episodes = detail.lines[selectedLine].episodes
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                                      spacing: 8) {
                                ForEach(Array(episodes.enumerated()), id: \.element.id) { i, ep in
                                    Button(ep.name) {
                                        playLine = selectedLine
                                        playEpisode = i
                                        showPlayer = true
                                    }
                                    .font(Theme.captionFont)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.card)
                                    .foregroundColor(.white)
                                    .cornerRadius(Theme.cornerSmall)
                                }
                            }
                            .padding(.horizontal, Theme.spacing)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .darkPage()
        .navigationTitle(vod.vod_name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await load() } }
        .fullScreenCover(isPresented: $showPlayer) {
            if let detail = detail {
                PlayerView(viewModel: PlayerViewModel(detail: detail, source: source,
                                                      lineIndex: playLine, episodeIndex: playEpisode,
                                                      history: history))
            }
        }
    }

    private func load() async {
        if detail != nil { return }
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await source.detail(id: vod.vod_id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "详情加载失败"
        }
    }
}
