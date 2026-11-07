# CatPlayer —— iOS 猫源播放器（最小可用版）

像 MiraPlay 那样的猫源播放器，全新写的 iOS App。目标：**iPhone 13 Pro / iOS 15+，Xcode 14.2（macOS 12，Swift 5.7）能打开**，不用 iOS 17+ 才有的 API。

> 这是最小可用版：能跑通“首页最新 → 详情 → 播放”这一条链。不是完整的大而全 App，UI 也没有做过度美化，先保证能编译、能跑、链路通。

## 能做什么

- **首页**：TMDB 轮播（trending 前 5，3 秒一换，手动滑 + 小圆点）+ TMDB 热门 / 高分横排海报 + 动漫入口 + 猫源最新（360zy）
- **TMDB**：API v3（trending/movie/week、movie/popular、movie/top_rated、search/movie），图片 `image.tmdb.org/t/p/w500` 海报、`/w780` 横图；点轮播/海报进 TMDB 详情，再用片名去猫源搜播放源
- **搜索**：TMDB 搜电影 + 所有启用的猫源搜片
- **详情**：海报大图、简介、线路分组（`$$$`）、集数（`#`，每集“集名$播放id”）
- **播放**：AVPlayer（HLS / mp4 直播点播都能播），选集、选线路、倍速、字幕开关、手势调亮度和音量、断点续播、下一集
- **历史**：播过就记，点一行回到详情继续播
- **我的 / 源管理**：TMDB 设置（代理 + Key）+ 猫源增删改、启用开关

## 猫源引擎（现在支持两种）

| 源 | 类型 | 做法 |
|---|---|---|
| 360zy（内置示例） | AppleCMS JSON | `ac=videolist` / `ac=detail`，直链 m3u8 优先（详情里按 m3u8 集数降序排） |
| 努努影院 nnyy.in（内置示例） | HTML | URLSession + 正则解析，不引第三方 HTML 库；播放 id 是“影片号:ep_slug”，播放时请求 `/_gp/{号}/{slug}` 取 m3u8 |

源用 JSON 配置文件管理：Bundle 里的 `CatPlayer/Sources.json` 是内置默认值（360zy + nnyy），首次启动拷到 `Documents/sources.json`，之后增删改都改那份文件。

## TMDB 设置（重要）

- **API Key 绝不写进代码**。默认代理域名是用户自己的 `https://cuilove.ccwu.cc`，Key 在 App 里“我的 → TMDB 设置”自己填，存在这台手机的 UserDefaults 里。
- 请求格式：`{代理}/3/trending/movie/week?api_key={Key}&language=zh-CN`
- 没填 Key 时首页轮播显示“去设置里填 TMDB Key”的提示卡片，**不崩、不空白**。

## 在 Xcode 14.2 打开

1. Mac 要 macOS 12，Xcode 14.2（最高就到这个版本，正好符合）
2. 双击 `CatPlayer.xcodeproj`
3. 左上角选真机（iPhone 13 Pro）或模拟器，`Product → Run`（⌘R）
4. 首次打开如果报签名问题：选项目 → Signing & Capabilities → Team 选你自己的 Apple ID（免费个人账号就行），Bundle Identifier 改成你自己的（比如 `com.你的名字.CatPlayer`）

## 真机安装

- 免费个人账号：Xcode 选真机直接 Run 就能装，证书 7 天过期，过期重装一次
- 有付费开发者账号：同上，证书 1 年
- 不用越狱，不用第三方签名工具；App 里没有私有 API，用的都是 AVFoundation / AVKit / SwiftUI 公开接口

## 流畅与刷新率（13 Pro 120Hz）

- **不写死帧率**：动画和滚动都走系统默认刷新率，13 Pro 上 ProMotion 自适应到 120Hz，60Hz 的机器也不会被强制拉到 120Hz；`Info.plist` 里**没有锁刷新率的键**
- 轮播定时器 **3 秒一换**，不用高频定时器耗电；页面消失时定时器停掉
- 图片：`AsyncImage` 思路 + `NSCache` 缓存，下载和解码都在后台线程，主线程只显示；列表全是 `LazyVStack` / `LazyHStack`
- JSON / HTML 解析都在 async 函数里（后台线程），不在主线程
- 漂亮但克制：深色主题、圆角海报、一层渐变遮罩，详情页顶部只用一层毛玻璃（`ultraThinMaterial`），**不叠多层模糊、不叠阴影**，不然 120Hz 也会掉帧
- 视频播放按片源帧率走，**不强制插帧到 120**

## 换 KSPlayer（播放器内核替换）

第一版用 AVPlayer，换 KSPlayer 只改三处，UI 不用动：

1. Xcode 里加 KSPlayer 的 SPM 包（https://github.com/kingslay/KSPlayer），`import KSPlayer`
2. 把 `Player/PlayerViewModel.swift` 底部的 `KSPlayerEngine` 取消注释，按 KSPlayer 的 API 把 `load/play/pause/setRate/seek` 补全
3. 把 `PlayerViewModel` 里 `AVPlayerEngine()` 改成 `KSPlayerEngine()`，`Player/PlayerView.swift` 里把 `VideoPlayer` 换成 KSPlayer 的 `KSVideoPlayerView`（那行旁边有注释）

