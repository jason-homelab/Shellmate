import SwiftUI

// MARK: - 分屏布局类型

private enum SplitLayout {
    case none
    case horizontal  // 左右分屏
    case vertical    // 上下分屏
    case grid        // 四格分屏 (2×2)，对齐 Figma-Spec-v2 §01
}

/// 主内容视图
/// 使用 NavigationSplitView 实现侧边栏和主区域的布局
struct ContentView: View {

    // MARK: - 状态

    @StateObject private var sessionStore = SessionStore()
    @StateObject private var groupStore = GroupStore()
    @StateObject private var tabBarStore = TabBarStore()

    // MARK: - 分屏状态
    @State private var splitLayout: SplitLayout = .none
    @State private var splitSessionId: Session.ID? = nil
    @State private var showSplitSessionPicker: Bool = false

    // MARK: - 外观状态
    @AppStorage("appearance.windowMode") private var windowMode: String = "auto"
    @AppStorage("appearance.bgOpacity")  private var bgOpacity: Double = 0
    @State private var showAppearancePicker: Bool = false

    // MARK: - 语言状态
    @AppStorage("app.language") private var appLanguage: String = "zh"
    @State private var showLanguagePicker: Bool = false

    // MARK: - 欢迎界面（首次启动，对齐 Figma-Spec-v2 §13）
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false

    // MARK: - 面板与对话框状态
    @State private var showScriptPanel: Bool = false
    @State private var showSharePopover: Bool = false

