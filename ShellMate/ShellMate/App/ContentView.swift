import SwiftUI

/// 主内容视图
/// 使用 NavigationSplitView 实现侧边栏和主区域的布局
struct ContentView: View {

    // MARK: - 状态

    @StateObject private var sessionStore = SessionStore()
    @StateObject private var groupStore = GroupStore()
    @StateObject private var tabBarStore = TabBarStore()

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
        .alert("错误", isPresented: .constant(sessionStore.errorMessage != nil)) {
            Button("确定") {
                sessionStore.errorMessage = nil
            }
        } message: {
            if let error = sessionStore.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - 终端内容区域

    @ViewBuilder
    private var terminalContentArea: some View {
        if let selectedTab = tabBarStore.selectedTab,
           let session = sessionStore.sessions.first(where: { $0.id == selectedTab.sessionId }) {
            // 显示当前选中标签页的终端视图
            // 使用 .id(selectedTab.id) 确保切换标签时视图正确刷新
            TerminalView(session: session)
                .id(selectedTab.id)
        } else {
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
        }
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
