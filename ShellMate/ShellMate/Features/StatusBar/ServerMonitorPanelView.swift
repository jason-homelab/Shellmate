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
                VStack(spacing: DesignTokens.Spacing.md) {
                    metricsGrid
                    networkCard
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
        .frame(width: 420)
        .frame(minHeight: 360, maxHeight: 520)
        .background(DesignTokens.Colors.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.50), radius: 20, x: 0, y: 6)
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
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .fill(DesignTokens.Gradients.aiGradient)
                    .frame(width: 32, height: 32)
                AppIcon.chartLine.image
                    .font(DesignTokens.Typography.bodyLargeStrong)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.px) {
                Text("服务器监控")
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(session.map { "\($0.username)@\($0.host)" } ?? "未连接")
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // 更新时间
            if let m = metrics {
                Text(m.updatedAt, style: .time)
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Button(action: onClose) {
                AppIcon.close.image
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, DesignTokens.Spacing.md)
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
                iconColor: DesignTokens.Colors.accentAI,
                value: metrics.map { "\(ServerMetrics.formatBytes($0.memoryUsed)) / \(ServerMetrics.formatBytes($0.memoryTotal))" } ?? "—",
                ratio: metrics?.memoryRatio ?? 0,
                history: memHistory,
                historyColor: DesignTokens.Colors.accentAI
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 标题行
            HStack(spacing: DesignTokens.Spacing.micro) {
                Image(systemName: icon)
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
            }

            // 当前数值
            Text(value)
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMicro, style: .continuous)
                        .fill(DesignTokens.Colors.borderPrimary)
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMicro, style: .continuous)
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
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
    }

    private var diskCard: some View {
        let used = metrics?.diskUsed ?? 0
        let total = metrics?.diskTotal ?? 1
        let ratio = total > 0 ? Double(used) / Double(total) : 0
        let diskColor: Color = ratio > 0.85 ? DesignTokens.Colors.statusError : DesignTokens.Colors.statusConnecting

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.micro) {
                AppIcon.storage.image
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(diskColor)
                Text("磁盘 (/)")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Text(String(format: "%.0f%%", ratio * 100))
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(diskColor)
            }

            Text(metrics.map { "\(ServerMetrics.formatBytes($0.diskUsed)) / \(ServerMetrics.formatBytes($0.diskTotal))" } ?? "—")
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMicro, style: .continuous)
                        .fill(DesignTokens.Colors.borderPrimary)
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMicro, style: .continuous)
                        .fill(diskColor)
                        .frame(width: geo.size.width * min(max(ratio, 0), 1), height: 5)
                }
            }
            .frame(height: 5)

            Text("剩余 " + (metrics.map { ServerMetrics.formatBytes($0.diskTotal - $0.diskUsed) } ?? "—"))
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
    }

    private var uptimeCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.micro) {
                AppIcon.clockArrow.image
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.accentSecondary)
                Text("采样统计")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
            }

            Text("\(cpuHistory.count) 个采样点")
                .font(DesignTokens.Typography.titleSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text("CPU 峰值：\(cpuHistory.max().map { String(format: "%.1f%%", $0) } ?? "—")")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Text("CPU 均值：\(cpuAverage.map { String(format: "%.1f%%", $0) } ?? "—")")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
    }

    // MARK: - 网络卡片（全宽）

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: DesignTokens.Spacing.micro) {
                AppIcon.networkIcon.image
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.accentIndigo)
                Text("网络 I/O")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
            }

            HStack(spacing: DesignTokens.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        AppIcon.arrowDown.image
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.accentSecondary)
                        Text("下载")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    Text(metrics.map { ServerMetrics.formatRate($0.networkRxRate) } ?? "—")
                        .font(DesignTokens.Typography.codeMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        AppIcon.arrowUp.image
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                        Text("上传")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    Text(metrics.map { ServerMetrics.formatRate($0.networkTxRate) } ?? "—")
                        .font(DesignTokens.Typography.codeMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }

                Spacer()
            }

            // 网络趋势图（下载/上传叠加）
            if !netRxHistory.isEmpty {
                ZStack {
                    SparklineView(values: netRxHistory, color: DesignTokens.Colors.accentSecondary)
                    SparklineView(values: netTxHistory, color: DesignTokens.Colors.accentPrimary.opacity(0.7))
                }
                .frame(height: 36)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
    }

    // MARK: - 辅助

    private var cpuColor: Color {
        guard let m = metrics else { return DesignTokens.Colors.accentSecondary }
        switch m.cpuColor {
        case .low:    return DesignTokens.Colors.accentSecondary
        case .medium: return DesignTokens.Colors.statusConnecting
        case .high:   return DesignTokens.Colors.statusError
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
