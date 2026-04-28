import SwiftUI
import AppKit

/// 会话认证 Tab（D01 Tab 2）
/// 选择认证方式并配置相关参数；含凭据保存开关和 SSH Agent 状态检测
struct SessionAuthTab: View {

    // MARK: - 属性

    @Binding var authMethod: AuthMethod
    @Binding var privateKeyPath: String
    @Binding var password: String
    @Binding var passphrase: String
    @Binding var saveCredential: Bool

    // MARK: - 私有状态

    @State private var showingKeyFilePicker = false  // 保留以兼容旧调用
    @State private var agentAvailable: Bool = false
    @State private var agentChecked: Bool = false

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // 认证方式卡片（3 选一）
                authMethodCards

                Divider()

                // 认证详情区（根据选中方式动态切换）
                Group {
                    switch authMethod {
                    case .password:
                        passwordAuthSection
                    case .privateKey:
                        privateKeyAuthSection
                    case .sshAgent:
                        sshAgentAuthSection
                    case .keyboardInteractive:
                        keyboardInteractiveSection
                    }
                }
                .transition(.opacity)
                .animation(DesignTokens.Animation.fast, value: authMethod)

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .onAppear {
            checkSSHAgent()
        }
    }

    // MARK: - 认证方式卡片

    private var authMethodCards: some View {
        HStack(spacing: 10) {
            ForEach(AuthMethod.allCases.filter { $0 != .sshAgent || AppVariant.supportsSSHAgent }) { method in
                AuthMethodCard(
                    method: method,
                    isSelected: authMethod == method,
                    onSelect: {
                        withAnimation(DesignTokens.Animation.fast) {
                            authMethod = method
                        }
                    }
                )
            }
        }
    }

    // MARK: - 密码认证

    private var passwordAuthSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            FormField(label: "SSH 密码") {
                CustomTextField(placeholder: "输入密码（可选，连接时输入）", text: $password, isSecure: true)
            }

            HStack {
                Text("记住密码（加密存储到本地）")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $saveCredential)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    // MARK: - 私钥认证

    private var privateKeyAuthSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            FormField(label: "私钥文件路径") {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    CustomTextField(placeholder: "~/.ssh/id_ed25519", text: $privateKeyPath)

                    Button("浏览…") {
                        browsePrivateKey()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("支持 Ed25519、RSA、ECDSA 格式")
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.textDisabled)

            FormField(label: "私钥密码（Passphrase）") {
                CustomTextField(placeholder: "留空表示无 Passphrase", text: $passphrase, isSecure: true)
            }

            HStack {
                Text("记住密码（加密存储到本地）")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $saveCredential)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
        // fileImporter 不支持显示隐藏文件夹，已改用 browsePrivateKey() 调用 NSOpenPanel
    }

    // MARK: - SSH Agent 认证

    private var sshAgentAuthSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 状态行
            HStack(spacing: DesignTokens.Spacing.sm) {
                if !agentChecked {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: agentAvailable
                          ? "checkmark.circle.fill"
                          : "xmark.circle.fill")
                        .font(DesignTokens.Typography.bodyLarge)
                        .foregroundColor(agentAvailable
                            ? DesignTokens.Colors.statusConnected
                            : DesignTokens.Colors.statusError)
                }

                Text(agentAvailable
                     ? "SSH Agent 已连接（SSH_AUTH_SOCK）"
                     : "未检测到 SSH Agent，请确认 ssh-agent 正在运行")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            // App Store 沙盒限制提示
            if !agentAvailable || AppVariant.isAppStoreBuild {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.statusConnecting)

                    Text(AppVariant.isAppStoreBuild
                         ? "Direct 版支持 SSH Agent，App Store 版受沙盒限制"
                         : "请先在终端运行 eval \"$(ssh-agent -s)\" 并用 ssh-add 添加密钥")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.statusConnecting)
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.statusConnecting.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                        .stroke(DesignTokens.Colors.statusConnecting.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 键盘交互认证

    private var keyboardInteractiveSection: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(DesignTokens.Typography.bodyLarge)
                .foregroundColor(DesignTokens.Colors.accentPrimary)

            Text("服务器会在连接时逐步提示输入认证信息（如一次性密码、验证码等）。")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.accentPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - 私钥文件选择（NSOpenPanel，支持显示隐藏文件夹）

    /// 私钥文件最大允许大小（64 KB）；超出说明所选文件不是私钥
    private static let maxPrivateKeySizeBytes: Int = 64 * 1024

    private func browsePrivateKey() {
        let panel = NSOpenPanel()
        panel.title = "选择私钥文件"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            // 校验文件大小，防止意外选择超大文件导致 OOM
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            guard fileSize <= Self.maxPrivateKeySizeBytes else {
                // 文件过大，不是合法私钥，忽略选择
                AppLogger.ui.debug("[SessionAuthTab] 所选文件超过 64 KB（\(fileSize) 字节），已忽略")
                return
            }
            privateKeyPath = url.path
        }
    }

    // MARK: - SSH Agent 检测

    private func checkSSHAgent() {
        Task.detached(priority: .background) {
            let socketPath = ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] ?? ""
            let available = !socketPath.isEmpty && FileManager.default.fileExists(atPath: socketPath)
            await MainActor.run {
                agentAvailable = available
                agentChecked = true
            }
        }
    }
}

// MARK: - 认证方式卡片（Figma 08-缺失组件补充 §三）

struct AuthMethodCard: View {

    let method: AuthMethod
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                // 图标圆形背景
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? DesignTokens.Colors.accentPrimary.opacity(0.2)
                              : DesignTokens.Colors.surfaceOverlay)
                        .frame(width: 32, height: 32)

                    Image(systemName: method.iconName)
                        .font(DesignTokens.Typography.titleMedium)
                        .foregroundColor(isSelected
                            ? DesignTokens.Colors.accentPrimary
                            : DesignTokens.Colors.textSecondary)
                }

                Text(method.displayName)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(isSelected
                        ? DesignTokens.Colors.accentPrimary
                        : DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .background(isSelected
                ? DesignTokens.Colors.accentPrimary.opacity(0.08)
                : DesignTokens.Colors.surfacePanel)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .stroke(
                        isSelected ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.borderSubtle,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 预览

#Preview("认证 Tab - 密码") {
    SessionAuthTab(
        authMethod: .constant(.password),
        privateKeyPath: .constant(""),
        password: .constant(""),
        passphrase: .constant(""),
        saveCredential: .constant(true)
    )
    .frame(width: 504, height: 400)
    .background(DesignTokens.Colors.surfacePanel)
}

#Preview("认证 Tab - 私钥") {
    SessionAuthTab(
        authMethod: .constant(.privateKey),
        privateKeyPath: .constant("~/.ssh/id_ed25519"),
        password: .constant(""),
        passphrase: .constant(""),
        saveCredential: .constant(true)
    )
    .frame(width: 504, height: 400)
    .background(DesignTokens.Colors.surfacePanel)
}
