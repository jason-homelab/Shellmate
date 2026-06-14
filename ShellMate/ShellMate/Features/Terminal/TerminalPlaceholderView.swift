import SwiftUI

// MARK: - 终端空状态视图

/// 终端区域空状态：无活跃标签页时或四格分屏未指定会话时显示
struct TerminalPlaceholderView: View {

    // MARK: - 属性

    var onNewSession: (() -> Void)?

    // MARK: - 状态

    @State private var appeared = false
    @State private var buttonHovered = false

    // MARK: - 视图

    var body: some View {
        emptyStateView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.surfaceWindow)
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // 图标容器：入场时从下方淡入 + 轻微放大
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.accentPrimary.opacity(0.10),
                                DesignTokens.Colors.accentIndigo.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.15), lineWidth: 0.75)
                    )
                AppIcon.desktop.image
                    .font(DesignTokens.Typography.heroMedium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentIndigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(appeared ? 1.0 : 0.80)
            .opacity(appeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.05), value: appeared)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("暂无活跃会话")
                    .font(DesignTokens.Typography.displayXSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("从侧边栏选择一个已有会话，\n或新建一个 SSH 连接开始工作。")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : 8)
            .animation(.easeOut(duration: 0.35).delay(0.15), value: appeared)

            // 新建按钮：hover 时轻微上浮 + 阴影加深
            Button(action: { onNewSession?() }) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    AppIcon.plus.image
                        .font(DesignTokens.Typography.labelSmall)
                    Text("新建会话")
                        .font(DesignTokens.Typography.labelLarge)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(
                    LinearGradient(
                        colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentIndigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
                .shadow(
                    color: DesignTokens.Colors.accentPrimary.opacity(buttonHovered ? 0.50 : 0.30),
                    radius: buttonHovered ? 14 : 10,
                    x: 0, y: buttonHovered ? 6 : 4
                )
                .offset(y: buttonHovered ? -2 : 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: buttonHovered)
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.Spacing.xxs)
            .onHover { buttonHovered = $0 }
            .opacity(appeared ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.35).delay(0.22), value: appeared)

            HStack(spacing: DesignTokens.Spacing.xs) {
                keyHint("⌘N")
                Text("新建")
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Text("·")
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                keyHint("⌘⌥F")
                Text("搜索")
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .font(DesignTokens.Typography.captionLarge)
            .opacity(appeared ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.35).delay(0.28), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }

    private func keyHint(_ key: String) -> some View {
        Text(key)
            .font(DesignTokens.Typography.codeTiny)
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(DesignTokens.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
            )
    }
}

// MARK: - 预览

#Preview("终端空状态") {
    TerminalPlaceholderView()
        .frame(width: 800, height: 600)
}
