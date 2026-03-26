import SwiftUI

/// 终端底部信息栏
/// - 未连接：仅显示灰点 + "Not Connected"
/// - 已连接：显示主机名、CPU/内存/磁盘/网络实时指标
struct TerminalStatusBarView: View {

    // MARK: - 属性

    let connectionState: ConnectionState
    var session: Session? = nil
    var serverMetrics: ServerMetrics? = nil

    /// 终端列数（连接时在右侧附加显示）
    var columns: Int = 80
    var rows: Int = 24
    var encoding: String = "UTF-8"
    var connectedAt: Date? = nil

    /// W12.6：观察同步输入状态
    @ObservedObject private var syncStore = SyncInputStore.shared

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 0) {
            if connectionState == .connected {
                connectedContent
            } else {
                disconnectedContent
            }
        }
        .frame(height: 28)
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

    // MARK: - 未连接状态

    private var disconnectedContent: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            GlowingStatusDot(color: connectionState.dotColor, size: 5)
            Text(connectionState == .connecting ? "Connecting..." : "Not Connected")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            // W12.6：同步输入状态
            if syncStore.isActive {
                syncBadge
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 已连接状态

    private var connectedContent: some View {
        HStack(spacing: 0) {
            // 左侧：状态点 + 主机信息
            HStack(spacing: DesignTokens.Spacing.xs) {
                GlowingStatusDot(color: connectionState.dotColor, size: 5)

                if let session {
                    Text(session.name)
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Text("\(session.username)@\(session.host)")
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                }

                // W12.6：同步输入状态
                if syncStore.isActive {
                    syncBadge
                }
            }
            .padding(.leading, DesignTokens.Spacing.md)

            Spacer(minLength: DesignTokens.Spacing.sm)

            // 右侧：指标
            if let metrics = serverMetrics {
                metricsView(metrics)
                    .padding(.trailing, DesignTokens.Spacing.md)
            } else {
                // 等待首次采集
                HStack(spacing: DesignTokens.Spacing.xs) {
                    // 编码 + 终端尺寸（后备显示）
                    Text(encoding)
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    divider
                    Text("\(columns) × \(rows)")
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .padding(.trailing, DesignTokens.Spacing.md)
            }
        }
    }

    // MARK: - 指标视图

    @ViewBuilder
    private func metricsView(_ m: ServerMetrics) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // CPU
            cpuView(m)
            divider

            // 内存
            memoryView(m)
            divider

            // 磁盘
            diskView(m)
            divider

            // 网络
            networkView(m)
            divider

            // 终端尺寸
            Text("\(columns)×\(rows)")
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    // MARK: - CPU

    private func cpuView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 3) {
            Text("CPU")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text(String(format: "%.1f%%", m.cpuUsage))
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(cpuColor(m.cpuColor))
                .monospacedDigit()
        }
    }

    private func cpuColor(_ load: ServerMetrics.CPULoad) -> Color {
        switch load {
        case .low: return DesignTokens.Colors.statusConnected
        case .medium: return .orange
        case .high: return DesignTokens.Colors.statusError
        }
    }

    // MARK: - 内存

    private func memoryView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 3) {
            Text("MEM")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            HStack(spacing: 2) {
                Text(ServerMetrics.formatBytes(m.memoryUsed))
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .monospacedDigit()
                Text("/")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Text(ServerMetrics.formatBytes(m.memoryTotal))
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .monospacedDigit()
            }
            // 内存使用率迷你条
            memoryBar(ratio: m.memoryRatio)
        }
    }

    private func memoryBar(ratio: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DesignTokens.Colors.borderSecondary)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(memoryBarColor(ratio))
                    .frame(width: geo.size.width * CGFloat(min(ratio, 1)))
            }
        }
        .frame(width: 32, height: 4)
    }

    private func memoryBarColor(_ ratio: Double) -> Color {
        if ratio < 0.7 { return DesignTokens.Colors.statusConnected }
        if ratio < 0.9 { return .orange }
        return DesignTokens.Colors.statusError
    }

    // MARK: - 磁盘

    private func diskView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 3) {
            Text("DISK")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            HStack(spacing: 2) {
                Text(ServerMetrics.formatBytes(m.diskUsed))
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .monospacedDigit()
                Text("/")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Text(ServerMetrics.formatBytes(m.diskTotal))
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 网络

    private func networkView(_ m: ServerMetrics) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: 2) {
                Text("↓")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.statusConnected)
                Text(ServerMetrics.formatRate(m.networkRxRate))
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .monospacedDigit()
            }
            HStack(spacing: 2) {
                Text("↑")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(.orange)
                Text(ServerMetrics.formatRate(m.networkTxRate))
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 共用组件

    private var divider: some View {
        Rectangle()
            .fill(DesignTokens.Colors.borderSecondary)
            .frame(width: 1, height: 10)
    }

    private var syncBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9))
                .foregroundColor(.orange)
            Text("同步(\(syncStore.syncCount))")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(.orange)
        }
    }
}

// MARK: - ConnectionState 扩展

extension ConnectionState {
    /// 状态描述
    var statusDescription: String {
        switch self {
        case .offline:      return "未连接到远程服务器"
        case .connecting:   return "正在建立 SSH 连接..."
        case .connected:    return "已成功连接到远程服务器"
        case .error:        return "连接出错，请检查网络或服务器状态"
        case .disconnecting: return "正在断开连接..."
        }
    }
}

// MARK: - 预览

#Preview("状态栏 - 未连接") {
    VStack(spacing: 0) {
        Rectangle()
            .fill(DesignTokens.Colors.surfaceWindow)
            .frame(height: 200)
        TerminalStatusBarView(connectionState: .offline)
    }
}

#Preview("状态栏 - 连接中") {
    VStack(spacing: 0) {
        Rectangle()
            .fill(DesignTokens.Colors.surfaceWindow)
            .frame(height: 200)
        TerminalStatusBarView(connectionState: .connecting)
    }
}

#Preview("状态栏 - 已连接，无指标") {
    VStack(spacing: 0) {
        Rectangle()
            .fill(DesignTokens.Colors.surfaceWindow)
            .frame(height: 200)
        TerminalStatusBarView(
            connectionState: .connected,
            session: Session.preview,
            columns: 120,
            rows: 30,
            encoding: "UTF-8"
        )
    }
}

#Preview("状态栏 - 已连接，有指标") {
    let metrics = ServerMetrics(
        cpuUsage: 34.5,
        memoryUsed: 3_758_096_384,
        memoryTotal: 8_589_934_592,
        diskUsed: 120_000_000_000,
        diskTotal: 512_000_000_000,
        networkRxRate: 2_097_152,
        networkTxRate: 524_288,
        updatedAt: Date()
    )
    VStack(spacing: 0) {
        Rectangle()
            .fill(DesignTokens.Colors.surfaceWindow)
            .frame(height: 200)
        TerminalStatusBarView(
            connectionState: .connected,
            session: Session.preview,
            serverMetrics: metrics,
            columns: 120,
            rows: 30,
            encoding: "UTF-8"
        )
    }
}