## 接下来要加的（下一步，不是这版）

### 1. 远程包（Node 服务）
现在猫源是 App 内直接请求源站。以后想接努努源那种远程包（Node 服务、`/config` + `/spider/<key>/3`）：

- 在 `Engine/` 新加一个 `RemotePackageSource`，遵守 `CatSource` 协议
- 它的 `homeVod/category/detail/search/play` 不直接请求源站，而是请求本地/远程 Node 服务的 `/spider/<key>/3/<路由>`（POST，body 是 JSON）
- `SourceStore` 里按 `kind: "remote"` 注册它，UI 不用改
- 注意：远程包的 `start/stop`、`{proxy}/config` 发现、端口 9988 这些都在 Node 服务那侧，App 只当客户端

### 2. js.js 蜘蛛（JavaScriptCore）
想让用户上传 js.js 蜘蛛（单个 ESM 文件，`createSpider` 工厂，六个 POST 路由）：

- 在 `Engine/` 新加 `JsSpiderSource`，用 iOS 自带的 `JavaScriptCore` 跑蜘蛛代码
- 要处理三件事：ESM 转 CommonJS（js.js 蜘蛛是 ESM，JavaScriptCore 只认普通 JS，得先转一次）、白名单 import（`axios / cheerio` 这些在 iOS 上没有，要自己提供等价物或禁掉）、`parse: 0` 直链才播、`parse: 1` 不要假装成功
- 蜘蛛文件存在 `Documents/spiders/`，`SourceStore` 按 `kind: "js"` 注册
- 详见 `~/workspace/custom-skills/writing-cat-spiders/SKILL.md`（js.md 是权威，CatPawOpen.md 只是参考）

### 3. 再往后
- 云盘解析（夸克 / UC 的转存 + 转码）：不要在 App 里重写，直接复用 niuer 那套逻辑（转存到 Wexfnw → 任务轮询 → 转码和下载并行拿地址），或者直接接 niuer-cms 那个包装层包
- 弹幕、投屏、下载离线：都是在 `PlayerViewModel` / `PlayerView` 上加，不动源引擎

## 文件结构

```
CatPlayer.xcodeproj/          Xcode 工程（Xcode 14.2 格式，iOS 15.0）
CatPlayer/
  CatPlayerApp.swift          App 入口，注入 SettingsStore / SourceStore / HistoryStore
  ContentView.swift           Tab：首页 / 搜索 / 历史 / 我的
  Theme.swift                 设计系统：深色、圆角 12、字体大小统一
  Models.swift                Vod / PlayLine / PlayEpisode / VodDetail / PlayResult
  Sources.json                内置源配置（360zy + nnyy）
  Info.plist                  iOS 15.0，不锁刷新率，ATS 全开（CMS 源有 http）
  Engine/
    CatSource.swift           源协议 + 后台网络小工具
    CmsSource.swift           AppleCMS JSON 源
    NnyySource.swift          nnyy.in HTML 源（URLSession + 正则）
    SourceStore.swift         源 JSON 配置文件管理（Documents/sources.json）
    TMDBService.swift         TMDB API v3 + 设置（Key 用户自己填）
    HistoryStore.swift        播放历史（UserDefaults）
    ImageCache.swift          图片 NSCache，后台下载解码
  Player/
    PlayerViewModel.swift     AVPlayer 内核 + KSPlayer 替换接口
    PlayerView.swift          播放页：选集/选线/倍速/字幕/手势亮度音量
  Views/
    HomeView.swift            首页：TMDB 轮播 + 热门/高分 + 动漫 + 最新
    AnimeView.swift           动漫分类页（LazyVStack 分页，顺滑）
    TMDBDetailView.swift      TMDB 详情 + “在猫源里搜同名”
    SearchView.swift          搜索：TMDB + 猫源
    DetailView.swift          猫源详情：海报大图 + 线路 + 集数
    HistoryView.swift         历史
    SourcesView.swift         我的：TMDB 设置 + 源管理
    PosterCard.swift          带缓存的海报卡片（全 App 一个样式）
  Assets.xcassets/            AppIcon + AccentColor
```

## 没验证过的部分（实话）

- 这台 Linux 虚拟机上没有 Xcode，**没有实际编译过**。代码是按 Xcode 14.2 / Swift 5.7 / iOS 15 API 写的（只用 NavigationView、AsyncImage 思路、VideoPlayer、Timer 这些老 API），但第一次在 Mac 上打开时如果报某个小错（比如某个 API 在 14.2 里拼写不同），把报错贴回来，我再改。
- nnyy.in 的 HTML 结构是按 2026-10-30 实测写的，站改版了要改 `NnyySource.swift` 里的正则。
- 360zy 的 API 是公开的 AppleCMS 接口，换源时在“我的”里加就行，不用改代码。
