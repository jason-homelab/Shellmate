import SwiftUI

// MARK: - GlassButtonVariant
//
// 按钮变体枚举，覆盖 Figma-Spec-v2 三种标准按钮语义。

public enum GlassButtonVariant {
    case primary      // 填充 Apple Blue，主操作（对话框确认按钮）
    case ghost        // 透明，hover white/5%（非工具栏通用按钮）
    case toolbarGhost // Figma §03: 工具栏按钮默认有 rgba(0,0,0,0.04) 背景
    case danger       // 填充红色，危险/破坏性操作（对话框删除按钮）
    case connect      // Figma §03: 永久 Apple Blue 浅背景 + Blue 前景（工具栏连接按钮）
    case disconnect   // ghost + 错误红 65% 前景色（工具栏断开按钮）
    case active       // primary-dim 背景 + Apple Blue 前景（激活态，如 AI 按钮）
}

// MARK: - GlassButtonStyle

/// 主按钮样式：填充背景 + `scaleEffect(0.95)` spring 按下动画
/// ghost 变体对齐 main-window.html .tb-btn：默认透明，hover 显示 white/5% 背景
struct GlassButtonStyle: ButtonStyle {

    let variant: GlassButtonVariant
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)   // 对齐 HTML .tb-btn { padding: 0 10px }
            .padding(.vertical, 5)      // 轻量竖向内边距，保持按钮高度约 28px
            .background(background(for: variant, isPressed: configuration.isPressed, isHovering: isHovering))
            .foregroundColor(foregroundColor(for: variant, isHovering: isHovering))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))  // Figma: rounded-lg = 8pt
            .overlay {
                // .active 变体（如 AI 按钮）加 teal 描边，对齐截图设计
                switch variant {
                case .active:
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.45), lineWidth: 0.75)
                default:
                    Color.clear
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.hover) { isHovering = hovering }
            }
    }

    @ViewBuilder
    private func background(for variant: GlassButtonVariant, isPressed: Bool, isHovering: Bool) -> some View {
        switch variant {
        case .primary:
            DesignTokens.Colors.accentPrimary.opacity(isPressed ? 0.85 : 1.0)
        case .ghost:
            if isPressed {
                DesignTokens.Colors.glassPress
            } else if isHovering {
                DesignTokens.Colors.surfaceHover
            } else {
                Color.clear
            }
        case .toolbarGhost:
            // Figma §03: 工具栏按钮默认 rgba(0,0,0,0.04) 背景
            if isPressed {
                DesignTokens.Colors.glassPress
            } else if isHovering {
                DesignTokens.Colors.glassMedium
            } else {
                DesignTokens.Colors.glassLight
            }
        case .connect:
            // Figma §03: 连接按钮永久 rgba(7,122,255,0.08) 背景
            DesignTokens.Colors.accentPrimary.opacity(isPressed ? 0.14 : (isHovering ? 0.10 : 0.08))
        case .disconnect:
            if isPressed {
                DesignTokens.Colors.statusError.opacity(0.12)
            } else if isHovering {
                DesignTokens.Colors.statusError.opacity(0.07)
            } else {
                DesignTokens.Colors.glassLight
            }
        case .danger:
            DesignTokens.Colors.statusError.opacity(isPressed ? 0.85 : 1.0)
        case .active:
            DesignTokens.Colors.accentPrimary.opacity(isPressed ? 0.20 : (isHovering ? 0.13 : 0.09))
        }
    }

    private func foregroundColor(for variant: GlassButtonVariant, isHovering: Bool) -> Color {
        switch variant {
        case .primary:        return .white
        case .ghost:          return isHovering ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary
        case .toolbarGhost:   return isHovering ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary
        case .danger:         return .white
        case .connect:        return DesignTokens.Colors.accentPrimary
        case .disconnect:     return DesignTokens.Colors.statusError.opacity(0.65)
        case .active:         return DesignTokens.Colors.accentPrimary
        }
    }
}

// MARK: - GhostButtonStyle

/// Ghost 按钮（无背景，文字 + 边框悬停效果）
struct GhostButtonStyle: ButtonStyle {

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .foregroundColor(isHovering ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(
                        isHovering ? DesignTokens.Colors.accentPrimary.opacity(0.5) : DesignTokens.Colors.borderPrimary,
                        lineWidth: 0.75
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.hover) { isHovering = hovering }
            }
    }
}

