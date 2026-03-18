import SwiftUI

/// D02 首次指纹确认弹窗
/// 当连接到新的 SSH 服务器时，显示主机密钥指纹供用户确认
struct HostKeyConfirmationView: View {

    // MARK: - 属性

    /// 主机名
    let host: String

    /// 端口号
    let port: Int32

    /// 主机密钥指纹
    let fingerprint: HostKeyFingerprint

    /// 确认回调
    var onConfirm: (() -> Void)?

    /// 取消回调
    var onCancel: (() -> Void)?

    // MARK: - 状态

    /// 是否记住此主机
    @State private var rememberHost: Bool = true

    /// 显示的指纹格式
    @State private var fingerprintFormat: FingerprintFormat = .sha256

    /// 指纹格式
    enum FingerprintFormat: String, CaseIterable {
        case sha256 = "SHA256"
        case md5 = "MD5"
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            Divider()

            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // 警告图标和说明
                    warningSection

                    // 主机信息
                    hostInfoSection

                    // 指纹信息
                    fingerprintSection

                    // 安全提示
                    securityTipsSection

                    // 记住选项
                    rememberOptionSection
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            // 底部按钮
            footerView
        }
        .frame(width: 520, height: 480)
        .background(DesignTokens.Colors.surfacePanel)
    }

    // MARK: - 子视图

    /// 标题栏
    private var headerView: some View {
        HStack {
            Image(systemName: "key.fill")
                .font(.system(size: 20))
                .foregroundColor(DesignTokens.Colors.statusConnecting)

            Text("验证主机密钥")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            Button(action: { onCancel?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(DesignTokens.Colors.surfaceCard)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    /// 警告说明
    private var warningSection: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Colors.statusConnecting)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("首次连接到此服务器")
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("无法验证主机 \"\(host)\" 的真实性。请确认以下指纹与服务器管理员提供的指纹一致。")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.statusConnecting.opacity(0.1))
        .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
    }

    /// 主机信息
    private var hostInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("主机信息")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            VStack(spacing: DesignTokens.Spacing.xs) {
                infoRow(label: "主机", value: host)
                infoRow(label: "端口", value: String(port))
                infoRow(label: "密钥类型", value: fingerprint.keyType.displayName)
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surfaceCard)
            .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
        }
    }

    /// 指纹信息
    private var fingerprintSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("主机密钥指纹")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Spacer()

                Picker("格式", selection: $fingerprintFormat) {
                    ForEach(FingerprintFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            // 指纹显示
            HStack {
                Text(displayFingerprint)
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .textSelection(.enabled)

                Spacer()

                Button(action: copyFingerprint) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("复制指纹")
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surfaceWindow)
            .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
        }
    }

    /// 安全提示
    private var securityTipsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("安全提示")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                tipRow(icon: "checkmark.circle", text: "通过安全渠道向服务器管理员确认指纹")
                tipRow(icon: "checkmark.circle", text: "不要在公共网络上首次连接重要服务器")
                tipRow(icon: "xmark.circle", text: "如果指纹不匹配，请勿继续连接", isWarning: true)
            }
        }
    }

    /// 记住选项
    private var rememberOptionSection: some View {
        Toggle(isOn: $rememberHost) {
            VStack(alignment: .leading, spacing: 2) {
                Text("记住此主机")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("将主机密钥保存到已知主机列表")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
        .toggleStyle(.switch)
        .tint(DesignTokens.Colors.accentPrimary)
    }

    /// 底部按钮
    private var footerView: some View {
        HStack {
            // 显示连接风险提示
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Text("确认后将建立 SSH 连接")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            Button("取消") {
                onCancel?()
            }
            .keyboardShortcut(.cancelAction)

            Button("确认连接") {
                if rememberHost {
                    saveHostKey()
                }
                onConfirm?()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 辅助视图

    /// 信息行
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()
        }
    }

    /// 提示行
    private func tipRow(icon: String, text: String, isWarning: Bool = false) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isWarning ? DesignTokens.Colors.statusError : DesignTokens.Colors.statusConnected)

            Text(text)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(isWarning ? DesignTokens.Colors.statusError : DesignTokens.Colors.textSecondary)
        }
    }

    // MARK: - 计算属性

    /// 显示的指纹
    private var displayFingerprint: String {
        switch fingerprintFormat {
        case .sha256:
            return fingerprint.sha256Display
        case .md5:
            return fingerprint.md5Display
        }
    }

    // MARK: - 方法

    /// 复制指纹到剪贴板
    private func copyFingerprint() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayFingerprint, forType: .string)
    }

    /// 保存主机密钥
    private func saveHostKey() {
        try? KnownHostsManager.shared.add(
            host: host,
            port: port,
            fingerprint: fingerprint
        )
    }
}

// MARK: - 预览

#Preview("首次指纹确认") {
    HostKeyConfirmationView(
        host: "server.example.com",
        port: 22,
        fingerprint: HostKeyFingerprint(
            keyType: .ed25519,
            sha256: "SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s",
            md5: "16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48",
            rawKey: Data()
        )
    )
}
