import SwiftUI
import AppKit

/// 设计令牌 v3.2 — Void 设计语言
/// 深色优先 · Terminal DNA · Apple Blue 品牌色
/// 各分类已拆分到独立文件：+Colors / +Typography / +Spacing / +Sizes / +Animation
enum DesignTokens {

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

        static let accentGlow       = ShadowStyle(color: Color(hex: "#077aff").opacity(0.22), radius: 18, x: 0, y: 0)
        static let accentGlowStrong = ShadowStyle(color: Color(hex: "#077aff").opacity(0.38), radius: 28, x: 0, y: 0)

        static let connectedGlow  = ShadowStyle(color: Color(hex: "#34d399").opacity(0.32), radius: 8, x: 0, y: 0)
        static let connectingGlow = ShadowStyle(color: Color(hex: "#fbbf24").opacity(0.32), radius: 8, x: 0, y: 0)
        static let errorGlow      = ShadowStyle(color: Color(hex: "#f87171").opacity(0.32), radius: 8, x: 0, y: 0)

        // 选中行蓝色光晕（Figma 诊断 P1 #3）
        static let selectedRowGlow = ShadowStyle(color: Color(hex: "#077aff").opacity(0.22), radius: 10, x: 0, y: 4)
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
                .init(color: Color(hex: "#077aff").opacity(0.45), location: 0.0),
                .init(color: Color(hex: "#4da3ff").opacity(0.22), location: 0.5),
                .init(color: Color(hex: "#077aff").opacity(0.12), location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// 强调按钮渐变（Apple Blue → Deep Blue，对齐 Figma hover:#0051d5）
        static let accentButton = LinearGradient(
            colors: [Color(hex: "#077aff"), Color(hex: "#0051d5")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// AI 助手渐变（Apple Blue → Indigo，对齐 Figma from-[#077aff] to-[#5856d6]）
        static let aiGradient = LinearGradient(
            colors: [Color(hex: "#077aff"), Color(hex: "#5856d6")],
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
