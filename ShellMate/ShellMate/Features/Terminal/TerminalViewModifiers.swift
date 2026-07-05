import SwiftUI
import SwiftTerm

// Phase 9：从 TerminalView.swift 抽出的 ViewModifier 与 helper view
// 原文件 1299 → ~1180 行（降幅 119 行）
// 这些是 W5 架构方案 §2 "TerminalView 拆分 Phase 1" 的最低风险一步

// MARK: - 通知处理 ViewModifier

/// 将 TerminalView 的菜单栏通知处理提取为独立 ViewModifier，
/// 避免 TerminalView.body 链式修饰符过多导致 Swift 类型检查超时
struct TerminalViewNotificationModifier: ViewModifier {

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

struct TerminalViewAlertModifier: ViewModifier {
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

// MARK: - Sheet 集群修饰符（Phase 17：从 TerminalView.body 抽出 7 个 .sheet）

/// 连接错误 / 服务器监控 / 会话摘要 / 高风险命令 / 密码向导 / 主机密钥确认·变更
/// 统一收敛到一个 ViewModifier，精简 TerminalView.body 并缓解类型检查压力。
struct TerminalViewSheetsModifier: ViewModifier {

    let session: Session
    let controller: TerminalController
    /// 连接错误弹窗「重试」回调（TerminalView.connect）
    let onConnect: () -> Void

    @Binding var showConnectionError: Bool
    @Binding var connectionErrorMessage: String
    @Binding var showMonitorPanel: Bool
    @Binding var showSummaryPanel: Bool
    @Binding var pendingRiskyCommand: CommandRisk?
    @Binding var isAIPanelOpen: Bool
    @Binding var aiInitialError: String?

    @EnvironmentObject private var aiSettings: AISettingsStore

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showConnectionError) {
                ConnectionErrorView(
                    session: session,
                    errorMessage: connectionErrorMessage,
                    onRetry: {
                        showConnectionError = false
                        onConnect()
                    },
                    onDismiss: { showConnectionError = false },
                    onAIDiagnose: aiSettings.isEnabled ? {
                        // AI-04：以连接错误上下文预填充 AI 助手面板
                        showConnectionError = false
                        aiInitialError = connectionErrorMessage
                        withAnimation(DesignTokens.Animation.standard) {
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
    }
}

// MARK: - 对话框集群修饰符（Phase 17：密码向导 + 主机密钥确认/变更）

/// 密码输入向导 / 首次主机密钥确认（D02）/ 主机密钥变更警告（D03）。
/// 与 TerminalViewSheetsModifier 拆分，避免单个 body 过长触发 function_body_length。
struct TerminalViewDialogsModifier: ViewModifier {

    let session: Session
    let controller: TerminalController

    @Binding var showCredentialWizard: Bool
    @Binding var wizardPassword: String
    @Binding var wizardSaveCredential: Bool
    @Binding var connectionErrorMessage: String
    @Binding var showConnectionError: Bool

    func body(content: Content) -> some View {
        content
            // 密码输入向导
            .sheet(isPresented: $showCredentialWizard) {
                CredentialWizardView(
                    session: session,
                    controller: controller,
                    isPresented: $showCredentialWizard,
                    password: $wizardPassword,
                    saveCredential: $wizardSaveCredential,
                    connectionErrorMessage: $connectionErrorMessage,
                    showConnectionError: $showConnectionError
                )
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
}

// MARK: - 状态同步修饰符（Phase 17：向共享底栏 ActiveTerminalStatusStore 推送）

/// 将活跃终端的连接状态 / 服务器指标 / 终端尺寸 / 连接时刻推送到共享底栏，
/// 并响应底栏「打开服务器监控」信号、把 SwiftTerm 视图引用回写给 controller。
struct TerminalViewStatusSyncModifier: ViewModifier {

    let isSelected: Bool
    let controller: TerminalController
    @Binding var showMonitorPanel: Bool
    @Binding var terminalViewRef: SwiftTerm.TerminalView?
    /// 推送当前终端状态到共享底栏（TerminalView.pushToStatusStore）
    let onPushStatus: () -> Void

    @EnvironmentObject private var terminalStatus: ActiveTerminalStatusStore

    func body(content: Content) -> some View {
        content
            // 当此 Tab 被选中时，将本终端状态推送到共享底栏
            .onChange(of: isSelected) { selected in
                if selected { onPushStatus() }
            }
            // controller 关键状态变化时同步推送
            .onChange(of: controller.state) { _ in onPushStatus() }
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
    }
}
