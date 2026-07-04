import SwiftUI

// MARK: - 密码输入向导

/// password / keyboard-interactive 认证且无已存凭据时，连接前弹出的密码输入向导。
/// 从 TerminalView 抽出（Phase 17）：状态经 @Binding 注入，连接逻辑委托给 TerminalController。
struct CredentialWizardView: View {

    /// 当前会话（用于展示 user@host:port 与认证方式）
    let session: Session
    /// 终端控制器（执行临时密码连接 / 复位 needsCredentialInput）
    let controller: TerminalController

    /// 向导是否显示（绑定 TerminalView.showCredentialWizard）
    @Binding var isPresented: Bool
    /// 密码输入（绑定 TerminalView.wizardPassword）
    @Binding var password: String
    /// 是否记住密码（绑定 TerminalView.wizardSaveCredential）
    @Binding var saveCredential: Bool
    /// 连接失败时回填的错误信息（绑定 TerminalView.connectionErrorMessage）
    @Binding var connectionErrorMessage: String
    /// 是否展示连接错误（绑定 TerminalView.showConnectionError）
    @Binding var showConnectionError: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("输入连接凭据")
                        .font(DesignTokens.Typography.titleMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text("\(session.username)@\(session.host):\(session.port)")
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                Spacer()
                Button {
                    isPresented = false
                    controller.needsCredentialInput = false
                } label: {
                    AppIcon.close.image
                        .font(DesignTokens.Typography.bodySmallStrong)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(DesignTokens.Colors.surfaceCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // 认证方式提示
                HStack(spacing: DesignTokens.Spacing.sm) {
                    AppIcon.key.image
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                    Text(session.authMethod == .keyboardInteractive ? "键盘交互认证" : "密码认证")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                // 密码输入
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("密码")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    CustomTextField(placeholder: "请输入密码", text: $password, isSecure: true)
                        .onSubmit { confirm() }
                }

                // 记住密码选项
                HStack {
                    Text("记住密码（保存到本设备凭据金库）")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Spacer()
                    Toggle("", isOn: $saveCredential)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            HStack {
                Spacer()
                Button("取消") {
                    isPresented = false
                    controller.needsCredentialInput = false
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

                Button("连接") {
                    confirm()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(password.isEmpty)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 380)
        .background(DesignTokens.Colors.surfacePanel)
    }

    private func confirm() {
        guard !password.isEmpty else { return }
        let pwd = password
        let save = saveCredential
        // 立即清零内存中的明文密码，避免残留
        password.removeAll(keepingCapacity: false)
        isPresented = false
        Task {
            do {
                try await controller.connectWithTemporaryPassword(pwd, save: save)
            } catch let error as SSHError {
                connectionErrorMessage = error.localizedDescription
                showConnectionError = true
            }
        }
    }
}
