import SwiftUI
import SwiftTerm
import AppKit

// MARK: - SwiftTerm NSViewRepresentable 包装器

/// 将 SwiftTerm 的 AppKit TerminalView 包装为 SwiftUI 视图
struct SwiftTermViewRepresentable: NSViewRepresentable {

    /// 外部持有终端视图引用（用于调用 feed/font 等操作）
    @Binding var viewRef: SwiftTerm.TerminalView?
    /// 委托（TerminalController）
    var controller: TerminalController
    /// 当前字号
    var fontSize: CGFloat
    /// 当前字体族名称（PostScript 名，空字符串时回退到系统等宽字体）
    var fontFamily: String
    /// 当前主题 ID（从 AppStorage 传入，变化时触发 updateNSView）
    var themeId: String
    /// Option 键作为 Meta 键（对齐 terminal.optionAsMeta AppStorage）
    var optionAsMeta: Bool

    func makeNSView(context: Context) -> SwiftTerm.TerminalView {
        let view = SwiftTerm.TerminalView(frame: .zero)
        view.terminalDelegate = controller
        view.font = resolvedFont()
        view.optionAsMetaKey = optionAsMeta
        applyTheme(themeId, to: view)
        // 延迟赋值避免 SwiftUI 状态更新循环
        Task { @MainActor in viewRef = view }
        return view
    }

    func updateNSView(_ nsView: SwiftTerm.TerminalView, context: Context) {
        let resolved = resolvedFont()
        if nsView.font.fontName != resolved.fontName || nsView.font.pointSize != resolved.pointSize {
            nsView.font = resolved
        }
        if nsView.optionAsMetaKey != optionAsMeta {
            nsView.optionAsMetaKey = optionAsMeta
        }
        applyTheme(themeId, to: nsView)
    }

    private func resolvedFont() -> NSFont {
        if !fontFamily.isEmpty, let custom = NSFont(name: fontFamily, size: fontSize) {
            return custom
        }
        return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    // MARK: - 主题应用

    private func applyTheme(_ id: String, to view: SwiftTerm.TerminalView) {
        let theme = AppTheme.allThemes.first(where: { $0.id == id }) ?? AppTheme.builtins[0]
        // 设置背景色和前景色
        view.nativeBackgroundColor = NSColor(theme.background)
        view.nativeForegroundColor = NSColor(theme.outputColor)
        // 安装完整的 16 色 ANSI 调色板
        if theme.ansiColors.count == 16 {
            let palette = theme.ansiColors.map { hexToSwiftTermColor($0) }
            view.installColors(palette)
        }
    }

    /// 将十六进制颜色字符串转换为 SwiftTerm.Color（8 位值扩展为 16 位）
    private func hexToSwiftTermColor(_ hex: String) -> SwiftTerm.Color {
        let stripped = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: stripped).scanHexInt64(&int)
        let r = UInt16((int >> 16) & 0xFF)
        let g = UInt16((int >> 8)  & 0xFF)
        let b = UInt16(int         & 0xFF)
        // 8 位 → 16 位：r8 * 257 = r8 << 8 | r8（保证 0 → 0，255 → 65535 线性映射）
        return SwiftTerm.Color(red: r << 8 | r, green: g << 8 | g, blue: b << 8 | b)
    }
}

// MARK: - 终端视图

/// 完整的 SSH 终端界面：工具栏 + SwiftTerm 渲染 + 搜索覆层 + 状态覆层
struct TerminalView: View {

    // MARK: - 属性

    let session: Session

    /// 此终端是否为当前选中 Tab（由 ContentView 注入）
    /// 仅选中的 TerminalView 向 ActiveTerminalStatusStore 推送状态
    var isSelected: Bool = true

    @StateObject private var controller: TerminalController

    /// ContentView 级面板状态（工具面板已提升至 ContentView，通过 environmentObject 共享）
    @EnvironmentObject private var panels: ContentViewModel

    /// 共享底栏状态（由根节点 environmentObject 注入）
    @EnvironmentObject private var terminalStatus: ActiveTerminalStatusStore

    /// SwiftTerm TerminalView 引用
    @State private var terminalViewRef: SwiftTerm.TerminalView?

    /// 字体族（绑定到外观设置，通过 updateNSView 同步到 SwiftTerm）
    @AppStorage("appearance.fontFamily") private var fontFamily: String = ""
    /// 全局主题 ID（只读，用于无会话覆盖时回退）
    @AppStorage("appearance.themeId") private var globalThemeId: String = "shellmate-dark"
    /// 全局字号（只读，用于无会话覆盖时回退）
    @AppStorage("appearance.fontSize") private var globalFontSize: Double = 13
    /// Option 键是否作为 Meta 键（terminal.optionAsMeta）
    @AppStorage("terminal.optionAsMeta") private var optionAsMeta: Bool = false
    /// 会话级别工作字号：初始化自有效值，工具栏 ±1 只修改此值，不写回 AppStorage
    @State private var sessionFontSize: Double = 13

