import SwiftUI

// MARK: - 分屏布局类型

enum SplitLayout {
    case none
    case horizontal  // 左右分屏
    case vertical    // 上下分屏
    case grid        // 四格分屏 (2×2)，对齐 Figma-Spec-v2 §01
}

/// 主内容视图
/// 使用 NavigationSplitView 实现侧边栏和主区域的布局
struct ContentView: View {

    // MARK: - 状态

    @StateObject var sessionStore = SessionStore()
    @StateObject var groupStore = GroupStore()
    @StateObject var tabBarStore = TabBarStore()

    /// 面板/分屏状态（统一由 ContentViewModel 管理）
    @StateObject var panels = ContentViewModel()

    // MARK: - 终端状态
    /// 活跃终端推送的状态数据（底栏状态栏消费）
    @ObservedObject private var terminalStatus = ActiveTerminalStatusStore.shared

    // MARK: - 外观状态
    @AppStorage("appearance.windowMode") var windowMode: String = "light"
    /// 数据库加载错误 Alert（在 init 之前已确定，State 驱动以正确响应 dismiss）
    @State private var showDBError: Bool = PersistenceController.shared.loadError != nil
    @AppStorage("appearance.bgOpacity") private var bgOpacity: Double = 0

    // MARK: - 语言状态
    @AppStorage("app.language") var appLanguage: String = "zh"

    // MARK: - 欢迎界面（首次启动，对齐 Figma-Spec-v2 §13）
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false

    // MARK: - 当前活跃会话（已有标签页的选中会话）
    var activeSession: Session? {
        guard let tab = tabBarStore.selectedTab else { return nil }
        return sessionStore.sessions.first(where: { $0.id == tab.sessionId })
    }

    /// 当前活跃 Tab 对应的 TerminalController（通过注册表查找）
    var activeController: TerminalController? {
        guard let tab = tabBarStore.selectedTab else { return nil }
        return TerminalControllerRegistry.shared.controller(for: tab.sessionId)
    }

    // MARK: - 视图

