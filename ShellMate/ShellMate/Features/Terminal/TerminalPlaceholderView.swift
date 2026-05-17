import SwiftUI

// MARK: - 终端空状态视图

/// 终端区域空状态：无活跃标签页时或四格分屏未指定会话时显示
struct TerminalPlaceholderView: View {

    // MARK: - 属性

    var onNewSession: (() -> Void)?

    // MARK: - 视图

    var body: some View {
        emptyStateView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.surfaceWindow)
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
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
                    .frame(width: 96, height: 96)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.15), lineWidth: 0.75)
                    )
                Image(systemName: "desktopcomputer")
                    .font(DesignTokens.Typography.heroMedium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentIndigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("暂无活跃会话")
                    .font(DesignTokens.Typography.displayXSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("从侧边栏选择一个已有会话，\n或新建一个 SSH 连接开始工作。")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { onNewSession?() }) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.labelSmall)
                    Text("新建会话")
                        .font(DesignTokens.Typography.labelLarge)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
                .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.Spacing.xxs)

            HStack(spacing: DesignTokens.Spacing.xs) {
                keyHint("⌘N")
                Text("新建")
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Text("·")
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                keyHint("⌘F")
                Text("搜索")
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .font(DesignTokens.Typography.captionLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
