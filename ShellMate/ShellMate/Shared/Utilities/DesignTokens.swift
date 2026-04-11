import SwiftUI
import AppKit

/// 设计令牌 v3.0 — macOS Native First 设计语言
/// Apple HIG 标准色系 + 玻璃拟态 + 自适应 Light/Dark 双模式
enum DesignTokens {

    // MARK: - 颜色

    enum Colors {

        // ── 自适应颜色辅助方法 ───────────────────────────────────

        /// 根据外观模式（Aqua / Dark Aqua）返回不同颜色
        private static func adaptive(light: NSColor, dark: NSColor) -> Color {
            Color(nsColor: NSColor(name: nil) { traits in
                traits.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            })
        }

        // ── 基底色（深空蓝黑 / 浅蓝灰双调色板）─────────────────

        /// 应用最深背景
        static let surfaceWindow = adaptive(
            light: NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1), // #F5F5F7（Apple 标准）
            dark:  NSColor(srgbRed: 0.027, green: 0.035, blue: 0.059, alpha: 1)  // #07090F
        )
        /// 次级面板背景
        static let surfacePanel = adaptive(
            light: NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1), // #F5F5F7
            dark:  NSColor(srgbRed: 0.047, green: 0.063, blue: 0.094, alpha: 1)  // #0C1018
        )
        /// 卡片背景
        static let surfaceCard = adaptive(
            light: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1), // #FFFFFF
            dark:  NSColor(srgbRed: 0.063, green: 0.082, blue: 0.125, alpha: 1)  // #101520
        )
        /// 覆层背景
        static let surfaceOverlay = adaptive(
            light: NSColor(srgbRed: 0.878, green: 0.890, blue: 0.937, alpha: 1), // #E0E3EF
            dark:  NSColor(srgbRed: 0.086, green: 0.114, blue: 0.180, alpha: 1)  // #161D2E
        )
        /// 输入框背景
        static let surfaceInput = adaptive(
            light: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1), // #FFFFFF
            dark:  NSColor(srgbRed: 0.039, green: 0.055, blue: 0.102, alpha: 1)  // #0A0E1A
        )

        // ── 玻璃覆层（叠加在 Material 之上）────────────────────

        static let glassUltraLight  = Color.primary.opacity(0.04)
        static let glassLight       = Color.primary.opacity(0.06)
        static let glassMedium      = Color.primary.opacity(0.09)
        static let glassHoverColor  = Color.primary.opacity(0.08)
        static let glassPress       = Color.primary.opacity(0.12)
        static let glassSelected    = Color(hex: "#007AFF").opacity(0.14)

        // ── 玻璃边框（光线折射效果）─────────────────────────────────

        static let glassBorderTop    = Color.primary.opacity(0.18)
        static let glassBorderSide   = Color.primary.opacity(0.07)
        static let glassBorderBottom = Color.primary.opacity(0.04)
        static let glassBorderAccent = Color(hex: "#007AFF").opacity(0.40)

        // ── 强调色（电光蓝）─────────────────────────────────────────

        static let accentPrimary    = Color(hex: "#007AFF")
        static let accentSecondary  = Color(hex: "#38BDF8")
        static let accentTertiary   = Color(hex: "#1A65D6")
        static let accentGlow       = Color(hex: "#007AFF").opacity(0.20)
        static let accentGlowStrong = Color(hex: "#007AFF").opacity(0.38)

        // ── 辅助强调色（紫色系）──────────────────────────────────────

        /// 紫蓝色强调（内存指标、AI 渐变等辅助场景）
        static let accentIndigo     = Color(hex: "#5856D6")

        // ── 文字色（自适应）──────────────────────────────────────

        static let textPrimary = adaptive(
            light: NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1), // #1D1D1F（Apple 标准）
            dark:  NSColor(srgbRed: 0.929, green: 0.941, blue: 1.000, alpha: 1)  // #EDF0FF
        )
        static let textSecondary = adaptive(
            light: NSColor(srgbRed: 0.525, green: 0.525, blue: 0.545, alpha: 1), // #86868B（Apple 标准）
            dark:  NSColor(srgbRed: 0.533, green: 0.573, blue: 0.667, alpha: 1)  // #8892AA
        )
        static let textTertiary = adaptive(
            light: NSColor(srgbRed: 0.682, green: 0.682, blue: 0.698, alpha: 1), // #AEAEB2（Apple 标准）
            dark:  NSColor(srgbRed: 0.322, green: 0.365, blue: 0.471, alpha: 1)  // #525D78
        )
        static let textDisabled = adaptive(
            light: NSColor(srgbRed: 0.780, green: 0.780, blue: 0.800, alpha: 1), // #C7C7CC（Apple 标准）
            dark:  NSColor(srgbRed: 0.196, green: 0.227, blue: 0.322, alpha: 1)  // #323A52
        )

        // ── 状态色（自适应：Light = Apple HIG / Dark = 宝石色调）──────

        static let statusConnected = adaptive(
            light: NSColor(srgbRed: 0.204, green: 0.780, blue: 0.349, alpha: 1), // #34C759（Apple 绿）
            dark:  NSColor(srgbRed: 0.204, green: 0.831, blue: 0.600, alpha: 1)  // #34D399
        )
        static let statusConnecting = adaptive(
            light: NSColor(srgbRed: 1.000, green: 0.584, blue: 0.000, alpha: 1), // #FF9500（Apple 橙）
            dark:  NSColor(srgbRed: 0.984, green: 0.749, blue: 0.141, alpha: 1)  // #FBBF24
        )
        static let statusError = adaptive(
            light: NSColor(srgbRed: 1.000, green: 0.231, blue: 0.188, alpha: 1), // #FF3B30（Apple 红）
            dark:  NSColor(srgbRed: 0.984, green: 0.443, blue: 0.522, alpha: 1)  // #FB7185
        )
        static let statusOffline = adaptive(
            light: NSColor(srgbRed: 0.557, green: 0.557, blue: 0.576, alpha: 1), // #8E8E93（Apple 灰）
            dark:  NSColor(srgbRed: 0.278, green: 0.337, blue: 0.412, alpha: 1)  // #475769
        )

        // ── 边框（自适应透明度）──────────────────────────────────

        static let borderPrimary   = Color.primary.opacity(0.10)
        static let borderSecondary = Color.primary.opacity(0.06)
        static let borderFocus     = Color(hex: "#007AFF").opacity(0.65)
        static let borderSubtle    = Color.primary.opacity(0.04)

        // ── 背景交互状态 ──────────────────────────────────────────

        static let backgroundHover    = Color.primary.opacity(0.06)
        static let backgroundSelected = Color(hex: "#007AFF").opacity(0.14)
        static let backgroundPressed  = Color(hex: "#007AFF").opacity(0.22)

        // ── 扩展令牌（兼容旧调用）──────────────────────────────────

        static let surfaceElevated    = surfaceCard
        static let surfaceToolbar     = surfacePanel
        static let borderDefault      = borderPrimary
        static let borderFaint        = borderSecondary
        static let terminalBackground    = surfaceWindow
        static let terminalText          = textPrimary
        /// 终端字体预览区背景（纯黑，模拟真实终端）
        static let terminalPreviewBg     = Color(hex: "#0C0C0E")
        /// 终端字体预览区 Prompt 颜色（默认绿色）
        static let terminalPromptDefault = Color(hex: "#4CAF7D")
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
        static let sidebarWidth:    CGFloat = 256  // v3.0: 224 → 256
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

        // 圆角（对齐 Figma-Spec-v2 §00 圆角令牌）
        // radius-sm:6  radius-md:8  radius-xl:12  radius-2xl:16  radius-3xl:24
        static let cornerRadiusXSmall: CGFloat = 6   // radius-sm：图标徽章、工具提示
        static let cornerRadiusSmall:  CGFloat = 8   // radius-md：按钮、输入框
        static let cornerRadiusMedium: CGFloat = 12  // radius-xl：会话行、标签触发器
        static let cornerRadiusLarge:  CGFloat = 16  // radius-2xl：弹窗容器
        static let cornerRadiusXLarge: CGFloat = 16  // 与 Large 对齐（原 20 无对应规范值）
        static let cornerRadiusPanel:  CGFloat = 24  // radius-3xl：欢迎界面英雄图标容器

        static let sheetWidth:    CGFloat = 540
        static let sheetMinHeight: CGFloat = 420

        static let toolbarHeight:      CGFloat = 48  // v3.0 新增
        static let tabBarHeight:       CGFloat = 40  // v3.0: 38 → 40
        static let tabMinWidth:        CGFloat = 100
        static let tabMaxWidth:        CGFloat = 200
        static let tabCloseButtonSize: CGFloat = 16

        static let statusBarHeight:    CGFloat = 32  // v3.0: 24 → 32

        static let aiPanelWidth:   CGFloat = 400  // v3.0 新增
        static let sftpPanelWidth: CGFloat = 500  // v3.0 新增

        // 终端字号界限
        static let terminalFontSizeMin: CGFloat = 9
        static let terminalFontSizeMax: CGFloat = 24

        // 会话行图标容器
        static let sessionIconSize: CGFloat = 32
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
        static let springResponse: Double = 0.35  // v3.0: 0.36 → 0.35
        static let springDamping:  Double = 0.75  // v3.0: 0.72 → 0.75

        static let standard = SwiftUI.Animation.easeInOut(duration: 0.20) // 标准 hover/press 过渡
        static let fast     = SwiftUI.Animation.easeInOut(duration: 0.10) // v3.0: 0.14 → 0.10（按钮按下）
        static let medium   = SwiftUI.Animation.easeInOut(duration: 0.30) // 面板展开/折叠
        static let slow     = SwiftUI.Animation.easeInOut(duration: 0.50) // 进度条/数值更新
        static let spring   = SwiftUI.Animation.spring(response: springResponse, dampingFraction: springDamping)
        static let glass    = SwiftUI.Animation.spring(response: 0.40, dampingFraction: 0.80) // 弹窗进入
        static let hover    = SwiftUI.Animation.easeOut(duration: 0.12)
    }

    // MARK: - 阴影（分层阴影系统，对齐 Figma-Spec-v2 §00）

    enum Shadow {
        // shadow-sm: 0 1px 2px rgba(0,0,0,0.06)
        static let small  = ShadowStyle(color: .black.opacity(0.06), radius: 2,  x: 0, y: 1)
        // shadow-md: 0 4px 6px rgba(0,0,0,0.07)
        static let medium = ShadowStyle(color: .black.opacity(0.07), radius: 6,  x: 0, y: 4)
        // shadow-lg: 0 10px 15px rgba(0,0,0,0.10)
        static let large  = ShadowStyle(color: .black.opacity(0.10), radius: 15, x: 0, y: 10)
        // shadow-2xl: 0 25px 50px rgba(0,0,0,0.25)
        static let xlarge = ShadowStyle(color: .black.opacity(0.25), radius: 50, x: 0, y: 25)

        static let accentGlow       = ShadowStyle(color: Color(hex: "#007AFF").opacity(0.22), radius: 18, x: 0, y: 0)
        static let accentGlowStrong = ShadowStyle(color: Color(hex: "#007AFF").opacity(0.38), radius: 28, x: 0, y: 0)

        static let connectedGlow  = ShadowStyle(color: Color(hex: "#34C759").opacity(0.32), radius: 8, x: 0, y: 0)
        static let connectingGlow = ShadowStyle(color: Color(hex: "#FF9500").opacity(0.32), radius: 8, x: 0, y: 0)
        static let errorGlow      = ShadowStyle(color: Color(hex: "#FF3B30").opacity(0.32), radius: 8, x: 0, y: 0)
    }

    // MARK: - 渐变

    enum Gradients {
        /// 玻璃边框渐变（顶部高光 → 底部阴影，模拟光折射）
        static func glassBorder() -> LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: Color.primary.opacity(0.20), location: 0.00),
                    .init(color: Color.primary.opacity(0.12), location: 0.25),
                    .init(color: Color.primary.opacity(0.05), location: 0.60),
                    .init(color: Color.primary.opacity(0.03), location: 1.00),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// 选中状态玻璃边框渐变（蓝色光晕）
        static let glassAccentBorder = LinearGradient(
            stops: [
                .init(color: Color(hex: "#007AFF").opacity(0.55), location: 0.0),
                .init(color: Color(hex: "#38BDF8").opacity(0.28), location: 0.5),
                .init(color: Color(hex: "#007AFF").opacity(0.15), location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 强调按钮渐变（蓝色 → 深蓝，对应 Apple HIG #007AFF → #0051D5）
        static let accentButton = LinearGradient(
            colors: [Color(hex: "#007AFF"), Color(hex: "#0051D5")],
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
