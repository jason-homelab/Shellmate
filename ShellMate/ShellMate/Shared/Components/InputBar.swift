import SwiftUI

// MARK: - InputBar
//
// 统一输入行组件，覆盖以下使用场景：
//   • AI 助手面板底部对话输入区
//   • SFTP 面板路径搜索栏
//
// 组成：[左侧前缀 Icon?] [居中 TextField] [右侧动作按钮]

struct InputBar: View {

    // MARK: - 属性

    /// 占位文字
    let placeholder: String

    /// 绑定文字
    @Binding var text: String

    /// 左侧前缀 SF Symbol（可选）
    var prefixIcon: String? = nil

    /// 右侧动作按钮 SF Symbol
    var actionIcon: String = "arrow.up.circle.fill"

    /// 是否禁用动作按钮
    var isActionDisabled: Bool = false

    /// 动作按钮是否显示为"停止"状态（流式输出时）
    var isStopMode: Bool = false

    /// 边框强调色（nil 时使用默认 borderPrimary）
    var accentBorder: Color? = nil

    /// 提交回调
    var onSubmit: () -> Void = {}

    /// 动作按钮回调
    var onAction: () -> Void = {}

    // MARK: - 视图

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {

            // ── 输入框区 ──────────────────────────────────────────
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let prefixIcon {
                    Image(systemName: prefixIcon)
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.iconSecondary)
                        .padding(.leading, DesignTokens.Spacing.sm)
                }

                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .onSubmit {
                            guard !isActionDisabled else { return }
                            onSubmit()
                        }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(minHeight: 44)
            .background(Color.white.opacity(0.80))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(
                        accentBorder ?? DesignTokens.Colors.borderPrimary,
                        lineWidth: accentBorder != nil ? 1.0 : 0.75
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)

            // ── 动作按钮 ──────────────────────────────────────────
            Button(action: onAction) {
                Image(systemName: isStopMode ? "stop.fill" : actionIcon)
                    .font(DesignTokens.Typography.bodyLargeStrong)
                    .foregroundColor(buttonForeground)
                    .frame(width: 44, height: 44)
                    .background(buttonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isActionDisabled && !isStopMode)
            .help(isStopMode ? "停止" : "发送")
        }
    }

    // MARK: - 私有计算属性

    private var buttonForeground: Color {
        if isStopMode { return DesignTokens.Colors.statusError }
        if isActionDisabled { return DesignTokens.Colors.textDisabled }
        return .white
    }

    private var buttonBackground: Color {
        if isStopMode { return DesignTokens.Colors.statusError.opacity(0.12) }
        if isActionDisabled { return DesignTokens.Colors.surfaceOverlay }
        return accentBorder ?? DesignTokens.Colors.accentPrimary
    }
}

// MARK: - 预览

#Preview("InputBar 变体") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        InputBar(
            placeholder: "Ask me anything about terminal commands...",
            text: .constant(""),
            actionIcon: "arrow.up",
            onAction: {}
        )

        InputBar(
            placeholder: "远程路径",
            text: .constant("/home/ubuntu"),
            prefixIcon: "folder",
            actionIcon: "magnifyingglass",
            onAction: {}
        )

        InputBar(
            placeholder: "用自然语言描述...",
            text: .constant(""),
            actionIcon: "arrow.up",
            accentBorder: DesignTokens.Colors.accentIndigo,
            onAction: {}
        )
    }
    .padding(DesignTokens.Spacing.xxl)
    .background(DesignTokens.Colors.surfacePanel)
}
