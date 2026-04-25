import SwiftUI
import AppKit

/// 设计令牌 v3.2 — Void 设计语言
/// 深色优先 · Terminal DNA · Apple Blue 品牌色
/// 参考 Figma-Spec-v2/00-总纲与设计令牌.md（Apple Blue #007aff 权威色）
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

        // ── Void 四层表面系统（深色优先）────────────────────────

        /// Void 最深背景层 #070a11（Operator Dark：更冷调深空蓝黑）
        static let surfaceWindow = adaptive(
            light: NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1), // #F5F5F7（亮色模式保留）
            dark:  NSColor(srgbRed: 0.027, green: 0.039, blue: 0.067, alpha: 1)  // #070a11 Operator Dark
        )
        /// Surface 面板层 #0d1117（Operator Dark：冷调深灰蓝）
        static let surfacePanel = adaptive(
            light: NSColor(srgbRed: 0.929, green: 0.933, blue: 0.945, alpha: 1), // #EDEFF1
            dark:  NSColor(srgbRed: 0.051, green: 0.067, blue: 0.090, alpha: 1)  // #0d1117 Surface
        )
        /// Elevated 卡片层 #131922（Operator Dark：标签/卡片层）
        static let surfaceCard = adaptive(
            light: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1), // #FFFFFF
            dark:  NSColor(srgbRed: 0.075, green: 0.098, blue: 0.133, alpha: 1)  // #131922 Elevated
        )
        /// Overlay 弹窗层 #1a2232（Operator Dark：弹窗层）
        static let surfaceOverlay = adaptive(
            light: NSColor(srgbRed: 0.953, green: 0.957, blue: 0.969, alpha: 1), // #F3F4F7
            dark:  NSColor(srgbRed: 0.102, green: 0.133, blue: 0.196, alpha: 1)  // #1a2232 Overlay
        )
        /// Input 输入框背景 #141826
        static let surfaceInput = adaptive(
            light: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1), // #FFFFFF
            dark:  NSColor(srgbRed: 0.078, green: 0.094, blue: 0.149, alpha: 1)  // #141826 Input
        )

        // ── 玻璃覆层（自适应：亮色用黑色叠加，深色用白色叠加）────────

        static let glassUltraLight = adaptive(
            light: NSColor(white: 0.0, alpha: 0.02),
            dark:  NSColor(white: 1.0, alpha: 0.03)
        )
        static let glassLight = adaptive(
            light: NSColor(white: 0.0, alpha: 0.03),
            dark:  NSColor(white: 1.0, alpha: 0.04)
        )
        static let glassMedium = adaptive(
            light: NSColor(white: 0.0, alpha: 0.05),
            dark:  NSColor(white: 1.0, alpha: 0.06)
        )
        static let glassHoverColor = adaptive(
            light: NSColor(white: 0.0, alpha: 0.03),
            dark:  NSColor(white: 1.0, alpha: 0.04)
        )
        /// 悬停状态背景（行/卡片 hover）— 亮色 black/5，深色 white/5
        static let surfaceHover = adaptive(
            light: NSColor(white: 0.0, alpha: 0.05),
            dark:  NSColor(white: 1.0, alpha: 0.05)
        )
        static let glassPress = adaptive(
            light: NSColor(white: 0.0, alpha: 0.07),
            dark:  NSColor(white: 1.0, alpha: 0.07)
        )
        /// 选中状态 Apple Blue 高亮 rgba(0,122,255,0.12)
        static let glassSelected    = Color(hex: "#007aff").opacity(0.12)

        // ── 边框（自适应：亮色用 #d2d2d7，深色用白色叠加）──────────

        static let glassBorderTop = adaptive(
            light: NSColor(white: 0.0, alpha: 0.08),
            dark:  NSColor(white: 1.0, alpha: 0.10)
        )
        static let glassBorderSide = adaptive(
            light: NSColor(white: 0.0, alpha: 0.05),
            dark:  NSColor(white: 1.0, alpha: 0.07)
        )
        static let glassBorderBottom = adaptive(
            light: NSColor(white: 0.0, alpha: 0.03),
            dark:  NSColor(white: 1.0, alpha: 0.04)
        )
        static let glassBorderAccent = Color(hex: "#007aff").opacity(0.30)

        // ── 主品牌色：Apple Blue（Figma-Spec-v2 §00 权威色）──────

        static let accentPrimary    = Color(hex: "#007aff")   // Apple Blue
        static let accentSecondary  = Color(hex: "#34d399")   // Success Green（NL 命令模式专用）
        static let accentTertiary   = Color(hex: "#0051d5")   // Apple Blue Dark（Hover 态）
        static let accentGlow       = Color(hex: "#007aff").opacity(0.20)
        static let accentGlowStrong = Color(hex: "#007aff").opacity(0.38)

        // ── AI 品牌色：Apple Indigo ──────────────────────────────

        /// AI 功能专属色 #818cf8（AI 模式切换器 / 设置页专用）
        static let accentAI         = Color(hex: "#818cf8")
        static let accentAIGlow     = Color(hex: "#818cf8").opacity(0.25)
        /// Apple Indigo #5856d6（对齐 Figma AI 头像渐变 to-[#5856d6]）
        static let accentIndigo     = Color(hex: "#5856d6")

        // ── 脚本自动化色 ────────────────────────────────────────

        static let accentScript     = Color(hex: "#fb923c")

        // ── 文字色（Void 冷白系）────────────────────────────────

        static let textPrimary = adaptive(
            light: NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1), // #1D1D1F（亮色）
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 1)  // #e2e4f0 Void 冷白
        )
        static let textSecondary = adaptive(
            light: NSColor(srgbRed: 0.525, green: 0.525, blue: 0.545, alpha: 1), // #86868B
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 0.52) // rgba(226,228,240,0.52) 对齐 --text-2
        )
        static let textTertiary = adaptive(
            light: NSColor(srgbRed: 0.682, green: 0.682, blue: 0.698, alpha: 1), // #AEAEB2
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 0.30) // rgba(226,228,240,0.30) 对齐 --text-3
        )
        static let textDisabled = adaptive(
            light: NSColor(srgbRed: 0.780, green: 0.780, blue: 0.800, alpha: 1), // #C7C7CC
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 0.18) // rgba(226,228,240,0.18)
        )

        // ── 状态色（Void 宝石调色板）────────────────────────────

        static let statusConnected = adaptive(
            light: NSColor(srgbRed: 0.204, green: 0.780, blue: 0.349, alpha: 1), // #34C759（Apple 绿）
            dark:  NSColor(srgbRed: 0.204, green: 0.831, blue: 0.600, alpha: 1)  // #34D399 宝石绿
        )
        static let statusConnecting = adaptive(
            light: NSColor(srgbRed: 1.000, green: 0.584, blue: 0.000, alpha: 1), // #FF9500
            dark:  NSColor(srgbRed: 0.984, green: 0.749, blue: 0.141, alpha: 1)  // #FBBF24 琥珀黄
        )
        static let statusError = adaptive(
            light: NSColor(srgbRed: 1.000, green: 0.231, blue: 0.188, alpha: 1), // #FF3B30
            dark:  NSColor(srgbRed: 0.973, green: 0.443, blue: 0.443, alpha: 1)  // #f87171 玫瑰红
        )
        static let statusOffline = adaptive(
            light: NSColor(srgbRed: 0.557, green: 0.557, blue: 0.576, alpha: 1), // #8E8E93
            dark:  NSColor(srgbRed: 0.886, green: 0.894, blue: 0.941, alpha: 0.28) // rgba(226,228,240,0.28)
        )

        // ── 边框（自适应：亮色 #d2d2d7/50，深色 white/7）────────────

        /// 标准边框：亮色 rgba(210,210,215,0.5)，深色 rgba(255,255,255,0.07)
        static let borderPrimary = adaptive(
            light: NSColor(srgbRed: 0.824, green: 0.824, blue: 0.847, alpha: 0.5),
            dark:  NSColor(white: 1.0, alpha: 0.07)
        )
        static let borderSecondary = adaptive(
            light: NSColor(srgbRed: 0.824, green: 0.824, blue: 0.847, alpha: 0.3),
            dark:  NSColor(white: 1.0, alpha: 0.05)
        )
        /// Focus 边框：Apple Blue rgba(0,122,255,0.35)
        static let borderFocus     = Color(hex: "#007aff").opacity(0.35)
        static let borderSubtle = adaptive(
            light: NSColor(srgbRed: 0.824, green: 0.824, blue: 0.847, alpha: 0.2),
            dark:  NSColor(white: 1.0, alpha: 0.04)
        )

        // ── 背景交互状态 ──────────────────────────────────────────

        static let backgroundHover = adaptive(
            light: NSColor(white: 0.0, alpha: 0.04),
            dark:  NSColor(white: 1.0, alpha: 0.04)
        )
        static let backgroundSelected = Color(hex: "#007aff").opacity(0.12)
        static let backgroundPressed  = Color(hex: "#007aff").opacity(0.18)

        // ── 扩展令牌（兼容旧调用）──────────────────────────────────

        static let surfaceElevated    = surfaceCard
        static let surfaceToolbar     = surfacePanel
        static let borderDefault      = borderPrimary
        static let borderFaint        = borderSecondary
        /// 终端背景 = Void 最深层 #0a0c12
        static let terminalBackground    = surfaceWindow
        static let terminalText          = textPrimary
        /// 终端字体预览区背景（Operator Dark 深空黑）
        static let terminalPreviewBg     = Color(hex: "#070a11")
        /// 终端 Prompt 颜色（Electric Teal）
        static let terminalPromptDefault = Color(hex: "#00d4aa")

        // ── Tab / 选中激活态 ────────────────────────────────────────

        /// 激活 Tab 背景色 rgba(0,122,255,0.07)
        static let surfaceActive = adaptive(
            light: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.92),
            dark:  NSColor(srgbRed: 0.000, green: 0.478, blue: 1.000, alpha: 0.07)  // rgba(0,122,255,0.07)
        )

        // ── 图标色 ──────────────────────────────────────────────────

        /// 主图标色
        static let iconPrimary   = textSecondary
        /// 次图标色
        static let iconSecondary = textTertiary

        // ── 代码块专用 ──────────────────────────────────────────────

        /// 代码块背景（Operator Dark 深空黑）
        static let codeBackground = Color(hex: "#070a11")
        /// 代码块文字色（teal）
        static let codeText       = Color(hex: "#00d4aa").opacity(0.75)

        // ── 危险色 ──────────────────────────────────────────────────

        /// 危险操作色（与 statusError 一致，语义化别名）
        static let danger = statusError
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
        static let sidebarWidth:    CGFloat = 240  // Void v3.1: 256 → 240
        static let sidebarMinWidth: CGFloat = 180
        static let sidebarMaxWidth: CGFloat = 320

        static let sessionRowHeight: CGFloat = 46
        static let groupRowHeight:   CGFloat = 30

        static let statusDotSize:       CGFloat = 7
        static let statusDotGlowRadius: CGFloat = 6

        static let buttonHeight:   CGFloat = 28
        static let buttonMinWidth: CGFloat = 80
        // h-7 w-7 = 28pt（Figma-Spec-v2 §02 §03 工具栏按钮规范）
        static let iconButtonSize: CGFloat = 28

        static let avatarSizeSmall:  CGFloat = 26
        static let avatarSizeMedium: CGFloat = 34
        static let avatarSizeLarge:  CGFloat = 52

        // 圆角（对齐 Figma-Spec-v2 §00 圆角令牌）
        // radius-sm:6  radius-md:8  radius-xl:12  radius-2xl:16  radius-3xl:24
        static let cornerRadiusXSmall: CGFloat = 6   // radius-sm：图标徽章、工具提示
        static let cornerRadiusSmall:  CGFloat = 8   // radius-md：按钮、输入框
        static let cornerRadiusMedium: CGFloat = 12  // radius-xl：会话行、标签触发器
        static let cornerRadiusLarge:  CGFloat = 16  // radius-2xl：弹窗容器
        static let cornerRadiusXLarge: CGFloat = 16  // 与 Large 对齐
        static let cornerRadiusPanel:  CGFloat = 24  // radius-3xl：欢迎界面英雄图标容器

        static let sheetWidth:    CGFloat = 540
        static let sheetMinHeight: CGFloat = 420

        static let toolbarHeight:      CGFloat = 44  // Void v3.1: 48 → 44
        static let tabBarHeight:       CGFloat = 38  // Void v3.1: 40 → 38
        static let tabMinWidth:        CGFloat = 100
        static let tabMaxWidth:        CGFloat = 200
        static let tabCloseButtonSize: CGFloat = 16

        static let statusBarHeight:    CGFloat = 28  // Void v3.1: 32 → 28

        static let aiPanelWidth:   CGFloat = 380  // Void v3.1: 400 → 380
        static let sftpPanelWidth: CGFloat = 480  // Void v3.1: 500 → 480

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

        static let accentGlow       = ShadowStyle(color: Color(hex: "#007aff").opacity(0.22), radius: 18, x: 0, y: 0)
        static let accentGlowStrong = ShadowStyle(color: Color(hex: "#007aff").opacity(0.38), radius: 28, x: 0, y: 0)

        static let connectedGlow  = ShadowStyle(color: Color(hex: "#34d399").opacity(0.32), radius: 8, x: 0, y: 0)
        static let connectingGlow = ShadowStyle(color: Color(hex: "#fbbf24").opacity(0.32), radius: 8, x: 0, y: 0)
        static let errorGlow      = ShadowStyle(color: Color(hex: "#f87171").opacity(0.32), radius: 8, x: 0, y: 0)
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

        /// 选中状态玻璃边框渐变（Apple Blue 光晕）
        static let glassAccentBorder = LinearGradient(
            stops: [
                .init(color: Color(hex: "#007aff").opacity(0.45), location: 0.0),
                .init(color: Color(hex: "#4da3ff").opacity(0.22), location: 0.5),
                .init(color: Color(hex: "#007aff").opacity(0.12), location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 强调按钮渐变（Apple Blue → Deep Blue，对齐 Figma hover:#0051d5）
        static let accentButton = LinearGradient(
            colors: [Color(hex: "#007aff"), Color(hex: "#0051d5")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// AI 助手渐变（Apple Blue → Indigo，对齐 Figma from-[#007aff] to-[#5856d6]）
        static let aiGradient = LinearGradient(
            colors: [Color(hex: "#007aff"), Color(hex: "#5856d6")],
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

    // ── 终端与面板专用 ───────────────────────────────────────────────

    /// 终端专用纯色背景（零 GPU 消耗，替代 .ultraThinMaterial）
    func terminalBackground() -> some View {
        self.background(DesignTokens.Colors.terminalBackground)
    }

    /// 标准面板投影（浮动面板统一阴影）
    func panelShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.25),
            radius: DesignTokens.Shadow.medium.radius,
            x: 0,
            y: 4
        )
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
