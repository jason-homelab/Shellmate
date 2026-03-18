import SwiftUI

/// 终端占位视图
/// 在终端功能实现前显示的占位界面
struct TerminalPlaceholderView: View {

    // MARK: - 属性

    /// 当前选中的会话（可选）
    var session: Session?

    /// 连接回调
    var onConnect: (() -> Void)?

    // MARK: - 视图

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            if let session = session {
                // 显示选中会话的信息
                sessionInfoView(session)
            } else {
                // 显示空状态
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow)
    }

    // MARK: - 会话信息视图

    @ViewBuilder
    private func sessionInfoView(_ session: Session) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.surfaceCard)
                    .frame(width: 80, height: 80)

                Image(systemName: "terminal.fill")
                    .font(.system(size: 32))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }

            // 会话名称
            Text(session.name)
                .font(DesignTokens.Typography.titleLarge)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // 连接信息
            Text("\(session.username)@\(session.host):\(session.port)")
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // 连接状态
            HStack(spacing: DesignTokens.Spacing.sm) {
                StatusDotView(state: session.connectionState)

                Text(session.connectionState.displayName)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(session.connectionState.dotColor)
            }
            .padding(.top, DesignTokens.Spacing.sm)

            // 连接按钮
            if session.connectionState == .offline {
                Button(action: {
                    onConnect?()
                }) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "bolt.fill")
                        Text("连接")
                    }
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.accentPrimary)
                    .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
                }
                .buttonStyle(.plain)
                .padding(.top, DesignTokens.Spacing.lg)
            }

            // 终端功能提示
            VStack(spacing: DesignTokens.Spacing.sm) {
                Divider()
                    .padding(.vertical, DesignTokens.Spacing.xl)

                Text("终端功能开发中")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Text("W4-W5 将实现完整的 SSH 连接和终端仿真")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "terminal")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text("选择一个会话开始")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("从左侧边栏选择一个会话，或双击会话以连接")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignTokens.Spacing.xxxl)
    }
}

// MARK: - 预览

#Preview("终端占位 - 无选中") {
    TerminalPlaceholderView()
        .frame(width: 800, height: 600)
}

#Preview("终端占位 - 有选中") {
    TerminalPlaceholderView(
        session: Session.preview,
        onConnect: { print("连接") }
    )
    .frame(width: 800, height: 600)
}

#Preview("终端占位 - 已连接") {
    var session = Session.preview
    session.connectionState = .connected

    return TerminalPlaceholderView(
        session: session,
        onConnect: { print("连接") }
    )
    .frame(width: 800, height: 600)
}