    /// 实际生效主题：会话有覆盖时取覆盖值，否则跟随全局
    private var effectiveThemeId: String {
        if let ov = session.overrideThemeId, !ov.isEmpty { return ov }
        return globalThemeId
    }

    private var effectiveThemeBackground: SwiftUI.Color {
        (AppTheme.allThemes.first { $0.id == effectiveThemeId } ?? AppTheme.builtins[0]).background
    }

    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var currentMatch: Int = 0
    @State private var totalMatches: Int = 0
    @State private var caseSensitive: Bool = false
    @State private var useRegex: Bool = false
    @State private var showConnectionError: Bool = false
    @State private var connectionErrorMessage: String = ""
    @State private var showSFTPError: Bool = false
    @State private var sftpErrorMessage: String = ""
    @State private var showTunnelError: Bool = false
    @State private var tunnelErrorMessage: String = ""
    /// 密码输入向导（password/keyboard-interactive 无凭据时显示）
    @State private var showCredentialWizard: Bool = false
    @State private var wizardPassword: String = ""
    @State private var wizardSaveCredential: Bool = true
    /// 私钥路径缺失提示（提示用户前往编辑会话）
    @State private var showPrivateKeyMissing: Bool = false
    /// 服务器监控面板
    @State private var showMonitorPanel: Bool = false
    /// W12.6：观察同步状态（由根节点 environmentObject 注入）
    @EnvironmentObject private var syncStore: SyncInputStore

    // MARK: - AI 助手

    /// AI 助手面板是否显示
    @State private var isAIPanelOpen: Bool = false
    /// 预填充的错误上下文（由错误侦探触发）
    @State private var aiInitialError: String? = nil
    /// AI-05：会话摘要面板是否显示
    @State private var showSummaryPanel: Bool = false
    /// AI-06：待执行的高风险命令（非 nil 时显示安全审计弹窗）
    @State private var pendingRiskyCommand: CommandRisk? = nil
    /// AI 设置观察（由根节点 environmentObject 注入）
    @EnvironmentObject private var aiSettings: AISettingsStore

    private let minFontSize: Double = Double(DesignTokens.Sizes.terminalFontSizeMin)
    private let maxFontSize: Double = Double(DesignTokens.Sizes.terminalFontSizeMax)

    /// SFTP 双栏面板宽度（使用设计令牌 sftpPanelWidth）
    @State private var sftpPanelWidth: CGFloat = DesignTokens.Sizes.sftpPanelWidth

    // MARK: - W7 横切层通电 #2：ConnectionStateOverlay 桥接

    /// 是否曾连接过（用于区分"初始 disconnected"与"已连接后掉线"）
    @State private var hasEverConnected: Bool = false

    /// 派生自 controller.state 的 W2 状态机表示，仅供 Overlay 使用
    /// 现有 .failed Sheet 不变，Overlay 仅承担 disconnected 重连 UX
    /// 自评 P1#9 修正：用 controller.lastDisconnectReason 区分用户主动 vs 网络丢失
    private var derivedTerminalState: TerminalConnectionState {
        switch controller.state {
        case .disconnected:
            guard hasEverConnected else { return .idle }
            // 用户主动断开 → 不弹 overlay 引导重连（语义上是用户预期的断开）
            // 网络/服务器异常断开 → 弹 overlay 引导重连
            let reason: TerminalConnectionState.DisconnectReason
            switch controller.lastDisconnectReason {
            case .userInitiated: reason = .userInitiated
            case .networkLost:   reason = .networkLost
            case .serverClosed:  reason = .serverClosed
            case .idleTimeout:   reason = .idleTimeout
            case .unknown:       reason = .networkLost  // 默认按网络丢失处理（引导重连）
            }
            return .disconnected(reason: reason)
        case .connecting:
            return .connecting(stage: .handshake)
        case .connected:
            return .connected(since: controller.connectedAt ?? Date())
        case .reconnecting(let attempt):
            return .reconnecting(attempt: attempt, maxAttempts: 5)
        case .failed:
            // .failed 沿用现有 Sheet 路径，Overlay 不参与
            return .idle
        }
    }

    // MARK: - 初始化

