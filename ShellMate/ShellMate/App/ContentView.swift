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

    // MARK: - 分屏状态
    @State var splitLayout: SplitLayout = .none
    /// 左右/上下分屏：第二格会话 ID
    @State var splitSessionId: Session.ID? = nil
    /// 四格分屏：格 1–3 的额外会话 ID（格 0 = mainTerminalStack）
    @State var gridSessionIds: [Session.ID] = []
    @State var showSplitSessionPicker: Bool = false

    // MARK: - 外观状态
    @AppStorage("appearance.windowMode") var windowMode: String = "auto"
    @AppStorage("appearance.bgOpacity")  private var bgOpacity: Double = 0
    @State var showAppearancePicker: Bool = false

    // MARK: - 语言状态
    @AppStorage("app.language") var appLanguage: String = "zh"
    @State var showLanguagePicker: Bool = false

    // MARK: - 欢迎界面（首次启动，对齐 Figma-Spec-v2 §13）
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false

    // MARK: - 面板与对话框状态
    @State var showScriptPanel: Bool = false
    @State var showSharePopover: Bool = false
    @State var showSSHConfigImport: Bool = false
    @State var showRecordingDialog: Bool = false
    @State var showLogPanel: Bool = false
    @State var showImportExportDialog: Bool = false

    // MARK: - 当前活跃会话（已有标签页的选中会话）
    var activeSession: Session? {
        guard let tab = tabBarStore.selectedTab else { return nil }
        return sessionStore.sessions.first(where: { $0.id == tab.sessionId })
    }

    /// 当前活跃 Tab 对应的 TerminalController（通过注册表查找）
    var activeController: TerminalController? {
        guard let tab = tabBarStore.selectedTab, !tab.isLocalTerminal else { return nil }
        return TerminalControllerRegistry.shared.controller(for: tab.sessionId)
    }

    // MARK: - 视图

    var body: some View {
        NavigationSplitView {
            // 侧边栏
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
        } detail: {
            detailArea
        }
        .navigationTitle("")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showScriptPanel) {
            ScriptLibraryView(onClose: { showScriptPanel = false })
        }
        .sheet(isPresented: $showSSHConfigImport) {
            sshConfigImportSheet
        }
        .sheet(isPresented: $showRecordingDialog) {
            if let ctrl = activeController {
                RecordingDialogView(
                    sessionName: ctrl.session.name,
                    recorder: ctrl.recorder,
                    onClose: { showRecordingDialog = false }
                )
            } else {
                // 无活跃 SSH 会话（本地 Shell 或无连接），仅展示历史录制列表
                RecordingDialogView(
                    sessionName: activeSession?.name ?? "",
                    recorder: SessionRecorder(),
                    onClose: { showRecordingDialog = false }
                )
            }
        }
        .sheet(isPresented: $showLogPanel) {
            LogPanelView(onClose: { showLogPanel = false })
        }
        .sheet(isPresented: $showImportExportDialog) {
            SessionImportExportView(
                sessions: sessionStore.sessions,
                onImport: { sessions in
                    Task {
                        for session in sessions {
                            await sessionStore.saveSession(session)
                        }
                    }
                },
                onClose: { showImportExportDialog = false }
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
        .sheet(isPresented: $showSplitSessionPicker, onDismiss: {
            // 若用户关闭弹窗时未选择会话，取消分屏
            let noSelection = splitLayout == .grid
                ? gridSessionIds.isEmpty
                : splitSessionId == nil
            if noSelection { splitLayout = .none }
        }) {
            if splitLayout == .grid {
                // 四格分屏：多选模式（最多选 3 个额外会话，任务 13.15）
                SplitSessionPickerView(
                    sessions: sessionStore.sessions,
                    isMultiSelect: true,
                    maxSelection: 3,
                    onSelectMultiple: { sessions in
                        gridSessionIds = sessions.map(\.id)
                        showSplitSessionPicker = false
                    },
                    onCancel: {
                        splitLayout = .none
                        gridSessionIds = []
                        showSplitSessionPicker = false
                    }
                )
                .frame(width: 400, height: 520)
            } else {
                // 左右/上下分屏：单选模式
                SplitSessionPickerView(
                    sessions: sessionStore.sessions,
                    onSelect: { session in
                        splitSessionId = session.id
                        showSplitSessionPicker = false
                    },
                    onCancel: {
                        splitLayout = .none
                        splitSessionId = nil
                        showSplitSessionPicker = false
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
        .alert("数据库错误", isPresented: .constant(PersistenceController.shared.loadError != nil)) {
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
            showLogPanel = true
        }
        // 欢迎界面覆层（首次启动，Figma-Spec-v2 §13）
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
                        sessionStore.showNewSessionForm() // 临时指向新建，后续对接导入
                    }
                )
                .zIndex(100)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        // 挂载时立即对 NSWindow 实例禁用原生 Window Tab Bar
        .background(WindowTabbingDisabler())
        // 背景透明度（仅作用于当前 ContentView 所在的主窗口）
        .background(WindowTransparencyConfigurator(opacity: bgOpacity))
        // 根据用户选择的外观模式应用 ColorScheme；nil 表示跟随系统
        .preferredColorScheme(preferredColorScheme)
        // 根据用户选择的语言应用 Locale
        .environment(\.locale, appLocale)
        // 新窗口打开时自动连接待连接会话（由右键菜单"在新窗口打开"写入 UserDefaults）
        .task {
            await checkPendingAutoConnect()
        }
        // 数据加载 + 菜单栏通知处理（拆分以规避 Swift 类型检查超时）
        .modifier(ContentViewLifecycleModifier(
            sessionStore: sessionStore,
            groupStore: groupStore,
            tabBarStore: tabBarStore,
            onConnect: connectToSession
        ))
    }

    // MARK: - 终端内容区域

    /// 主区域：标签栏 + 终端内容 + 全局状态栏（拆分以规避编译器类型推断超时）
    private var detailArea: some View {
        VStack(spacing: 0) {
            // 标签栏（任务 13.7-B：始终显示，冷启动即有本地 Shell 标签）
            TerminalTabBarView(store: tabBarStore, onNewTab: {
                sessionStore.showNewSessionForm()
            })
            terminalContentArea
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#f5f5f7"), Color(hex: "#e8e8ed")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private var terminalContentArea: some View {
        // 分屏布局（任务 13.15：四格分屏支持独立会话）
        switch splitLayout {
        case .horizontal:
            if let splitId = splitSessionId,
               let s = sessionStore.sessions.first(where: { $0.id == splitId }) {
                HSplitView {
                    mainTerminalStack.frame(minWidth: 300)
                    TerminalView(session: s).frame(minWidth: 300)
                }
            } else { mainTerminalStack }

        case .vertical:
            if let splitId = splitSessionId,
               let s = sessionStore.sessions.first(where: { $0.id == splitId }) {
                VSplitView {
                    mainTerminalStack.frame(minHeight: 200)
                    TerminalView(session: s).frame(minHeight: 200)
                }
            } else { mainTerminalStack }

        case .grid:
            // 四格分屏：格 0 = 当前标签栈，格 1-3 = gridSessionIds 对应会话
            // 若某格未选会话则显示本地 Shell（LocalTerminalView）
            let g = gridSessionIds.compactMap { id in
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

    /// 四格分屏中单个额外格子：有会话则显示 TerminalView，否则显示本地 Shell
    @ViewBuilder
    private func gridPanel(session: Session?) -> some View {
        if let session {
            TerminalView(session: session)
        } else {
            LocalTerminalView()
        }
    }

    /// 主终端标签栈（ZStack + opacity 保持多标签连接存活，TC-004）
    private var mainTerminalStack: some View {
        ZStack {
            ForEach(tabBarStore.tabs) { tab in
                Group {
                    if tab.isLocalTerminal {
                        // 13.7：本地终端标签页（无需 SSH）
                        LocalTerminalView()
                    } else if let session = sessionStore.sessions.first(where: { $0.id == tab.sessionId }) {
                        TerminalView(session: session)
                    }
                }
                .opacity(tabBarStore.selectedTabId == tab.id ? 1 : 0)
                .zIndex(tabBarStore.selectedTabId == tab.id ? 1 : 0)
                .allowsHitTesting(tabBarStore.selectedTabId == tab.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Figma: bg-white/50 backdrop-blur-sm
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.50))
    }
}

// MARK: - 预览

#Preview("主窗口") {
    ContentView()
        .frame(width: 1200, height: 800)
}
