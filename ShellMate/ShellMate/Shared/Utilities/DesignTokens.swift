import SwiftUI

/// 设计令牌 v2.0 — 液态玻璃（Liquid Glass）设计语言
/// 玻璃拟态 + 拟物化 + 现代极简的融合体系
enum DesignTokens {

    // MARK: - 颜色

    enum Colors {

        // ── 基底色（深空蓝黑调色板）──────────────────────────────

        /// 应用最深背景：深空蓝黑
        static let surfaceWindow    = Color(hex: "#07090F")
        /// 次级面板背景：深蓝黑
        static let surfacePanel     = Color(hex: "#0C1018")
        /// 卡片背景：带蓝调的深色
        static let surfaceCard      = Color(hex: "#101520")
        /// 覆层背景：略亮的深蓝
        static let surfaceOverlay   = Color(hex: "#161D2E")
        /// 输入框背景：极深蓝黑
        static let surfaceInput     = Color(hex: "#0A0E1A")

        // ── 玻璃覆层（叠加在 Material 之上）────────────────────

        static let glassUltraLight  = Color.white.opacity(0.04)
        static let glassLight       = Color.white.opacity(0.06)
        static let glassMedium      = Color.white.opacity(0.09)
        static let glassHoverColor  = Color.white.opacity(0.08)
        static let glassPress       = Color.white.opacity(0.12)
        static let glassSelected    = Color(hex: "#2C7EF8").opacity(0.14)

        // ── 玻璃边框（光线折射效果）─────────────────────────────────

        static let glassBorderTop    = Color.white.opacity(0.22)
        static let glassBorderSide   = Color.white.opacity(0.08)
        static let glassBorderBottom = Color.black.opacity(0.35)
        static let glassBorderAccent = Color(hex: "#2C7EF8").opacity(0.40)

        // ── 强调色（电光蓝）─────────────────────────────────────────

        static let accentPrimary    = Color(hex: "#2C7EF8")
        static let accentSecondary  = Color(hex: "#38BDF8")
        static let accentTertiary   = Color(hex: "#1A65D6")
        static let accentGlow       = Color(hex: "#2C7EF8").opacity(0.20)
        static let accentGlowStrong = Color(hex: "#2C7EF8").opacity(0.38)

        // ── 文字色（略带蓝调，更通透）───────────────────────────────

        static let textPrimary   = Color(hex: "#EDF0FF")
        static let textSecondary = Color(hex: "#8892AA")
        static let textTertiary  = Color(hex: "#525D78")
        static let textDisabled  = Color(hex: "#323A52")

        // ── 状态色（更鲜亮、更精致）────────────────────────────────

        static let statusConnected  = Color(hex: "#34D399")
        static let statusConnecting = Color(hex: "#FBBF24")
        static let statusError      = Color(hex: "#FB7185")
        static let statusOffline    = Color(hex: "#475569")

        // ── 边框（基于透明白色）─────────────────────────────────

        static let borderPrimary   = Color.white.opacity(0.10)
        static let borderSecondary = Color.white.opacity(0.06)
        static let borderFocus     = Color(hex: "#2C7EF8").opacity(0.65)
        static let borderSubtle    = Color.white.opacity(0.04)

        // ── 背景交互状态 ──────────────────────────────────────────

        static let backgroundHover    = Color.white.opacity(0.06)
        static let backgroundSelected = Color(hex: "#2C7EF8").opacity(0.14)
        static let backgroundPressed  = Color(hex: "#2C7EF8").opacity(0.22)

        // ── 扩展令牌（兼容旧调用）──────────────────────────────────

        static let surfaceElevated    = surfaceCard
        static let surfaceToolbar     = surfacePanel
        static let borderDefault      = borderPrimary
        static let borderFaint        = borderSecondary
        static let terminalBackground = surfaceWindow
        static let terminalText       = textPrimary
    }

    // MARK: - 间距

    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs:  CGFloat = 4
        static let xs:   CGFloat = 6
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
        static let xxl:  CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - 尺寸

