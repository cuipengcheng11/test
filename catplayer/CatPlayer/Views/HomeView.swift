import SwiftUI
import Combine

// ---------- 首页 ----------
// 上：TMDB 轮播（trending 前 5，3 秒一换，手动也能滑，小圆点）
// 中：TMDB 热门、TMDB 高分，横排海报
// 下：动漫入口 + 猫源最新（360zy 的 homeVod）
// 流畅：列表全是 LazyVStack / LazyHStack，图片走缓存、后台解码；
// 轮播只用一个 3 秒定时器，不用高频定时器；动画都走系统调度，不写死帧率。

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var trending: [TMDBMovie] = []
    @Published var popular: [TMDBMovie] = []
    @Published var topRated: [TMDBMovie] = []
    @Published var latest: [Vod] = []
    @Published var latestSourceName: String = ""
    @Published var isLoading = false
    @Published var tmdbMessage: String?

    // settings / store 不存在 ViewModel 里，由调用方在 load 时传入，
    // 这样 ViewModel 不用在 View 的 init 里拿环境对象（SwiftUI 的 init 拿不到）。
    func load(settings: SettingsStore, store: SourceStore) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        // TMDB：没填 Key 就跳过，UI 显示去设置的提示，不崩、不空白
        if settings.hasTMDBKey {
            let service = TMDBService(settings: settings)
            do {
                async let t = service.trending()
                async let p = service.popular()
                async let r = service.topRated()
                let (trending, popular, topRated) = try await (t, p, r)
                self.trending = Array(trending.prefix(5))
                self.popular = popular
                self.topRated = topRated
                self.tmdbMessage = nil
            } catch {
                self.tmdbMessage = (error as? LocalizedError)?.errorDescription ?? "TMDB 加载失败"
            }
        } else {
            trending = []
            popular = []
            topRated = []
            tmdbMessage = "还没填 TMDB Key"
        }

        // 猫源最新：取第一个启用的 CMS 源（默认 360zy）
        if let source = store.enabledSources.first(where: { $0.kind == .cms }) ?? store.enabledSources.first {
            latestSourceName = source.name
            do {
                latest = try await source.homeVod()
            } catch {
                latest = []
            }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: SourceStore
    @EnvironmentObject var history: HistoryStore
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedIndex = 0
    // 轮播定时器：3 秒一换，不用高频定时器，省电；页面消失自动停（onDisappear 取消）
    @State private var timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    carouselSection
                    tmdbRowSection(title: "热门电影", movies: viewModel.popular)
                    tmdbRowSection(title: "高分电影", movies: viewModel.topRated)
                    animeSection
                    latestSection
                }
                .padding(.bottom, 20)
            }
            .darkPage()
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // 回到首页时把 3 秒定时器接回来（离开时停掉，省电）
                timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
                Task { await viewModel.load(settings: settings, store: store) }
            }
            .onDisappear {
                timer.upstream.connect().cancel()
            }
            .onReceive(timer) { _ in
                guard !viewModel.trending.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    selectedIndex = (selectedIndex + 1) % viewModel.trending.count
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // ---------- 轮播 ----------
    private var carouselSection: some View {
        Group {
            if !settings.hasTMDBKey {
                // 没填 Key：显示提示卡片，不空白、不崩
                NavigationLink(destination: SourcesView()) {
                    HStack(spacing: Theme.spacingSmall) {
                        Image(systemName: "key.fill")
                            .foregroundColor(Theme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("去设置里填 TMDB Key")
                                .font(Theme.sectionFont)
                                .foregroundColor(Theme.primaryText)
                            Text("填了 Key 才能看到 TMDB 轮播和热门海报")
                                .font(Theme.captionFont)
                                .foregroundColor(Theme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(Theme.spacing)
                    .background(Theme.card)
                    .cornerRadius(Theme.corner)
                }
                .padding(.horizontal, Theme.spacing)
            } else if viewModel.trending.isEmpty {
                RoundedRectangle(cornerRadius: Theme.corner)
                    .fill(Theme.card)
                    .frame(height: 210)
                    .overlay(ProgressView().progressViewStyle(.circular))
                    .padding(.horizontal, Theme.spacing)
            } else {
                VStack(spacing: Theme.spacingTiny) {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(viewModel.trending.enumerated()), id: \.element.id) { i, movie in
                            NavigationLink(destination: TMDBDetailView(movie: movie)) {
                                CarouselCard(movie: movie)
                            }
                            .tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                    .padding(.horizontal, Theme.spacing)
                    // 小圆点
                    HStack(spacing: 6) {
                        ForEach(0..<viewModel.trending.count, id: \.self) { i in
                            Circle()
                                .fill(i == selectedIndex ? Theme.accent : Color.white.opacity(0.3))
                                .frame(width: i == selectedIndex ? 8 : 6, height: i == selectedIndex ? 8 : 6)
                        }
                    }
                }
            }
        }
    }

    // ---------- TMDB 横排 ----------
    private func tmdbRowSection(title: String, movies: [TMDBMovie]) -> some View {
        Group {
            if !movies.isEmpty {
                VStack(alignment: .leading, spacing: Theme.spacingSmall) {
                    Text(title)
                        .font(Theme.sectionFont)
                        .padding(.horizontal, Theme.spacing)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: Theme.spacingSmall) {
                            ForEach(movies) { movie in
                                NavigationLink(destination: TMDBDetailView(movie: movie)) {
                                    TMDBPosterCard(movie: movie)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.spacing)
                    }
                }
            }
        }
    }

    // ---------- 动漫入口 ----------
    private var animeSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            HStack {
                Text("动漫")
                    .font(Theme.sectionFont)
                Spacer()
                NavigationLink("全部 >", destination: AnimeView())
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.secondaryText)
            }
            .padding(.horizontal, Theme.spacing)
            NavigationLink(destination: AnimeView()) {
                HStack(spacing: Theme.spacingSmall) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("动漫分类")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.primaryText)
                        Text("努努影院动漫区，顺滑列表")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(Theme.secondaryText)
                }
                .padding(Theme.spacing)
                .background(Theme.card)
                .cornerRadius(Theme.corner)
            }
            .padding(.horizontal, Theme.spacing)
        }
    }

    // ---------- 猫源最新 ----------
    private var latestSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSmall) {
            HStack {
                Text("最新上架")
                    .font(Theme.sectionFont)
                if !viewModel.latestSourceName.isEmpty {
                    Text(viewModel.latestSourceName)
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.spacing)
            if viewModel.latest.isEmpty {
                Text("猫源暂时没拿到数据，检查网络或源是否启用")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.secondaryText)
                    .padding(.horizontal, Theme.spacing)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: Theme.spacingSmall) {
                    ForEach(viewModel.latest) { vod in
                        if let source = store.enabledSources.first(where: { $0.kind == .cms }) ?? store.enabledSources.first {
                            NavigationLink(destination: DetailView(source: source, vod: vod)) {
                                PosterCard(vod: vod, width: 110)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Theme.spacing)
            }
        }
    }
}

/// 轮播卡片：大横图 + 一层渐变遮罩 + 标题，不叠模糊/阴影
private struct CarouselCard: View {
    var movie: TMDBMovie

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedImageView(urlString: movie.backdropURL?.absoluteString ?? movie.posterURL?.absoluteString ?? "", aspectRatio: 16.0 / 9.0)
            // 一层渐变遮罩，标题才看得清
            LinearGradient(colors: [.clear, .black.opacity(0.8)],
                           startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(movie.yearText)  ★ \(movie.ratingText)  ·  \(movie.overview)")
                    .font(Theme.captionFont)
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
            }
            .padding(Theme.spacingSmall)
        }
    }
}
