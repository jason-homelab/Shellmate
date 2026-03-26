import SwiftUI

/// 会话表单弹窗 (D01)
/// 用于新建和编辑会话，包含 4 个 Tab
struct SessionFormSheet: View {

    // MARK: - 属性

    /// 正在编辑的会话（nil 表示新建）
    var editingSession: Session?

    /// 可选分组列表
    var groups: [SessionGroup] = []

    /// 保存回调
    var onSave: ((Session) -> Void)?

    /// 取消回调
    var onCancel: (() -> Void)?

    // MARK: - 状态

    @State private var selectedTab: FormTab = .basic

    // 基本信息
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var selectedGroupId: UUID?

    // 认证信息
    @State private var authMethod: AuthMethod = .password
    @State private var privateKeyPath: String = ""
    @State private var password: String = ""
    @State private var passphrase: String = ""

    // 认证设置（新增）
    @State private var saveCredential: Bool = true

    // 高级设置
    @State private var keepAliveInterval: Int32 = 60
    @State private var autoReconnect: Bool = true
    @State private var encoding: String = "UTF-8"
    @State private var proxyJump: String = ""
    @State private var connectTimeout: Int32 = 30
    @State private var maxReconnectRetries: Int32 = 3
    @State private var reconnectInterval: Int32 = 5
    @State private var envVarEntries: [EnvVarEntry] = []

    // 外观设置（覆盖：空字符串/0 表示跟随全局，不修改全局设置）
    @State private var colorHex: String = "#4A90D9"
    @State private var tags: [String] = []
    @State private var overrideThemeId: String = ""
    @State private var overrideFontSizeValue: Int32 = 0
    @State private var startupCommand: String = ""

    // 验证状态
    @State private var validationErrors: [String] = []

    // MARK: - Tab 枚举

    enum FormTab: String, CaseIterable {
        case basic = "基本"
        case auth = "认证"
        case advanced = "高级"
        case appearance = "外观"

        var iconName: String {
            switch self {
            case .basic: return "server.rack"
            case .auth: return "key.fill"
            case .advanced: return "gearshape.fill"
            case .appearance: return "paintbrush.fill"
            }
        }
    }

    // MARK: - 计算属性

    private var isEditing: Bool {
        editingSession != nil
    }

