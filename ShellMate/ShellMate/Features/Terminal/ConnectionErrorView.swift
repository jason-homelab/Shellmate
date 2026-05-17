import SwiftUI

// MARK: - 连接失败错误分析（§15.6）

/// 对连接错误消息进行分类，提供可能原因和解决方案
struct ConnectionErrorAnalysis {
    let category: Category
    let title: String
    let suggestions: [String]

    enum Category {
        case authFailed        // 认证失败（密码错误/密钥不匹配）
        case networkUnreachable // 网络不可达（超时/拒绝连接）
        case hostKeyChanged    // Host key 变更
        case portBlocked       // 端口不可达（防火墙/端口错误）
        case unknown           // 其他

        var icon: String {
            switch self {
            case .authFailed:         return "lock.slash"
            case .networkUnreachable: return "wifi.exclamationmark"
            case .hostKeyChanged:     return "exclamationmark.shield"
            case .portBlocked:        return "network.slash"
            case .unknown:            return "xmark.octagon"
            }
        }

        var iconColor: Color {
            switch self {
            case .authFailed:         return DesignTokens.Colors.statusConnecting
            case .networkUnreachable: return DesignTokens.Colors.statusError
            case .hostKeyChanged:     return DesignTokens.Colors.statusError
            case .portBlocked:        return DesignTokens.Colors.statusConnecting
            case .unknown:            return DesignTokens.Colors.textSecondary
            }
        }
    }

    /// 根据错误消息文本推断错误类别
    static func analyze(_ message: String) -> ConnectionErrorAnalysis {
        let lower = message.lowercased()

        if lower.contains("authentication") || lower.contains("auth") ||
           lower.contains("password") || lower.contains("密码") ||
           lower.contains("publickey") || lower.contains("permission denied") {
            return ConnectionErrorAnalysis(
                category: .authFailed,
                title: "认证失败",
                suggestions: [
                    "检查用户名和密码是否正确",
                    "若使用私钥认证，确认密钥文件路径存在且权限为 600",
                    "确认远端服务器允许密码认证（PasswordAuthentication yes）",
                    "尝试使用 ssh-keyscan 确认服务器公钥是否匹配"
                ]
            )
        }

        if lower.contains("host key") || lower.contains("known_hosts") ||
           lower.contains("identification has changed") {
            return ConnectionErrorAnalysis(
                category: .hostKeyChanged,
                title: "Host Key 已变更",
                suggestions: [
                    "服务器的 SSH Host Key 与本地记录不匹配",
                    "若服务器已重装或合法更换密钥，请前往「设置 → 安全」清除旧 Host Key",
                    "若未知原因发生变更，可能存在中间人攻击（MITM），请谨慎操作",
                    "可运行 ssh-keygen -R <主机名> 清除旧记录"
                ]
            )
        }

        if lower.contains("connection refused") || lower.contains("refused") ||
           lower.contains("port") || lower.contains("拒绝") {
            return ConnectionErrorAnalysis(
                category: .portBlocked,
                title: "端口被拒绝",
                suggestions: [
                    "确认 SSH 服务端口正确（默认 22，部分服务器使用自定义端口）",
                    "检查服务器防火墙是否允许该端口的入站连接",
                    "尝试 telnet <主机> <端口> 测试端口连通性",
                    "若使用跳板机，检查跳板机配置是否正确"
                ]
            )
        }

        if lower.contains("timeout") || lower.contains("timed out") ||
           lower.contains("unreachable") || lower.contains("network") ||
           lower.contains("no route") || lower.contains("超时") {
            return ConnectionErrorAnalysis(
                category: .networkUnreachable,
                title: "网络不可达",
                suggestions: [
                    "确认主机地址（IP 或域名）是否正确",
                    "检查本机网络连接是否正常",
                    "尝试 ping <主机> 测试网络连通性",
                    "若在内网，检查是否需要 VPN 或跳板机",
                    "适当增大「连接超时」时间（设置 → 高级）"
                ]
            )
        }

        return ConnectionErrorAnalysis(
            category: .unknown,
            title: "连接失败",
            suggestions: [
                "检查主机地址、端口、用户名是否填写正确",
                "查看服务器日志（/var/log/auth.log 或 /var/log/secure）",
                "尝试在终端使用 ssh 命令手动连接以获取详细报错",
                "若问题持续，联系服务器管理员确认账户状态"
            ]
        )
    }
}

// MARK: - 连接错误详情视图（替代简单 alert）

struct ConnectionErrorView: View {

    let session: Session
    let errorMessage: String
    var onRetry: () -> Void
    var onDismiss: () -> Void
    /// AI-04：点击后以错误上下文预填充 AI 助手面板，nil 表示 AI 功能未启用
    var onAIDiagnose: (() -> Void)?

    private var analysis: ConnectionErrorAnalysis {
        ConnectionErrorAnalysis.analyze(errorMessage)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(width: 440)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 8)
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(analysis.category.iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: analysis.category.icon)
                    .font(DesignTokens.Typography.displayXSmall)
                    .foregroundColor(analysis.category.iconColor)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.nano) {
                Text(analysis.title)
                    .font(DesignTokens.Typography.labelLargeAlt)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("\(session.name) · \(session.username)@\(session.host):\(session.port)")
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 14)
    }

    // MARK: - 内容

    private var contentView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 错误原文（等宽字体，可滚动）
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text("错误详情")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                ScrollView(.vertical, showsIndicators: false) {
                    Text(errorMessage)
                        .font(DesignTokens.Typography.codeTiny)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 60)
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.surfaceHover)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            // 解决建议
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("可能原因 & 解决方案")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                ForEach(Array(analysis.suggestions.enumerated()), id: \.offset) { idx, suggestion in
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                        Text("\(idx + 1)")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                            .frame(width: 16, height: 16)
                            .background(DesignTokens.Colors.accentPrimary.opacity(0.10))
                            .clipShape(Circle())
                        Text(suggestion)
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 底部

    @ObservedObject private var aiSettings = AISettingsStore.shared

    private var footerView: some View {
        HStack {
            // AI 诊断按钮：始终占位，无 AI 或未启用时 disabled + tooltip 引导
            Button {
                onDismiss()
                onAIDiagnose?()
            } label: {
                Label("AI 诊断", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            .disabled(!aiSettings.isEnabled || onAIDiagnose == nil)
            .help(aiSettings.isEnabled ? "用 AI 分析此错误并给出修复建议" : "请先在「设置 → AI」中启用 AI 功能")

            Spacer()
            Button("关闭", action: onDismiss)
                .buttonStyle(.bordered)
            Button(action: onRetry) {
                Label("重试连接", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }
}

// MARK: - 预览

#Preview("连接失败 - 认证失败") {
    ConnectionErrorView(
        session: Session(name: "开发服务器", host: "192.168.1.100", username: "ubuntu"),
        errorMessage: "SSH_AUTH_FAILED: Authentication failed for user ubuntu (password authentication rejected by server)",
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}
