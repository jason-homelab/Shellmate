import SwiftUI

/// 终端状态栏视图
/// 显示当前终端的连接状态、尺寸等信息
struct TerminalStatusBarView: View {

    // MARK: - 属性

    /// 连接状态
    let connectionState: ConnectionState

    /// 终端列数
    var columns: Int = 80

    /// 终端行数
    var rows: Int = 24

    /// 编码
    var encoding: String = "UTF-8"

    /// 连接开始时间（用于显示已连接时长）
    var connectedAt: Date? = nil

    /// 是否显示详细信息
    @State private var showingDetails: Bool = false
    /// W12.6：观察同步输入状态
    @ObservedObject private var syncStore = SyncInputStore.shared

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 左侧：连接状态
            connectionStatusView

            // W12.6：同步输入状态
            syncStatusView

            Spacer()

            // 右侧：终端信息
            HStack(spacing: DesignTokens.Spacing.lg) {
                // 已连接时长（仅连接时显示）
                if let connectedAt = connectedAt, connectionState == .connected {
                    TimelineView(.periodic(from: connectedAt, by: 1)) { _ in
                        Text(connectionDuration(from: connectedAt))
                            .font(DesignTokens.Typography.codeSmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .help("连接已持续 \(connectionDuration(from: connectedAt))")
                    }

                    statusDivider
                }

                // 编码
                encodingView

                // 分隔线
                statusDivider

                // 终端尺寸
                terminalSizeView
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 24)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay { Rectangle().fill(DesignTokens.Colors.glassUltraLight) }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.Colors.glassBorderSide)
                .frame(height: 0.5)
        }
    }

    // MARK: - 时长计算

    private func connectionDuration(from date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// W12.6：同步输入状态段（syncCount > 0 时显示）
    @ViewBuilder
    private var syncStatusView: some View {
        if syncStore.isActive {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                Text("同步 (\(syncStore.syncCount))")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - 子视图

    /// 连接状态视图
    private var connectionStatusView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // 状态点（发光效果）
            GlowingStatusDot(color: connectionState.dotColor, size: 5)

            // 状态文字
            Text(connectionState.displayName)
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .help(connectionState.statusDescription)
    }

    /// 编码视图
    private var encodingView: some View {
        Text(encoding)
            .font(DesignTokens.Typography.labelSmall)
            .foregroundColor(DesignTokens.Colors.textTertiary)
    }

    /// 终端尺寸视图
    private var terminalSizeView: some View {
        Text("\(columns) × \(rows)")
            .font(DesignTokens.Typography.codeSmall)
            .foregroundColor(DesignTokens.Colors.textTertiary)
            .help("终端尺寸：\(columns) 列 × \(rows) 行")
    }

    /// 分隔线
    private var statusDivider: some View {
        Rectangle()
            .fill(DesignTokens.Colors.borderSecondary)
            .frame(width: 1, height: 12)
    }
}

// MARK: - ConnectionState 扩展

extension ConnectionState {
    /// 状态描述
    var statusDescription: String {
        switch self {
        case .offline:
            return "未连接到远程服务器"
        case .connecting:
            return "正在建立 SSH 连接..."
        case .connected:
            return "已成功连接到远程服务器"
        case .error:
            return "连接出错，请检查网络或服务器状态"
        case .disconnecting:
            return "正在断开连接..."
        }
    }
}

// MARK: - 预览

#Preview("状态栏 - 已连接") {
    VStack(spacing: 0) {
        Rectangle()
            .fill(DesignTokens.Colors.surfaceWindow)
            .frame(height: 200)

        TerminalStatusBarView(
            connectionState: .connected,
            columns: 120,
            rows: 30,
            encoding: "UTF-8"
        )
    }
}

#Preview("状态栏 - 连接中") {
    VStack(spacing: 0) {
        Rectangle()
            .fill(DesignTokens.Colors.surfaceWindow)
            .frame(height: 200)

        TerminalStatusBarView(
            connectionState: .connecting,
            columns: 80,
            rows: 24,
            encoding: "UTF-8"
        )
    }
}

#Preview("状态栏 - 所有状态") {
    VStack(spacing: 0) {
        ForEach([ConnectionState.connected, .connecting, .error, .offline], id: \.self) { state in
            TerminalStatusBarView(
                connectionState: state,
                columns: 80,
                rows: 24,
                encoding: "UTF-8"
            )
        }
    }
}