    init(session: Session, isSelected: Bool = true) {
        self.session = session
        self.isSelected = isSelected
        _controller = StateObject(wrappedValue: TerminalController(session: session))
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            toolbarView

            if showSearch {
                searchBarView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 终端主区域（含 Compose Pane 纵向布局）
            terminalAndComposeView

        }
        .background(DesignTokens.Colors.terminalBackground)
        .onAppear {
            // 初始化会话字号：有覆盖则用覆盖值，否则跟随全局
            sessionFontSize = session.overrideFontSize > 0
                ? Double(session.overrideFontSize)
                : globalFontSize
            // 注册至全局注册表，供 ContentView 查找 recorder 等
            TerminalControllerRegistry.shared.register(controller, for: session.id)
            Task { @MainActor in
                connect()
            }
            pushToStatusStore()
        }
        .onDisappear {
            TerminalControllerRegistry.shared.unregister(sessionId: session.id)
            // Tab 关闭时显式断开 SSH 连接，确保资源正常释放。
            // TerminalController.deinit 中无法可靠调用 disconnect（weak self 在 deinit 时已为 nil），
            // 因此必须在视图消失时主动断连。
            Task { await controller.disconnect() }
            // 重置 SessionStore 连接状态，避免侧边栏计数器不归零
            AppEvent.postConnectionState(sessionId: session.id, state: .offline)
        }
        .onChange(of: globalFontSize) { newVal in
            // 无会话覆盖时同步全局变化，不覆盖有独立字号的会话
            if session.overrideFontSize <= 0 {
                sessionFontSize = newVal
            }
        }
        // 当此 Tab 被选中时，将本终端状态推送到共享底栏
        .onChange(of: isSelected) { selected in
            if selected { pushToStatusStore() }
        }
        // controller 关键状态变化时同步推送
        .onChange(of: controller.state) { _ in pushToStatusStore() }
        .onChange(of: controller.serverMetrics) { _ in
            guard isSelected else { return }
            terminalStatus.serverMetrics = controller.serverMetrics
        }
        .onChange(of: controller.terminalSize) { _ in
            guard isSelected else { return }
            terminalStatus.terminalColumns = controller.terminalSize.columns
            terminalStatus.terminalRows = controller.terminalSize.rows
        }
        .onChange(of: controller.connectedAt) { _ in
            guard isSelected else { return }
            terminalStatus.connectedAt = controller.connectedAt
        }
        // 底栏触发"打开服务器监控"信号：由活跃 TerminalView 响应并显示 sheet
        .onChange(of: terminalStatus.shouldShowMonitorPanel) { should in
            if should && isSelected {
                showMonitorPanel = true
                terminalStatus.shouldShowMonitorPanel = false
            }
        }
        .onChange(of: terminalViewRef) { newView in
            controller.terminalView = newView
        }
        .onChange(of: controller.state) { newState in
            // 将 TerminalController 的实际连接状态同步回 SessionStore
            AppEvent.postConnectionState(sessionId: session.id, state: newState.toConnectionState)
            if case .failed(let reason) = newState {
                connectionErrorMessage = reason
                showConnectionError = true
            }
            // W7：跟踪是否曾连接过，供 ConnectionStateOverlay 判定是否显示重连按钮
            if case .connected = newState { hasEverConnected = true }
        }
        // Phase 2：BannerHost(.terminal) slot 接入，让 Feedback Banner 可在终端内显示
        .overlay(alignment: .top) {
            BannerHost(slot: .terminal)
                .padding(.top, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.md)
        }
        // W7 横切层通电 #2：在 disconnected 后挂出 ConnectionStateOverlay
        // .failed 仍走原 Sheet 路径，二者互斥（derivedTerminalState 已在 .failed 返回 .idle）
        .overlay {
            ConnectionStateOverlay(
                state: derivedTerminalState,
                onReconnect: {
                    Task { @MainActor in connect() }
                },
                onCancel: {
                    // 用户主动取消重连引导，不主动断连，仅隐藏 overlay（标记 idle）
                    hasEverConnected = false
                },
                onEditCredentials: {
                    // 未来接 AI/Settings 入口；先用 Toast 占位提示
                    FeedbackCenter.shared.present(.info("请前往会话编辑修改凭据"))
                }
            )
        }
        .sheet(isPresented: $showConnectionError) {
            ConnectionErrorView(
                session: session,
                errorMessage: connectionErrorMessage,
                onRetry: {
                    showConnectionError = false
                    connect()
                },
                onDismiss: { showConnectionError = false },
                onAIDiagnose: aiSettings.isEnabled ? {
                    // AI-04：以连接错误上下文预填充 AI 助手面板
                    showConnectionError = false
                    aiInitialError = connectionErrorMessage
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAIPanelOpen = true
                    }
                } : nil
            )
        }
        .sheet(isPresented: $showMonitorPanel) {
            ServerMonitorPanelView(
                session: session,
                metrics: Binding(
                    get: { controller.serverMetrics },
                    set: { _ in }
                ),
                onClose: { showMonitorPanel = false }
            )
        }
        // AI-05：会话摘要面板
        .sheet(isPresented: $showSummaryPanel) {
            AISummaryView(
                sessionName: "\(session.name) · \(session.username)@\(session.host)",
                terminalOutput: controller.recentTerminalOutput(),
                onClose: { showSummaryPanel = false }
            )
        }
        // AI-06：高风险命令安全审计弹窗
        .sheet(item: $pendingRiskyCommand) { risk in
            CommandSafetyAlertView(
                risk: risk,
                onConfirm: {
                    pendingRiskyCommand = nil
                    controller.sendComposeContent(risk.command + "\r")
                },
                onCancel: {
                    pendingRiskyCommand = nil
                }
            )
        }
        .modifier(TerminalViewAlertModifier(
            showSFTPError: $showSFTPError, sftpErrorMessage: sftpErrorMessage,
            showTunnelError: $showTunnelError, tunnelErrorMessage: tunnelErrorMessage
        ))
        .modifier(TerminalViewNotificationModifier(
            sessionId: session.id,
            isSelected: isSelected,
            controller: controller,
            showSearch: $showSearch,
            fontSize: $sessionFontSize,
            isAIPanelOpen: $isAIPanelOpen,
            aiInitialError: $aiInitialError,
            minFontSize: minFontSize,
            maxFontSize: maxFontSize,
            onToggleSFTP: toggleSFTPPanel
        ))
        // 监听凭据缺失状态
        .onChange(of: controller.needsCredentialInput) { needed in
            if needed {
                wizardPassword = ""
                wizardSaveCredential = true
                showCredentialWizard = true
            }
        }
        .onChange(of: controller.needsCredentialEdit) { needed in
            if needed { showPrivateKeyMissing = true }
        }
        // W12.5：搜索文本变化时触发 SwiftTerm 搜索
        .onChange(of: searchText) { _ in
            if searchText.isEmpty {
                terminalViewRef?.clearSearch()
                totalMatches = 0
                currentMatch = 0
            } else {
                findNext()
            }
        }
        .onChange(of: caseSensitive) { _ in
            guard !searchText.isEmpty else { return }
            findNext()
        }
        .onChange(of: useRegex) { _ in
            guard !searchText.isEmpty else { return }
            findNext()
        }
        // 私钥路径未配置提示
        .alert("私钥路径未配置", isPresented: $showPrivateKeyMissing) {
            Button("确定", role: .cancel) {
                showPrivateKeyMissing = false
                controller.needsCredentialEdit = false
            }
        } message: {
            Text("此会话使用私钥认证，但未设置私钥文件路径。请在「编辑会话 → 认证」中选择私钥文件后再连接。")
        }
        // 密码输入向导
        .sheet(isPresented: $showCredentialWizard) {
            credentialWizardView
        }
        // D02：首次连接新主机，显示主机密钥确认弹窗
        .sheet(
            isPresented: Binding(
                get: {
                    if case .newHost = controller.pendingHostKeyState { return true }
                    return false
                },
                set: { if !$0 { controller.rejectHostKey() } }
            )
        ) {
            if case .newHost(let fingerprint) = controller.pendingHostKeyState {
                HostKeyConfirmationView(
                    host: session.host,
                    port: session.port,
                    fingerprint: fingerprint,
                    onConfirm: { controller.acceptNewHostKey() },
                    onCancel: { controller.rejectHostKey() }
                )
                .frame(width: 560)
            }
        }
        // D03：主机密钥变更，显示安全警告弹窗
        .sheet(
            isPresented: Binding(
                get: {
                    if case .changedHost = controller.pendingHostKeyState { return true }
                    return false
                },
                set: { if !$0 { controller.rejectHostKey() } }
            )
        ) {
            if case .changedHost(let oldFP, let newFP) = controller.pendingHostKeyState {
                HostKeyChangedWarningView(
                    host: session.host,
                    port: session.port,
                    oldFingerprint: oldFP,
                    newFingerprint: newFP,
                    onProceed: { controller.acceptChangedHostKey() },
                    onCancel: { controller.rejectHostKey() }
                )
                .frame(width: 600)
            }
        }
    }

    // MARK: - 子视图

    /// 终端主区域 + Compose Pane 纵向布局（提取为独立属性以规避类型检查超时）
    private var terminalAndComposeView: some View {
        VStack(spacing: 0) {
            // 终端内容区 + SFTP 右侧边栏 + AI 助手面板
            HStack(spacing: 0) {
                // 终端内容 + 错误侦探徽章叠加
                ZStack(alignment: .bottomTrailing) {
                    terminalContentView

                    // AI 错误侦探悬浮徽章
                    if aiSettings.isEnabled,
                       aiSettings.errorDetectiveEnabled,
                       let errText = controller.detectedErrorText {
                        AIErrorDetectiveView(
                            errorText: errText,
                            onAnalyze: { text in
                                aiInitialError = text
                                withAnimation(DesignTokens.Animation.standard) {
                                    isAIPanelOpen = true
                                }
                                controller.clearDetectedError()
                            },
                            onDismiss: {
                                controller.clearDetectedError()
                            }
                        )
                        .padding(DesignTokens.Spacing.md)
                        .zIndex(10)
                    }
                }

                sftpSidebarTabView

                if controller.isSFTPPanelOpen,
                   let sftpSess = controller.sftpSession,
                   let transferQueue = controller.sftpTransferQueue {
                    SFTPPanelView(
                        sftpSession: sftpSess,
                        transferQueue: transferQueue,
                        sessionName: session.name,
                        syncDirectory: controller.currentRemoteDirectory,
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                _ = Task { await controller.closeSFTPPanel() }
                            }
                        }
                    )
                    .frame(width: sftpPanelWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                // AI 助手右侧面板
                if isAIPanelOpen {
                    AIAssistantPanelView(
                        session: session,
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAIPanelOpen = false
                                aiInitialError = nil
                                panels.showAIPanel = false
                            }
                        },
                        initialError: aiInitialError,
                        onInsertCommand: { command in
                            // AI-06：安全检查，高风险命令弹窗拦截
                            if let risk = CommandSafetyChecker.check(command) {
                                pendingRiskyCommand = risk
                            } else {
                                controller.sendComposeContent(command + "\r")
                            }
                        }
                    )
                    .frame(width: DesignTokens.Sizes.aiPanelWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            if controller.isComposePaneOpen {
                ComposePaneView(
                    onSend: { text in
                        // AI-06：安全检查，高风险命令弹窗拦截
                        if let risk = CommandSafetyChecker.check(text) {
                            pendingRiskyCommand = risk
                        } else {
                            controller.sendComposeContent(text)
                        }
                    },
                    onClose: { controller.isComposePaneOpen = false },
                    contextProvider: { controller.recentTerminalOutput() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // 移除 TerminalStatusBarView 后，SwiftTerm NSView 会按 intrinsicContentSize 定高。
        // 必须显式声明 maxHeight: .infinity，确保终端区域填满 VStack 中的剩余空间。
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var toolbarView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 终端标题（已连接时显示，如 "ubuntu@host: ~"）
            if !controller.terminalTitle.isEmpty {
                Text(controller.terminalTitle)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // 右侧工具按钮
            toolButtonsView
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 36)
        .background {
            Rectangle()
                .fill(DesignTokens.Colors.surfacePanel)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignTokens.Colors.glassBorderSide)
                        .frame(height: 0.5)
                }
        }
    }

    private var toolButtonsView: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.xxs) {
            fontSizeControls

            toolbarDivider

            ToolbarButton(icon: "clear", tooltip: "清屏 (⌘K)") {
                controller.clearTerminal()
            }

            ToolbarButton(
                icon: "magnifyingglass",
                tooltip: "搜索 (⌘F)",
                isActive: showSearch
            ) {
                withAnimation { showSearch.toggle() }
            }

            toolbarDivider

            // SFTP 文件管理器按钮
            ToolbarButton(
                icon: "arrow.up.arrow.down",
                tooltip: "SFTP 文件管理器",
                isEnabled: controller.state == .connected,
                isActive: controller.isSFTPPanelOpen
            ) {
                toggleSFTPPanel()
            }

            // 隧道管理器按钮（⌘⇧U）
            ToolbarButton(
                icon: "arrow.left.arrow.right",
                tooltip: "隧道管理器 (⌘⇧U)",
                isActive: panels.showTunnelPanel
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { panels.showTunnelPanel.toggle() }
            }

            // tmux 会话管理器按钮（⌘⇧T）
            if case .available = controller.tmuxStore.availability {
                ToolbarButton(
                    icon: "rectangle.3.group",
                    tooltip: "tmux 会话管理器 (⌘⇧T)",
                    isActive: panels.showTmuxPanel,
                    tintColor: panels.showTmuxPanel ? DesignTokens.Colors.accentPrimary : nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { panels.showTmuxPanel.toggle() }
                }
            }

            // Compose Pane 按钮
            ToolbarButton(
                icon: "text.alignleft",
                tooltip: "命令编辑区",
                isActive: controller.isComposePaneOpen
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    controller.isComposePaneOpen.toggle()
                }
            }

            // W11：快捷命令管理器按钮（⌘⇧K）
            ToolbarButton(
                icon: "list.bullet.rectangle",
                tooltip: "快捷命令 (⌘⇧K)",
                isActive: panels.showQuickCommandPanel
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { panels.showQuickCommandPanel.toggle() }
            }

            // W12.6：同步输入按钮（O03）
            ToolbarButton(
                icon: syncStore.isSynced(session.id) ? "square.grid.2x2.fill" : "square.grid.2x2",
                tooltip: syncStore.isSynced(session.id) ? "关闭同步输入" : "同步输入",
                isEnabled: controller.state == .connected,
                isActive: syncStore.isSynced(session.id),
                tintColor: syncStore.isSynced(session.id) ? DesignTokens.Colors.statusConnecting : nil
            ) {
                if syncStore.isSynced(session.id) {
                    syncStore.deactivate()
                } else {
                    panels.syncInputSessionId = session.id
                    withAnimation(.easeInOut(duration: 0.2)) { panels.showSyncInputPanel = true }
                }
            }

            toolbarDivider

            // AI 助手按钮（仅在 AI 功能启用时显示）
            if aiSettings.isEnabled {
                ToolbarButton(
                    icon: "sparkles",
                    tooltip: "AI 助手 (⌘⇧A)",
                    isActive: isAIPanelOpen,
                    tintColor: isAIPanelOpen ? nil : (controller.detectedErrorText != nil ? DesignTokens.Colors.statusConnecting : nil)
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAIPanelOpen.toggle()
                        if !isAIPanelOpen { aiInitialError = nil }
                    }
                }

                // AI-05：会话摘要按钮（⌘⇧S）
                ToolbarButton(
                    icon: "text.viewfinder",
                    tooltip: "会话摘要 (⌘⇧S)",
                    isEnabled: controller.state == .connected
                ) {
                    showSummaryPanel = true
                }
            }
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(DesignTokens.Colors.borderSecondary)
            .frame(width: 1, height: 16)
            .padding(.horizontal, DesignTokens.Spacing.xxs)
    }

    private var fontSizeControls: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.xxs) {
            ToolbarButton(
                icon: "minus.magnifyingglass",
                tooltip: "减小字号 (⌘-)",
                isEnabled: sessionFontSize > minFontSize
            ) {
                sessionFontSize = max(minFontSize, sessionFontSize - 1)
            }

            Text("\(Int(sessionFontSize))pt")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 34)
                .multilineTextAlignment(.center)

            ToolbarButton(
                icon: "plus.magnifyingglass",
                tooltip: "增大字号 (⌘+)",
                isEnabled: sessionFontSize < maxFontSize
            ) {
                sessionFontSize = min(maxFontSize, sessionFontSize + 1)
            }
        }
    }

    private var searchBarView: some View {
        TerminalSearchBar(
            searchText: $searchText,
            currentMatch: $currentMatch,
            totalMatches: totalMatches,
            caseSensitive: $caseSensitive,
            useRegex: $useRegex,
            onClose: {
                withAnimation {
                    showSearch = false
                    searchText = ""
                    terminalViewRef?.clearSearch()
                    totalMatches = 0
                    currentMatch = 0
                }
            },
            onNext: findNext,
            onPrevious: findPrevious
        )
        .padding(DesignTokens.Spacing.sm)
    }

    // MARK: - SFTP 右侧 Sidebar

    /// SFTP 右侧边栏 Tab 条（始终可见，20pt 宽）
    /// 参考 Figma Screen 03：SFTPPanel 在 TerminalArea 右侧；左边框作为面板分隔线
    private var sftpSidebarTabView: some View {
        VStack(spacing: 0) {
            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    toggleSFTPPanel()
                }
            } label: {
                VStack(spacing: DesignTokens.Spacing.micro) {
                    // 箭头方向指示（展开 ← / 收起 →）
                    Image(systemName: controller.isSFTPPanelOpen ? "chevron.right" : "chevron.left")
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    // SFTP 图标（Figma: folder.fill）
                    AppIcon.folderFill.image
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(
                            controller.isSFTPPanelOpen
                                ? DesignTokens.Colors.accentPrimary
                                : DesignTokens.Colors.textTertiary
                        )

                    // "SFTP" 纵向标签（面板收起时显示）
                    if !controller.isSFTPPanelOpen {
                        Text("SFTP")
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .rotationEffect(.degrees(-90))
                            .fixedSize()
                    }
                }
                .frame(width: 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .disabled(controller.state != .connected && !controller.isSFTPPanelOpen)
            .help(controller.isSFTPPanelOpen ? "隐藏 SFTP 面板" : "SFTP 文件管理器")

            Spacer()
        }
        .frame(width: 20)
        .background(DesignTokens.Colors.surfacePanel)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(DesignTokens.Colors.borderFaint),
            alignment: .leading
        )
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(DesignTokens.Colors.borderFaint),
            alignment: .trailing
        )
    }

    private var terminalContentView: some View {
        ZStack {
            SwiftTermViewRepresentable(
                viewRef: $terminalViewRef,
                controller: controller,
                fontSize: CGFloat(sessionFontSize),
                fontFamily: fontFamily,
                themeId: effectiveThemeId,
                optionAsMeta: optionAsMeta
            )
            // Figma 9:15: terminal text 需要左侧呼吸空间；仅内缩 SwiftTerm NSView，
            // ZStack 覆盖层和侧边面板不受影响；背景由父级 .background(effectiveThemeBackground) 提供同色填充
            .padding(.leading, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            stateOverlay

            // W12.6：同步输入激活时橙色边框指示
            if syncStore.isSynced(session.id) {
                Rectangle()
                    .stroke(DesignTokens.Colors.statusConnecting, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 用当前主题背景色填充 SwiftTerm 左侧内缩区域，避免与用户自定义主题色不匹配
        .background(effectiveThemeBackground)
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch controller.state {
        case .disconnected:     disconnectedOverlay
        case .connecting:       connectingOverlay
        case .reconnecting(let attempt): reconnectingOverlay(attempt: attempt)
        case .failed(let reason): failedOverlay(reason: reason)
        case .connected:        EmptyView()
        }
    }

    private var disconnectedOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "terminal")
                .font(DesignTokens.Typography.heroLarge)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text("未连接")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("\(session.username)@\(session.host):\(session.port)")
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Button(action: connect) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    AppIcon.quickCommand.image
                    Text("连接")
                }
                .font(DesignTokens.Typography.labelLarge)
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xxl)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.95))
    }

    private var connectingOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView().controlSize(.large)
            Text("正在连接...")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Text("\(session.username)@\(session.host)")
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.9))
    }

    private func reconnectingOverlay(attempt: Int) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView().controlSize(.large)
            Text("正在重连...")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Text("第 \(attempt) 次尝试，共 \(controller.reconnectConfig.maxAttempts) 次")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Button("取消") { controller.cancelReconnect() }
                .buttonStyle(.bordered)
                .padding(.top, DesignTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.9))
    }

    private func failedOverlay(reason: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            AppIcon.feedbackWarn.image
                .font(DesignTokens.Typography.heroLarge)
                .foregroundColor(DesignTokens.Colors.statusError)

            Text("连接失败")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text(reason)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xxxl)

            HStack(spacing: DesignTokens.Spacing.md) {
                Button("重试") { connect() }.buttonStyle(.borderedProminent)
                Button("关闭") {
                    showConnectionError = false
                    Task { await controller.disconnect() }
                }.buttonStyle(.bordered)
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.95))
    }

    // MARK: - 密码输入向导

    private var credentialWizardView: some View {
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
                Button(action: {
                    showCredentialWizard = false
                    controller.needsCredentialInput = false
                }) {
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
                    CustomTextField(placeholder: "请输入密码", text: $wizardPassword, isSecure: true)
                        .onSubmit { confirmCredentialWizard() }
                }

                // 记住密码选项
                HStack {
                    Text("记住密码（保存到本设备凭据金库）")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Spacer()
                    Toggle("", isOn: $wizardSaveCredential)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            HStack {
                Spacer()
                Button("取消") {
                    showCredentialWizard = false
                    controller.needsCredentialInput = false
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])

                Button("连接") {
                    confirmCredentialWizard()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(wizardPassword.isEmpty)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 380)
        .background(DesignTokens.Colors.surfacePanel)
    }

    private func confirmCredentialWizard() {
        guard !wizardPassword.isEmpty else { return }
        let pwd = wizardPassword
        let save = wizardSaveCredential
        // 立即清零内存中的明文密码，避免残留
        wizardPassword.removeAll(keepingCapacity: false)
        showCredentialWizard = false
        Task {
            do {
                try await controller.connectWithTemporaryPassword(pwd, save: save)
            } catch let error as SSHError {
                connectionErrorMessage = error.localizedDescription
                showConnectionError = true
            }
        }
    }

    // MARK: - 方法

    /// 将本终端当前状态推送到共享底栏 store（仅 isSelected 时有效）
    private func pushToStatusStore() {
        guard isSelected else { return }
        let store = terminalStatus
        let ctrl = controller
        store.connectionState = ctrl.state.toConnectionState
        store.session = session
        store.serverMetrics = ctrl.serverMetrics
        store.terminalColumns = ctrl.terminalSize.columns
        store.terminalRows = ctrl.terminalSize.rows
        store.encoding = session.encoding
        store.connectedAt = ctrl.connectedAt
        store.latencyMs = ctrl.latencyMs
        store.tmuxAttachedSession = ctrl.tmuxStore.attachedSessionName
        store.tmuxSessionCount = ctrl.tmuxStore.sessions.count
        store.tmuxWindows = {
            guard let name = ctrl.tmuxStore.attachedSessionName else { return [] }
            return ctrl.tmuxStore.sessions.first(where: { $0.name == name })?.windows ?? []
        }()
        store.onSelectTmuxWindow = { index in ctrl.tmuxStore.selectWindow(index: index) }
    }

    private func connect() {
        Task {
            do {
                try await controller.connect()
            } catch let error as SSHError {
                connectionErrorMessage = error.localizedDescription
                showConnectionError = true
            }
        }
    }

    private func toggleSFTPPanel() {
        if controller.isSFTPPanelOpen {
            Task {
                await controller.closeSFTPPanel()
            }
        } else {
            Task {
                do {
                    try await controller.openSFTPPanel()
                } catch {
                    // 保留原 Alert 路径（向后兼容），同时叠加 W7 Feedback Banner
                    // 含 retry Action：演示横切层通电 #4 错误恢复路径
                    sftpErrorMessage = error.localizedDescription
                    showSFTPError = true
                    FeedbackCenter.shared.present(.error(
                        "SFTP 连接失败",
                        message: LocalizedStringKey(error.localizedDescription),
                        actions: [
                            .retry { @MainActor in
                                do {
                                    try await controller.openSFTPPanel()
                                } catch {
                                    AppLogger.sftp.warning("SFTP retry failed: \(error.localizedDescription, privacy: .public)")
                                }
                            }
                        ],
                        bannerSlot: .global
                    ))
                }
            }
        }
    }

    // MARK: - W12.5 终端搜索（接入 SwiftTerm）

    private func findNext() {
        guard !searchText.isEmpty else { return }
        let opts = SearchOptions(caseSensitive: caseSensitive, regex: useRegex)
        let found = terminalViewRef?.findNext(searchText, options: opts) ?? false
        totalMatches = found ? 1 : 0
        currentMatch = found ? 1 : 0
    }

    private func findPrevious() {
        guard !searchText.isEmpty else { return }
        let opts = SearchOptions(caseSensitive: caseSensitive, regex: useRegex)
        let found = terminalViewRef?.findPrevious(searchText, options: opts) ?? false
        totalMatches = found ? 1 : 0
        currentMatch = found ? 1 : 0
    }
}

