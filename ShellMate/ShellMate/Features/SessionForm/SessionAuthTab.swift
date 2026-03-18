import SwiftUI

/// 会话认证 Tab
/// 选择认证方式并配置相关参数
struct SessionAuthTab: View {

    // MARK: - 属性

    @Binding var authMethod: AuthMethod
    @Binding var privateKeyPath: String

    // MARK: - 私有状态

    @State private var showingKeyFilePicker = false

    // MARK: - 视图

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 认证方式选择
            Text("认证方式")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // 认证方式卡片
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignTokens.Spacing.md) {
                ForEach(AuthMethod.allCases) { method in
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

            // 根据认证方式显示额外配置
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

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 密码认证配置

    private var passwordAuthSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Divider()
                .padding(.vertical, DesignTokens.Spacing.sm)

            Text("密码将安全存储在系统钥匙串中")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            FormField(label: "密码") {
                SecureField("输入密码（可选，连接时输入）", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - 私钥认证配置

    private var privateKeyAuthSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Divider()
                .padding(.vertical, DesignTokens.Spacing.sm)

            FormField(label: "私钥文件") {
                HStack {
                    TextField("选择私钥文件", text: $privateKeyPath)
                        .textFieldStyle(.roundedBorder)

                    Button("浏览...") {
                        showingKeyFilePicker = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            FormField(label: "私钥密码") {
                SecureField("如果私钥有密码保护", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
            }

            // 常用私钥路径提示
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 12))
                Text("常用路径: ~/.ssh/id_rsa, ~/.ssh/id_ed25519")
                    .font(DesignTokens.Typography.bodySmall)
            }
            .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .fileImporter(
            isPresented: $showingKeyFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                privateKeyPath = url.path
            }
        }
    }

    // MARK: - SSH Agent 认证配置

    private var sshAgentAuthSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Divider()
                .padding(.vertical, DesignTokens.Spacing.sm)

            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundColor(DesignTokens.Colors.accentPrimary)

                Text("将使用系统 SSH Agent 进行认证。请确保已将密钥添加到 Agent。")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.accentPrimary.opacity(0.1))
            .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)

            Text("注意：此功能在 App Store 版本中不可用")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.statusConnecting)
        }
    }

    // MARK: - 键盘交互认证配置

    private var keyboardInteractiveSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Divider()
                .padding(.vertical, DesignTokens.Spacing.sm)

            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundColor(DesignTokens.Colors.accentPrimary)

                Text("服务器会在连接时提示输入认证信息（如一次性密码、验证码等）。")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.accentPrimary.opacity(0.1))
            .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
        }
    }
}

/// 认证方式卡片
struct AuthMethodCard: View {

    let method: AuthMethod
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: method.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textSecondary)

                Text(method.displayName)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(isSelected ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? DesignTokens.Colors.backgroundSelected : DesignTokens.Colors.surfaceCard)
            .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium)
                    .stroke(isSelected ? DesignTokens.Colors.accentPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 预览

#Preview("认证 Tab") {
    SessionAuthTab(
        authMethod: .constant(.password),
        privateKeyPath: .constant("")
    )
    .frame(width: 480, height: 400)
    .background(DesignTokens.Colors.surfacePanel)
}

#Preview("认证 Tab - 私钥") {
    SessionAuthTab(
        authMethod: .constant(.privateKey),
        privateKeyPath: .constant("~/.ssh/id_rsa")
    )
    .frame(width: 480, height: 400)
    .background(DesignTokens.Colors.surfacePanel)
}
