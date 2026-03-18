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

    /// 是否显示详细信息
    @State private var showingDetails: Bool = false

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 左侧：连接状态
            connectionStatusView

            Spacer()

            // 右侧：终端信息
            HStack(spacing: DesignTokens.Spacing.lg) {
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
        .background(DesignTokens.Colors.surfacePanel)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - 子视图

    /// 连接状态视图
    private var connectionStatusView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // 状态点
            Circle()
                .fill(connectionState.dotColor)
                .frame(width: 6, height: 6)

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
