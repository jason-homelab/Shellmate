import SwiftUI

// MARK: - 服务器性能监控详情面板（对标 FinalShell，Figma-Spec-v2 §05）

/// 弹出式监控详情面板
/// 显示 CPU / 内存 / 磁盘 / 网络的历史趋势图 + 实时数值
struct ServerMonitorPanelView: View {

    // MARK: - 属性

    let session: Session?
    @Binding var metrics: ServerMetrics?
    var onClose: () -> Void

    // MARK: - 历史数据（最多保留 60 个采样点，每 2 秒一次 = 最近 2 分钟）

    @State private var cpuHistory:   [Double] = []
    @State private var memHistory:   [Double] = []
    @State private var netRxHistory: [Double] = []
    @State private var netTxHistory: [Double] = []

    private let maxHistory = 60

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    metricsGrid
                    networkCard
                }
                .padding(16)
            }
        }
        .frame(width: 420)
        .frame(minHeight: 360, maxHeight: 520)
        .background(Color.white.opacity(0.95))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 6)
        .onChange(of: metrics) { newMetrics in
            appendHistory(newMetrics)
        }
        .onAppear {
            // 初始化历史
            if let m = metrics { appendHistory(m) }
        }
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#007aff"), Color(hex: "#5856d6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("服务器监控")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(session.map { "\($0.username)@\($0.host)" } ?? "未连接")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // 更新时间
            if let m = metrics {
                Text(m.updatedAt, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - 指标网格（2×2）

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard(
                title: "CPU 使用率",
                icon: "cpu",
                iconColor: cpuColor,
                value: metrics.map { String(format: "%.1f%%", $0.cpuUsage) } ?? "—",
                ratio: metrics.map { $0.cpuUsage / 100.0 } ?? 0,
                history: cpuHistory,
                historyColor: cpuColor
            )

            metricCard(
                title: "内存使用率",
                icon: "memorychip",
                iconColor: Color(hex: "#5856d6"),
                value: metrics.map { "\(ServerMetrics.formatBytes($0.memoryUsed)) / \(ServerMetrics.formatBytes($0.memoryTotal))" } ?? "—",
                ratio: metrics?.memoryRatio ?? 0,
                history: memHistory,
                historyColor: Color(hex: "#5856d6")
            )

            diskCard
            uptimeCard
        }
    }

    private func metricCard(
        title: String,
        icon: String,
        iconColor: Color,
        value: String,
        ratio: Double,
        history: [Double],
        historyColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
            }

            // 当前数值
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(iconColor)
                        .frame(width: geo.size.width * min(max(ratio, 0), 1), height: 5)
                }
            }
            .frame(height: 5)

            // 迷你趋势图
            if !history.isEmpty {
                SparklineView(values: history, color: historyColor)
                    .frame(height: 24)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.40), lineWidth: 0.5)
        )
    }

    private var diskCard: some View {
        let used = metrics?.diskUsed ?? 0
        let total = metrics?.diskTotal ?? 1
        let ratio = total > 0 ? Double(used) / Double(total) : 0
        let diskColor: Color = ratio > 0.85 ? Color(hex: "#ff3b30") : Color(hex: "#ff9500")

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 11))
                    .foregroundColor(diskColor)
                Text("磁盘 (/)")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Text(String(format: "%.0f%%", ratio * 100))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(diskColor)
            }

            Text(metrics.map { "\(ServerMetrics.formatBytes($0.diskUsed)) / \(ServerMetrics.formatBytes($0.diskTotal))" } ?? "—")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(diskColor)
                        .frame(width: geo.size.width * min(max(ratio, 0), 1), height: 5)
                }
            }
            .frame(height: 5)

            Text("剩余 " + (metrics.map { ServerMetrics.formatBytes($0.diskTotal - $0.diskUsed) } ?? "—"))
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .padding(12)
        .background(Color.white.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.40), lineWidth: 0.5)
        )
    }

    private var uptimeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#34c759"))
                Text("采样统计")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
            }

            Text("\(cpuHistory.count) 个采样点")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text("CPU 峰值：\(cpuHistory.max().map { String(format: "%.1f%%", $0) } ?? "—")")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Text("CPU 均值：\(cpuAverage.map { String(format: "%.1f%%", $0) } ?? "—")")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .padding(12)
        .background(Color.white.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.40), lineWidth: 0.5)
        )
    }

    // MARK: - 网络卡片（全宽）

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "network")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.accentIndigo)
                Text("网络 I/O")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#34c759"))
                        Text("下载")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    Text(metrics.map { ServerMetrics.formatRate($0.networkRxRate) } ?? "—")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#ff9500"))
                        Text("上传")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    Text(metrics.map { ServerMetrics.formatRate($0.networkTxRate) } ?? "—")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }

                Spacer()
            }

            // 网络趋势图（下载/上传叠加）
            if !netRxHistory.isEmpty {
                ZStack {
                    SparklineView(values: netRxHistory, color: Color(hex: "#34c759"))
                    SparklineView(values: netTxHistory, color: Color(hex: "#ff9500").opacity(0.7))
                }
                .frame(height: 36)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.40), lineWidth: 0.5)
        )
    }

    // MARK: - 辅助

    private var cpuColor: Color {
        guard let m = metrics else { return Color(hex: "#34c759") }
        switch m.cpuColor {
        case .low:    return Color(hex: "#34c759")
        case .medium: return Color(hex: "#ff9500")
        case .high:   return Color(hex: "#ff3b30")
        }
    }

    private var cpuAverage: Double? {
        guard !cpuHistory.isEmpty else { return nil }
        return cpuHistory.reduce(0, +) / Double(cpuHistory.count)
    }

    private func appendHistory(_ metrics: ServerMetrics?) {
        guard let m = metrics else { return }
        cpuHistory.append(m.cpuUsage)
        memHistory.append(m.memoryRatio * 100)
        netRxHistory.append(m.networkRxRate)
        netTxHistory.append(m.networkTxRate)
        if cpuHistory.count   > maxHistory { cpuHistory.removeFirst() }
        if memHistory.count   > maxHistory { memHistory.removeFirst() }
        if netRxHistory.count > maxHistory { netRxHistory.removeFirst() }
        if netTxHistory.count > maxHistory { netTxHistory.removeFirst() }
    }
}

