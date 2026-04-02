import SwiftUI

/// 会话表单弹窗 (D01)
/// 单页滚动表单，对齐 Figma-Spec-v2 第 06 章规范
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

    // 基本信息
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var selectedGroupId: UUID?
    @AppStorage("general.defaultProtocol") private var defaultProtocol: String = "SSH"
    @State private var connectionProtocol: String = "SSH"

    // 认证信息
    @State private var authMethod: AuthMethod = .password
    @State private var privateKeyPath: String = ""
    @State private var password: String = ""
    @State private var passphrase: String = ""

    // 认证设置
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

    // tmux 配置
    @State private var tmuxConfig: TmuxConfig = TmuxConfig()

    // 外观设置（覆盖：空字符串/0 表示跟随全局，不修改全局设置）
    @State private var colorHex: String = "#4A90D9"
    @State private var tags: [String] = []
    @State private var overrideThemeId: String = ""
    @State private var overrideFontSizeValue: Int32 = 0
    @State private var startupCommand: String = ""

    // 验证状态
    @State private var validationErrors: [String] = []

    // 高级设置折叠状态
    @State private var advancedExpanded: Bool = false

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

    // MARK: - 颜色常量

    private let labelColor = Color(hex: "#1d1d1f")
    private let borderColor = Color(hex: "#d2d2d7").opacity(0.5)
    private let fieldBackground = Color.white.opacity(0.8)

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            Divider()
                .overlay(borderColor)

            // 单页滚动表单
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // 1. 名称
                    fieldGroup(label: "名称") {
                        styledTextField("输入会话名称", text: $name)
                    }

                    // 2. 协议
                    fieldGroup(label: "协议") {
                        Picker("", selection: $connectionProtocol) {
                            Text("SSH").tag("SSH")
                            Text("Telnet").tag("Telnet")
                            Text("Serial").tag("Serial")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(fieldBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(borderColor, lineWidth: 1)
                        )
                    }

                    // 3. 主机 + 端口（并排）
                    VStack(alignment: .leading, spacing: 6) {
                        Text("主机 / 端口")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(labelColor)
                        HStack(spacing: 16) {
                            styledTextField("主机地址或 IP", text: $host)
                                .frame(maxWidth: .infinity)
                            styledTextField("22", text: $port)
                                .frame(width: 80)
                        }
                    }

                    // 4. 用户名
                    fieldGroup(label: "用户名") {
                        styledTextField("登录用户名", text: $username)
                    }

                    // 5. 密码 + 保存密码
                    fieldGroup(label: "密码") {
                        VStack(spacing: 8) {
                            styledSecureField("输入密码（可选）", text: $password)
                            HStack(spacing: 8) {
                                Toggle("保存密码到 Keychain", isOn: $saveCredential)
                                    .toggleStyle(.checkbox)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#6e6e73"))
                                Spacer()
                            }
                        }
                    }

                    // 6. 分组
                    fieldGroup(label: "分组") {
                        Picker("", selection: $selectedGroupId) {
                            Text("无分组").tag(Optional<UUID>.none)
                            ForEach(groups) { group in
                                Text(group.name).tag(Optional(group.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(fieldBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(borderColor, lineWidth: 1)
                        )
                    }

                    // 7. 高级设置（折叠）
                    DisclosureGroup(
                        isExpanded: $advancedExpanded,
                        content: {
                            VStack(spacing: 16) {
                                // 认证方式
                                fieldGroup(label: "认证方式") {
                                    Picker("", selection: $authMethod) {
                                        Text("密码").tag(AuthMethod.password)
                                        Text("私钥").tag(AuthMethod.privateKey)
                                        Text("SSH Agent").tag(AuthMethod.sshAgent)
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(fieldBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(borderColor, lineWidth: 1)
                                    )
                                }

                                if authMethod == .privateKey {
                                    fieldGroup(label: "私钥路径") {
                                        styledTextField("~/.ssh/id_rsa", text: $privateKeyPath)
                                    }
                                    fieldGroup(label: "私钥密码短语") {
                                        styledSecureField("Passphrase（可选）", text: $passphrase)
                                    }
                                }

                                // 代理跳转
                                fieldGroup(label: "代理跳转 (ProxyJump)") {
                                    styledTextField("user@jump-host:22", text: $proxyJump)
                                }

                                // 连接超时 + Keep-Alive
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("连接超时 (秒)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(labelColor)
                                        styledTextField("30", text: Binding(
                                            get: { String(connectTimeout) },
                                            set: { connectTimeout = Int32($0) ?? 30 }
                                        ))
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Keep-Alive (秒)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(labelColor)
                                        styledTextField("60", text: Binding(
                                            get: { String(keepAliveInterval) },
                                            set: { keepAliveInterval = Int32($0) ?? 60 }
                                        ))
                                    }
                                }

                                // 自动重连
                                HStack {
                                    Toggle("自动重连", isOn: $autoReconnect)
                                        .toggleStyle(.checkbox)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(labelColor)
                                    Spacer()
                                }

                                if autoReconnect {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("最大重试次数")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(labelColor)
                                            styledTextField("3", text: Binding(
                                                get: { String(maxReconnectRetries) },
                                                set: { maxReconnectRetries = Int32($0) ?? 3 }
                                            ))
                                        }
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("重连间隔 (秒)")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(labelColor)
                                            styledTextField("5", text: Binding(
                                                get: { String(reconnectInterval) },
                                                set: { reconnectInterval = Int32($0) ?? 5 }
                                            ))
                                        }
                                    }
                                }

                                // 编码
                                fieldGroup(label: "字符编码") {
                                    Picker("", selection: $encoding) {
                                        Text("UTF-8").tag("UTF-8")
                                        Text("GBK").tag("GBK")
                                        Text("GB2312").tag("GB2312")
                                        Text("ISO-8859-1").tag("ISO-8859-1")
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(fieldBackground)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(borderColor, lineWidth: 1)
                                    )
                                }

                                // 启动命令
                                fieldGroup(label: "启动命令") {
                                    styledTextField("连接后自动执行的命令（可选）", text: $startupCommand)
                                }
                            }
                            .padding(.top, 12)
                        },
                        label: {
                            Text("高级设置")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#007aff"))
                        }
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
                }
                .padding(20)
            }

            Divider()
                .overlay(borderColor)

            // 底部按钮
            footerView
        }
        .frame(width: 500)
        .frame(minHeight: 520)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(hex: "#d2d2d7").opacity(0.5), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 32, x: 0, y: 8)
        )
        .onAppear {
            loadSessionData()
            // 新建会话时，协议默认跟随通用设置里的"默认连接协议"
            if editingSession == nil {
                connectionProtocol = defaultProtocol
            }
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(labelColor)
                Text("填写连接信息")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#6e6e73"))
            }

            Spacer()

            Button(action: { onCancel?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#6e6e73"))
                    .frame(width: 24, height: 24)
                    .background(Color(hex: "#f2f2f7"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - 底部按钮

    private var footerView: some View {
        HStack(spacing: 12) {
            // 验证错误提示
            if !validationErrors.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#ff3b30"))
                    Text(validationErrors.first ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#ff3b30"))
                }
            }

            Spacer()

            // 取消按钮
            Button("取消") {
                onCancel?()
            }
            .font(.system(size: 14))
            .foregroundColor(Color(hex: "#1d1d1f"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "#f2f2f7"))
            .cornerRadius(8)
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            // 保存按钮
            Button(isEditing ? "保存" : "创建") {
                saveSession()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(canSave ? Color(hex: "#007aff") : Color(hex: "#007aff").opacity(0.4))
            .cornerRadius(8)
            .shadow(color: Color(hex: "#007aff").opacity(0.3), radius: 8, x: 0, y: 4)
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - 通用字段组

    @ViewBuilder
    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(labelColor)
            content()
        }
    }

    // MARK: - 通用样式 TextField

    @ViewBuilder
    private func styledTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(fieldBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }

    // MARK: - 通用样式 SecureField

    @ViewBuilder
    private func styledSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(fieldBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
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
        tmuxConfig = TmuxConfigStore.load(sessionId: session.id)

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

        // 保存 tmux 配置（UserDefaults，不影响 Core Data）
        TmuxConfigStore.save(tmuxConfig, sessionId: session.id)

        // 将密码/Passphrase 写入凭据金库
        saveCredentials(for: session)

        onSave?(session)
    }

    private func saveCredentials(for session: Session) {
        guard saveCredential else { return }
        // 提前拷贝到局部变量，随后立即清零 @State 内存中的明文
        let pwd = password
        let pp = passphrase
        password.removeAll(keepingCapacity: false)
        passphrase.removeAll(keepingCapacity: false)
        Task {
            do {
                if !pwd.isEmpty {
                    try await CredentialVault.shared.save(pwd, sessionId: session.id, type: .password)
                }
                if !pp.isEmpty {
                    try await CredentialVault.shared.save(pp, sessionId: session.id, type: .passphrase)
                }
            } catch {
                // 凭据保存失败时记录错误，不静默吞掉
                print("[SessionFormSheet] 凭据保存失败: \(error.localizedDescription)")
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
