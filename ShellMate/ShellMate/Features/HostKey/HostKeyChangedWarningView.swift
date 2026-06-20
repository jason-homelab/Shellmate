import SwiftUI

/// D03 密钥变更警告弹窗
/// 当检测到主机密钥变更时显示的 P0 级安全警告
/// 这是严重的安全事件，可能表示中间人攻击
struct HostKeyChangedWarningView: View {

    // MARK: - 属性

    /// 主机名
    let host: String

    /// 端口号
    let port: Int32

    /// 旧指纹
    let oldFingerprint: String

    /// 新指纹
    let newFingerprint: HostKeyFingerprint

    /// 继续连接回调（危险操作）
    var onProceed: (() -> Void)?

    /// 取消回调
    var onCancel: (() -> Void)?

    /// 查看详情回调
    var onViewDetails: (() -> Void)?

    // MARK: - 状态

    /// 确认理解风险
    @State private var understandRisk: Bool = false

    /// 确认已验证新密钥
    @State private var verifiedNewKey: Bool = false

    /// 显示详细信息
    @State private var showDetails: Bool = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 警告标题栏
            warningHeader

            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // 严重警告
                    criticalWarningSection

                    // 可能的原因
                    possibleCausesSection

                    // 指纹对比
                    fingerprintComparisonSection

                    // 建议操作
                    recommendedActionsSection

