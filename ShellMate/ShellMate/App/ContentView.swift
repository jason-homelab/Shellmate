import SwiftUI

/// 主内容视图
/// 使用 NavigationSplitView 实现侧边栏和主区域的布局
struct ContentView: View {

    // MARK: - 状态

    @StateObject private var sessionStore = SessionStore()
    @StateObject private var groupStore = GroupStore()

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
            // 主区域（终端）
            if let session = sessionStore.selectedSession {
                TerminalView(session: session)
            } else {
                // 无选中会话时显示空状态
                TerminalPlaceholderView(
                    session: nil,
                    onConnect: nil
                )
            }
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
            .help("新建会话")
            .keyboardShortcut("n", modifiers: .command)
        }

        // 连接/断开
        ToolbarItem(placement: .primaryAction) {
            if let session = sessionStore.selectedSession {
                if session.connectionState == .connected {
                    Button(action: {
                        disconnectSession(session)
                    }) {
                        Label("断开", systemImage: "bolt.slash.fill")
                    }
                    .help("断开连接")
                } else if session.connectionState == .offline {
                    Button(action: {
                        connectToSession(session)
                    }) {
                        Label("连接", systemImage: "bolt.fill")
                    }
                    .help("连接")
                    .keyboardShortcut(.return, modifiers: .command)
                }
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
        // 选中会话，TerminalView 会处理实际的连接
        sessionStore.selectedSessionId = session.id

        // 更新最后连接时间
        Task {
            await sessionStore.updateLastConnectedAt(for: session.id)
        }
    }

    private func disconnectSession(_ session: Session) {
        // 断开连接状态由 TerminalController 管理
        sessionStore.updateConnectionState(for: session.id, state: .offline)
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
