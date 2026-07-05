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

    // MARK: - W4 新增：测试连接状态（解 UE-P0#2）

    @State private var preflightResult: PreflightResult?
    @State private var preflightRunning: Bool = false
    @State private var showPreflightPanel: Bool = false

    // MARK: - 颜色常量

    private let labelColor = DesignTokens.Colors.textPrimary
    // Figma 11:7: border-[rgba(0,0,0,0.12)]
    private let borderColor = Color.black.opacity(0.12)
    private let fieldBackground = DesignTokens.Colors.surfaceInput

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
                    // 1. 协议（决定后续字段结构，放首位）
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

                    // 2. 主机 + 端口（SSH / Telnet）
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

                    // 2b. 串口设备（Serial）
                    if vm.connectionProtocol == "Serial" {
                        serialConfigSection
                    }

                    // 3. 用户名（SSH / Telnet）
                    if vm.connectionProtocol != "Serial" {
                        fieldGroup(label: "用户名") {
                            CustomTextField(placeholder: "登录用户名", text: $vm.username)
                        }
                    }

                    // 4. 密码（仅 SSH）
                    if vm.connectionProtocol == "SSH" {
                        fieldGroup(label: "密码") {
                            VStack(spacing: DesignTokens.Spacing.sm) {
                                CustomTextField(placeholder: "输入密码（可选）", text: $vm.password, isSecure: true)
                                HStack(spacing: 4) {
                                    Text("保存密码到 Keychain")
                                        .font(DesignTokens.Typography.bodySmall)
                                        .foregroundColor(DesignTokens.Colors.textSecondary)
                                    // Phase 3：术语 Tooltip — Keychain 解释
                                    AppIcon.info.image
                                        .font(.system(size: 11))
                                        .foregroundColor(DesignTokens.Colors.textTertiary)
                                        .help("Keychain 是 macOS 系统提供的密码加密存储，仅本机可用，重启不丢失")
                                    Spacer()
                                    Toggle("", isOn: $vm.saveCredential)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                            }
                        }
                    }

                    // 5. 高级设置（折叠，含私钥/跳板机等认证配置）
                    advancedSection

                    // 6. 分组（元数据，置于认证配置之后）
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

                    // 7. 名称（可由主机自动推断，置于末位）
                    fieldGroup(label: "会话名称") {
                        CustomTextField(placeholder: "留空则自动使用主机名", text: $vm.name)
                    }
                }
                .padding(DesignTokens.Spacing.xl)
            }

            Divider().overlay(borderColor)

            // W4：测试连接结果面板（内联于布局流，可关闭，避免遮挡底部按钮）
            if showPreflightPanel {
                preflightPanel
                Divider().overlay(borderColor)
            }

            footerView
        }
        .frame(width: 500)
        .frame(minHeight: 520)
        // Figma 11:2: bg-[#fafafb] rounded-[16px] shadow-[0px_20px_60px_0px_rgba(0,0,0,0.2)]
        .background(DesignTokens.Colors.surfaceWindow)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .shadow(color: Color.black.opacity(0.20), radius: 30, x: 0, y: 20)
        .onAppear {
            vm.configure(defaultProtocol: defaultProtocol)
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                // Figma 11:4: text-[18px] font-semibold
                Text(vm.isEditing ? "编辑 SSH 会话" : "新建 SSH 会话")
                    .font(DesignTokens.Typography.titlePanel)
                    .foregroundColor(labelColor)
                // Figma 11:5: text-[13px] font-normal text-[#8e8e93]
                Text(vm.isEditing ? "编辑 SSH 连接信息" : "创建新的 SSH 连接会话")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            Button(action: { vm.cancel() }) {
                AppIcon.close.image
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
            // 显示所有校验错误（逐行），而非只显示第一条
            if !vm.validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(vm.validationErrors, id: \.self) { error in
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            AppIcon.feedbackWarn.image
                                .font(DesignTokens.Typography.bodySmall)
                                .foregroundColor(DesignTokens.Colors.statusError)
                            Text(error)
                                .font(DesignTokens.Typography.bodySmall)
                                .foregroundColor(DesignTokens.Colors.statusError)
                        }
                    }
                }
            }

            // W4 新增：测试连接按钮（解 UE-P0#2）
            Button(action: runPreflight) {
                HStack(spacing: 6) {
                    if preflightRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        AppIcon.connect.image.font(.system(size: 12))
                    }
                    Text(preflightRunning ? "测试中…" : "测试连接")
                }
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(height: 36)
                .padding(.horizontal, 14)
                .background(DesignTokens.Colors.glassLight)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.glassBorderSide, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(preflightRunning || vm.host.isEmpty)
            .opacity((preflightRunning || vm.host.isEmpty) ? 0.5 : 1.0)
            .help("不打开会话，先验证主机连通性 (DNS / TCP / SSH)")

            Spacer()

            // Figma 11:33: bg-[rgba(0,0,0,0.05)] h-[36px] w-[80px] rounded-[8px] text-[#6e6e73]
            Button("取消") { vm.cancel() }
                .font(DesignTokens.Typography.bodyLargeMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 80, height: 36)
                .background(Color.black.opacity(cancelHovered ? 0.08 : 0.05))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(DesignTokens.Animation.hover) { cancelHovered = hovering }
                }
                .keyboardShortcut(.escape, modifiers: [])

            // Figma 11:35: bg-[#077aff] h-[36px] rounded-[8px] shadow-[0px_4px_12px_0px_rgba(7,122,255,0.3)]
            Button(vm.isEditing ? "保存修改" : "创建会话") { vm.save() }
                .font(DesignTokens.Typography.bodyLargeMedium)
                .foregroundColor(.white)
                .frame(width: 120, height: 36)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 6, x: 0, y: 4)
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!vm.canSave)
                .opacity(vm.canSave ? 1.0 : 0.4)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.lg)
        .overlay(alignment: .top) {
            // 自评 P1#7：sessionForm slot Banner Host，覆盖表单顶部
            // 用于表单内 inline 错误恢复（独立于 Preflight 浮层）
            BannerHost(slot: .sessionForm)
                .padding(.top, 4)
                .allowsHitTesting(true)
        }
    }

    // MARK: - W4：测试连接结果面板（内联，带关闭按钮）

    private var preflightPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text("连接测试")
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(labelColor)
                Spacer()
                Button {
                    withAnimation(DesignTokens.Animation.fast) { showPreflightPanel = false }
                } label: {
                    AppIcon.close.image
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("关闭测试结果")
            }
            PreflightProgressView(result: preflightResult, isRunning: preflightRunning)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - W4 新增：触发 Preflight

    /// 由当前表单的认证配置构建预检认证方式。
    /// 仅 SSH 协议做握手+认证探测；无凭据时退化为 .skipAuth（仅测到握手）。
    private var preflightAuthMethod: PreflightAuthMethod {
        guard vm.connectionProtocol == "SSH" else { return .skipAuth }
        switch vm.authMethod {
        case .password:
            return vm.password.isEmpty ? .skipAuth : .password(vm.password)
        case .privateKey:
            guard !vm.privateKeyPath.isEmpty else { return .skipAuth }
            let expanded = (vm.privateKeyPath as NSString).expandingTildeInPath
            return .privateKey(path: expanded, passphrase: vm.passphrase.isEmpty ? nil : vm.passphrase)
        case .sshAgent:
            return .agent
        case .keyboardInteractive:
            return .skipAuth
        }
    }

    private func runPreflight() {
        let host = vm.host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        let portValue = Int(vm.port) ?? 22

        preflightRunning = true
        withAnimation(DesignTokens.Animation.fast) { showPreflightPanel = true }
        preflightResult = nil

        let auth = preflightAuthMethod
        Task {
            let result = await ConnectionPreflightService.shared.preflight(
                host: host,
                port: portValue,
                username: vm.username,
                authMethod: auth
            )
            await MainActor.run {
                preflightResult = result
                preflightRunning = false
                // 横切层通电 #1：触发 Feedback Toast
                fireFeedbackForPreflight(result, host: host)
            }
        }
    }

    /// W7：根据 Preflight 结果触发 FeedbackCenter Toast
    /// - 成功 → success Toast（含耗时）
    /// - 失败 → warn Toast（仅简要提示，详细建议保留在 PreflightProgressView 内）
    private func fireFeedbackForPreflight(_ result: PreflightResult, host: String) {
        switch result.summary {
        case .success:
            FeedbackCenter.shared.present(.success(
                "连接测试成功",
                message: "总耗时 \(result.totalElapsedMs)ms"
            ))
        case .failedAt(let stage, _):
            FeedbackCenter.shared.present(.warn(
                "测试失败：\(stageName(stage))",
                message: "详细原因见下方诊断"
            ))
        case .cancelled:
            break
        }
    }

    private func stageName(_ stage: PreflightStage) -> String {
        switch stage {
        case .dns:       return "DNS 解析"
        case .tcp:       return "TCP 建联"
        case .handshake: return "SSH 握手"
        case .auth:      return "身份认证"
        }
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
                        AppIcon.arrowClockwise.image
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
                            // Phase 3：术语 Tooltip — SSH Agent 解释
                            .help(vm.authMethod == .sshAgent
                                ? "SSH Agent 通过 $SSH_AUTH_SOCK 套接字使用系统已加载的私钥（需 ssh-add 添加）。App Store 版受 sandbox 限制无法访问"
                                : "选择身份认证方式：密码 / 私钥文件 / 已加载的 SSH Agent 密钥")
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
