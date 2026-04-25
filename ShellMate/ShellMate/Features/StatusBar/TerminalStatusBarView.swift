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
        // Figma: bg-[#f5f5f7]/90
        .background(DesignTokens.Colors.surfacePanel)
        // Void: border-t rgba(255,255,255,0.07)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.Colors.borderPrimary)
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
            if connectionState == .connecting {
                GlowingStatusDot(color: connectionState.dotColor, size: 2)
            } else {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            Text(connectionState == .connecting ? "Connecting..." : "Not connected")
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
        // HTML: .statusbar { font-family:mono; font-size:10px; padding:0 10px; gap:5px }
        HStack(spacing: 5) {
            // ── 左侧：连接信息芯片 ──────────────────────────────
            // HTML: .status-session { background:rgba(52,211,153,0.055); border:1px solid rgba(52,211,153,0.12) }
            HStack(spacing: 5) {
                statusDotView

                if let session {
                    Text(session.name)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    Text("\(session.username)@\(session.host)")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }

                // 连接时长
                if let connectedAt {
                    Text("·")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    Text(connectionDuration(from: connectedAt))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(DesignTokens.Colors.statusConnected.opacity(0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.statusConnected.opacity(0.12), lineWidth: 0.75)
                    }
            )

            // tmux、同步状态保持独立（不放入芯片）
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

            if syncStore.isActive { syncBadge }

            Spacer(minLength: 0)

            // ── 右侧：芯片指标 ──────────────────────────────────
            if let metrics = serverMetrics {
                Group {
                    if let tap = onMetricsTap {
                        Button(action: tap) { metricsView(metrics) }
                            .buttonStyle(.plain)
                            .help("点击查看服务器监控详情")
                    } else {
                        metricsView(metrics)
                    }
                }
            } else {
                // 无指标：终端尺寸 + SSH 端口芯片
                HStack(spacing: 5) {
                    metricChip {
                        Text("\(columns)×\(rows)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    metricChip {
                        Text("SSH:\(session?.port ?? 22)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - 芯片容器

    @ViewBuilder
    private func metricChip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(DesignTokens.Colors.glassUltraLight)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.75)
                    }
            )
    }

    /// 状态点（带 pulse 动画）— main-window.html .status-dot
    @State private var dotPulse = false
    private var statusDotView: some View {
        Circle()
            .fill(DesignTokens.Colors.statusConnected)
            .shadow(color: DesignTokens.Colors.statusConnected.opacity(0.60), radius: 3, x: 0, y: 0)
            .frame(width: 6, height: 6)
            .opacity(dotPulse ? 0.40 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    dotPulse = true
                }
            }
    }

    // MARK: - 指标视图

    @ViewBuilder
    private func metricsView(_ m: ServerMetrics) -> some View {
        // HTML: gap:5px，各指标独立芯片（无分隔线）
        HStack(spacing: 5) {
            metricChip { cpuView(m) }
            metricChip { memoryView(m) }
            metricChip { diskView(m) }
            metricChip { networkView(m) }
            // HTML: .status-port 芯片
            metricChip {
                Text("SSH:\(session?.port ?? 22)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
    }

    private var statusSepV: some View {
        Rectangle()
            .fill(DesignTokens.Colors.borderPrimary)
            .frame(width: 1, height: 12)
    }

    // MARK: - CPU（对齐 main-window.html .status-metric）

    private func cpuView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 4) {
            // HTML: .status-label { color: rgba(226,228,240,0.22) }
            Text("CPU")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            // HTML: .metric-val.warn/.ok { font-weight:600; color:warning/success }
            Text(String(format: "%.1f%%", m.cpuUsage))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(cpuColor(m.cpuColor))
            // HTML: .mini-bars { height:10px; gap:1.5px } .mini-bar { width:3px; opacity:0.65 }
            HStack(spacing: 1.5) {
                ForEach(Array(cpuHistory.suffix(5).enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(cpuColor(m.cpuColor).opacity(0.65))
                        .frame(width: 3, height: max(2, CGFloat(value / 100.0) * 10))
                        .frame(height: 10, alignment: .bottom)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: cpuHistory.count)
        }
    }

    private func cpuColor(_ load: ServerMetrics.CPULoad) -> Color {
        switch load {
        case .low: return DesignTokens.Colors.statusConnected
        case .medium: return DesignTokens.Colors.statusConnecting
        case .high: return DesignTokens.Colors.statusError
        }
    }

    // MARK: - 内存（对齐 main-window.html .status-metric）

    private func memoryView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 4) {
            Text("MEM")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            HStack(spacing: 2) {
                Text(ServerMetrics.formatBytes(m.memoryUsed))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(memoryBarColor(m.memoryRatio))
                Text("/")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Text(ServerMetrics.formatBytes(m.memoryTotal))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            // HTML: .progress-track { width:36px; height:4px; background:rgba(255,255,255,0.08) }
            memoryBar(ratio: m.memoryRatio)
        }
    }

    private func memoryBar(ratio: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.Colors.borderSubtle)
                RoundedRectangle(cornerRadius: 2)
                    .fill(memoryBarColor(ratio))
                    .frame(width: geo.size.width * CGFloat(min(ratio, 1)))
            }
        }
        .frame(width: 36, height: 4)  // HTML: width:36px height:4px
    }

    private func memoryBarColor(_ ratio: Double) -> Color {
        if ratio < 0.7 { return DesignTokens.Colors.statusConnected }
        if ratio < 0.9 { return DesignTokens.Colors.statusConnecting }
        return DesignTokens.Colors.statusError
    }

    // MARK: - 磁盘（对齐 main-window.html .status-metric）

    private func diskView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 4) {
            Text("DISK")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text(ServerMetrics.formatBytes(m.diskUsed))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    // MARK: - 网络（对齐 main-window.html .status-metric）

    private func networkView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 4) {
            // HTML: .net-arrow { color: rgba(226,228,240,0.22) }
            // HTML: .net-down { color: var(--success); font-weight:600 }
            // HTML: .net-up { color: var(--primary); font-weight:600 }
            Text("↓")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text(ServerMetrics.formatRate(m.networkRxRate))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.statusConnected)
            Text("↑")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text(ServerMetrics.formatRate(m.networkTxRate))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.accentPrimary)
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

    // 保留旧 divider 供其他地方调用（已改为 statusSepV，此处保留兼容）
    private var divider: some View { statusSepV }

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
                                        : DesignTokens.Colors.surfaceHover)
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
