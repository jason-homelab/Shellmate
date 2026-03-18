import SwiftUI

/// 设计令牌
/// 定义全局颜色、间距、尺寸等设计常量
enum DesignTokens {

    // MARK: - 颜色 (深色模式)

    enum Colors {
        // 表面颜色
        static let surfaceWindow = Color(hex: "#0C0C0E")
        static let surfacePanel = Color(hex: "#1A1A1C")
        static let surfaceCard = Color(hex: "#242426")
        static let surfaceOverlay = Color(hex: "#2E2E30")

        // 文字颜色
        static let textPrimary = Color(hex: "#EEEDF5")
        static let textSecondary = Color(hex: "#9D9CAA")
        static let textTertiary = Color(hex: "#6B6A78")
        static let textDisabled = Color(hex: "#4A4A52")

        // 强调色
        static let accentPrimary = Color(hex: "#4A90D9")
        static let accentSecondary = Color(hex: "#3A7BC8")
        static let accentTertiary = Color(hex: "#2A66B7")

        // 状态颜色
        static let statusConnected = Color(hex: "#2DCE7A")
        static let statusConnecting = Color(hex: "#F0A500")
        static let statusError = Color(hex: "#F04060")
        static let statusOffline = Color(hex: "#6B6A78")

        // 边框颜色
        static let borderPrimary = Color(hex: "#3A3A3C")
        static let borderSecondary = Color(hex: "#2A2A2C")
        static let borderFocus = Color(hex: "#4A90D9")

        // 背景颜色
        static let backgroundHover = Color(hex: "#2A2A2C")
        static let backgroundSelected = Color(hex: "#4A90D9").opacity(0.2)
        static let backgroundPressed = Color(hex: "#4A90D9").opacity(0.3)
    }

    // MARK: - 间距

    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - 尺寸

    enum Sizes {
        // 侧边栏
        static let sidebarWidth: CGFloat = 220
        static let sidebarMinWidth: CGFloat = 180
        static let sidebarMaxWidth: CGFloat = 320

        // 行高度
        static let sessionRowHeight: CGFloat = 44
        static let groupRowHeight: CGFloat = 28

        // 状态点
        static let statusDotSize: CGFloat = 6
        static let statusDotGlowRadius: CGFloat = 4

        // 按钮
        static let buttonHeight: CGFloat = 28
        static let buttonMinWidth: CGFloat = 80
        static let iconButtonSize: CGFloat = 24

        // 头像/图标
        static let avatarSizeSmall: CGFloat = 24
        static let avatarSizeMedium: CGFloat = 32
        static let avatarSizeLarge: CGFloat = 48

        // 圆角
        static let cornerRadiusSmall: CGFloat = 4
        static let cornerRadiusMedium: CGFloat = 6
        static let cornerRadiusLarge: CGFloat = 8
        static let cornerRadiusXLarge: CGFloat = 12

        // 弹窗
        static let sheetWidth: CGFloat = 520
        static let sheetMinHeight: CGFloat = 400

        // TabBar
        static let tabBarHeight: CGFloat = 36
        static let tabMinWidth: CGFloat = 100
        static let tabMaxWidth: CGFloat = 200
        static let tabCloseButtonSize: CGFloat = 16
    }

    // MARK: - 字体

    enum Typography {
        // 标题
        static let titleLarge = Font.system(size: 20, weight: .semibold)
        static let titleMedium = Font.system(size: 16, weight: .semibold)
        static let titleSmall = Font.system(size: 14, weight: .semibold)

        // 正文
        static let bodyLarge = Font.system(size: 14, weight: .regular)
        static let bodyMedium = Font.system(size: 13, weight: .regular)
        static let bodySmall = Font.system(size: 12, weight: .regular)

        // 标签
        static let labelLarge = Font.system(size: 13, weight: .medium)
        static let labelMedium = Font.system(size: 12, weight: .medium)
        static let labelSmall = Font.system(size: 11, weight: .medium)

        // 代码
        static let codeLarge = Font.system(size: 14, weight: .regular, design: .monospaced)
        static let codeMedium = Font.system(size: 13, weight: .regular, design: .monospaced)
        static let codeSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    }

    // MARK: - 动画

    enum Animation {
        // 弹性动画参数
        static let springResponse: Double = 0.35
        static let springDamping: Double = 0.7

        // 标准动画
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.3)

        // 弹性动画
        static let spring = SwiftUI.Animation.spring(response: springResponse, dampingFraction: springDamping)
    }

    // MARK: - 阴影

    enum Shadow {
        static let small = ShadowStyle(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        static let large = ShadowStyle(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
}

/// 阴影样式
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - 视图修饰器

extension View {
    /// 应用阴影样式
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    /// 应用卡片样式
    func cardStyle() -> some View {
        self
            .background(DesignTokens.Colors.surfaceCard)
            .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
    }

    /// 应用面板样式
    func panelStyle() -> some View {
        self
            .background(DesignTokens.Colors.surfacePanel)
            .cornerRadius(DesignTokens.Sizes.cornerRadiusLarge)
    }
}
