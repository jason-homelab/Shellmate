import SwiftUI

/// 会话列表视图
/// 显示分组和会话的列表，支持拖拽排序和右键菜单
struct SessionListView: View {

    // MARK: - 属性

    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var groupStore: GroupStore

    /// 双击会话回调（连接）
    var onConnect: ((Session) -> Void)?

    // MARK: - 视图

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                // 未分组的会话
                ungroupedSessionsSection

                // 分组列表
                ForEach(groupStore.topLevelGroups) { group in
                    groupSection(group)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
    }

    // MARK: - 未分组会话

    @ViewBuilder
    private var ungroupedSessionsSection: some View {
        let ungroupedSessions = sessionStore.filteredSessions.filter { $0.groupId == nil }

        // 未分组区域头部（作为拖拽目标）
        if !ungroupedSessions.isEmpty || draggedSessionId != nil {
            HStack {
                Text("未分组")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(Color.clear)
            .onDrop(of: [.text], delegate: UngroupedDropDelegate(
                sessionStore: sessionStore,
                draggedSessionId: $draggedSessionId
            ))
        }

        ForEach(ungroupedSessions) { session in
            sessionRow(session)
        }
    }

    // MARK: - 分组部分

    @ViewBuilder
    private func groupSection(_ group: SessionGroup) -> some View {
        let sessionsInGroup = sessionStore.filteredSessions.filter { $0.groupId == group.id }

        // 分组头部
        GroupHeaderView(
            group: group,
            sessionCount: sessionsInGroup.count,
            onToggle: {
                Task {
                    await groupStore.toggleExpanded(group)
                }
            },
            onDoubleClick: {
                groupStore.showEditGroupForm(for: group)
            }
        )
        .contextMenu {
            groupContextMenu(group)
        }
        .onDrop(of: [.text], delegate: GroupDropDelegate(
            targetGroup: group,
            sessionStore: sessionStore,
            draggedSessionId: $draggedSessionId
        ))

        // 分组下的会话（展开时显示）
        if group.isExpanded {
            ForEach(sessionsInGroup) { session in
                sessionRow(session)
                    .padding(.leading, DesignTokens.Spacing.lg)
            }
        }
    }

    // MARK: - 私有状态

    /// 正在拖拽的会话 ID
    @State private var draggedSessionId: UUID?

    // MARK: - 会话行

    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        SessionRowView(
            session: session,
            isSelected: sessionStore.selectedSessionId == session.id,
            onDoubleClick: {
                onConnect?(session)
            }
        )
        .onTapGesture {
            sessionStore.selectedSessionId = session.id
        }
        .contextMenu {
            sessionContextMenu(session)
        }
        .onDrag {
            draggedSessionId = session.id
            return NSItemProvider(object: session.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: SessionDropDelegate(
            targetSession: session,
            sessionStore: sessionStore,
            draggedSessionId: $draggedSessionId
        ))
    }

    // MARK: - 会话右键菜单

    @ViewBuilder
    private func sessionContextMenu(_ session: Session) -> some View {
        Button("连接") {
            onConnect?(session)
        }

        Divider()

        Button("编辑") {
            sessionStore.showEditSessionForm(for: session)
        }

        Button("复制") {
            duplicateSession(session)
        }

        Divider()

        Menu("移动到分组") {
            Button("未分组") {
                Task {
                    await sessionStore.moveSession(session, to: nil)
                }
            }

            Divider()

            ForEach(groupStore.groups) { group in
                Button(group.name) {
                    Task {
                        await sessionStore.moveSession(session, to: group.id)
                    }
                }
            }
        }

        Divider()

        Button("删除", role: .destructive) {
            Task {
                await sessionStore.deleteSession(session)
            }
        }
    }

    // MARK: - 分组右键菜单

    @ViewBuilder
    private func groupContextMenu(_ group: SessionGroup) -> some View {
        Button("编辑分组") {
            groupStore.showEditGroupForm(for: group)
        }

        Button("新建子分组") {
            // 创建子分组时设置父分组
            groupStore.showNewGroupForm()
        }

        Divider()

        if group.isExpanded {
            Button("折叠") {
                Task {
                    await groupStore.setExpanded(group, isExpanded: false)
                }
            }
        } else {
            Button("展开") {
                Task {
                    await groupStore.setExpanded(group, isExpanded: true)
                }
            }
        }

        Button("全部展开子项") {
            Task {
                await groupStore.setExpanded(group, isExpanded: true)
                for childId in group.childrenIds {
                    if let child = groupStore.group(by: childId) {
                        await groupStore.setExpanded(child, isExpanded: true)
                    }
                }
            }
        }

        Divider()

        // 移动到其他分组（嵌套）
        Menu("移动到分组") {
            Button("顶级分组") {
                Task {
                    var updatedGroup = group
                    updatedGroup.parentId = nil
                    await groupStore.saveGroup(updatedGroup)
                }
            }

            Divider()

            ForEach(groupStore.groups.filter { $0.id != group.id && $0.parentId != group.id }) { targetGroup in
                Button(targetGroup.name) {
                    Task {
                        var updatedGroup = group
                        updatedGroup.parentId = targetGroup.id
                        await groupStore.saveGroup(updatedGroup)
                    }
                }
            }
        }

        Divider()

        Button("删除分组", role: .destructive) {
            Task {
                await groupStore.deleteGroup(group)
            }
        }
    }

    // MARK: - 辅助方法

    private func duplicateSession(_ session: Session) {
        var newSession = session
        newSession = Session(
            name: "\(session.name) 副本",
            host: session.host,
            port: session.port,
            username: session.username,
            authMethod: session.authMethod,
            keepAliveInterval: session.keepAliveInterval,
            autoReconnect: session.autoReconnect,
            encoding: session.encoding,
            tags: session.tags,
            colorHex: session.colorHex,
            groupId: session.groupId
        )

        Task {
            await sessionStore.saveSession(newSession)
        }
    }
}

// MARK: - 未分组拖拽代理

/// 未分组拖拽代理
/// 处理将会话拖拽到未分组区域的操作
struct UngroupedDropDelegate: DropDelegate {
    let sessionStore: SessionStore
    @Binding var draggedSessionId: UUID?

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedId = draggedSessionId else {
            return false
        }