    // MARK: - 当前活跃会话（已有标签页的选中会话）
    private var activeSession: Session? {
        guard let tab = tabBarStore.selectedTab else { return nil }
        return sessionStore.sessions.first(where: { $0.id == tab.sessionId })
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
            // 主区域：标签栏 + 终端内容
            VStack(spacing: 0) {
                // 标签栏（有标签时显示）
                if !tabBarStore.tabs.isEmpty {
                    TerminalTabBarView(store: tabBarStore, onNewTab: {
                        // 新建标签页：打开新建会话表单
                        sessionStore.showNewSessionForm()
                    })
                }

                // 终端内容区域
                terminalContentArea
            }
            .background(DesignTokens.Colors.surfaceWindow)
        }
        .navigationTitle("")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showScriptPanel) {
            ScriptLibraryView(onClose: { showScriptPanel = false })
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
            if splitSessionId == nil { splitLayout = .none }
        }) {
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
        // 数据加载 + 菜单栏通知处理（拆分以规避 Swift 类型检查超时）
        .modifier(ContentViewLifecycleModifier(
            sessionStore: sessionStore,
            groupStore: groupStore,
            tabBarStore: tabBarStore,
            onConnect: connectToSession
        ))
    }

    // MARK: - 终端内容区域

    @ViewBuilder
    private var terminalContentArea: some View {
        if tabBarStore.tabs.isEmpty {
            // 空状态（对齐 Figma App.tsx：🖥️ emoji + 渐变卡片 + 蓝色按钮）
            VStack(spacing: 0) {
                // 渐变 emoji 图标卡片
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(
                            colors: [
                                DesignTokens.Colors.accentPrimary.opacity(0.10),
                                DesignTokens.Colors.accentIndigo.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
                    Text("🖥️")
                        .font(.system(size: 48))
                }
                .frame(width: 96, height: 96)

                Spacer().frame(height: 24)

                Text("暂无活跃会话")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#1d1d1f"))

                Spacer().frame(height: 8)

                Text("从左侧选择一个会话，或创建新会话开始连接")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#86868b"))
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 24)

                // bg-[#007aff] hover:bg-[#0051d5] rounded-xl
                Button("新建会话") {
                    sessionStore.showNewSessionForm()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(DesignTokens.Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.surfaceWindow)
        } else {
            // 分屏：有分屏会话时显示分割布局
            if splitLayout != .none,
               let splitId = splitSessionId,
               let splitSession = sessionStore.sessions.first(where: { $0.id == splitId }) {
                switch splitLayout {
                case .horizontal:
                    HSplitView {
                        mainTerminalStack.frame(minWidth: 300)
                        TerminalView(session: splitSession).frame(minWidth: 300)
                    }
                case .vertical:
                    VSplitView {
                        mainTerminalStack.frame(minHeight: 200)
                        TerminalView(session: splitSession).frame(minHeight: 200)
                    }
                case .grid:
                    // 四格分屏 (2×2)：上下各一行，每行左右两格
                    VSplitView {
                        HSplitView {
                            mainTerminalStack.frame(minWidth: 200, minHeight: 150)
                            TerminalView(session: splitSession).frame(minWidth: 200, minHeight: 150)
                        }
                        HSplitView {
                            TerminalView(session: splitSession).frame(minWidth: 200, minHeight: 150)
                            TerminalView(session: splitSession).frame(minWidth: 200, minHeight: 150)
                        }
                    }
                case .none:
                    mainTerminalStack
                }
            } else {
                mainTerminalStack
            }
        }
    }

    /// 主终端标签栈（ZStack + opacity 保持多标签连接存活，TC-004）
    private var mainTerminalStack: some View {
        ZStack {
            ForEach(tabBarStore.tabs) { tab in
                if let session = sessionStore.sessions.first(where: { $0.id == tab.sessionId }) {
                    TerminalView(session: session)
                        .opacity(tabBarStore.selectedTabId == tab.id ? 1 : 0)
                        .zIndex(tabBarStore.selectedTabId == tab.id ? 1 : 0)
                        .allowsHitTesting(tabBarStore.selectedTabId == tab.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow)
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        // ── 左侧：连接控制 + 功能按钮 ─────────────────────────

        ToolbarItemGroup(placement: .navigation) {
            // 连接
            Button {
                if let session = sessionStore.selectedSession { connectToSession(session) }
            } label: {
                Text("连接")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(sessionStore.selectedSession != nil
                        ? DesignTokens.Colors.accentPrimary
                        : DesignTokens.Colors.textSecondary)
            }
            .disabled(sessionStore.selectedSession == nil)
            .help("连接选中会话 (⌘↩)")
            .keyboardShortcut(.return, modifiers: .command)

            // 断开
            Button {
                if let sessionId = tabBarStore.selectedTab?.sessionId {
                    NotificationCenter.default.post(
                        name: .disconnectActiveTerminalRequested,
                        object: nil,
                        userInfo: ["sessionId": sessionId]
                    )
                }
            } label: {
                Text("断开")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(tabBarStore.selectedTab != nil
                        ? DesignTokens.Colors.statusError
                        : DesignTokens.Colors.textSecondary)
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("断开当前会话")

            // 脚本自动化
            Button { showScriptPanel = true } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            .help("脚本自动化")

            // SFTP
            Button {
                NotificationCenter.default.post(name: .sftpPanelRequested, object: nil)
            } label: {
                Image(systemName: "folder.badge.gearshape")
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("文件传输 (SFTP)")

            // 分屏（支持左右/上下/四格，对齐 Figma-Spec-v2 §03）
            Menu {
                if splitLayout == .none {
                    Button {
                        splitLayout = .horizontal; showSplitSessionPicker = true
                    } label: { Label("左右分屏", systemImage: "rectangle.split.2x1") }
                    Button {
                        splitLayout = .vertical; showSplitSessionPicker = true
                    } label: { Label("上下分屏", systemImage: "rectangle.split.1x2") }
                    Button {
                        splitLayout = .grid; showSplitSessionPicker = true
                    } label: { Label("四格分屏 (2×2)", systemImage: "rectangle.split.2x2") }
                } else {
                    Button {
                        splitLayout = .horizontal
                        if splitSessionId == nil { showSplitSessionPicker = true }
                    } label: { Label("切换为左右分屏", systemImage: "rectangle.split.2x1") }
                    Button {
                        splitLayout = .vertical
                        if splitSessionId == nil { showSplitSessionPicker = true }
                    } label: { Label("切换为上下分屏", systemImage: "rectangle.split.1x2") }
                    Button {
                        splitLayout = .grid
                        if splitSessionId == nil { showSplitSessionPicker = true }
                    } label: { Label("切换为四格分屏", systemImage: "rectangle.split.2x2") }
                    Divider()
                    Button(role: .destructive) {
                        splitLayout = .none; splitSessionId = nil
                    } label: { Label("关闭分屏", systemImage: "rectangle") }
                }
            } label: {
                Image(systemName: splitLayout != .none
                    ? "rectangle.split.2x1.fill"
                    : "rectangle.split.2x1")
                .foregroundColor(splitLayout != .none ? DesignTokens.Colors.accentPrimary : nil)
            }
            .help(splitLayout != .none ? "分屏管理" : "开启分屏")

            // 日志/搜索
            Button {
                NotificationCenter.default.post(name: .searchTerminalRequested, object: nil)
            } label: {
                Image(systemName: "doc.text")
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("终端内搜索 (⌘F)")
        }

        // ── 中间：当前会话名 pill ─────────────────────────────

        ToolbarItem(placement: .principal) {
            Group {
                if let session = activeSession {
                    Text(session.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.06))
                        .clipShape(Capsule())
                } else {
                    Text("ShellMate")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
        }

        // ── 右侧：全局操作 ────────────────────────────────────

        ToolbarItemGroup(placement: .primaryAction) {
            Button { showSharePopover.toggle() } label: {
                Image(systemName: "square.and.arrow.up.on.square")
            }
            .popover(isPresented: $showSharePopover, arrowEdge: .bottom) {
                sessionShareMenu
            }
            .help("导入 / 导出会话")

            Button {
                showAppearancePicker.toggle()
            } label: {
                Image(systemName: windowModeIcon)
            }
            .popover(isPresented: $showAppearancePicker, arrowEdge: .bottom) {
                AppearanceModePickerView(windowMode: $windowMode)
            }
            .help("外观模式")

            Button { showLanguagePicker.toggle() } label: {
                Text(appLanguage == "en" ? "EN" : "中")
                    .font(.system(size: 12, weight: .medium))
                    .frame(minWidth: 20)
            }
            .popover(isPresented: $showLanguagePicker, arrowEdge: .bottom) {
                languagePickerMenu
            }
            .help("切换语言 / Switch Language")
        }
    }

    private var windowModeIcon: String {
        switch windowMode {
        case "light": return "sun.max"
        case "dark":  return "moon"
        default:      return "circle.lefthalf.filled"
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch windowMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private var appLocale: Locale {
        appLanguage == "en" ? Locale(identifier: "en_US") : Locale(identifier: "zh_Hans")
    }

    // MARK: - 语言选择器菜单

    private var languagePickerMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            languageOption(label: "中文", tag: "zh")
            languageOption(label: "English", tag: "en")
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(minWidth: 120)
    }

    private func languageOption(label: String, tag: String) -> some View {
        Button(action: {
            appLanguage = tag
            showLanguagePicker = false
        }) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                if appLanguage == tag {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 会话表单弹窗

    private var sessionFormSheet: some View {
        SessionFormSheet(
            editingSession: sessionStore.editingSession,
            groups: groupStore.groups,
            onSave: { session in
                Task {
                    await sessionStore.saveSession(session)
                    sessionStore.dismissSessionForm()
                }
            },
            onCancel: {
                sessionStore.dismissSessionForm()
            }
        )
    }

    // MARK: - 分组表单弹窗

    private var groupFormSheet: some View {
        GroupFormSheet(
            editingGroup: groupStore.editingGroup,
            onSave: { group in
                Task {
                    await groupStore.saveGroup(group)
                    groupStore.dismissGroupForm()
                }
            },
            onCancel: {
                groupStore.dismissGroupForm()
            }
        )
    }

    // MARK: - 导入/导出 Popover

    private var sessionShareMenu: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("会话配置")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 2)

            Button {
                showSharePopover = false
                exportSessions()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc")
                        .frame(width: 16)
                    Text("导出会话配置…")
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .background(Color.clear)
            .contentShape(Rectangle())

            Button {
                showSharePopover = false
                importSessions()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .frame(width: 16)
                    Text("导入会话配置…")
                }
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .background(Color.clear)
            .contentShape(Rectangle())

            Divider()
                .padding(.horizontal, 12)

            Text("密码与私钥不会包含在导出文件中")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .padding(.top, 2)
        }
        .frame(width: 220)
    }

    // MARK: - 导出会话（JSON，不含凭据）

    private func exportSessions() {
        struct SessionExport: Encodable {
            let version: Int = 1
            let exportedAt: String
            let sessions: [SessionRecord]
        }
        struct SessionRecord: Encodable {
            let name, host, username, encoding: String
            let port: Int32
            let authMethodRaw: Int16
            let keepAliveInterval, connectTimeout: Int32
            let autoReconnect: Bool
            let tags: [String]
            let proxyJumpString: String?
            let startupCommand: String?
        }

        let exportedAt = ISO8601DateFormatter().string(from: Date())
        let records = sessionStore.sessions.map { s in
            SessionRecord(
                name: s.name, host: s.host, username: s.username, encoding: s.encoding,
                port: s.port, authMethodRaw: s.authMethod.rawValue,
                keepAliveInterval: s.keepAliveInterval, connectTimeout: s.connectTimeout,
                autoReconnect: s.autoReconnect, tags: s.tags,
                proxyJumpString: s.proxyJumpString, startupCommand: s.startupCommand
            )
        }
        let export = SessionExport(exportedAt: exportedAt, sessions: records)
        guard let data = try? JSONEncoder().encode(export) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "shellmate-sessions-\(ISO8601DateFormatter().string(from: Date()).prefix(10)).json"
        panel.prompt = "导出"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - 导入会话

    private func importSessions() {
        struct SessionExport: Decodable {
            let version: Int
            let sessions: [SessionRecord]
        }
        struct SessionRecord: Decodable {
            let name, host, username, encoding: String
            let port: Int32
            let authMethodRaw: Int16
            let keepAliveInterval, connectTimeout: Int32
            let autoReconnect: Bool
            let tags: [String]
            let proxyJumpString: String?
            let startupCommand: String?
        }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.prompt = "导入"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let export = try? JSONDecoder().decode(SessionExport.self, from: data)
        else { return }

        Task {
            for record in export.sessions {
                let authMethod = AuthMethod(rawValue: record.authMethodRaw) ?? .password
                let session = Session(
                    name: record.name, host: record.host, port: record.port,
                    username: record.username, authMethod: authMethod,
                    keepAliveInterval: record.keepAliveInterval, autoReconnect: record.autoReconnect,
                    encoding: record.encoding, tags: record.tags,
                    proxyJumpString: record.proxyJumpString, connectTimeout: record.connectTimeout,
                    startupCommand: record.startupCommand
                )
                await sessionStore.saveSession(session)
            }
        }
    }

    // MARK: - 设置窗口

    private func openNativeSettingsWindow() {
        // showSettingsWindow: 自 macOS 13 起可用（最低部署目标），无需版本判断
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    // MARK: - 连接方法

    private func connectToSession(_ session: Session) {
        sessionStore.selectedSessionId = session.id

        // 如果该会话已有标签页，直接切换到它
        if let existingTab = tabBarStore.tab(for: session.id) {
            tabBarStore.selectTab(existingTab)
        } else {
            // 否则新建标签页
            tabBarStore.addTab(for: session)
        }

        // 更新最后连接时间
        Task {
            await sessionStore.updateLastConnectedAt(for: session.id)
        }
    }
}

// MARK: - 窗口标签禁用器

/// 原生 Window Tab Bar 禁用器
///
/// 使用 NSView 子类覆写 viewDidMoveToWindow()，该方法在 view 被加入窗口层级时
/// 由 AppKit 回调，此时 window 属性保证非 nil——比 DispatchQueue.main.async 更可靠。
///
/// 三重防御层级（配合 AppDelegate 的 ① ② ③ 共同生效）：
/// - AppDelegate.applicationWillFinishLaunching：类级别，拦截窗口创建前
/// - AppDelegate.applicationDidFinishLaunching：实例级别，覆盖已有窗口
/// - 此处：视图级别，兜底处理 NavigationSplitView 内部列窗口
private final class _WindowTabbingDisablerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.tabbingMode = .disallowed
    }
}

private struct WindowTabbingDisabler: NSViewRepresentable {
    func makeNSView(context: Context) -> _WindowTabbingDisablerView {
        _WindowTabbingDisablerView()
    }
    func updateNSView(_ nsView: _WindowTabbingDisablerView, context: Context) {}
}

// MARK: - 主窗口透明度 / Vibrancy 配置器

/// 背景透明度配置视图（零尺寸 NSView，挂载到主窗口以精确控制窗口背景透明度）
/// 仅附加在 ContentView，不影响设置面板等辅助窗口
private final class _WindowTransparencyView: NSView {

    var opacity: Double = 0 { didSet { applyToWindow() } }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyToWindow()
    }

    func applyToWindow() {
        guard let window else { return }
        if opacity > 0 {
            window.isOpaque = false
            // opacity 0→0% 透明；100→100% 透明
            let alpha = max(0.0, 1.0 - opacity / 100.0)
            window.backgroundColor = NSColor(white: 0.07, alpha: alpha)
        } else {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
        }
    }
}

private struct WindowTransparencyConfigurator: NSViewRepresentable {
    let opacity: Double

    func makeNSView(context: Context) -> _WindowTransparencyView {
        let view = _WindowTransparencyView()
        view.opacity = opacity
        return view
    }

    func updateNSView(_ nsView: _WindowTransparencyView, context: Context) {
        nsView.opacity = opacity
    }
}

// MARK: - 生命周期与通知处理 ViewModifier

/// 将数据加载和菜单栏通知处理拆分为独立 ViewModifier，
/// 避免 ContentView.body 中链式修饰符过多导致 Swift 类型检查超时
private struct ContentViewLifecycleModifier: ViewModifier {

    let sessionStore: SessionStore
    let groupStore: GroupStore
    let tabBarStore: TabBarStore
    let onConnect: (Session) -> Void

    func body(content: Content) -> some View {
        content
            // 会话 / 分组操作
            .onReceive(NotificationCenter.default.publisher(for: .newSessionRequested)) { _ in
                sessionStore.showNewSessionForm()
            }
            .onReceive(NotificationCenter.default.publisher(for: .newGroupRequested)) { _ in
                groupStore.showNewGroupForm()
            }
            .onReceive(NotificationCenter.default.publisher(for: .connectSessionRequested)) { _ in
                if let session = sessionStore.selectedSession { onConnect(session) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .disconnectSessionRequested)) { _ in
                if let sessionId = tabBarStore.selectedTab?.sessionId {
                    NotificationCenter.default.post(
                        name: .disconnectActiveTerminalRequested,
                        object: nil,
                        userInfo: ["sessionId": sessionId]
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .disconnectAllRequested)) { _ in
                for tab in tabBarStore.tabs {
                    NotificationCenter.default.post(
                        name: .disconnectActiveTerminalRequested,
                        object: nil,
                        userInfo: ["sessionId": tab.sessionId]
                    )
                }
            }
            // 标签页操作
            .onReceive(NotificationCenter.default.publisher(for: .newTabRequested)) { _ in
                if let session = sessionStore.selectedSession {
                    onConnect(session)
                } else {
                    sessionStore.showNewSessionForm()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeTabRequested)) { _ in
                if let tab = tabBarStore.selectedTab { tabBarStore.requestCloseTab(tab) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .nextTabRequested)) { _ in
                tabBarStore.selectNextTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: .previousTabRequested)) { _ in
                tabBarStore.selectPreviousTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: .selectTabRequested)) { notification in
                if let index = notification.userInfo?["index"] as? Int {
                    tabBarStore.selectTab(at: index)
                }
            }
    }
}

// MARK: - 分屏会话选择弹窗

/// 选择要在分屏窗格显示的会话
struct SplitSessionPickerView: View {

    let sessions: [Session]
    var onSelect: ((Session) -> Void)?
    var onCancel: (() -> Void)?

    @State private var searchText: String = ""

    private var filteredSessions: [Session] {
        if searchText.isEmpty { return sessions }
        return sessions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("选择分屏会话")
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Spacer()
                Button(action: { onCancel?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(DesignTokens.Colors.surfaceCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            // 搜索框
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                TextField("搜索会话…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DesignTokens.Typography.bodySmall)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            .padding(DesignTokens.Spacing.md)

            // 会话列表
            if filteredSessions.isEmpty {
                Spacer()
                Text("没有匹配的会话")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Spacer()
            } else {
                List(filteredSessions, id: \.id) { session in
                    Button(action: { onSelect?(session) }) {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "terminal")
                                .font(.system(size: 13))
                                .foregroundColor(DesignTokens.Colors.accentPrimary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.name)
                                    .font(DesignTokens.Typography.labelMedium)
                                    .foregroundColor(DesignTokens.Colors.textPrimary)
                                Text("\(session.username)@\(session.host):\(session.port)")
                                    .font(DesignTokens.Typography.codeSmall)
                                    .foregroundColor(DesignTokens.Colors.textTertiary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("取消", action: { onCancel?() })
                    .buttonStyle(.bordered)
            }
            .padding(DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.surfacePanel)
    }
}

/// 分组表单弹窗
struct GroupFormSheet: View {

    // MARK: - 属性

    var editingGroup: SessionGroup?
    var onSave: ((SessionGroup) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - 状态

    @State private var name: String = ""
    @State private var colorHex: String = "#4A90D9"

    // MARK: - 预设颜色

    private let presetColors: [String] = [
        "#4A90D9", "#2DCE7A", "#F0A500", "#F04060",
        "#9B59B6", "#E67E22", "#1ABC9C", "#34495E"
    ]

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text(editingGroup != nil ? "编辑分组" : "新建分组")
                    .font(DesignTokens.Typography.titleMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Button(action: { onCancel?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(DesignTokens.Colors.surfaceCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            // 内容
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                FormField(label: "分组名称", isRequired: true) {
                    TextField("输入分组名称", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                FormField(label: "颜色") {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ForEach(presetColors, id: \.self) { hex in
                            Button(action: { colorHex = hex }) {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                colorHex == hex ? Color.white : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()

            Divider()

            // 底部按钮
            HStack {
                Spacer()

                Button("取消") {
                    onCancel?()
                }
                .buttonStyle(.bordered)

                Button(editingGroup != nil ? "保存" : "创建") {
                    saveGroup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 400, height: 280)
        .background(DesignTokens.Colors.surfacePanel)
        .onAppear {
            if let group = editingGroup {
                name = group.name
                colorHex = group.colorHex
            }
        }
    }

    private func saveGroup() {
        let group: SessionGroup
        if let existing = editingGroup {
            group = SessionGroup(
                id: existing.id,
                name: name.trimmingCharacters(in: .whitespaces),
                colorHex: colorHex,
                sortOrder: existing.sortOrder,
                isExpanded: existing.isExpanded,
                modifiedAt: Date(),
                parentId: existing.parentId,
                childrenIds: existing.childrenIds
            )
        } else {
            group = SessionGroup(
                name: name.trimmingCharacters(in: .whitespaces),
                colorHex: colorHex
            )
        }
        onSave?(group)
    }
}

// MARK: - 预览

#Preview("主窗口") {
    ContentView()
        .frame(width: 1200, height: 800)
}
