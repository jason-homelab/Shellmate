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

    func makeNSView(context: Context) -> SwiftTerm.TerminalView {
        let view = SwiftTerm.TerminalView(frame: .zero)
        view.terminalDelegate = controller
        view.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        // 延迟赋值避免 SwiftUI 状态更新循环
        DispatchQueue.main.async { viewRef = view }
        return view
    }

    func updateNSView(_ nsView: SwiftTerm.TerminalView, context: Context) {
        if nsView.font.pointSize != fontSize {
            nsView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }
}

// MARK: - 终端视图

/// 完整的 SSH 终端界面：工具栏 + SwiftTerm 渲染 + 搜索覆层 + 状态覆层
struct TerminalView: View {

    // MARK: - 属性

    let session: Session

    @StateObject private var controller: TerminalController

    /// SwiftTerm TerminalView 引用
    @State private var terminalViewRef: SwiftTerm.TerminalView?

    /// 字号（绑定到外观设置，通过 updateNSView 同步到 SwiftTerm）
    @AppStorage("appearance.fontSize") private var fontSize: Double = 13

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
    /// W11：快捷命令面板是否显示
    @State private var isQuickCommandOpen: Bool = false
    /// W12.3：凭据缺失提示弹窗
    @State private var showCredentialsMissing: Bool = false
    /// W12.6：同步输入确认弹窗
    @State private var showSyncConfirm: Bool = false
    /// W12.6：观察同步状态
    @ObservedObject private var syncStore = SyncInputStore.shared

    private let minFontSize: Double = 9
    private let maxFontSize: Double = 24

    // MARK: - 初始化

