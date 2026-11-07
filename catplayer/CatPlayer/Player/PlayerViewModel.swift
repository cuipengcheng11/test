import Foundation
import AVFoundation
import SwiftUI

// ---------- 播放器内核抽象 ----------
// 第一版用 AVPlayer（系统自带，HLS / mp4 直播点播都能播，不用引第三方库）。
// 换 KSPlayer 只改三处（见文件底部注释），PlayerView 和 DetailView 都不用改。
//
//   换 KSPlayer 的三步：
//   1) Xcode 里加 KSPlayer 的 SPM 包（https://github.com/kingslay/KSPlayer），
//      import KSPlayer；
//   2) 把文件底部的 KSPlayerEngine 取消注释，按 KSPlayer 的 API 把
//      load/play/pause/setRate/seek 补全；
//   3) 把下面 init 里的 AVPlayerEngine() 改成 KSPlayerEngine()。
//   注意：KSPlayer 没有 AVPlayer 对象，PlayerView 里 VideoPlayer 那一行
//   要改成 KSPlayer 的 KSVideoPlayerView（底部注释里写了改法）。

protocol VideoPlayerEngine: AnyObject {
    /// AVPlayer 内核返回真正的 AVPlayer；KSPlayer 内核返回 nil，
    /// PlayerView 看到 nil 就改用 KSPlayer 的 View（见 PlayerView 注释）。
    var avPlayer: AVPlayer? { get }
    var isPlaying: Bool { get }
    func load(url: URL, headers: [String: String])
    func play()
    func pause()
    func setRate(_ rate: Float)
    func seek(to seconds: Double)
}

/// AVPlayer 内核：URL 里带 header 的做法是把 header 放到 AVURLAsset 的 options 里。
final class AVPlayerEngine: VideoPlayerEngine {
    let player = AVPlayer()
    var avPlayer: AVPlayer? { player }
    var isPlaying: Bool { player.rate > 0 }

    func load(url: URL, headers: [String: String]) {
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    func play() { player.play() }
    func pause() { player.pause() }

    func setRate(_ rate: Float) {
        // 倍速：rate 直接设，0.5 / 1 / 1.5 / 2 都行；暂停时先 play 再设 rate
        if rate == 0 { player.pause() } else { player.rate = rate }
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }
}

/*
// ---------- KSPlayer 内核（先注释掉，等接 KSPlayer 时再开） ----------
// import KSPlayer
//
// final class KSPlayerEngine: VideoPlayerEngine {
//     // KSPlayer 的播放器对象，PlayerView 里用 KSVideoPlayerView 渲染它，
//     // 不要再用 SwiftUI 的 VideoPlayer(player:)。
//     let ksPlayer = KSVideoPlayer()
//     var avPlayer: AVPlayer? { nil }
//     var isPlaying: Bool { ksPlayer.isPlaying }
//     func load(url: URL, headers: [String: String]) {
//         // KSPlayer 的 options 里有 headers 字段，按它的 API 把 headers 传进去；
//         // 直链 m3u8 / mp4 都直接给 url，不用嗅探。
//         ksPlayer.set(url: url, options: KSOptions(headers: headers))
//     }
//     func play() { ksPlayer.play() }
//     func pause() { ksPlayer.pause() }
//     func setRate(_ rate: Float) { ksPlayer.playbackRate = rate }
//     func seek(to seconds: Double) { ksPlayer.seek(to: seconds) }
// }
*/

// ---------- 播放页的 ViewModel ----------
// 播放不强制插帧、不改帧率：AVPlayer 按片源帧率走，
// 13 Pro 的 120Hz ProMotion 由系统自适应，60Hz 的机器也不会被强制拉到 120。
// 字幕开关：HLS 内嵌字幕走 AVPlayer 的字幕组选择；外挂字幕以后再加。

final class PlayerViewModel: ObservableObject {
    @Published var detail: VodDetail
    @Published var source: any CatSource
    @Published var lineIndex: Int = 0
    @Published var episodeIndex: Int = 0
    @Published var speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    @Published var speed: Float = 1.0 { didSet { engine.setRate(speed) } }
    @Published var subtitleOn: Bool = true
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // 换 KSPlayer 改这一行：AVPlayerEngine() -> KSPlayerEngine()
    let engine: any VideoPlayerEngine = AVPlayerEngine()
    var player: AVPlayer? { engine.avPlayer }

    private let history: HistoryStore

    var currentLine: PlayLine? {
        guard lineIndex < detail.lines.count else { return nil }
        return detail.lines[lineIndex]
    }
    var currentEpisode: PlayEpisode? {
        guard let line = currentLine, episodeIndex < line.episodes.count else { return nil }
        return line.episodes[episodeIndex]
    }

    init(detail: VodDetail, source: any CatSource, lineIndex: Int, episodeIndex: Int, history: HistoryStore) {
        self.detail = detail
        self.source = source
        self.lineIndex = lineIndex
        self.episodeIndex = episodeIndex
        self.history = history
    }

    @MainActor
    func loadCurrent() async {
        guard let ep = currentEpisode, let line = currentLine else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await source.resolvePlay(playID: ep.playID)
            guard result.parse == 0, let url = URL(string: result.url) else {
                throw SourceError.notPlayable
            }
            engine.load(url: url, headers: result.headers)
            engine.setRate(speed)
            applySubtitleSetting()
            history.record(vod: detail, sourceKey: source.key, sourceName: source.name,
                           lineName: line.name, episodeName: ep.name)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "播不了"
        }
        isLoading = false
    }

    @MainActor
    func playEpisode(line: Int, episode: Int) async {
        lineIndex = line
        episodeIndex = episode
        await loadCurrent()
    }

    @MainActor
    func playNext() async {
        guard let line = currentLine else { return }
        if episodeIndex + 1 < line.episodes.count {
            episodeIndex += 1
        } else if lineIndex + 1 < detail.lines.count {
            lineIndex += 1
            episodeIndex = 0
        } else { return }
        await loadCurrent()
    }

    func togglePlay() {
        if engine.isPlaying { engine.pause() } else { engine.play() }
    }

    /// 字幕开关：选 / 取消 AVPlayer 当前 item 的字幕组。
    /// 没有内嵌字幕的片子，这个开关点了也没效果，属于正常情况。
    func applySubtitleSetting() {
        guard let item = player?.currentItem else { return }
        guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
        if subtitleOn {
            item.selectMediaOptionAutomatically(in: group)
        } else {
            item.select(nil, in: group)
        }
    }
}
