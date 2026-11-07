import SwiftUI

// ---------- 设计系统：全 App 共用一套 ----------
// 深色主题为主，像主流视频 App：黑底、圆角海报、克制阴影。
// 流畅要求不变：这里只用圆角 + 一层线性渐变遮罩，
// 不用多层模糊、不叠阴影、不在列表行里加 .shadow()，120Hz 下才不会掉帧。

enum Theme {
    static let background = Color(red: 0.02, green: 0.02, blue: 0.04)   // 近黑
    static let card = Color(red: 0.11, green: 0.11, blue: 0.13)        // 卡片底
    static let cardBorder = Color.white.opacity(0.08)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 0.62, green: 0.63, blue: 0.68)
    static let accent = Color(red: 1.0, green: 0.27, blue: 0.23)       // 红色点缀
    static let accentSoft = Color(red: 1.0, green: 0.27, blue: 0.23).opacity(0.15)

    static let corner: CGFloat = 12        // 海报、卡片统一圆角
    static let cornerSmall: CGFloat = 8    // 按钮、集数格统一圆角
    static let spacing: CGFloat = 16       // 页面边距
    static let spacingSmall: CGFloat = 12  // 卡片间距
    static let spacingTiny: CGFloat = 8

    // 字体统一：标题 20 加粗 / 小标题 16 半粗 / 正文 14 / 说明 12
    static let titleFont = Font.system(size: 20, weight: .bold)
    static let sectionFont = Font.system(size: 17, weight: .semibold)
    static let bodyFont = Font.system(size: 14, weight: .regular)
    static let captionFont = Font.system(size: 12, weight: .regular)
}

/// 深色底 + 白字，所有页面都用这个修饰器开头，避免有的页面白底有的黑底。
struct DarkPage: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.background.ignoresSafeArea())
            .foregroundColor(Theme.primaryText)
    }
}

extension View {
    func darkPage() -> some View { modifier(DarkPage()) }
}