    private var title: String {
        isEditing ? "编辑会话" : "新建会话"
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int32(port) != nil
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            Divider()

            // Tab 选择器
            tabPicker

            Divider()

            // Tab 内容
            tabContent

            Divider()

            // 底部按钮
            footerView
        }
        .frame(width: DesignTokens.Sizes.sheetWidth)
        .frame(minHeight: DesignTokens.Sizes.sheetMinHeight)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                        .fill(DesignTokens.Colors.surfacePanel.opacity(0.82))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                        .strokeBorder(DesignTokens.Gradients.glassBorder(), lineWidth: 0.75)
                }
        }
        .onAppear {
            loadSessionData()
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            Text(title)
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            Button(action: { onCancel?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 24, height: 24)
                    .glassPanel(radius: 12)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - Tab 选择器

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(FormTab.allCases, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    @ViewBuilder
    private func tabButton(_ tab: FormTab) -> some View {
        Button(action: {
            withAnimation(DesignTokens.Animation.fast) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 12))

                Text(tab.rawValue)
                    .font(DesignTokens.Typography.labelMedium)
            }
            .foregroundColor(selectedTab == tab ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                        .fill(DesignTokens.Colors.glassSelected)
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                                .strokeBorder(DesignTokens.Gradients.glassAccentBorder, lineWidth: 0.75)
                        }
                } else {
                    Color.clear
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 内容

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .basic:
            SessionBasicTab(
                name: $name,
                host: $host,
                port: $port,
                username: $username,
                selectedGroupId: $selectedGroupId,
                groups: groups
            )

        case .auth:
            SessionAuthTab(
                authMethod: $authMethod,
                privateKeyPath: $privateKeyPath,
                password: $password,
                passphrase: $passphrase,
                saveCredential: $saveCredential
            )

        case .advanced:
            SessionAdvancedTab(
                proxyJump: $proxyJump,
                autoReconnect: $autoReconnect,
                maxReconnectRetries: $maxReconnectRetries,
                reconnectInterval: $reconnectInterval,
                keepAliveInterval: $keepAliveInterval,
                connectTimeout: $connectTimeout,
                envVarEntries: $envVarEntries
            )

        case .appearance:
            SessionAppearanceTab(
                overrideThemeId: $overrideThemeId,
                overrideFontSizeValue: $overrideFontSizeValue,
                startupCommand: $startupCommand
            )
        }
    }

    // MARK: - 底部按钮

    private var footerView: some View {
        HStack {
            // 验证错误提示
            if !validationErrors.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DesignTokens.Colors.statusError)

                    Text(validationErrors.first ?? "")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.statusError)
                }
            }

            Spacer()

            // 取消按钮
            Button("取消") {
                onCancel?()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])

            // 保存按钮
            Button(isEditing ? "保存" : "创建") {
                saveSession()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canSave)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 数据加载

    private func loadSessionData() {
        guard let session = editingSession else { return }

        name = session.name
        host = session.host
        port = String(session.port)
        username = session.username
        selectedGroupId = session.groupId
        authMethod = session.authMethod
        privateKeyPath = session.privateKeyPath ?? ""
        keepAliveInterval = session.keepAliveInterval
        autoReconnect = session.autoReconnect
        encoding = session.encoding
        colorHex = session.colorHex ?? "#4A90D9"
        tags = session.tags
        proxyJump = session.proxyJumpString ?? ""
        connectTimeout = session.connectTimeout
        maxReconnectRetries = session.maxReconnectRetries
        reconnectInterval = session.reconnectInterval
        envVarEntries = session.envVars.map { EnvVarEntry(key: $0.key, value: $0.value) }
        startupCommand = session.startupCommand ?? ""
        overrideThemeId = session.overrideThemeId ?? ""
        overrideFontSizeValue = session.overrideFontSize

        // 编辑时不回显已存储的密码，保持空白（用户若要修改则重新输入）
        password = ""
        passphrase = ""
    }

    // MARK: - 保存会话

    private func saveSession() {
        // 验证
        validationErrors = []

        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("请输入会话名称")
        }
        if host.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("请输入主机地址")
        }
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("请输入用户名")
        }
        guard let portNumber = Int32(port), portNumber > 0, portNumber <= 65535 else {
            validationErrors.append("请输入有效的端口号 (1-65535)")
            return
        }

        if !validationErrors.isEmpty { return }

        // 创建或更新会话
        let session: Session
        // 将 envVarEntries 转换为 [String: String] 字典（过滤空 key）
        let envVars = Dictionary(
            envVarEntries
                .filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { ($0.key.trimmingCharacters(in: .whitespaces), $0.value) },
            uniquingKeysWith: { _, last in last }
        )

        if let existing = editingSession {
            session = Session(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                host: host.trimmingCharacters(in: .whitespaces),
                port: portNumber,
                username: username.trimmingCharacters(in: .whitespaces),
                authMethod: authMethod,
                keychainRef: existing.keychainRef,
                privateKeyPath: privateKeyPath.isEmpty ? nil : privateKeyPath,
                keepAliveInterval: keepAliveInterval,
                autoReconnect: autoReconnect,
                encoding: encoding,
                tags: tags,
                sortOrder: existing.sortOrder,
                colorHex: colorHex,
                lastConnectedAt: existing.lastConnectedAt,
                createdAt: existing.createdAt,
                modifiedAt: Date(),
                isSoftDeleted: false,
                groupId: selectedGroupId,
                proxyJumpString: proxyJump.isEmpty ? nil : proxyJump,
                connectTimeout: connectTimeout,
                maxReconnectRetries: maxReconnectRetries,
                reconnectInterval: reconnectInterval,
                envVars: envVars,
                startupCommand: startupCommand.isEmpty ? nil : startupCommand,
                overrideThemeId: overrideThemeId.isEmpty ? nil : overrideThemeId,
                overrideFontSize: overrideFontSizeValue
            )
        } else {
            session = Session(
                name: name.trimmingCharacters(in: .whitespaces),
                host: host.trimmingCharacters(in: .whitespaces),
                port: portNumber,
                username: username.trimmingCharacters(in: .whitespaces),
                authMethod: authMethod,
                privateKeyPath: privateKeyPath.isEmpty ? nil : privateKeyPath,
                keepAliveInterval: keepAliveInterval,
                autoReconnect: autoReconnect,
                encoding: encoding,
                tags: tags,
                colorHex: colorHex,
                groupId: selectedGroupId,
                proxyJumpString: proxyJump.isEmpty ? nil : proxyJump,
                connectTimeout: connectTimeout,
                maxReconnectRetries: maxReconnectRetries,
                reconnectInterval: reconnectInterval,
                envVars: envVars,
                startupCommand: startupCommand.isEmpty ? nil : startupCommand,
                overrideThemeId: overrideThemeId.isEmpty ? nil : overrideThemeId,
                overrideFontSize: overrideFontSizeValue
            )
        }

        // 将密码/Passphrase 写入凭据金库
        saveCredentials(for: session)

        onSave?(session)
    }

    private func saveCredentials(for session: Session) {
        guard saveCredential else { return }
        Task {
            if !password.isEmpty {
                try? await CredentialVault.shared.save(password, sessionId: session.id, type: .password)
            }
            if !passphrase.isEmpty {
                try? await CredentialVault.shared.save(passphrase, sessionId: session.id, type: .passphrase)
            }
        }
    }
}

// MARK: - 预览

#Preview("新建会话") {
    SessionFormSheet(
        groups: SessionGroup.previewList,
        onSave: { session in print("保存: \(session.name)") },
        onCancel: { print("取消") }
    )
}

#Preview("编辑会话") {
    SessionFormSheet(
        editingSession: Session.preview,
        groups: SessionGroup.previewList,
        onSave: { session in print("保存: \(session.name)") },
        onCancel: { print("取消") }
    )
}