    init(session: Session) {
        self.session = session
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
            let terminalAndCompose = VStack(spacing: 0) {
                // 终端 + SFTP 面板水平分割
                if controller.isSFTPPanelOpen,
                   let sftpSess = controller.sftpSession,
                   let transferQueue = controller.sftpTransferQueue {
                    HSplitView {
                        terminalContentView
                            .frame(minWidth: 300)
                        SFTPPanelView(
                            sftpSession: sftpSess,
                            transferQueue: transferQueue,
                            onClose: {
                                Task { await controller.closeSFTPPanel() }
                            }
                        )
                        .frame(minWidth: 280, maxWidth: 600)
                    }
                } else {
                    terminalContentView
                }

                // Compose Pane（O02）停靠于终端下方
                if controller.isComposePaneOpen {
                    ComposePaneView(
                        onSend: { text in controller.sendComposeContent(text) },
                        onClose: { controller.isComposePaneOpen = false }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            terminalAndCompose

            // 底部状态栏（连接状态 + 已连接时长 + 终端尺寸 + 编码）
            TerminalStatusBarView(
                connectionState: controller.state.stateColor,
                columns: controller.terminalSize.columns,
                rows: controller.terminalSize.rows,
                encoding: session.encoding,
                connectedAt: controller.connectedAt
            )

            // 隧道管理器浮动面板（⌘⇧U）
            if controller.isTunnelManagerOpen {
                Color.clear
                    .overlay(
                        TunnelManagerView(
                            tunnelManager: controller.tunnelManager,
                            onClose: { controller.closeTunnelManager() }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    )
                    .allowsHitTesting(true)
            }

            // W11：快捷命令管理器浮动面板（⌘⇧K）
            if isQuickCommandOpen {
                Color.clear
                    .overlay(
                        QuickCommandManagerView(
                            store: QuickCommandStore.shared,
                            onSendCommand: { cmd in controller.sendQuickCommand(cmd) },
                            onClose: { withAnimation { isQuickCommandOpen = false } }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    )
                    .allowsHitTesting(true)
            }

            // W12.6：同步输入确认弹窗
            if showSyncConfirm {
                Color.clear
                    .overlay(
                        SyncInputConfirmView(
                            currentSessionId: session.id,
                            onConfirm: { ids in
                                syncStore.activate(sessionIds: ids)
                                showSyncConfirm = false
                            },
                            onCancel: { showSyncConfirm = false }
                        )
                    )
                    .allowsHitTesting(true)
            }
        }
        .background(DesignTokens.Colors.surfaceWindow)
        .onAppear {
            Task { @MainActor in
                connect()
            }
        }
        .onChange(of: terminalViewRef) { newView in
            controller.terminalView = newView
        }
        .onChange(of: controller.state) { newState in
            if case .failed(let reason) = newState {
                connectionErrorMessage = reason
                showConnectionError = true
            }
        }
        .alert("连接错误", isPresented: $showConnectionError) {
            Button("重试") { connect() }
            Button("取消", role: .cancel) {}
        } message: {
            Text(connectionErrorMessage)
        }
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
        // 菜单栏通知监听：SFTP / 隧道 / 快捷命令 / Compose Pane
        .onReceive(NotificationCenter.default.publisher(for: .sftpPanelRequested)) { _ in
            toggleSFTPPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tunnelManagerRequested)) { _ in
            if controller.isTunnelManagerOpen { controller.closeTunnelManager() }
            else { controller.openTunnelManager() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickCommandsRequested)) { _ in
            withAnimation { isQuickCommandOpen.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .composePaneRequested)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { controller.isComposePaneOpen.toggle() }
        }
        // 菜单栏通知监听：清屏 / 搜索 / 字体
        .onReceive(NotificationCenter.default.publisher(for: .clearTerminalRequested)) { _ in
            controller.clearTerminal()
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchTerminalRequested)) { _ in
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
        // W12.3：监听凭据缺失状态
        .onChange(of: controller.credentialsMissing) { missing in
            if missing { showCredentialsMissing = true }
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
        // W12.3：凭据缺失提示
        .alert("本设备凭据缺失", isPresented: $showCredentialsMissing) {
            Button("前往编辑") {
                // 此处可触发编辑会话的导航；当前版本仅关闭弹窗
                showCredentialsMissing = false
                controller.credentialsMissing = false
            }
            Button("取消", role: .cancel) {
                showCredentialsMissing = false
                controller.credentialsMissing = false
            }
        } message: {
            Text("此会话的密码/密钥未在本设备的 Keychain 中找到，可能是通过 iCloud 同步过来的。请在编辑会话页面重新输入凭据后再连接。")
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

    private var toolbarView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                StatusDotView(state: controller.state.stateColor)
                Text(controller.state.displayName)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            if !controller.terminalTitle.isEmpty {
                Text(controller.terminalTitle)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            toolButtonsView
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfacePanel)
        .overlay(Divider(), alignment: .bottom)
    }

    private var toolButtonsView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            fontSizeControls

            Divider().frame(height: 16).padding(.horizontal, DesignTokens.Spacing.xs)

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

            Divider().frame(height: 16).padding(.horizontal, DesignTokens.Spacing.xs)

            // SFTP 文件管理器按钮
            ToolbarButton(
                icon: "folder.fill.badge.wifi",
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
                isActive: controller.isTunnelManagerOpen
            ) {
                if controller.isTunnelManagerOpen {
                    controller.closeTunnelManager()
                } else {
                    controller.openTunnelManager()
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
                isActive: isQuickCommandOpen
            ) {
                withAnimation { isQuickCommandOpen.toggle() }
            }

            // W12.6：同步输入按钮（O03）
            ToolbarButton(
                icon: syncStore.isSynced(session.id) ? "square.grid.2x2.fill" : "square.grid.2x2",
                tooltip: syncStore.isSynced(session.id) ? "关闭同步输入" : "同步输入",
                isEnabled: controller.state == .connected,
                isActive: syncStore.isSynced(session.id),
                tintColor: syncStore.isSynced(session.id) ? .orange : nil
            ) {
                if syncStore.isSynced(session.id) {
                    syncStore.deactivate()
                } else {
                    showSyncConfirm = true
                }
            }

            Divider().frame(height: 16).padding(.horizontal, DesignTokens.Spacing.xs)

            connectionButton
        }
    }

    private var fontSizeControls: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ToolbarButton(
                icon: "minus.magnifyingglass",
                tooltip: "减小字号 (⌘-)",
                isEnabled: fontSize > minFontSize
            ) {
                fontSize = max(minFontSize, fontSize - 1)
            }

            Text("\(Int(fontSize))pt")
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 40)

            ToolbarButton(
                icon: "plus.magnifyingglass",
                tooltip: "增大字号 (⌘+)",
                isEnabled: fontSize < maxFontSize
            ) {
                fontSize = min(maxFontSize, fontSize + 1)
            }
        }
    }

    @ViewBuilder
    private var connectionButton: some View {
        switch controller.state {
        case .connected:
            ToolbarButton(
                icon: "xmark.circle",
                tooltip: "断开连接",
                tintColor: DesignTokens.Colors.statusError
            ) {
                Task { await controller.disconnect() }
            }
        case .disconnected, .failed:
            ToolbarButton(
                icon: "bolt.fill",
                tooltip: "连接",
                tintColor: DesignTokens.Colors.statusConnected
            ) {
                connect()
            }
        case .connecting, .reconnecting:
            ToolbarButton(icon: "xmark.circle", tooltip: "取消") {
                controller.cancelReconnect()
                Task { await controller.disconnect() }
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

    private var terminalContentView: some View {
        ZStack {
            SwiftTermViewRepresentable(
                viewRef: $terminalViewRef,
                controller: controller,
                fontSize: CGFloat(fontSize)
            )

            stateOverlay

            // W12.6：同步输入激活时橙色边框指示
            if syncStore.isSynced(session.id) {
                Rectangle()
                    .stroke(Color.orange, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
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
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text("未连接")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("\(session.username)@\(session.host):\(session.port)")
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Button(action: connect) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "bolt.fill")
                    Text("连接")
                }
                .font(DesignTokens.Typography.labelLarge)
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xxl)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.accentPrimary)
                .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
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
                Button("关闭") {}.buttonStyle(.bordered)
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.95))
    }

    // MARK: - 方法

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
            Task { await controller.closeSFTPPanel() }
        } else {
            Task {
                do {
                    try await controller.openSFTPPanel()
                } catch {
                    sftpErrorMessage = error.localizedDescription
                    showSFTPError = true
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
