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

    /// SSH 连接延迟（ms），nil 表示未测量
    var latency: Int? = nil

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
    @EnvironmentObject private var syncStore: SyncInputStore

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
        // Figma 9:24: bg-[rgba(245,245,247,0.95)]
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
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
        // Figma 9:26: gap-1.5 = 6pt, text-[11px] = captionLarge, text-[#86868b]
        HStack(spacing: 6) {
            if connectionState == .connecting {
                GlowingStatusDot(color: connectionState.dotColor, size: 3)
            } else {
                Image(systemName: "wifi.slash")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            Text(connectionState == .connecting ? "连接中…" : "未连接")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // W12.6：同步输入状态
            if syncStore.isActive {
                syncBadge
            }
        }
        // Figma: px-4 = 16pt
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 已连接状态

    private var connectedContent: some View {
        // Figma: gap-4 = 16pt 顶层间距
        HStack(spacing: DesignTokens.Spacing.lg) {
            // ── 左侧：Figma 9:26 — "● Connected · user@host · Xms"，整行 #34d399
            HStack(spacing: 6) {
                statusDotView

                if let session {
                    // Figma: 整段文字统一 text-[11px] text-[#34d399]
                    Group {
                        Text("已连接 · \(session.username)@\(session.host)")
                        + (latency.map { Text(" · \($0)ms") } ?? Text(""))
                    }
                    // Figma 9:26: text-[11px] = captionLarge
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.statusConnected)
                    .lineLimit(1)
                }
            }

            // tmux、同步状态保持独立（不放入芯片）
            if let sessionName = tmuxAttachedSession {
                tmuxBadge(sessionName: sessionName)
                    // 扩大热区：整行高度 × 最小 120px 宽度，方便鼠标点击
                    .contentShape(Rectangle().inset(by: -6))
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
                // 无指标：Figma right = Activity icon + "SSH Port {port}"
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Text("SSH Port \(session?.port ?? 22)")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
        }
        // Figma: px-4 = 16pt
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }

    // MARK: - 芯片容器（仅作内边距包装，无视觉背景）

    @ViewBuilder
    private func metricChip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
    }

    /// 状态点（带 pulse 动画）
    /// Figma: w-2 h-2 rounded-full bg-[#34c759] shadow-sm animate-pulse
    @State private var dotPulse = false
    private var statusDotView: some View {
        Circle()
            .fill(DesignTokens.Colors.statusConnected)
            .shadow(color: DesignTokens.Colors.statusConnected.opacity(0.60), radius: 3, x: 0, y: 0)
            .frame(width: DesignTokens.Sizes.statusDotSize, height: DesignTokens.Sizes.statusDotSize)
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
        // Figma: gap-4 = 16pt 各指标内联
        HStack(spacing: DesignTokens.Spacing.lg) {
            cpuView(m)
            memoryView(m)
            diskView(m)
            networkView(m)
            // Figma: Activity icon h-3 w-3 + "SSH Port {port}" text-xs text-[#86868b]
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Text("SSH:\(session?.port ?? 22)")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }


    // MARK: - CPU（对齐 main-window.html .status-metric）

    private func cpuView(_ m: ServerMetrics) -> some View {
        // Figma: gap-2 内部 + gap-1.5 文字组（外层使用 gap-2，文字组用 gap-1.5）
        HStack(spacing: 8) {
            // Figma: p-1 rounded-md bg-[#007aff]/10，icon h-3 w-3 = 12pt
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary.opacity(0.10))
                Image(systemName: "cpu")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }
            .frame(width: 20, height: 20)

            HStack(spacing: 6) {
                Text("处理器")
                    .font(DesignTokens.Typography.captionSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                // Figma: font-semibold ${cpuColor}（12pt semibold）
                Text(String(format: "%.1f%%", m.cpuUsage))
                    .font(DesignTokens.Typography.bodySmallStrong)
                    .monospacedDigit()
                    .foregroundColor(cpuColor(m.cpuColor))
                // Figma: 8 bars, max height 12px, w-0.5 = 2pt, opacity-60
                HStack(alignment: .bottom, spacing: 1.5) {
                    ForEach(Array(cpuHistory.suffix(8).enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(cpuColor(m.cpuColor).opacity(0.60))
                            .frame(width: 2, height: max(2, CGFloat(value / 100.0) * 12))
                    }
                }
                .frame(height: 12)
                .animation(.easeInOut(duration: 0.3), value: cpuHistory.count)
            }
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
        HStack(spacing: 8) {
            // Figma: p-1 rounded-md bg-[#5856d6]/10，icon h-3 w-3 = 12pt
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                    .fill(Color(hex: "#5856d6").opacity(0.10))
                Image(systemName: "memorychip")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(Color(hex: "#5856d6"))
            }
            .frame(width: 20, height: 20)
            HStack(spacing: 6) {
                Text("内存")
                    .font(DesignTokens.Typography.captionSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                HStack(spacing: 2) {
                    Text(ServerMetrics.formatBytes(m.memoryUsed))
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .monospacedDigit()
                        .foregroundColor(memoryBarColor(m.memoryRatio))
                    Text("/")
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Text(ServerMetrics.formatBytes(m.memoryTotal))
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .monospacedDigit()
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                // Figma: w-12 h-1.5 = 48pt × 6pt
                memoryBar(ratio: m.memoryRatio)
            }
        }
    }

    private func memoryBar(ratio: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Figma: bg-black/5 rounded-full overflow-hidden
                Capsule()
                    .fill(DesignTokens.Colors.surfaceHover)
                Capsule()
                    .fill(memoryBarColor(ratio))
                    .frame(width: geo.size.width * CGFloat(min(ratio, 1)))
            }
        }
        // Figma: w-12 h-1.5 = 48pt × 6pt
        .frame(width: 48, height: 6)
    }

    private func memoryBarColor(_ ratio: Double) -> Color {
        if ratio < 0.7 { return DesignTokens.Colors.statusConnected }
        if ratio < 0.9 { return DesignTokens.Colors.statusConnecting }
        return DesignTokens.Colors.statusError
    }

    // MARK: - 磁盘（对齐 main-window.html .status-metric）

    private func diskView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 8) {
            // Figma: p-1 rounded-md bg-[#ff9500]/10，icon h-3 w-3 = 12pt
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                    .fill(Color(hex: "#ff9500").opacity(0.10))
                Image(systemName: "internaldrive")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(Color(hex: "#ff9500"))
            }
            .frame(width: 20, height: 20)
            HStack(spacing: 6) {
                Text("磁盘")
                    .font(DesignTokens.Typography.captionSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                HStack(spacing: 2) {
                    Text(ServerMetrics.formatBytes(m.diskUsed))
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .monospacedDigit()
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text("/")
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Text(ServerMetrics.formatBytes(m.diskTotal))
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .monospacedDigit()
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - 网络（对齐 main-window.html .status-metric）

    private func networkView(_ m: ServerMetrics) -> some View {
        HStack(spacing: 8) {
            // Figma: p-1 rounded-md bg-[#34c759]/10，icon h-3 w-3 = 12pt
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                    .fill(DesignTokens.Colors.statusConnected.opacity(0.10))
                Image(systemName: "network")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.statusConnected)
            }
            .frame(width: 20, height: 20)
            // Figma: gap-2 between rx/tx groups, gap-1 inside each
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("↓")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Text(ServerMetrics.formatRate(m.networkRxRate))
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .monospacedDigit()
                        .foregroundColor(DesignTokens.Colors.statusConnected)
                }
                HStack(spacing: 4) {
                    Text("↑")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Text(ServerMetrics.formatRate(m.networkTxRate))
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .monospacedDigit()
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                }
            }
        }
    }

    // MARK: - 共用组件


    private var syncBadge: some View {
        HStack(spacing: DesignTokens.Spacing.nano) {
            Image(systemName: "bolt.fill")
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.statusConnecting)
            Text("同步(\(syncStore.syncCount))")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.statusConnecting)
        }
    }

    /// 已附加 tmux 会话时的绿色徽章
    private func tmuxBadge(sessionName: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.nano) {
            Image(systemName: "rectangle.3.group.fill")
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.statusConnected)
            Text("tmux:\(sessionName)")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.statusConnected)
                .lineLimit(1)
        }
    }

    /// 有 tmux 会话但未附加时的灰色徽章
    private func tmuxIdleBadge(count: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.nano) {
            Image(systemName: "rectangle.3.group")
                .font(DesignTokens.Typography.captionSmall)
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
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "macwindow")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                Text("切换 tmux 窗口")
                    .font(DesignTokens.Typography.bodySmallStrong)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.top, 10)
            .padding(.bottom, DesignTokens.Spacing.sm)

            Divider()

            // 窗口列表
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DesignTokens.Spacing.xxxs) {
                    ForEach(tmuxWindows, id: \.index) { window in
                        Button {
                            onSelectTmuxWindow?(window.index)
                            showWindowPopover = false
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                // 窗口序号徽章
                                Text("\(window.index)")
                                    .font(DesignTokens.Typography.codeTiny)
                                    .foregroundColor(window.isActive
                                        ? DesignTokens.Colors.accentPrimary
                                        : DesignTokens.Colors.textTertiary)
                                    .frame(width: 20, height: 20)
                                    .background(window.isActive
                                        ? DesignTokens.Colors.accentPrimary.opacity(0.12)
                                        : DesignTokens.Colors.surfaceHover)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXXSmall, style: .continuous))

                                Text(window.name)
                                    .font(DesignTokens.Typography.codeSmall)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                if window.isActive {
                                    Image(systemName: "checkmark")
                                        .font(DesignTokens.Typography.captionSmall)
                                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(window.isActive
                                ? DesignTokens.Colors.accentPrimary.opacity(0.06)
                                : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xs)
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