        // 查找被拖拽的会话
        guard let session = sessionStore.filteredSessions.first(where: { $0.id == draggedId }) else {
            return false
        }

        // 移动会话到未分组
        Task {
            await sessionStore.moveSession(session, to: nil)
        }

        draggedSessionId = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        guard let draggedId = draggedSessionId else {
            return false
        }

        // 检查会话是否已经是未分组的
        guard let session = sessionStore.filteredSessions.first(where: { $0.id == draggedId }) else {
            return false
        }

        return session.groupId != nil
    }
}

// MARK: - 分组拖拽代理

/// 分组拖拽代理
/// 处理将会话拖拽到分组上的操作
struct GroupDropDelegate: DropDelegate {
    let targetGroup: SessionGroup
    let sessionStore: SessionStore
    @Binding var draggedSessionId: UUID?

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedId = draggedSessionId else {
            return false
        }

        // 查找被拖拽的会话
        guard let session = sessionStore.filteredSessions.first(where: { $0.id == draggedId }) else {
            return false
        }

        // 移动会话到目标分组
        Task {
            await sessionStore.moveSession(session, to: targetGroup.id)
        }

        draggedSessionId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        // 可以添加视觉反馈，如高亮分组
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        // 验证是否可以放置
        guard let draggedId = draggedSessionId else {
            return false
        }

        // 检查会话是否已经在目标分组中
        guard let session = sessionStore.filteredSessions.first(where: { $0.id == draggedId }) else {
            return false
        }

        return session.groupId != targetGroup.id
    }
}

// MARK: - 会话拖拽代理

/// 会话拖拽代理
/// 处理会话行之间的拖拽排序
struct SessionDropDelegate: DropDelegate {
    let targetSession: Session
    let sessionStore: SessionStore
    @Binding var draggedSessionId: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggedSessionId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedSessionId,
              draggedId != targetSession.id else {
            return
        }

        // 只能在同一分组内排序
        let draggedSession = sessionStore.filteredSessions.first { $0.id == draggedId }
        guard draggedSession?.groupId == targetSession.groupId else {
            return
        }

        // 获取同一分组内的会话列表
        let groupSessions = sessionStore.filteredSessions.filter { $0.groupId == targetSession.groupId }

        guard let sourceIndex = groupSessions.firstIndex(where: { $0.id == draggedId }),
              let destinationIndex = groupSessions.firstIndex(where: { $0.id == targetSession.id }) else {
            return
        }

        // 更新排序
        Task {
            await sessionStore.updateSortOrder(
                from: IndexSet(integer: sourceIndex),
                to: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex,
                in: targetSession.groupId
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - 预览

#Preview("会话列表") {
    let sessionStore = SessionStore()
    let groupStore = GroupStore()

    return SessionListView(
        sessionStore: sessionStore,
        groupStore: groupStore
    )
    .frame(width: 220, height: 600)
    .background(DesignTokens.Colors.surfaceWindow)
}
