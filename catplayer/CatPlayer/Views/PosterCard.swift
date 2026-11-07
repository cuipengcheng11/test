import SwiftUI

// ---------- 带缓存的图片 ----------
// 下载 + 解码在后台（ImageCache.load 是 async 的），主线程只显示；
// 占位就是一块深色圆角矩形，不加模糊、不加阴影，滚动时不掉帧。

struct CachedImageView: View {
    var urlString: String
    var aspectRatio: CGFloat = 2.0 / 3.0

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Theme.card
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .task(id: urlString) {
            image = await ImageCache.shared.load(urlString: urlString)
        }
    }
}

/// 圆角海报卡片：海报 + 片名 + 备注，全 App 一个样式。
/// 圆角只用一次 clipShape，不叠 shadow / blur。
struct PosterCard: View {
    var vod: Vod
    var width: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedImageView(urlString: vod.vod_pic)
                .frame(width: width)
                .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            Text(vod.vod_name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.primaryText)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
            if !vod.vod_remarks.isEmpty {
                Text(vod.vod_remarks)
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
        }
        .frame(width: width)
    }
}

/// TMDB 海报卡片（TMDBMovie 和 Vod 字段不一样，单独一版，样式和上面统一）
struct TMDBPosterCard: View {
    var movie: TMDBMovie
    var width: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedImageView(urlString: movie.posterURL?.absoluteString ?? "")
                .frame(width: width)
                .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            Text(movie.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.primaryText)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
            Text("\(movie.yearText)  ★ \(movie.ratingText)")
                .font(Theme.captionFont)
                .foregroundColor(Theme.secondaryText)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
        }
        .frame(width: width)
    }
}
