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
        /// 透明蓝底 + 蓝字（Figma 连接按钮 rgba(7,122,255,0.08)/#077AFF）
        case tinted
        /// 透明红底 + 红字（析构操作：断开连接）
        case destructive
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

    // Figma: 文字/混合按钮 6pt，图标按钮 8pt
    private var cornerRadius: CGFloat {
        variant == .iconOnly
            ? DesignTokens.Sizes.cornerRadiusSmall   // 8pt — 右侧图标按钮
            : DesignTokens.Sizes.cornerRadiusXSmall  // 6pt — 左侧文字/混合按钮
    }

    var body: some View {
        configuration.label
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(foregroundColor)
            .modifier(SizeModifier(variant: variant))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundColor)
                // Figma: shadow-sm shadow-[#077aff]/30（仅 primary 有蓝色投影）
                .shadow(
                    color: tone == .primary
                        ? DesignTokens.Colors.accentPrimary.opacity(0.30)
                        : Color.clear,
                    radius: 2, x: 0, y: 1
                )
            )
            // Tab 键焦点环（HIG：accent 色 1.5pt 边框，2pt 偏移）
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.accentPrimary, lineWidth: 1.5)
                    .padding(-2)
                }
            }
            // Figma: disabled:opacity-40（实心蓝/透明蓝按钮 disabled 降至 40%）
            .opacity(!isEnabled && (tone == .primary || tone == .tinted || tone == .destructive) ? 0.40 : 1.0)
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
        switch tone {
        case .primary:
            // Figma: text-white（实心蓝按钮白字，disabled 统一用 opacity 处理）
            return .white
        case .tinted:
            return DesignTokens.Colors.accentPrimary
        case .destructive:
            return DesignTokens.Colors.statusError
        case .normal:
            // Figma: text-[#6E6E73]（工具栏按钮次要灰色 textSecondary）
            return DesignTokens.Colors.textSecondary
        case .ghost:
            return DesignTokens.Colors.textPrimary
        }
    }

    // MARK: - 背景色

    private var backgroundColor: Color {
        let isPressed = configuration.isPressed
        switch tone {
        case .primary:
            // Figma: bg-[#077aff] hover:bg-[#0051d5]，disabled:opacity-40（由 opacity 统一处理）
            if isPressed  { return DesignTokens.Colors.accentTertiary }  // #0051d5
            if isHovering { return DesignTokens.Colors.accentTertiary }  // #0051d5
            return DesignTokens.Colors.accentPrimary                     // #077aff
        case .tinted:
            if isPressed  { return DesignTokens.Colors.accentPrimary.opacity(0.15) }
            if isHovering { return DesignTokens.Colors.accentPrimary.opacity(0.12) }
            return DesignTokens.Colors.accentPrimary.opacity(0.08)
        case .destructive:
            if isPressed  { return DesignTokens.Colors.statusError.opacity(0.15) }
            if isHovering { return DesignTokens.Colors.statusError.opacity(0.12) }
            return DesignTokens.Colors.statusError.opacity(0.08)
        case .normal:
            // Figma 7:6–7:21：bg = rgba(0,0,0,0.04)，hover/press 叠加
            if isPressed  { return Color.black.opacity(0.08) }
            if isHovering { return Color.black.opacity(0.06) }
            return Color.black.opacity(0.04)
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
                .padding(.horizontal, DesignTokens.Spacing.sm)  // Figma 7:4–7:21: px-8
                .frame(height: 26)  // Figma 7:4: h-[26px]（所有工具栏文字按钮统一高度）
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