    enum Sizes {
        static let sidebarWidth:    CGFloat = 224
        static let sidebarMinWidth: CGFloat = 180
        static let sidebarMaxWidth: CGFloat = 320

        static let sessionRowHeight: CGFloat = 46
        static let groupRowHeight:   CGFloat = 30

        static let statusDotSize:       CGFloat = 7
        static let statusDotGlowRadius: CGFloat = 6

        static let buttonHeight:   CGFloat = 28
        static let buttonMinWidth: CGFloat = 80
        static let iconButtonSize: CGFloat = 26

        static let avatarSizeSmall:  CGFloat = 26
        static let avatarSizeMedium: CGFloat = 34
        static let avatarSizeLarge:  CGFloat = 52

        // 圆角（更慷慨的圆角半径）
        static let cornerRadiusXSmall: CGFloat = 5
        static let cornerRadiusSmall:  CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12
        static let cornerRadiusLarge:  CGFloat = 16
        static let cornerRadiusXLarge: CGFloat = 20
        static let cornerRadiusPanel:  CGFloat = 24

        static let sheetWidth:    CGFloat = 540
        static let sheetMinHeight: CGFloat = 420

        static let tabBarHeight:       CGFloat = 38
        static let tabMinWidth:        CGFloat = 100
        static let tabMaxWidth:        CGFloat = 200
        static let tabCloseButtonSize: CGFloat = 16
    }

    // MARK: - 字体

    enum Typography {
        static let titleLarge  = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let titleMedium = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let titleSmall  = Font.system(size: 13, weight: .semibold, design: .rounded)

        static let bodyLarge   = Font.system(size: 14, weight: .regular)
        static let bodyMedium  = Font.system(size: 13, weight: .regular)
        static let bodySmall   = Font.system(size: 12, weight: .regular)

        static let labelLarge  = Font.system(size: 13, weight: .medium)
        static let labelMedium = Font.system(size: 12, weight: .medium)
        static let labelSmall  = Font.system(size: 11, weight: .medium)

        static let codeLarge   = Font.system(size: 14, weight: .regular, design: .monospaced)
        static let codeMedium  = Font.system(size: 13, weight: .regular, design: .monospaced)
        static let codeSmall   = Font.system(size: 12, weight: .regular, design: .monospaced)
    }

    // MARK: - 动画

    enum Animation {
        static let springResponse: Double = 0.36
        static let springDamping:  Double = 0.72

        static let standard = SwiftUI.Animation.easeInOut(duration: 0.20)
        static let fast     = SwiftUI.Animation.easeInOut(duration: 0.14)
        static let slow     = SwiftUI.Animation.easeInOut(duration: 0.30)
        static let spring   = SwiftUI.Animation.spring(response: springResponse, dampingFraction: springDamping)
        static let glass    = SwiftUI.Animation.spring(response: 0.42, dampingFraction: 0.76)
        static let hover    = SwiftUI.Animation.easeOut(duration: 0.12)
    }

    // MARK: - 阴影（分层阴影系统）

    enum Shadow {
        static let small  = ShadowStyle(color: .black.opacity(0.28), radius: 6,  x: 0, y: 3)
        static let medium = ShadowStyle(color: .black.opacity(0.40), radius: 16, x: 0, y: 7)
        static let large  = ShadowStyle(color: .black.opacity(0.52), radius: 32, x: 0, y: 14)
        static let xlarge = ShadowStyle(color: .black.opacity(0.65), radius: 56, x: 0, y: 24)

        static let accentGlow       = ShadowStyle(color: Color(hex: "#2C7EF8").opacity(0.22), radius: 18, x: 0, y: 0)
        static let accentGlowStrong = ShadowStyle(color: Color(hex: "#2C7EF8").opacity(0.38), radius: 28, x: 0, y: 0)

        static let connectedGlow  = ShadowStyle(color: Color(hex: "#34D399").opacity(0.32), radius: 8, x: 0, y: 0)
        static let connectingGlow = ShadowStyle(color: Color(hex: "#FBBF24").opacity(0.32), radius: 8, x: 0, y: 0)
        static let errorGlow      = ShadowStyle(color: Color(hex: "#FB7185").opacity(0.32), radius: 8, x: 0, y: 0)
    }

