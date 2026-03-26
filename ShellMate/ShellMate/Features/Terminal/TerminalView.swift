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

    func makeNSView(context: Context) -> SwiftTerm.TerminalView {
        let view = SwiftTerm.TerminalView(frame: .zero)
        view.terminalDelegate = controller
        view.font = resolvedFont()
        applyTheme(themeId, to: view)
        // 延迟赋值避免 SwiftUI 状态更新循环
        DispatchQueue.main.async { viewRef = view }
        return view
    }

    func updateNSView(_ nsView: SwiftTerm.TerminalView, context: Context) {
        let resolved = resolvedFont()
        if nsView.font.fontName != resolved.fontName || nsView.font.pointSize != resolved.pointSize {
            nsView.font = resolved
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
        guard let theme = AppTheme.builtins.first(where: { $0.id == id })
                       ?? AppTheme.builtins.first else { return }
        let bg = NSColor(theme.background)
        let fg = NSColor(theme.outputColor)
        if view.nativeBackgroundColor != bg {
            view.nativeBackgroundColor = bg
        }
        if view.nativeForegroundColor != fg {
            view.nativeForegroundColor = fg
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

    /// 字体族（绑定到外观设置，通过 updateNSView 同步到 SwiftTerm）
    @AppStorage("appearance.fontFamily") private var fontFamily: String = ""
    /// 全局主题 ID（只读，用于无会话覆盖时回退）
    @AppStorage("appearance.themeId") private var globalThemeId: String = "shellmate-dark"
    /// 全局字号（只读，用于无会话覆盖时回退）
    @AppStorage("appearance.fontSize") private var globalFontSize: Double = 13
    /// 会话级别工作字号：初始化自有效值，工具栏 ±1 只修改此值，不写回 AppStorage
    @State private var sessionFontSize: Double = 13

    /// 实际生效主题：会话有覆盖时取覆盖值，否则跟随全局
    private var effectiveThemeId: String {
        if let ov = session.overrideThemeId, !ov.isEmpty { return ov }
        return globalThemeId
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
    /// W11：快捷命令面板是否显示
    @State private var isQuickCommandOpen: Bool = false
    /// 密码输入向导（password/keyboard-interactive 无凭据时显示）
    @State private var showCredentialWizard: Bool = false
    @State private var wizardPassword: String = ""
    @State private var wizardSaveCredential: Bool = true
    /// 私钥路径缺失提示（提示用户前往编辑会话）
    @State private var showPrivateKeyMissing: Bool = false
    /// W12.6：同步输入确认弹窗
    @State private var showSyncConfirm: Bool = false
    /// W12.6：观察同步状态
    @ObservedObject private var syncStore = SyncInputStore.shared

    private let minFontSize: Double = 9
    private let maxFontSize: Double = 24

    /// SFTP 面板宽度（Figma 规范默认 290pt，可拖拽调整）
    @State private var sftpPanelWidth: CGFloat = 290

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
            terminalAndComposeView

            // 底部状态栏（连接状态 + 主机指标）
            TerminalStatusBarView(
                connectionState: controller.state.stateColor,
                session: session,
                serverMetrics: controller.serverMetrics,
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
            // 初始化会话字号：有覆盖则用覆盖值，否则跟随全局
            sessionFontSize = session.overrideFontSize > 0
                ? Double(session.overrideFontSize)
                : globalFontSize
            Task { @MainActor in
                connect()
            }
        }
        .onChange(of: globalFontSize) { newVal in
            // 无会话覆盖时同步全局变化，不覆盖有独立字号的会话
            if session.overrideFontSize <= 0 {
                sessionFontSize = newVal
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
        .modifier(TerminalViewNotificationModifier(
            sessionId: session.id,
            controller: controller,
            showSearch: $showSearch,
            fontSize: $sessionFontSize,
            isQuickCommandOpen: $isQuickCommandOpen,
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
            // 终端内容区 + SFTP 右侧边栏
            HStack(spacing: 0) {
                terminalContentView

                sftpSidebarTabView

                if controller.isSFTPPanelOpen,
                   let sftpSess = controller.sftpSession,
                   let transferQueue = controller.sftpTransferQueue {
                    SFTPPanelView(
                        sftpSession: sftpSess,
                        transferQueue: transferQueue,
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                _ = Task { await controller.closeSFTPPanel() }
                            }
                        }
                    )
                    .frame(width: sftpPanelWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            if controller.isComposePaneOpen {
                ComposePaneView(
                    onSend: { text in controller.sendComposeContent(text) },
                    onClose: { controller.isComposePaneOpen = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

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
                .fill(.ultraThinMaterial)
                .overlay(Rectangle().fill(DesignTokens.Colors.glassUltraLight))
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

            toolbarDivider

            connectionButton
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
                VStack(spacing: 5) {
                    // 箭头方向指示（展开 ← / 收起 →）
                    Image(systemName: controller.isSFTPPanelOpen ? "chevron.right" : "chevron.left")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    // SFTP 图标（Figma: folder.fill）
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundColor(
                            controller.isSFTPPanelOpen
                                ? DesignTokens.Colors.accentPrimary
                                : DesignTokens.Colors.textTertiary
                        )

                    // "SFTP" 纵向标签（面板收起时显示）
                    if !controller.isSFTPPanelOpen {
                        Text("SFTP")
                            .font(.system(size: 9, weight: .medium))
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
                themeId: effectiveThemeId
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

    // MARK: - 密码输入向导

    private var credentialWizardView: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                VStack(alignment: .leading, spacing: 4) {
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
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(DesignTokens.Colors.surfaceCard)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // 认证方式提示
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                    Text(session.authMethod == .keyboardInteractive ? "键盘交互认证" : "密码认证")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                // 密码输入
                VStack(alignment: .leading, spacing: 6) {
                    Text("密码")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    SecureField("请输入密码", text: $wizardPassword)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { confirmCredentialWizard() }
                }

                // 记住密码选项
                Toggle("记住密码（保存到本设备凭据金库）", isOn: $wizardSaveCredential)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .toggleStyle(.checkbox)
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

// MARK: - 通知处理 ViewModifier

/// 将 TerminalView 的菜单栏通知处理提取为独立 ViewModifier，
/// 避免 TerminalView.body 链式修饰符过多导致 Swift 类型检查超时
private struct TerminalViewNotificationModifier: ViewModifier {

    let sessionId: UUID
    let controller: TerminalController
    @Binding var showSearch: Bool
    @Binding var fontSize: Double
    @Binding var isQuickCommandOpen: Bool
    let minFontSize: Double
    let maxFontSize: Double
    let onToggleSFTP: () -> Void

    func body(content: Content) -> some View {
        content
            // 断开连接（通过 sessionId 精确路由）
            .onReceive(NotificationCenter.default.publisher(for: .disconnectActiveTerminalRequested)) { notification in
                guard let targetId = notification.userInfo?["sessionId"] as? UUID,
                      targetId == sessionId else { return }
                Task { await controller.disconnect() }
            }
            // 面板控制
            .onReceive(NotificationCenter.default.publisher(for: .sftpPanelRequested)) { _ in
                onToggleSFTP()
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
            // 终端控制
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
