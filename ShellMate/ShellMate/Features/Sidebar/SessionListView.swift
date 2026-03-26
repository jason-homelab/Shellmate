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

        // 未分组区域头部（有未分组会话或有分组时始终显示，作为拖拽目标）
        if !ungroupedSessions.isEmpty || !groupStore.topLevelGroups.isEmpty {
            HStack {
                Text("未分组")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(Color.clear)
            .dropDestination(for: String.self) { items, _ in
                guard let idString = items.first,
                      let sessionId = UUID(uuidString: idString),
                      let session = sessionStore.sessions.first(where: { $0.id == sessionId }),
                      session.groupId != nil else { return false }
                draggedSessionId = nil
                Task { await sessionStore.moveSession(session, to: nil) }
                return true
            }
        }

        ForEach(ungroupedSessions) { session in
            sessionRow(session)
        }
    }

    // MARK: - 分组部分

    @ViewBuilder
    private func groupSection(_ group: SessionGroup) -> some View {
        let sessionsInGroup = sessionStore.filteredSessions.filter { $0.groupId == group.id }

        // 分组头部（用 VStack 包裹透明缓冲区以扩大拖拽命中区域）
        VStack(spacing: 0) {
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

            // 透明缓冲区：将拖拽命中高度从 30pt 扩大至 44pt
            Color.clear.frame(height: 14)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first,
                  let sessionId = UUID(uuidString: idString),
                  let session = sessionStore.sessions.first(where: { $0.id == sessionId }),
                  session.groupId != group.id else { return false }
            draggedSessionId = nil
            Task {
                await sessionStore.moveSession(session, to: group.id)
                // 自动展开目标分组，让用户看到移入的会话
                if !group.isExpanded {
                    await groupStore.setExpanded(group, isExpanded: true)
                }
            }
            return true
        }

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
                        // 自动展开目标分组，让用户看到移入的会话
                        if let current = groupStore.groups.first(where: { $0.id == group.id }),
                           !current.isExpanded {
                            await groupStore.setExpanded(current, isExpanded: true)
                        }
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

// MARK: - 会话拖拽代理

/// 会话拖拽代理
/// 处理会话行之间的拖拽排序
struct SessionDropDelegate: DropDelegate {
    let targetSession: Session
    let sessionStore: SessionStore
    @Binding var draggedSessionId: UUID?

    func performDrop(info: DropInfo) -> Bool {
        defer { draggedSessionId = nil }

        // 优先从 NSItemProvider 读取，避免 @Binding 时序问题
        let providers = info.itemProviders(for: [.text])
        if let provider = providers.first {
            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
                let idString: String?
                if let data = item as? Data {
                    idString = String(data: data, encoding: .utf8)
                } else if let str = item as? String {
                    idString = str
                } else {
                    idString = nil
                }
                guard let str = idString,
                      let draggedId = UUID(uuidString: str),
                      draggedId != targetSession.id,
                      let draggedSession = sessionStore.filteredSessions.first(where: { $0.id == draggedId }),
                      draggedSession.groupId != targetSession.groupId else { return }
                Task { @MainActor in
                    await sessionStore.moveSession(draggedSession, to: targetSession.groupId)
                }
            }
            return true
        }

        // 兜底：使用 @Binding（同组内重排时走此路径，跨组则依赖上方）
        guard let draggedId = draggedSessionId,
              draggedId != targetSession.id,
              let draggedSession = sessionStore.filteredSessions.first(where: { $0.id == draggedId }) else {
            return false
        }

        if draggedSession.groupId != targetSession.groupId {
            Task {
                await sessionStore.moveSession(draggedSession, to: targetSession.groupId)
            }
        }

        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedSessionId,
              draggedId != targetSession.id else {
            return
        }

        // 仅在同一分组内处理排序
        let draggedSession = sessionStore.filteredSessions.first { $0.id == draggedId }
        guard draggedSession?.groupId == targetSession.groupId else {
            return
        }

        let groupSessions = sessionStore.filteredSessions.filter { $0.groupId == targetSession.groupId }

        guard let sourceIndex = groupSessions.firstIndex(where: { $0.id == draggedId }),
              let destinationIndex = groupSessions.firstIndex(where: { $0.id == targetSession.id }) else {
            return
        }

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
