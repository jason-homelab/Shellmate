import SwiftUI
import SwiftTerm
import AppKit

// MARK: - 终端视图
// SwiftTerm NSViewRepresentable 包装器已抽出至 SwiftTermViewRepresentable.swift（Phase 17）

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
            TerminalToolbarView(
                controller: controller,
                session: session,
                showSearch: $showSearch,
                isAIPanelOpen: $isAIPanelOpen,
                aiInitialError: $aiInitialError,
                showSummaryPanel: $showSummaryPanel,
                sessionFontSize: $sessionFontSize,
                minFontSize: minFontSize,
                maxFontSize: maxFontSize,
                onToggleSFTP: { toggleSFTPPanel() }
            )

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
        .modifier(TerminalViewStatusSyncModifier(
            isSelected: isSelected,
            controller: controller,
            showMonitorPanel: $showMonitorPanel,
            terminalViewRef: $terminalViewRef,
            onPushStatus: { pushToStatusStore() }
        ))
        .onChange(of: controller.state) { newState in
            // 将 TerminalController 的实际连接状态同步回 SessionStore
            AppEvent.postConnectionState(sessionId: session.id, state: newState.toConnectionState)
            if case .failed(let reason) = newState {
                connectionErrorMessage = reason
                showConnectionError = true
            }
            // W7：跟踪是否曾连接过，供 ConnectionStateOverlay 判定是否显示重连按钮
            if case .connected = newState {
                if !hasEverConnected {
                    // Phase 13：首次连接成功引导
                    OnboardingDirector.onFirstSuccessfulConnection()
                }
                hasEverConnected = true
            }
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
                    // Phase 4：真接入 — 触发 SessionStore 编辑当前会话
                    NotificationCenter.default.post(
                        name: .editSessionRequested,
                        object: nil,
                        userInfo: ["sessionId": session.id]
                    )
                }
            )
        }
        .modifier(TerminalViewSheetsModifier(
            session: session,
            controller: controller,
            onConnect: { connect() },
            showConnectionError: $showConnectionError,
            connectionErrorMessage: $connectionErrorMessage,
            showMonitorPanel: $showMonitorPanel,
            showSummaryPanel: $showSummaryPanel,
            pendingRiskyCommand: $pendingRiskyCommand,
            isAIPanelOpen: $isAIPanelOpen,
            aiInitialError: $aiInitialError
        ))
        .modifier(TerminalViewDialogsModifier(
            session: session,
            controller: controller,
            showCredentialWizard: $showCredentialWizard,
            wizardPassword: $wizardPassword,
            wizardSaveCredential: $wizardSaveCredential,
            connectionErrorMessage: $connectionErrorMessage,
            showConnectionError: $showConnectionError
        ))
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

                SFTPSidebarTab(controller: controller, onToggle: { toggleSFTPPanel() })

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

    // MARK: - 终端内容区

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
    /// Phase 14：已抽出到 TerminalStateOverlays.swift
    /// 原 4 个 overlay 子视图（~100 行）成为独立 TerminalStateOverlay struct
    private var stateOverlay: some View {
        TerminalStateOverlay(
            state: controller.state,
            session: session,
            maxReconnectAttempts: controller.reconnectConfig.maxAttempts,
            onConnect: { connect() },
            onCancelReconnect: { controller.cancelReconnect() },
            onDismissFailure: {
                showConnectionError = false
                Task { await controller.disconnect() }
            }
        )
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
                            },
                            // Phase 4：testNetwork 真接入 — 触发 Preflight DNS+TCP 检查
                            .testNetwork { @MainActor in
                                let result = await ConnectionPreflightService.shared.preflight(
                                    host: session.host, port: Int(session.port),
                                    username: session.username, authMethod: .skipAuth
                                )
                                if case .success = result.summary {
                                    FeedbackCenter.shared.present(.success(
                                        "网络可达",
                                        message: "DNS + TCP 检查通过，问题可能在远端 SFTP 子系统"
                                    ))
                                } else {
                                    FeedbackCenter.shared.present(.warn(
                                        "网络层异常",
                                        message: "测试连接面板可看详细原因"
                                    ))
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
