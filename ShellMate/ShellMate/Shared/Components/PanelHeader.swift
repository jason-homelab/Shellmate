// UI 重构 by Frontend Designer Style
import SwiftUI

// MARK: - PanelHeader
//
// 浮动面板统一顶部栏：左侧图标徽章 + 标题，右侧 hover 关闭按钮。
// 对齐 Void 设计语言 — 图标用 teal 轻量背景，关闭按钮圆角矩形 + 悬停反馈。

struct PanelHeader: View {

    let icon: String
    let title: String
    let onClose: () -> Void

    @State private var isCloseHovering = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {

            // ── 图标徽章 ──
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary.opacity(0.10))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }

            // ── 标题 ──
            Text(title)
                .font(DesignTokens.Typography.titleSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // ── 关闭按钮（hover 反馈）──
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(
                        isCloseHovering
                            ? DesignTokens.Colors.textPrimary
                            : DesignTokens.Colors.textTertiary
                    )
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                            .fill(
                                isCloseHovering
                                    ? DesignTokens.Colors.surfaceHover
                                    : Color.clear
                            )
                    )
            }
            .buttonStyle(.plain)
            .help("关闭")
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.hover) { isCloseHovering = hovering }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background {
            Rectangle()
                .fill(DesignTokens.Colors.glassUltraLight)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignTokens.Colors.borderSubtle)
                        .frame(height: 0.5)
                }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        PanelHeader(icon: "sparkles", title: "AI 助手") {}
        PanelHeader(icon: "arrow.up.arrow.down", title: "文件传输") {}
        PanelHeader(icon: "network", title: "隧道管理器") {}
    }
    .frame(width: 400)
    .background(DesignTokens.Colors.surfacePanel)
}
