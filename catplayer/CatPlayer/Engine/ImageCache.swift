import UIKit

// ---------- 图片缓存 ----------
// AsyncImage 自带 URLSession 缓存，但列表来回滚动时还是会重复解码，
// 这里再加一层 NSCache（内存，系统缺内存时自动清），
// 图片下载 + 解码都在后台线程做，主线程只负责显示，120Hz 滚动才不掉帧。
// 注意：不要在图片上叠多层模糊、阴影、圆角，圆角只用一次 clipShape。

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 150 * 1024 * 1024 // 150MB
    }

    /// 后台下载 + 解码，返回后调用方在主线程赋值。
    func load(urlString: String) async -> UIImage? {
        if urlString.isEmpty { return nil }
        if let hit = cache.object(forKey: urlString as NSString) { return hit }
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: urlString as NSString)
            return image
        } catch {
            return nil
        }
    }
}