// MARK: - 迷你趋势图（Sparkline）

struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2 {
                let maxVal = values.max() ?? 1
                let minVal = values.min() ?? 0
                let range = max(maxVal - minVal, 1)
                let w = geo.size.width
                let h = geo.size.height
                let step = w / Double(values.count - 1)

                Path { path in
                    let points = values.enumerated().map { (i, v) in
                        CGPoint(
                            x: Double(i) * step,
                            y: h - (v - minVal) / range * h
                        )
                    }
                    path.move(to: points[0])
                    for i in 1..<points.count {
                        let prev = points[i - 1]
                        let curr = points[i]
                        let cp1 = CGPoint(x: prev.x + step * 0.4, y: prev.y)
                        let cp2 = CGPoint(x: curr.x - step * 0.4, y: curr.y)
                        path.addCurve(to: curr, control1: cp1, control2: cp2)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                // 填充渐变
                Path { path in
                    let points = values.enumerated().map { (i, v) in
                        CGPoint(
                            x: Double(i) * step,
                            y: h - (v - minVal) / range * h
                        )
                    }
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: points[0])
                    for i in 1..<points.count {
                        let prev = points[i - 1]
                        let curr = points[i]
                        let cp1 = CGPoint(x: prev.x + step * 0.4, y: prev.y)
                        let cp2 = CGPoint(x: curr.x - step * 0.4, y: curr.y)
                        path.addCurve(to: curr, control1: cp1, control2: cp2)
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [color.opacity(0.20), color.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }
        }
    }
}

// MARK: - 预览

#Preview("服务器监控面板") {
    ServerMonitorPanelView(
        session: nil,
        metrics: .constant(ServerMetrics(
            cpuUsage: 34.2,
            memoryUsed: 2_147_483_648,
            memoryTotal: 8_589_934_592,
            diskUsed: 50_000_000_000,
            diskTotal: 200_000_000_000,
            networkRxRate: 1_200_000,
            networkTxRate: 450_000,
            updatedAt: Date()
        )),
        onClose: {}
    )
    .padding()
}
