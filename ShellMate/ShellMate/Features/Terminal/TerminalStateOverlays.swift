import SwiftUI

// Phase 14：从 TerminalView.swift 抽出状态 overlay 5 个子视图
// 原文件 stateOverlay/disconnectedOverlay/connectingOverlay/reconnectingOverlay/failedOverlay
// 占用约 100 行，全部纯 UI 渲染，零业务逻辑改动
// 业务回调通过 closure 参数传入，保持解耦

struct TerminalStateOverlay: View {

    let state: TerminalController.State
    let session: Session
    let maxReconnectAttempts: Int
    let onConnect: () -> Void
    let onCancelReconnect: () -> Void
    let onDismissFailure: () -> Void

    var body: some View {
        switch state {
        case .disconnected:     disconnectedOverlay
        case .connecting:       connectingOverlay
        case .reconnecting(let attempt): reconnectingOverlay(attempt: attempt)
        case .failed(let reason): failedOverlay(reason: reason)
        case .connected:        EmptyView()
        }
    }

    private var disconnectedOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            AppIcon.terminal.image
                .font(DesignTokens.Typography.heroLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text("未连接")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("\(session.username)@\(session.host):\(session.port)")
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Button(action: onConnect) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    AppIcon.quickCommand.image
                    Text("连接")
                }
                .font(DesignTokens.Typography.labelLarge)
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xxl)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.95))
    }

    private var connectingOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView().controlSize(.large)
            Text("正在连接...")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Text("\(session.username)@\(session.host)")
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.9))
    }

    private func reconnectingOverlay(attempt: Int) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView().controlSize(.large)
            Text("正在重连...")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Text("第 \(attempt) 次尝试，共 \(maxReconnectAttempts) 次")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Button("取消", action: onCancelReconnect)
                .buttonStyle(.bordered)
                .padding(.top, DesignTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.9))
    }

    private func failedOverlay(reason: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            AppIcon.feedbackWarn.image
                .font(DesignTokens.Typography.heroLarge)
                .foregroundColor(DesignTokens.Colors.statusError)

            Text("连接失败")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text(reason)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xxxl)

            HStack(spacing: DesignTokens.Spacing.md) {
                Button("重试", action: onConnect).buttonStyle(.borderedProminent)
                Button("关闭", action: onDismissFailure).buttonStyle(.bordered)
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.95))
    }
}