// MARK: - 通知处理 ViewModifier

/// 将 TerminalView 的菜单栏通知处理提取为独立 ViewModifier，
/// 避免 TerminalView.body 链式修饰符过多导致 Swift 类型检查超时
private struct TerminalViewNotificationModifier: ViewModifier {

    let sessionId: UUID
    let isSelected: Bool
    let controller: TerminalController
    @Binding var showSearch: Bool
    @Binding var fontSize: Double
    @Binding var isAIPanelOpen: Bool
    @Binding var aiInitialError: String?
    let minFontSize: Double
    let maxFontSize: Double
    let onToggleSFTP: () -> Void
    @EnvironmentObject private var panels: ContentViewModel

    func body(content: Content) -> some View {
        content
            // 断开连接（通过 sessionId 精确路由）
            .onReceive(NotificationCenter.default.publisher(for: .disconnectActiveTerminalRequested)) { notification in
                guard let targetId = AppEvent.extractDisconnectTerminal(from: notification),
                      targetId == sessionId else { return }
                Task { await controller.disconnect() }
            }
            // 面板控制
            .onReceive(NotificationCenter.default.publisher(for: .sftpPanelRequested)) { _ in
                guard isSelected else { return }
                onToggleSFTP()
                panels.showSFTPPanel = controller.isSFTPPanelOpen
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiPanelRequested)) { _ in
                guard isSelected else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAIPanelOpen.toggle()
                    if !isAIPanelOpen { aiInitialError = nil }
                }
                panels.showAIPanel = isAIPanelOpen
            }
            .onReceive(NotificationCenter.default.publisher(for: .composePaneRequested)) { _ in
                guard isSelected else { return }
                withAnimation(.easeInOut(duration: 0.2)) { controller.isComposePaneOpen.toggle() }
            }
            // 终端控制（仅作用于当前活跃 Tab，其余 Tab 的 TerminalView 虽然存活在 ZStack 中也不响应）
            .onReceive(NotificationCenter.default.publisher(for: .clearTerminalRequested)) { _ in
                guard isSelected else { return }
                controller.clearTerminal()
            }
            .onReceive(NotificationCenter.default.publisher(for: .searchTerminalRequested)) { _ in
                guard isSelected else { return }
                withAnimation { showSearch.toggle() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .increaseFontRequested)) { _ in
                fontSize = min(maxFontSize, fontSize + 1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .decreaseFontRequested)) { _ in
                fontSize = max(minFontSize, fontSize - 1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetFontRequested)) { _ in
                fontSize = 13
            }
            // 脚本库：将脚本内容逐行发送到活跃终端
            .onReceive(NotificationCenter.default.publisher(for: .runScriptRequested)) { notification in
                guard isSelected,
                      let (content, _) = AppEvent.extractRunScript(from: notification) else { return }
                Task {
                    let lines = content.components(separatedBy: "\n")
                    for line in lines {
                        guard !line.hasPrefix("#") else { continue } // 跳过注释行
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { continue }
                        try? await controller.send(trimmed + "\r")
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms 行间延迟
                    }
                }
            }
    }
}

// MARK: - 多终端标签视图

struct MultiTerminalView: View {

    @ObservedObject var sessionManager: TerminalSessionManager
    let sessions: [Session]

    var body: some View {
        if let selectedId = sessionManager.selectedControllerId,
           let session = sessions.first(where: { $0.id == selectedId }) {
            TerminalView(session: session)
        } else {
            Text("请从侧边栏选择会话")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}


// MARK: - 连接相关 Alert 修饰符（拆分以避免类型检查超时）

private struct TerminalViewAlertModifier: ViewModifier {
    @Binding var showSFTPError: Bool
    let sftpErrorMessage: String
    @Binding var showTunnelError: Bool
    let tunnelErrorMessage: String

    func body(content: Content) -> some View {
        content
            .alert("SFTP 连接失败", isPresented: $showSFTPError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(sftpErrorMessage)
            }
            .alert("隧道启动失败", isPresented: $showTunnelError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(tunnelErrorMessage)
            }
    }
}
