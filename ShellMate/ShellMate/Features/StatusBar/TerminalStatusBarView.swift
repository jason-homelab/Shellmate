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

    /// tmux 状态：附加的会话名（nil 表示未附加）
    var tmuxAttachedSession: String? = nil
    /// tmux 状态：已知会话总数（0 表示无会话或 tmux 不可用）
    var tmuxSessionCount: Int = 0
    /// 23.5：当前会话的窗口列表（供 Popover 快切）
    var tmuxWindows: [TmuxWindow] = []
    /// 23.5：切换 tmux 窗口回调
    var onSelectTmuxWindow: ((Int) -> Void)? = nil

    /// 点击指标区域的回调（打开服务器监控面板）
    var onMetricsTap: (() -> Void)? = nil

    /// W12.6：观察同步输入状态
    @ObservedObject private var syncStore = SyncInputStore.shared

    /// CPU 历史读数（最近 8 次，用于 sparkline 柱状图）
    @State private var cpuHistory: [Double] = []
    /// 23.5：窗口快切 Popover 是否显示
    @State private var showWindowPopover: Bool = false

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 0) {
            if connectionState == .connected {
                connectedContent
            } else {
                disconnectedContent
            }
        }
        .frame(height: DesignTokens.Sizes.statusBarHeight)
        // Figma: bg-[#f5f5f7]/90 backdrop-blur-2xl
        .background(.ultraThinMaterial)
        .background(Color(hex: "#f5f5f7").opacity(0.90))
        // Figma: border-t border-[#d2d2d7]/50
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "#d2d2d7").opacity(0.50))
                .frame(height: 0.5)
        }
        // CPU 历史记录：每次 metrics 更新时追加，保留最近 8 条
        .onChange(of: serverMetrics?.cpuUsage) { newValue in
            guard let v = newValue else { return }
            cpuHistory.append(v)
            if cpuHistory.count > 8 { cpuHistory.removeFirst() }
        }
    }

    // MARK: - 未连接状态

    private var disconnectedContent: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            GlowingStatusDot(color: connectionState.dotColor, size: 2)
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
                GlowingStatusDot(color: connectionState.dotColor, size: 2)

                if let session {
                    Text(session.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#1d1d1f"))
                        .lineLimit(1)
                    // Figma: 分隔点 •
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#86868b"))
                    Text("\(session.username)@\(session.host)")
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(Color(hex: "#86868b"))
                        .lineLimit(1)
                }

                // 连接时长（本地化格式）
                if let connectedAt {
                    Text(connectionDuration(from: connectedAt))
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .monospacedDigit()
                }

                // tmux 状态指示器（23.5：点击展开窗口快切 Popover）
                if let sessionName = tmuxAttachedSession {
                    tmuxBadge(sessionName: sessionName)
                        .onTapGesture {
                            if !tmuxWindows.isEmpty { showWindowPopover.toggle() }
                        }
                        .popover(isPresented: $showWindowPopover, arrowEdge: .top) {
                            tmuxWindowPopover
                        }
                        .help(tmuxWindows.isEmpty ? "已附加 tmux 会话" : "点击切换 tmux 窗口")
                } else if tmuxSessionCount > 0 {
                    tmuxIdleBadge(count: tmuxSessionCount)
                }

                // W12.6：同步输入状态
                if syncStore.isActive {
                    syncBadge
                }
            }
            .padding(.leading, DesignTokens.Spacing.md)

            Spacer(minLength: DesignTokens.Spacing.sm)

            // 右侧：指标（可点击打开监控面板）
            if let metrics = serverMetrics {
                Group {
                    if let tap = onMetricsTap {
                        Button(action: tap) {
                            metricsView(metrics)
                        }
                        .buttonStyle(.plain)
                        .help("点击查看服务器监控详情")
                    } else {
                        metricsView(metrics)
                    }
                }
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

            // Figma §9: Activity icon + "SSH Port {port}"
            HStack(spacing: 4) {
                Image(systemName: "network")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "#86868b"))
                Text("SSH Port \(session?.port ?? 22)")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(Color(hex: "#86868b"))
            }
        }
    }

    // MARK: - CPU

    private func cpuView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 4) {
            // 彩色图标徽章（Figma: p-1 rounded-md bg-[#007aff]/10）
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: "#007aff").opacity(0.10))
                    .frame(width: 16, height: 16)
                Image(systemName: "cpu")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color(hex: "#007aff"))
            }
            Text("CPU")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(Color(hex: "#86868b"))
            Text(String(format: "%.1f%%", m.cpuUsage))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(cpuColor(m.cpuColor))
                .monospacedDigit()
        }
    }

    private func cpuColor(_ load: ServerMetrics.CPULoad) -> Color {
        switch load {
        case .low: return DesignTokens.Colors.statusConnected
        case .medium: return DesignTokens.Colors.statusConnecting
        case .high: return DesignTokens.Colors.statusError
        }
    }

    // MARK: - 内存

    private func memoryView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 4) {
            // Figma: p-1 rounded-md bg-[#5856d6]/10
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: "#5856d6").opacity(0.10))
                    .frame(width: 16, height: 16)
                Image(systemName: "memorychip")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color(hex: "#5856d6"))
            }
            Text("Memory")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(Color(hex: "#86868b"))
            HStack(spacing: 2) {
                Text(ServerMetrics.formatBytes(m.memoryUsed))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(memoryBarColor(m.memoryRatio))
                    .monospacedDigit()
                Text("/")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(Color(hex: "#86868b"))
                Text(ServerMetrics.formatBytes(m.memoryTotal))
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(Color(hex: "#86868b"))
                    .monospacedDigit()
            }
            // Figma: w-12 h-1.5 bg-black/5 rounded-full
            memoryBar(ratio: m.memoryRatio)
        }
    }

    private func memoryBar(ratio: Double) -> some View {
        // Figma: w-12 h-1.5 bg-black/5 rounded-full
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.05))
                RoundedRectangle(cornerRadius: 3)
                    .fill(memoryBarColor(ratio))
                    .frame(width: geo.size.width * CGFloat(min(ratio, 1)))
            }
        }
        .frame(width: 48, height: 6)
    }

    private func memoryBarColor(_ ratio: Double) -> Color {
        if ratio < 0.7 { return DesignTokens.Colors.statusConnected }
        if ratio < 0.9 { return DesignTokens.Colors.statusConnecting }
        return DesignTokens.Colors.statusError
    }

    // MARK: - 磁盘

    private func diskView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 4) {
            // Figma: p-1 rounded-md bg-[#ff9500]/10
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: "#ff9500").opacity(0.10))
                    .frame(width: 16, height: 16)
                Image(systemName: "internaldrive")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color(hex: "#ff9500"))
            }
            Text("Disk")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(Color(hex: "#86868b"))
            HStack(spacing: 2) {
                Text(ServerMetrics.formatBytes(m.diskUsed))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#1d1d1f"))
                    .monospacedDigit()
                Text("/")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(Color(hex: "#86868b"))
                Text(ServerMetrics.formatBytes(m.diskTotal))
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(Color(hex: "#86868b"))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 网络

    private func networkView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 4) {
            // Figma: p-1 rounded-md bg-[#34c759]/10
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: "#34c759").opacity(0.10))
                    .frame(width: 16, height: 16)
                Image(systemName: "wifi")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color(hex: "#34c759"))
            }
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Text("↓")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#34c759"))  // Figma: green
                    Text(ServerMetrics.formatRate(m.networkRxRate))
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(Color(hex: "#34c759"))
                        .monospacedDigit()
                }
                HStack(spacing: 2) {
                    Text("↑")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#007aff"))  // Figma: blue（非橙色）
                    Text(ServerMetrics.formatRate(m.networkTxRate))
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(Color(hex: "#007aff"))
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - 共用组件

    /// 使用 DateComponentsFormatter 本地化输出连接时长
    private func connectionDuration(from date: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.maximumUnitCount = 2
        return formatter.string(from: date, to: Date()) ?? ""
    }

    // Figma: h-4 w-px bg-[#d2d2d7]/50
    private var divider: some View {
        Rectangle()
            .fill(Color(hex: "#d2d2d7").opacity(0.50))
            .frame(width: 1, height: 16)
    }

    private var syncBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.statusConnecting)
            Text("同步(\(syncStore.syncCount))")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.statusConnecting)
        }
    }

    /// 已附加 tmux 会话时的绿色徽章
    private func tmuxBadge(sessionName: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.statusConnected)
            Text("tmux:\(sessionName)")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.statusConnected)
                .lineLimit(1)
        }
    }

    /// 有 tmux 会话但未附加时的灰色徽章
    private func tmuxIdleBadge(count: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("tmux[\(count)]")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
    }

    // MARK: - 23.5 窗口快切 Popover

    /// 点击已附加 tmux 徽章时弹出的窗口列表 Popover
    private var tmuxWindowPopover: some View {
        VStack(spacing: 0) {
            // 标题行
            HStack(spacing: 6) {
                Image(systemName: "macwindow")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                Text("切换 tmux 窗口")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            // 窗口列表
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(tmuxWindows, id: \.index) { window in
                        Button {
                            onSelectTmuxWindow?(window.index)
                            showWindowPopover = false
                        } label: {
                            HStack(spacing: 8) {
                                // 窗口序号徽章
                                Text("\(window.index)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(window.isActive
                                        ? DesignTokens.Colors.accentPrimary
                                        : DesignTokens.Colors.textTertiary)
                                    .frame(width: 20, height: 20)
                                    .background(window.isActive
                                        ? DesignTokens.Colors.accentPrimary.opacity(0.12)
                                        : Color.black.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                                Text(window.name)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                if window.isActive {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(window.isActive
                                ? DesignTokens.Colors.accentPrimary.opacity(0.06)
                                : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 200)
        }
        .frame(width: 200)
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