    // MARK: - 渐变

    enum Gradients {
        /// 玻璃边框渐变（顶部高光 → 底部阴影，模拟光折射）
        static func glassBorder() -> LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.24), location: 0.00),
                    .init(color: Color.white.opacity(0.14), location: 0.25),
                    .init(color: Color.white.opacity(0.06), location: 0.60),
                    .init(color: Color.black.opacity(0.08), location: 1.00),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// 选中状态玻璃边框渐变（蓝色光晕）
        static let glassAccentBorder = LinearGradient(
            stops: [
                .init(color: Color(hex: "#2C7EF8").opacity(0.55), location: 0.0),
                .init(color: Color(hex: "#38BDF8").opacity(0.28), location: 0.5),
                .init(color: Color(hex: "#2C7EF8").opacity(0.15), location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 强调按钮渐变（蓝色 → 深蓝）
        static let accentButton = LinearGradient(
            colors: [Color(hex: "#3D8EFF"), Color(hex: "#1E5CD0")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 阴影样式

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - 玻璃拟态视图修饰器

extension View {

    // ── 核心玻璃效果 ─────────────────────────────────────────────

    /// 标准玻璃卡片：毛玻璃 + 光折射边框 + 深度阴影
    func glassCard(
        radius: CGFloat = DesignTokens.Sizes.cornerRadiusMedium,
        shadow: Bool = true
    ) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(DesignTokens.Colors.glassUltraLight)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                DesignTokens.Gradients.glassBorder(),
                                lineWidth: 0.75
                            )
                    }
            }
            .applyIf(shadow) {
                $0.shadow(DesignTokens.Shadow.medium)
            }
    }

    /// 轻量玻璃面板（无阴影，嵌套用）
    func glassPanel(radius: CGFloat = DesignTokens.Sizes.cornerRadiusSmall) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DesignTokens.Colors.glassLight)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.glassBorderSide, lineWidth: 0.5)
                    }
            }
    }

    /// 选中玻璃效果（蓝色强调 + 光晕边框）
    func glassSelected(radius: CGFloat = DesignTokens.Sizes.cornerRadiusMedium) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DesignTokens.Colors.glassSelected)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                DesignTokens.Gradients.glassAccentBorder,
                                lineWidth: 0.75
                            )
                    }
            }
    }

    /// 悬停玻璃效果
    func glassHoverEffect(radius: CGFloat = DesignTokens.Sizes.cornerRadiusMedium) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DesignTokens.Colors.glassHoverColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.glassBorderSide, lineWidth: 0.5)
                    }
            }
    }

    // ── 阴影快捷方法 ──────────────────────────────────────────────

    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    // ── 旧接口兼容 ─────────────────────────────────────────────────

    func cardStyle() -> some View {
        self.glassCard(radius: DesignTokens.Sizes.cornerRadiusMedium)
    }

    func panelStyle() -> some View {
        self.glassCard(radius: DesignTokens.Sizes.cornerRadiusLarge)
    }

    // ── 条件修饰器 ────────────────────────────────────────────────

    @ViewBuilder
    func applyIf<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - 发光状态点

/// 带多层光晕的状态指示灯（玻璃拟态 + 拟物感）
struct GlowingStatusDot: View {

    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            // 外层漫射光晕
            Circle()
                .fill(color.opacity(0.20))
                .frame(width: size * 2.8, height: size * 2.8)
                .blur(radius: size * 0.9)

            // 中层光晕
            Circle()
                .fill(color.opacity(0.38))
                .frame(width: size * 1.7, height: size * 1.7)
                .blur(radius: size * 0.35)

            // 核心实心点
            Circle()
                .fill(color)
                .frame(width: size, height: size)

            // 拟物高光点（球面感）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.60), Color.clear],
                        center: .init(x: 0.32, y: 0.28),
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)
        }
        .frame(width: size * 2.8, height: size * 2.8)
    }
}
