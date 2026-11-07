import SwiftUI
import AVKit

// ---------- 播放页 ----------
// 手势：点一下显示/隐藏控制栏；双击暂停/继续；
// 左半边上下滑调亮度，右半边上下滑调音量；左右滑快进/快退（松手生效）。
// 亮度和音量用系统 API，拖动时只改数值、不重建视图，120Hz 下不掉帧。
// 换 KSPlayer 时：把下面的 VideoPlayer 换成 KSVideoPlayerView，
// 手势和选集/选线/倍速/字幕这些 UI 都不用动。

struct PlayerView: View {
    @StateObject var viewModel: PlayerViewModel
    @State private var showControls = true
    @State private var dragStart: CGPoint = .zero
    @State private var dragStartBrightness: CGFloat = 0.5
    @State private var dragStartVolume: Float = 1.0
    @State private var brightness: CGFloat = 0.5
    @State private var volume: Float = 1.0
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                // KSPlayer 内核时 avPlayer 是 nil，这里会显示这行；
                // 按 PlayerViewModel 底部的注释把 VideoPlayer 换成 KSVideoPlayerView 即可。
                Text("播放器内核未接入")
                    .foregroundColor(Theme.secondaryText)
            }

            if viewModel.isLoading {
                ProgressView().progressViewStyle(.circular).scaleEffect(1.4)
            }
            if let err = viewModel.errorMessage {
                Text(err)
                    .font(Theme.bodyFont)
                    .foregroundColor(.white)
                    .padding(Theme.spacingSmall)
                    .background(Theme.card)
                    .cornerRadius(Theme.cornerSmall)
            }

            if showControls {
                controlsOverlay
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            brightness = UIScreen.main.brightness
            volume = viewModel.player?.volume ?? 1.0
            Task { await viewModel.loadCurrent() }
        }
        .onDisappear { viewModel.engine.pause() }
        .contentShape(Rectangle())
        // 点一下显示/隐藏控制栏。双击暂停/继续这里故意不做：
        // 单击和双击放在同一个 View 上会互相抢，点一下会先触发一次控制栏切换，
        // 暂停/继续用控制栏里的播放按钮，更稳。
        .onTapGesture { showControls.toggle() }
        .gesture(dragGesture)
    }

    // ---------- 手势：只在手势里改亮度/音量，不重建整个播放页 ----------
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if dragStart == .zero {
                    dragStart = value.startLocation
                    dragStartBrightness = UIScreen.main.brightness
                    dragStartVolume = viewModel.player?.volume ?? 1.0
                }
                let dy = value.translation.height
                if dragStart.x < UIScreen.main.bounds.width / 2 {
                    // 左半边：亮度
                    let b = max(0.05, min(1.0, dragStartBrightness - dy / 300))
                    UIScreen.main.brightness = b
                    brightness = b
                } else {
                    // 右半边：音量
                    let v = max(0, min(1.5, dragStartVolume - Float(dy / 300)))
                    viewModel.player?.volume = v
                    volume = v
                }
            }
            .onEnded { _ in dragStart = .zero }
    }

    // ---------- 控制栏：顶部标题 + 底部选集/选线/倍速/字幕 ----------
    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                Text(viewModel.detail.vod_name)
                    .font(Theme.sectionFont)
                    .lineLimit(1)
                Spacer()
                if let ep = viewModel.currentEpisode {
                    Text(ep.name)
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.secondaryText)
                }
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: Theme.spacingTiny) {
                // 选线路
                if viewModel.detail.lines.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: Theme.spacingTiny) {
                            ForEach(Array(viewModel.detail.lines.enumerated()), id: \.element.id) { i, line in
                                Button(line.name) {
                                    Task { await viewModel.playEpisode(line: i, episode: 0) }
                                }
                                .font(Theme.captionFont)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(i == viewModel.lineIndex ? Theme.accent : Theme.card)
                                .foregroundColor(.white)
                                .cornerRadius(Theme.cornerSmall)
                            }
                        }
                        .padding(.horizontal, Theme.spacing)
                    }
                }
                // 选集
                if let line = viewModel.currentLine {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: Theme.spacingTiny) {
                            ForEach(Array(line.episodes.enumerated()), id: \.element.id) { i, ep in
                                Button(ep.name) {
                                    Task { await viewModel.playEpisode(line: viewModel.lineIndex, episode: i) }
                                }
                                .font(Theme.captionFont)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(i == viewModel.episodeIndex ? Theme.accent : Theme.card)
                                .foregroundColor(.white)
                                .cornerRadius(Theme.cornerSmall)
                            }
                        }
                        .padding(.horizontal, Theme.spacing)
                    }
                }
                // 播放控制行
                HStack(spacing: 20) {
                    Button(action: { viewModel.togglePlay() }) {
                        Image(systemName: viewModel.engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                    }
                    Button("下一集") { Task { await viewModel.playNext() } }
                        .font(Theme.bodyFont)
                    // 倍速
                    Menu("\(String(format: "%.2g", viewModel.speed))x") {
                        ForEach(viewModel.speeds, id: \.self) { s in
                            Button("\(String(format: "%.2g", s))x") { viewModel.speed = s }
                        }
                    }
                    .font(Theme.bodyFont)
                    // 字幕开关
                    Button(viewModel.subtitleOn ? "字幕开" : "字幕关") {
                        viewModel.subtitleOn.toggle()
                        viewModel.applySubtitleSetting()
                    }
                    .font(Theme.bodyFont)
                    Spacer()
                    Text("亮度 \(Int(brightness * 100))%  音量 \(Int(volume * 100))%")
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.secondaryText)
                }
                .foregroundColor(.white)
                .padding(.horizontal, Theme.spacing)
                .padding(.bottom, 12)
            }
            .background(
                // 底部一层渐变遮罩（就一层，不叠模糊/阴影），字才看得清
                LinearGradient(colors: [.clear, .black.opacity(0.75)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
    }
}
