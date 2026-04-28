import SwiftUI

// MARK: - 通用胶囊按钮样式
//
// 替代 ToolbarTextButton / ToolbarPillIconButton / HoverIconButton /
// ToolbarIconButtonStyle 等多套重复实现。
//
// 使用方式：
// ```
// // 文字按钮
// Button { ... } label: {
//     Label("AI", systemImage: "sparkle")
// }
// .buttonStyle(PillButtonStyle(tone: .normal))
//
// // 仅图标按钮
// Button { ... } label: {
//     Image(systemName: "magnifyingglass")
// }
// .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
//
// // 蓝色主操作
// Button { ... } label: {
//     Label("连接", systemImage: "power")
// }
// .buttonStyle(PillButtonStyle(tone: .primary))
//
// // 透明（仅 hover 显示背景）
// Button { ... } label: {
//     Image(systemName: "plus")
// }
// .buttonStyle(PillButtonStyle(tone: .ghost, variant: .iconOnly))
// ```

struct PillButtonStyle: ButtonStyle {

    enum Tone {
        /// 灰色默认背景（surfaceHover 持久），hover/press 加深
        case normal
        /// 蓝色主操作（accentPrimary opacity 渐变）
        case primary
        /// 透明默认，仅 hover/press 显示背景
        case ghost
    }

    enum Variant {
        /// 文字（含可选前缀图标），h-7 px-3 自适应宽度
        case text
        /// 仅图标，固定 28×28
        case iconOnly
    }

    let tone: Tone
    var variant: Variant = .text

    func makeBody(configuration: Configuration) -> some View {
        PillButtonContent(tone: tone, variant: variant, configuration: configuration)
    }
}

// MARK: - 实际渲染（独立 View 以承载 @State / @FocusState）

private struct PillButtonContent: View {
    let tone: PillButtonStyle.Tone
    let variant: PillButtonStyle.Variant
    let configuration: PillButtonStyle.Configuration

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    var body: some View {
        configuration.label
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(foregroundColor)
            .modifier(SizeModifier(variant: variant))
            .background(
                RoundedRectangle(
                    cornerRadius: DesignTokens.Sizes.cornerRadiusSmall,
                    style: .continuous
                )
                .fill(backgroundColor)
            )
            // Tab 键焦点环（HIG：accent 色 1.5pt 边框，2pt 偏移）
            .overlay {
                if isFocused {
                    RoundedRectangle(
                        cornerRadius: DesignTokens.Sizes.cornerRadiusSmall + 2,
                        style: .continuous
                    )
                    .strokeBorder(DesignTokens.Colors.accentPrimary, lineWidth: 1.5)
                    .padding(-2)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignTokens.Animation.hover, value: isHovering)
            .animation(DesignTokens.Animation.fast, value: configuration.isPressed)
            .animation(DesignTokens.Animation.fast, value: isFocused)
            .onHover { isHovering = $0 }
            .focused($isFocused)
            .contentShape(Rectangle())
    }

    // MARK: - 前景色

    private var foregroundColor: Color {
        if !isEnabled { return DesignTokens.Colors.textDisabled }
        switch tone {
        case .primary: return DesignTokens.Colors.accentPrimary
        case .normal, .ghost: return DesignTokens.Colors.textSecondary
        }
    }

    // MARK: - 背景色

    private var backgroundColor: Color {
        guard isEnabled else { return Color.clear }
        let isPressed = configuration.isPressed
        switch tone {
        case .primary:
            if isPressed  { return DesignTokens.Colors.accentPrimary.opacity(0.18) }
            if isHovering { return DesignTokens.Colors.accentPrimary.opacity(0.14) }
            return DesignTokens.Colors.accentPrimary.opacity(0.10)
        case .normal:
            if isPressed  { return DesignTokens.Colors.glassPress }
            if isHovering { return DesignTokens.Colors.glassMedium }
            return DesignTokens.Colors.surfaceHover
        case .ghost:
            if isPressed  { return DesignTokens.Colors.glassPress }
            if isHovering { return DesignTokens.Colors.surfaceHover }
            return Color.clear
        }
    }
}

// MARK: - Variant 尺寸修饰器

private struct SizeModifier: ViewModifier {
    let variant: PillButtonStyle.Variant

    func body(content: Content) -> some View {
        switch variant {
        case .iconOnly:
            content
                .frame(
                    width: DesignTokens.Sizes.iconButtonSize,
                    height: DesignTokens.Sizes.iconButtonSize
                )
        case .text:
            content
                .padding(.horizontal, DesignTokens.Spacing.md)
                .frame(height: DesignTokens.Sizes.iconButtonSize)
        }
    }
}

// MARK: - 预览

#Preview("PillButton 全状态") {
    VStack(spacing: DesignTokens.Spacing.md) {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Button { } label: {
                Label("连接", systemImage: "power")
            }
            .buttonStyle(PillButtonStyle(tone: .primary))

            Button("断开") { }
                .buttonStyle(PillButtonStyle(tone: .normal))

            Button { } label: {
                Label("AI", systemImage: "sparkle")
            }
            .buttonStyle(PillButtonStyle(tone: .normal))

            Button("禁用态") { }
                .buttonStyle(PillButtonStyle(tone: .normal))
                .disabled(true)
        }

        HStack(spacing: DesignTokens.Spacing.xxs) {
            Button { } label: { Image(systemName: "shippingbox") }
                .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            Button { } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            Button { } label: { Image(systemName: "gearshape") }
                .buttonStyle(PillButtonStyle(tone: .ghost, variant: .iconOnly))
        }
    }
    .padding()
    .frame(width: 600)
    .background(DesignTokens.Colors.surfaceWindow)
}