    var body: some View {
        NavigationSplitView {
            // 侧边栏（含底部统计条，放在 NavigationSplitView 内部避免悬浮面板问题）
            SessionSidebarView(
                sessionStore: sessionStore,
                groupStore: groupStore,
                onConnect: { session in
                    connectToSession(session)
                }
            )
            .navigationSplitViewColumnWidth(
                min: DesignTokens.Sizes.sidebarMinWidth,
                ideal: DesignTokens.Sizes.sidebarWidth,
                max: DesignTokens.Sizes.sidebarMaxWidth
            )
            // 二次兜底：在 NavigationSplitView 列级别压制 sidebar vibrancy 穿透
            .background(DesignTokens.Colors.surfaceWindow)
        } detail: {
            detailArea
        }
        .navigationTitle("ShellMate")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $panels.showScriptPanel) {
            ScriptLibraryView(onClose: { panels.showScriptPanel = false })
        }
        .sheet(isPresented: $panels.showSSHConfigImport) {
            sshConfigImportSheet
        }
        .sheet(isPresented: $panels.showRecordingDialog) {
            if let ctrl = activeController {
                RecordingDialogView(
                    sessionName: ctrl.session.name,
                    recorder: ctrl.recorder,
                    onClose: { panels.showRecordingDialog = false }
                )
            } else {
                // 无活跃 SSH 会话（本地 Shell 或无连接），仅展示历史录制列表
                RecordingDialogView(
                    sessionName: activeSession?.name ?? "",
                    recorder: SessionRecorder(),
                    onClose: { panels.showRecordingDialog = false }
                )
            }
        }
        .sheet(isPresented: $panels.showLogPanel) {
            LogPanelView(onClose: { panels.showLogPanel = false })
        }
        .sheet(isPresented: $panels.showImportExportDialog) {
            SessionImportExportView(
                sessions: sessionStore.sessions,
                onImport: { sessions in
                    Task {
                        for session in sessions {
                            await sessionStore.saveSession(session)
                        }
                    }
                },
                onClose: { panels.showImportExportDialog = false }
            )
        }
        .sheet(isPresented: $sessionStore.isShowingSessionForm) {
            sessionFormSheet
        }
        .sheet(isPresented: $groupStore.isShowingGroupForm) {
            groupFormSheet
        }
        .sheet(isPresented: $tabBarStore.isShowingCloseConfirmation) {
            TabCloseConfirmationView(store: tabBarStore)
                .frame(width: 320)
        }
        .sheet(isPresented: $panels.showSplitSessionPicker, onDismiss: {
            // 若用户关闭弹窗时未选择会话，取消分屏
            let noSelection = panels.splitLayout == .grid
                ? panels.gridSessionIds.isEmpty
                : panels.splitSessionId == nil
            if noSelection { panels.splitLayout = .none }
        }) {
            if panels.splitLayout == .grid {
                // 四格分屏：多选模式（最多选 3 个额外会话，任务 13.15）
                SplitSessionPickerView(
                    sessions: sessionStore.sessions,
                    isMultiSelect: true,
                    maxSelection: 3,
                    onSelectMultiple: { sessions in
                        panels.gridSessionIds = sessions.map(\.id)
                        panels.showSplitSessionPicker = false
                    },
                    onCancel: {
                        panels.splitLayout = .none
                        panels.gridSessionIds = []
                        panels.showSplitSessionPicker = false
                    }
                )
                .frame(width: 400, height: 520)
            } else {
                // 左右/上下分屏：单选模式
                SplitSessionPickerView(
                    sessions: sessionStore.sessions,
                    onSelect: { session in
                        panels.splitSessionId = session.id
                        panels.showSplitSessionPicker = false
                    },
                    onCancel: {
                        panels.splitLayout = .none
                        panels.splitSessionId = nil
                        panels.showSplitSessionPicker = false
                    }
                )
                .frame(width: 360, height: 480)
            }
        }
        .alert("错误", isPresented: Binding(
            get: { sessionStore.errorMessage != nil },
            set: { if !$0 { sessionStore.errorMessage = nil } }
        )) {
            Button("确定") {
                sessionStore.errorMessage = nil
            }
        } message: {
            if let error = sessionStore.errorMessage {
                Text(error)
            }
        }
        .alert("数据库错误", isPresented: $showDBError) {
            Button("退出") { NSApp.terminate(nil) }
        } message: {
            if let error = PersistenceController.shared.loadError {
                Text("本地数据库初始化失败，应用无法继续运行。\n\n\(error.localizedDescription)")
            }
        }
        // 全局 UI 通知处理
        .onReceive(NotificationCenter.default.publisher(for: .settingsRequested)) { _ in
            openNativeSettingsWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .logPanelRequested)) { _ in
            panels.showLogPanel = true
        }
        // 同步 TerminalController 实际连接状态到 SessionStore（侧边栏计数器）和 TabBarStore（标签点颜色）
        .onReceive(NotificationCenter.default.publisher(for: .sessionConnectionStateChanged)) { notification in
            guard let (sessionId, state) = AppEvent.extractConnectionState(from: notification) else { return }
            sessionStore.updateConnectionState(for: sessionId, state: state)
            if let tab = tabBarStore.tabs.first(where: { $0.sessionId == sessionId }) {
                tabBarStore.updateConnectionState(for: tab.id, state: state)
            }
        }
        // 侧边栏右键"分屏打开"：在现有主终端旁边打开目标会话
        .onReceive(NotificationCenter.default.publisher(for: .splitSessionRequested)) { notification in
            guard let (sessionId, layoutStr) = AppEvent.extractSplitSession(from: notification),
                  sessionStore.sessions.contains(where: { $0.id == sessionId }) else { return }
            panels.splitLayout = layoutStr == "horizontal" ? .horizontal : .vertical
            panels.splitSessionId = sessionId
        }
        // 挂载时立即对 NSWindow 实例禁用原生 Window Tab Bar
        .background(WindowTabbingDisabler())
        // 背景透明度（仅作用于当前 ContentView 所在的主窗口）
        .background(WindowTransparencyConfigurator(opacity: bgOpacity, windowMode: windowMode))
        // NSToolbar 背景：对齐 Figma `bg-[#f5f5f7]/80`（亮色 #F5F5F7 / 深色 #070a11）
        .toolbarBackground(DesignTokens.Colors.surfaceWindow, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        // 根据用户选择的外观模式应用 ColorScheme；nil 表示跟随系统
        .preferredColorScheme(preferredColorScheme)
        // 根据用户选择的语言应用 Locale
        .environment(\.locale, appLocale)
        // 新窗口打开时自动连接待连接会话（由右键菜单"在新窗口打开"写入 UserDefaults）
        .task {
            await checkPendingAutoConnect()
        }
        // 活跃 Tab 变化时同步侧边栏选中高亮（快捷键切换 Tab 场景）
        .onChange(of: tabBarStore.selectedTabId) { newId in
            guard let newId,
                  let tab = tabBarStore.tabs.first(where: { $0.id == newId }) else { return }
            sessionStore.selectedSessionId = tab.sessionId
        }
        // 数据加载 + 菜单栏通知处理（拆分以规避 Swift 类型检查超时）
        .modifier(ContentViewLifecycleModifier(
            sessionStore: sessionStore,
            groupStore: groupStore,
            tabBarStore: tabBarStore,
            onConnect: connectToSession
        ))
        // 兜底不透明背景，防止窗口透明时缝隙露出桌面壁纸
        .background(DesignTokens.Colors.surfaceWindow)
        // 欢迎界面覆层（首次启动，覆盖整个窗口含底栏）
        .overlay {
            if !hasLaunchedBefore {
                WelcomeScreenView(
                    onDismiss: {
                        hasLaunchedBefore = true
                    },
                    onCreateSession: {
                        hasLaunchedBefore = true
                        sessionStore.showNewSessionForm()
                    },
                    onImportConfiguration: {
                        hasLaunchedBefore = true
                        sessionStore.showNewSessionForm()
                    }
                )
                .zIndex(100)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
    }

    // MARK: - 终端内容区域

    /// 主区域：标签栏 + 终端内容 + 状态栏（Figma-Spec-v2 §04）
    private var detailArea: some View {
        VStack(spacing: 0) {
            // 标签栏：会话 Tab 切换
            TerminalTabBarView(store: tabBarStore, onNewTab: {
                sessionStore.showNewSessionForm()
            })
            // 终端内容区（填满剩余空间）
            terminalContentArea
            // 终端状态栏（固定底部，与侧边栏 footer 同 Y 轴对齐）
            TerminalStatusBarView(
                connectionState: terminalStatus.connectionState,
                session: terminalStatus.session,
                serverMetrics: terminalStatus.serverMetrics,
                columns: terminalStatus.terminalColumns,
                rows: terminalStatus.terminalRows,
                encoding: terminalStatus.encoding,
                connectedAt: terminalStatus.connectedAt,
                latency: terminalStatus.latencyMs,
                tmuxAttachedSession: terminalStatus.tmuxAttachedSession,
                tmuxSessionCount: terminalStatus.tmuxSessionCount,
                tmuxWindows: terminalStatus.tmuxWindows,
                onSelectTmuxWindow: terminalStatus.onSelectTmuxWindow,
                onMetricsTap: terminalStatus.serverMetrics != nil
                    ? { terminalStatus.shouldShowMonitorPanel = true }
                    : nil
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.terminalBackground)
        .clipShape(Rectangle())
    }

    @ViewBuilder
    private var terminalContentArea: some View {
        // 分屏布局（任务 13.15：四格分屏支持独立会话）
        switch panels.splitLayout {
        case .horizontal:
            if let splitId = panels.splitSessionId,
               let s = sessionStore.sessions.first(where: { $0.id == splitId }) {
                HSplitView {
                    mainTerminalStack.frame(minWidth: 300)
                    TerminalView(session: s, isSelected: false).frame(minWidth: 300)
                }
            } else { mainTerminalStack }

        case .vertical:
            if let splitId = panels.splitSessionId,
               let s = sessionStore.sessions.first(where: { $0.id == splitId }) {
                VSplitView {
                    mainTerminalStack.frame(minHeight: 200)
                    TerminalView(session: s, isSelected: false).frame(minHeight: 200)
                }
            } else { mainTerminalStack }

        case .grid:
            // 四格分屏：格 0 = 当前标签栈，格 1-3 = gridSessionIds 对应会话
            // 若某格未选会话则显示本地 Shell（LocalTerminalView）
            let g = panels.gridSessionIds.compactMap { id in
                sessionStore.sessions.first(where: { $0.id == id })
            }
            VSplitView {
                HSplitView {
                    mainTerminalStack.frame(minWidth: 200, minHeight: 150)
                    gridPanel(session: g[safe: 0]).frame(minWidth: 200, minHeight: 150)
                }
                HSplitView {
                    gridPanel(session: g[safe: 1]).frame(minWidth: 200, minHeight: 150)
                    gridPanel(session: g[safe: 2]).frame(minWidth: 200, minHeight: 150)
                }
            }

        case .none:
            mainTerminalStack
        }
    }

    /// 四格分屏中单个额外格子：有会话则显示 TerminalView，否则显示占位视图
    /// 分屏格子不参与状态推送，isSelected 固定为 false
    @ViewBuilder
    private func gridPanel(session: Session?) -> some View {
        if let session {
            TerminalView(session: session, isSelected: false)
        } else {
            TerminalPlaceholderView(onNewSession: { sessionStore.showNewSessionForm() })
        }
    }

    /// 主终端标签栈（ZStack + opacity 保持多标签连接存活，TC-004）
    private var mainTerminalStack: some View {
        ZStack {
            if tabBarStore.tabs.isEmpty {
                TerminalPlaceholderView(onNewSession: { sessionStore.showNewSessionForm() })
            } else {
                ForEach(tabBarStore.tabs) { tab in
                    Group {
                        if let session = sessionStore.sessions.first(where: { $0.id == tab.sessionId }) {
                            TerminalView(
                                session: session,
                                isSelected: tabBarStore.selectedTabId == tab.id
                            )
                        }
                    }
                    .opacity(tabBarStore.selectedTabId == tab.id ? 1 : 0)
                    .zIndex(tabBarStore.selectedTabId == tab.id ? 1 : 0)
                    .allowsHitTesting(tabBarStore.selectedTabId == tab.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 终端区域使用纯色背景，零毛玻璃，降低 GPU 渲染压力（W27 Sprint-01 §修改意见3）
        .background(DesignTokens.Colors.terminalBackground)
        .clipShape(Rectangle())
    }

}

// MARK: - 预览

#Preview("主窗口") {
    ContentView()
        .frame(width: 1200, height: 800)
}
