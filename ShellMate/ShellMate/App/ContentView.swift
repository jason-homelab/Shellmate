import SwiftUI

// MARK: - 分屏布局类型

private enum SplitLayout {
    case none
    case horizontal  // 左右分屏
    case vertical    // 上下分屏
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
        // 14.5：终端类应用强制深色模式，确保颜色令牌始终正确渲染
        // 用户可在系统设置中覆盖（外观设置面板 S02 将来接管此逻辑）
        .preferredColorScheme(.dark)
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
            // 空状态：无标签页时引导用户连接
            VStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: "terminal")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Text("请从左侧选择一个会话")
                    .font(DesignTokens.Typography.bodyLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Text("双击会话或点击「连接」按钮以打开终端")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.surfaceWindow)
        } else {
            // 分屏：有分屏会话时显示分割布局
            if splitLayout != .none,
               let splitId = splitSessionId,
               let splitSession = sessionStore.sessions.first(where: { $0.id == splitId }) {
                if splitLayout == .horizontal {
                    HSplitView {
                        mainTerminalStack.frame(minWidth: 300)
                        TerminalView(session: splitSession).frame(minWidth: 300)
                    }
                } else {
                    VSplitView {
                        mainTerminalStack.frame(minHeight: 200)
                        TerminalView(session: splitSession).frame(minHeight: 200)
                    }
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
        // 新建会话
        ToolbarItem(placement: .primaryAction) {
            Button(action: {
                sessionStore.showNewSessionForm()
            }) {
                Label("新建会话", systemImage: "plus")
            }
            .help("新建会话 (⌘N)")
            .keyboardShortcut("n", modifiers: .command)
        }

        // 新建标签页（⌘T）：有选中会话时直接打开，否则显示新建会话表单
        ToolbarItem(placement: .primaryAction) {
            Button(action: {
                if let session = sessionStore.selectedSession {
                    connectToSession(session)
                } else {
                    sessionStore.showNewSessionForm()
                }
            }) {
                Label("新建标签页", systemImage: "plus.rectangle.on.rectangle")
            }
            .help("新建标签页 (⌘T)")
            .keyboardShortcut("t", modifiers: .command)
        }

        // 快速连接（无标签页时显示）
        ToolbarItem(placement: .primaryAction) {
            if tabBarStore.tabs.isEmpty, let session = sessionStore.selectedSession {
                Button(action: {
                    connectToSession(session)
                }) {
                    Label("连接", systemImage: "bolt.fill")
                }
                .help("连接选中会话 (⌘↩)")
                .keyboardShortcut(.return, modifiers: .command)
            }
        }

        // 分屏控制（有标签页时显示）
        ToolbarItem(placement: .primaryAction) {
            if !tabBarStore.tabs.isEmpty {
                Menu {
                    if splitLayout == .none {
                        Button(action: { showSplitSessionPicker = true; splitLayout = .horizontal }) {
                            Label("左右分屏", systemImage: "rectangle.split.2x1")
                        }
                        Button(action: { showSplitSessionPicker = true; splitLayout = .vertical }) {
                            Label("上下分屏", systemImage: "rectangle.split.1x2")
                        }
                    } else {
                        Button(action: {
                            splitLayout = .horizontal
                            if splitSessionId == nil { showSplitSessionPicker = true }
                        }) {
                            Label("切换为左右分屏", systemImage: "rectangle.split.2x1")
                        }
                        Button(action: {
                            splitLayout = .vertical
                            if splitSessionId == nil { showSplitSessionPicker = true }
                        }) {
                            Label("切换为上下分屏", systemImage: "rectangle.split.1x2")
                        }
                        Divider()
                        Button(role: .destructive) {
                            splitLayout = .none
                            splitSessionId = nil
                        } label: {
                            Label("关闭分屏", systemImage: "rectangle")
                        }
                    }
                } label: {
                    Image(systemName: splitLayout != .none ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                        .foregroundColor(splitLayout != .none ? DesignTokens.Colors.accentPrimary : nil)
                }
                .help(splitLayout != .none ? "分屏管理" : "开启分屏")
            }
        }
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
                        .cornerRadius(12)
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
            .cornerRadius(DesignTokens.Sizes.cornerRadiusSmall)
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
                        .cornerRadius(12)
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