                    // 确认复选框
                    confirmationSection
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            // 底部按钮
            footerView
        }
        .frame(width: 560, height: 620)
        .background(DesignTokens.Colors.surfaceOverlay)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 40, x: 0, y: 20)
    }

    // MARK: - 子视图

    /// 警告标题栏
    private var warningHeader: some View {
        HStack {
            AppIcon.feedbackWarn.image
                .font(DesignTokens.Typography.displaySmall)
                .foregroundColor(DesignTokens.Colors.statusError)

            Text("安全警告：主机密钥已变更")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.statusError)

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.statusError.opacity(0.1))
    }

    /// 严重警告
    private var criticalWarningSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                AppIcon.shieldSlash.image
                    .font(DesignTokens.Typography.heroMedium)
                    .foregroundColor(DesignTokens.Colors.statusError)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("检测到潜在的安全威胁")
                        .font(DesignTokens.Typography.titleSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Text("服务器 \"\(host)\" 的主机密钥与之前记录的不匹配。这可能意味着：")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 中间人攻击警告
            HStack(spacing: DesignTokens.Spacing.sm) {
                AppIcon.personXmark.image
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.statusError)

                Text("有人可能正在拦截您的连接（中间人攻击）")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .fontWeight(.semibold)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.statusError.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
        }
    }

    /// 可能的原因
    private var possibleCausesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("可能的原因")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                causeRow(
                    icon: .warning,
                    title: "中间人攻击",
                    description: "攻击者可能正在拦截并篡改您的网络通信",
                    severity: .critical
                )

                causeRow(
                    icon: .serverRack,
                    title: "服务器重新安装",
                    description: "服务器可能已重新安装或迁移到新机器",
                    severity: .warning
                )

                causeRow(
                    icon: .keyHorizontal,
                    title: "密钥已更换",
                    description: "服务器管理员可能出于安全原因更换了主机密钥",
                    severity: .info
                )

                causeRow(
                    icon: .networkIcon,
                    title: "DNS 劫持",
                    description: "您的 DNS 可能被劫持，连接到了错误的服务器",
                    severity: .critical
                )
            }
        }
    }

    /// 指纹对比
    private var fingerprintComparisonSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("指纹对比")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Spacer()

                Button(action: { showDetails.toggle() }) {
                    Text(showDetails ? "隐藏详情" : "显示详情")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: DesignTokens.Spacing.sm) {
                // 旧指纹
                fingerprintRow(
                    label: "已记录的指纹",
                    value: oldFingerprint,
                    icon: .feedbackSuccess,
                    color: DesignTokens.Colors.statusConnected
                )

                // 箭头
                AppIcon.arrowDown.image
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.statusError)

                // 新指纹
                fingerprintRow(
                    label: "当前收到的指纹",
                    value: newFingerprint.sha256Display,
                    icon: .dismiss,
                    color: DesignTokens.Colors.statusError
                )
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surfaceCard)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
            )

            if showDetails {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("密钥类型: \(newFingerprint.keyType.displayName)")
                    Text("MD5 指纹: \(newFingerprint.md5Display)")
                }
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(DesignTokens.Spacing.sm)
            }
        }
    }

    /// 建议操作
    private var recommendedActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("建议操作")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                actionRow(number: 1, text: "立即停止连接")
                actionRow(number: 2, text: "通过其他安全渠道联系服务器管理员")
                actionRow(number: 3, text: "确认服务器是否确实更换了密钥")
                actionRow(number: 4, text: "如果无法确认，请勿继续连接")
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surfaceCard)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
            )
        }
    }

    /// 确认复选框
    private var confirmationSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("如果您确定要继续连接，请确认：")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Text("我理解继续连接可能导致凭据泄露")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $understandRisk)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                HStack {
                    Text("我已通过其他渠道验证了新的主机密钥")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $verifiedNewKey)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.statusError.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium)
                    .stroke(DesignTokens.Colors.statusError.opacity(0.3), lineWidth: 1)
            )
        }
    }

    /// 底部按钮
    private var footerView: some View {
        HStack {
            Button(action: { removeOldKey() }) {
                Label("移除旧密钥记录", systemImage: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(DesignTokens.Colors.textSecondary)

            Spacer()

            Button("断开连接") {
                onCancel?()
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.Colors.accentPrimary)

            Button("仍然连接") {
                updateHostKey()
                onProceed?()
            }
            .disabled(!canProceed)
            .buttonStyle(.bordered)
            .foregroundColor(canProceed ? DesignTokens.Colors.statusError : DesignTokens.Colors.textTertiary)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 辅助视图

    /// 原因行
    private func causeRow(icon: AppIcon, title: String, description: String, severity: Severity) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            icon.image
                .font(DesignTokens.Typography.bodyLarge)
                .foregroundColor(severity.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(title)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .fontWeight(.medium)

                Text(description)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
    }

    /// 指纹行
    private func fingerprintRow(label: String, value: String, icon: AppIcon, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                icon.image
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(color)

                Text(label)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Text(value)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .textSelection(.enabled)
        }
    }

    /// 操作行
    private func actionRow(number: Int, text: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text("\(number)")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(Circle())

            Text(text)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }

    // MARK: - 类型

    enum Severity {
        case critical
        case warning
        case info

        var color: Color {
            switch self {
            case .critical: return DesignTokens.Colors.statusError
            case .warning: return DesignTokens.Colors.statusConnecting
            case .info: return DesignTokens.Colors.accentPrimary
            }
        }
    }

    // MARK: - 计算属性

    /// 是否可以继续
    private var canProceed: Bool {
        understandRisk && verifiedNewKey
    }

    // MARK: - 方法

    /// 移除旧密钥记录
    private func removeOldKey() {
        try? KnownHostsManager.shared.remove(host: host, port: port)
    }

    /// 更新主机密钥
    private func updateHostKey() {
        try? KnownHostsManager.shared.add(
            host: host,
            port: port,
            fingerprint: newFingerprint,
            comment: "用户确认更新于 \(Date())"
        )
    }
}

// MARK: - 预览

#Preview("密钥变更警告") {
    HostKeyChangedWarningView(
        host: "server.example.com",
        port: 22,
        oldFingerprint: "SHA256:AAAAB3NzaC1yc2EAAAADAQABAAABgQC...",
        newFingerprint: HostKeyFingerprint(
            keyType: .ed25519,
            sha256: "uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s",
            md5: "16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48",
            rawKey: Data()
        )
    )
}
