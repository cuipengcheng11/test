import Foundation
import SwiftUI

// ---------- TMDB 设置 ----------
// Key 绝不写进代码：默认代理域名是用户自己的 https://cuilove.ccwu.cc，
// API Key 由用户在“我的 → TMDB 设置”里自己填，存在 UserDefaults 里。
// 没填 Key 时首页不崩、不空白，轮播区显示去设置的提示。

final class SettingsStore: ObservableObject {
    @Published var tmdbProxy: String {
        didSet { UserDefaults.standard.set(tmdbProxy, forKey: "tmdb.proxy") }
    }
    @Published var tmdbKey: String {
        didSet { UserDefaults.standard.set(tmdbKey, forKey: "tmdb.apiKey") }
    }

    static let defaultProxy = "https://cuilove.ccwu.cc"

    var hasTMDBKey: Bool { !tmdbKey.trimmingCharacters(in: .whitespaces).isEmpty }

    init() {
        let proxy = UserDefaults.standard.string(forKey: "tmdb.proxy") ?? Self.defaultProxy
        self.tmdbProxy = proxy.isEmpty ? Self.defaultProxy : proxy
        self.tmdbKey = UserDefaults.standard.string(forKey: "tmdb.apiKey") ?? ""
    }
}

// ---------- TMDB API v3 ----------
// 请求格式：{proxy}/3/trending/movie/week?api_key={key}&language=zh-CN
// 图片：https://image.tmdb.org/t/p/w500 海报，/t/p/w780 横图。
// TMDB 的图片域名是固定的，不走代理；只有 API 请求走用户的代理域名。

struct TMDBMovie: Identifiable, Decodable, Hashable {
    var id: Int
    var title: String
    var original_title: String?
    var overview: String
    var poster_path: String?
    var backdrop_path: String?
    var release_date: String?
    var vote_average: Double
    var vote_count: Int

    var posterURL: URL? {
        guard let p = poster_path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(p)")
    }
    var backdropURL: URL? {
        guard let p = backdrop_path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(p)")
    }
    var yearText: String {
        guard let d = release_date, d.count >= 4 else { return "" }
        return String(d.prefix(4))
    }
    var ratingText: String { String(format: "%.1f", vote_average) }
}

private struct TMDBListResponse: Decodable {
    var results: [TMDBMovie]
}

enum TMDBError: Error, LocalizedError {
    case noKey
    case badURL
    case badResponse

    var errorDescription: String? {
        switch self {
        case .noKey: return "还没填 TMDB Key"
        case .badURL: return "TMDB 地址不对"
        case .badResponse: return "TMDB 没返回数据"
        }
    }
}

struct TMDBService {
    let proxy: String
    let apiKey: String

    init(settings: SettingsStore) {
        self.proxy = settings.tmdbProxy.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        self.apiKey = settings.tmdbKey.trimmingCharacters(in: .whitespaces)
    }

    private func url(path: String, extra: [String: String] = [:]) throws -> URL {
        guard !apiKey.isEmpty else { throw TMDBError.noKey }
        var comps = URLComponents(string: proxy + "/3" + path)
        var items = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "zh-CN"),
        ]
        for (k, v) in extra { items.append(URLQueryItem(name: k, value: v)) }
        comps?.queryItems = items
        guard let url = comps?.url else { throw TMDBError.badURL }
        return url
    }

    private func fetchList(path: String, extra: [String: String] = [:]) async throws -> [TMDBMovie] {
        let url = try url(path: path, extra: extra)
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        // 请求在后台线程跑，JSON 解析也在后台，不占主线程
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TMDBError.badResponse
        }
        return try JSONDecoder().decode(TMDBListResponse.self, from: data).results
    }

    func trending() async throws -> [TMDBMovie] {
        try await fetchList(path: "/trending/movie/week")
    }

    func popular(page: Int = 1) async throws -> [TMDBMovie] {
        try await fetchList(path: "/movie/popular", extra: ["page": "\(page)"])
    }

    func topRated(page: Int = 1) async throws -> [TMDBMovie] {
        try await fetchList(path: "/movie/top_rated", extra: ["page": "\(page)"])
    }

    func searchMovies(query: String, page: Int = 1) async throws -> [TMDBMovie] {
        try await fetchList(path: "/search/movie", extra: ["query": query, "page": "\(page)"])
    }
}
