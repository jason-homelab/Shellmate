import SwiftUI

/// 会话表单弹窗 (D01)
/// 纯布局容器：状态和业务逻辑委托给 SessionFormViewModel
struct SessionFormSheet: View {

    // MARK: - 属性（只作为 vm 初始化的来源，不直接驱动 UI）

    var editingSession: Session?
    var defaultGroupId: UUID? = nil
    var groups: [SessionGroup] = []
    var onSave: ((Session) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - ViewModel

    @StateObject private var vm: SessionFormViewModel

    /// 跟随通用设置里的"默认连接协议"，仅新建时生效
    @AppStorage("general.defaultProtocol") private var defaultProtocol: String = "SSH"

    // MARK: - 纯 UI 状态（hover 动画，不属于业务）

    @State private var cancelHovered: Bool = false

    // MARK: - 颜色常量

    private let labelColor = DesignTokens.Colors.textPrimary
    private let borderColor = Color(hex: "#d2d2d7").opacity(0.50)
    private let fieldBackground = Color.white.opacity(0.80)

    // MARK: - 初始化

    init(
        editingSession: Session? = nil,
        defaultGroupId: UUID? = nil,
        groups: [SessionGroup] = [],
        onSave: ((Session) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.editingSession = editingSession
        self.defaultGroupId = defaultGroupId
        self.groups = groups
        self.onSave = onSave
        self.onCancel = onCancel
        _vm = StateObject(wrappedValue: SessionFormViewModel(
            editingSession: editingSession,
            defaultGroupId: defaultGroupId,
            groups: groups,
            onSave: onSave,
            onCancel: onCancel
        ))
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider().overlay(borderColor)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // 1. 名称
                    fieldGroup(label: "名称") {
                        CustomTextField(placeholder: "输入会话名称", text: $vm.name)
                    }

                    // 2. 协议
                    fieldGroup(label: "协议") {
                        Picker("", selection: $vm.connectionProtocol) {
                            Text("SSH").tag("SSH")
                            Text("Telnet").tag("Telnet")
                            Text("Serial").tag("Serial")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(borderColor, lineWidth: 1)
                        )
                        .onChange(of: vm.connectionProtocol) { newValue in
                            vm.handleProtocolChange(newValue)
                        }
                    }

                    // 3. 主机 + 端口（SSH / Telnet 显示）
                    if vm.connectionProtocol != "Serial" {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("主机 / 端口")
                                .font(DesignTokens.Typography.labelLarge)
                                .foregroundColor(labelColor)
                            HStack(spacing: DesignTokens.Spacing.lg) {
                                CustomTextField(placeholder: "主机地址或 IP", text: $vm.host)
                                    .frame(maxWidth: .infinity)
                                CustomTextField(
                                    placeholder: vm.connectionProtocol == "Telnet" ? "23" : "22",
                                    text: $vm.port
                                )
                                .frame(width: 80)
                            }
                        }
                    }

                    // 3b. 串口设备（Serial 显示）
                    if vm.connectionProtocol == "Serial" {
                        serialConfigSection
                    }

                    // 4. 用户名（SSH / Telnet 显示）
                    if vm.connectionProtocol != "Serial" {
                        fieldGroup(label: "用户名") {
                            CustomTextField(placeholder: "登录用户名", text: $vm.username)
                        }
                    }

                    // 5. 密码（仅 SSH 显示）
                    if vm.connectionProtocol == "SSH" {
                        fieldGroup(label: "密码") {
                            VStack(spacing: DesignTokens.Spacing.sm) {
                                CustomTextField(placeholder: "输入密码（可选）", text: $vm.password, isSecure: true)
                                HStack {
                                    Text("保存密码到 Keychain")
                                        .font(DesignTokens.Typography.bodySmall)
                                        .foregroundColor(DesignTokens.Colors.textSecondary)
                                    Spacer()
                                    Toggle("", isOn: $vm.saveCredential)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                            }
                        }
                    }

                    // 6. 分组
                    fieldGroup(label: "分组") {
                        Picker("", selection: $vm.selectedGroupId) {
                            Text("无分组").tag(Optional<UUID>.none)
                            ForEach(vm.groups) { group in
                                Text(group.name).tag(Optional(group.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(borderColor, lineWidth: 1)
                        )
                    }

                    // 7. 高级设置（折叠）
                    advancedSection
                }
                .padding(DesignTokens.Spacing.xl)
            }

            Divider().overlay(borderColor)

            footerView
        }
        .frame(width: 500)
        .frame(minHeight: 520)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .fill(Color.white.opacity(0.95))
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.20), radius: 32, x: 0, y: 8)
        .onAppear {
            vm.configure(defaultProtocol: defaultProtocol)
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(vm.title)
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(labelColor)
                Text("填写连接信息")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            Button(action: { vm.cancel() }) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(DesignTokens.Colors.surfaceHover)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    // MARK: - 底部按钮

    private var footerView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            if !vm.validationErrors.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.statusError)
                    Text(vm.validationErrors.first ?? "")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.statusError)
                }
            }

            Spacer()

            Button("取消") { vm.cancel() }
                .font(DesignTokens.Typography.bodyLarge)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(cancelHovered ? DesignTokens.Colors.surfaceHover : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(DesignTokens.Animation.hover) { cancelHovered = hovering }
                }
                .keyboardShortcut(.escape, modifiers: [])

            Button("保存会话") { vm.save() }
                .font(DesignTokens.Typography.bodyLargeMedium)
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 12, x: 0, y: 4)
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!vm.canSave)
                .opacity(vm.canSave ? 1.0 : 0.4)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    // MARK: - 通用字段组

    @ViewBuilder
    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(label)
                .font(DesignTokens.Typography.labelLarge)
                .foregroundColor(labelColor)
            content()
        }
    }

    // MARK: - 串口配置区段

    @ViewBuilder
    private var serialConfigSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            fieldGroup(label: "串口设备") {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Picker("", selection: $vm.serialPortPath) {
                        if vm.availableSerialPorts.isEmpty {
                            Text("无可用设备").tag("")
                        }
                        ForEach(vm.availableSerialPorts, id: \.self) { path in
                            Text(path).tag(path)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
                    Button {
                        vm.refreshSerialPorts()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("刷新串口设备列表")
                }
                if vm.availableSerialPorts.isEmpty {
                    Text("未检测到串口设备，请连接 USB 转串口适配器后刷新")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.statusConnecting)
                }
            }

            HStack(spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("波特率")
                        .font(DesignTokens.Typography.labelLarge)
                        .foregroundColor(labelColor)
                    Picker("", selection: $vm.serialBaudRate) {
                        ForEach(SerialBaudRate.allCases, id: \.rawValue) { rate in
                            Text(rate.displayName).tag(rate.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("数据位")
                        .font(DesignTokens.Typography.labelLarge)
                        .foregroundColor(labelColor)
                    Picker("", selection: $vm.serialDataBits) {
                        Text("5").tag(Int32(5))
                        Text("6").tag(Int32(6))
                        Text("7").tag(Int32(7))
                        Text("8").tag(Int32(8))
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
                }
            }

            HStack(spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("奇偶校验")
                        .font(DesignTokens.Typography.labelLarge)
                        .foregroundColor(labelColor)
                    Picker("", selection: $vm.serialParity) {
                        Text("无").tag("none")
                        Text("奇校验").tag("odd")
                        Text("偶校验").tag("even")
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("停止位")
                        .font(DesignTokens.Typography.labelLarge)
                        .foregroundColor(labelColor)
                    Picker("", selection: $vm.serialStopBits) {
                        Text("1").tag(Int32(1))
                        Text("2").tag(Int32(2))
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
                }
            }

            fieldGroup(label: "流控") {
                Picker("", selection: $vm.serialFlowControl) {
                    Text("无").tag("none")
                    Text("硬件 (RTS/CTS)").tag("hardware")
                    Text("软件 (XON/XOFF)").tag("software")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous).strokeBorder(borderColor, lineWidth: 1))
            }
        }
    }

    // MARK: - 高级设置区段

    @ViewBuilder
    private var advancedSection: some View {
        DisclosureGroup(
            isExpanded: $vm.advancedExpanded,
            content: {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // 认证方式（仅 SSH）
                    if vm.connectionProtocol == "SSH" {
                        fieldGroup(label: "认证方式") {
                            Picker("", selection: $vm.authMethod) {
                                Text("密码").tag(AuthMethod.password)
                                Text("私钥").tag(AuthMethod.privateKey)
                                Text("SSH Agent").tag(AuthMethod.sshAgent)
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall).strokeBorder(borderColor, lineWidth: 1))
                        }

                        if vm.authMethod == .privateKey {
                            fieldGroup(label: "私钥路径") {
                                CustomTextField(placeholder: "~/.ssh/id_rsa", text: $vm.privateKeyPath)
                            }
                            fieldGroup(label: "私钥密码短语") {
                                CustomTextField(placeholder: "Passphrase（可选）", text: $vm.passphrase, isSecure: true)
                            }
                        }

                        fieldGroup(label: "代理跳转 (ProxyJump)") {
                            CustomTextField(placeholder: "user@jump-host:22", text: $vm.proxyJump)
                        }
                    }

                    // 连接超时 + Keep-Alive（Serial 不需要）
                    if vm.connectionProtocol != "Serial" {
                        HStack(spacing: DesignTokens.Spacing.lg) {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text("连接超时 (秒)")
                                    .font(DesignTokens.Typography.labelLarge)
                                    .foregroundColor(labelColor)
                                CustomTextField(placeholder: "30", text: Binding(
                                    get: { String(vm.connectTimeout) },
                                    set: { vm.connectTimeout = Int32($0) ?? 30 }
                                ))
                            }
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text("Keep-Alive (秒)")
                                    .font(DesignTokens.Typography.labelLarge)
                                    .foregroundColor(labelColor)
                                CustomTextField(placeholder: "60", text: Binding(
                                    get: { String(vm.keepAliveInterval) },
                                    set: { vm.keepAliveInterval = Int32($0) ?? 60 }
                                ))
                            }
                        }

                        HStack {
                            Text("自动重连")
                                .font(DesignTokens.Typography.labelLarge)
                                .foregroundColor(labelColor)
                            Spacer()
                            Toggle("", isOn: $vm.autoReconnect)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        if vm.autoReconnect {
                            HStack(spacing: DesignTokens.Spacing.lg) {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                    Text("最大重试次数")
                                        .font(DesignTokens.Typography.labelLarge)
                                        .foregroundColor(labelColor)
                                    CustomTextField(placeholder: "3", text: Binding(
                                        get: { String(vm.maxReconnectRetries) },
                                        set: { vm.maxReconnectRetries = Int32($0) ?? 3 }
                                    ))
                                }
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                    Text("重连间隔 (秒)")
                                        .font(DesignTokens.Typography.labelLarge)
                                        .foregroundColor(labelColor)
                                    CustomTextField(placeholder: "5", text: Binding(
                                        get: { String(vm.reconnectInterval) },
                                        set: { vm.reconnectInterval = Int32($0) ?? 5 }
                                    ))
                                }
                            }
                        }
                    }

                    // 字符编码
                    fieldGroup(label: "字符编码") {
                        Picker("", selection: $vm.encoding) {
                            Text("UTF-8").tag("UTF-8")
                            Text("GBK").tag("GBK")
                            Text("GB2312").tag("GB2312")
                            Text("ISO-8859-1").tag("ISO-8859-1")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall).strokeBorder(borderColor, lineWidth: 1))
                    }

                    // Login Script
                    fieldGroup(label: "Login Script") {
                        ZStack(alignment: .topLeading) {
                            if vm.startupCommand.isEmpty {
                                Text("连接成功后自动执行的命令（支持多行，每行独立执行）")
                                    .font(DesignTokens.Typography.bodyMedium)
                                    .foregroundColor(Color.secondary.opacity(0.6))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, DesignTokens.Spacing.sm)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $vm.startupCommand)
                                .font(DesignTokens.Typography.codeMedium)
                                .frame(minHeight: 72, maxHeight: 120)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, DesignTokens.Spacing.xs)
                                .padding(.vertical, DesignTokens.Spacing.xxs)
                        }
                        .background(fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall).strokeBorder(borderColor, lineWidth: 1))
                    }

                    // tmux 集成（仅 SSH）
                    if vm.connectionProtocol == "SSH" {
                        tmuxSection
                    }
                }
                .padding(.top, DesignTokens.Spacing.md)
            },
            label: {
                Text("高级设置")
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }
        )
        .padding(.horizontal, 10)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                .strokeBorder(borderColor, lineWidth: 0.75)
        )
    }

    // MARK: - tmux 集成区段

    @ViewBuilder
    private var tmuxSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("tmux 集成")
                .font(DesignTokens.Typography.labelLarge)
                .foregroundColor(labelColor)

            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text("连接后自动检测 tmux")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text("SSH 连接成功后静默检测远程 tmux 可用性")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                Spacer()
                Toggle("", isOn: $vm.tmuxConfig.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if vm.tmuxConfig.enabled {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("自动附加策略")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Picker("", selection: $vm.tmuxConfig.autoAttach) {
                        ForEach(TmuxAutoAttach.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall).strokeBorder(borderColor, lineWidth: 1))
                }

                if vm.tmuxConfig.autoAttach == .named {
                    CustomTextField(placeholder: "会话名称", text: $vm.tmuxConfig.sessionName)
                }
                if vm.tmuxConfig.autoAttach == .create {
                    CustomTextField(placeholder: "新会话名称（留空使用 tmux 默认编号）", text: $vm.tmuxConfig.newSessionName)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("SSH 断开时")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Picker("", selection: $vm.tmuxConfig.disconnectBehavior) {
                        ForEach(TmuxDisconnectBehavior.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall).strokeBorder(borderColor, lineWidth: 1))
                }

                HStack {
                    Text("有会话时自动弹出管理器")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $vm.tmuxConfig.autoShowManager)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                .strokeBorder(borderColor.opacity(0.60), lineWidth: 0.75)
        )
    }
}

// MARK: - 预览

#Preview("新建会话") {
    SessionFormSheet(
        groups: SessionGroup.previewList,
        onSave: { session in AppLogger.ui.debug("保存: \(session.name)") },
        onCancel: { AppLogger.ui.debug("取消") }
    )
}

#Preview("编辑会话") {
    SessionFormSheet(
        editingSession: Session.preview,
        groups: SessionGroup.previewList,
        onSave: { session in AppLogger.ui.debug("保存: \(session.name)") },
        onCancel: { AppLogger.ui.debug("取消") }
    )
}
