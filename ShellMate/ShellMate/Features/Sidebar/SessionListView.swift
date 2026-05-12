import SwiftUI

/// 会话列表视图
/// 显示分组和会话的列表，支持拖拽排序和右键菜单
struct SessionListView: View {

    // MARK: - 属性

    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var groupStore: GroupStore

    /// 双击会话回调（连接）
    var onConnect: ((Session) -> Void)?

    @Environment(\.openWindow) private var openWindow

    // MARK: - 视图

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.xxs, pinnedViews: []) {
                // 未分组的会话
                ungroupedSessionsSection

                // 分组列表
                ForEach(groupStore.topLevelGroups) { group in
                    groupSection(group)
                }
            }
            // Figma 8:15/8:20: left=4, trailing=4 → 行容器230pt，选中行再加6pt trailing → 蓝色背景224pt
            // 非选中行填满230pt，悬停背景更贴近 Figma（8:20 rows overflow to ~248px in 256px frame）
            .padding(.leading, 4)
            .padding(.trailing, 4)
            .padding(.top, 14)
            .padding(.bottom, 4)
        }
        // 移除 ScrollView 默认白色背景，让父层 surfaceWindow (#F5F5F7) 透出
        .scrollContentBackground(.hidden)
        .background(DesignTokens.Colors.surfaceWindow)
    }

    // MARK: - 未分组会话

    @ViewBuilder
    private var ungroupedSessionsSection: some View {
        let ungroupedSessions = sessionStore.filteredSessions.filter { $0.groupId == nil }

        // 未分组拖拽目标区域（透明，不显示标签）
        if !ungroupedSessions.isEmpty || !groupStore.topLevelGroups.isEmpty {
            Color.clear
                .frame(height: 4)
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
            }
        }
    }

    // MARK: - 私有状态

    /// 正在拖拽的会话 ID
    @State private var draggedSessionId: UUID?

    /// 当前拖拽悬停的目标会话 ID（用于显示插入指示线）
    @State private var dropTargetSessionId: UUID?

    // MARK: - 会话行

    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        VStack(spacing: 0) {
            // 拖拽插入指示线（当前悬停目标上方显示蓝色线条）
            if dropTargetSessionId == session.id && draggedSessionId != session.id {
                RoundedRectangle(cornerRadius: 1)
                    .fill(DesignTokens.Colors.accentPrimary)
                    .frame(height: 2)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .transition(.opacity)
            }

            SessionRowView(
                session: session,
                isSelected: sessionStore.selectedSessionId == session.id
            )
            .opacity(draggedSessionId == session.id ? 0.4 : 1.0)
            // 选中行收窄至 224pt（非选中行填满 230pt 更接近 Figma 8:15/8:20 比例）
            .padding(.trailing, sessionStore.selectedSessionId == session.id ? 6 : 0)
            .animation(DesignTokens.Animation.hover, value: sessionStore.selectedSessionId == session.id)
        }
        .onTapGesture {
            // Figma-Spec-v2 §02：单击即连接；onDoubleClick 已移除（BUG-002：双击会触发父级
            // 单击手势导致 onConnect 调用两次，创建重复标签页）
            onConnect?(session)
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
            draggedSessionId: $draggedSessionId,
            dropTargetSessionId: $dropTargetSessionId
        ))
    }

    // MARK: - 会话右键菜单

    @ViewBuilder
    private func sessionContextMenu(_ session: Session) -> some View {
        Button("连接") {
            onConnect?(session)
        }

        Button("在新窗口打开") {
            // 选中会话，写入待连接会话 ID，再打开新窗口（新窗口会自动连接）
            sessionStore.selectedSessionId = session.id
            UserDefaults.standard.set(session.id.uuidString, forKey: "pendingAutoConnectSessionId")
            openWindow(id: "main")
        }

        Menu("分屏打开") {
            Button("左右分屏") {
                NotificationCenter.default.post(
                    name: .splitSessionRequested,
                    object: nil,
                    userInfo: ["sessionId": session.id, "layout": "horizontal"]
                )
            }
            Button("上下分屏") {
                NotificationCenter.default.post(
                    name: .splitSessionRequested,
                    object: nil,
                    userInfo: ["sessionId": session.id, "layout": "vertical"]
                )
            }
        }

        Divider()

        Button("编辑") {
            // 从 store 取最新快照：拖拽后 session 闭包参数可能已过期（groupId 为旧值）
            let fresh = sessionStore.sessions.first(where: { $0.id == session.id }) ?? session
            sessionStore.showEditSessionForm(for: fresh)
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
        Button("新建会话") {
            sessionStore.showNewSessionForm(groupId: group.id)
        }

        Button("编辑分组") {
            groupStore.showEditGroupForm(for: group)
        }

        Button("新建子分组") {
            groupStore.showNewGroupForm(parentId: group.id)
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
/// 处理会话行之间的拖拽排序（本地即时重排 + 放下时持久化）
struct SessionDropDelegate: DropDelegate {
    let targetSession: Session
    let sessionStore: SessionStore
    @Binding var draggedSessionId: UUID?
    @Binding var dropTargetSessionId: UUID?

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedSessionId = nil
            dropTargetSessionId = nil
        }

        guard let draggedId = draggedSessionId,
              draggedId != targetSession.id else {
            // 兜底：从 NSItemProvider 读取（跨组移动场景）
            return handleCrossGroupDrop(info: info)
        }

        let draggedSession = sessionStore.filteredSessions.first { $0.id == draggedId }

        if draggedSession?.groupId == targetSession.groupId {
            // 同组内：排序已在 dropEntered 中完成，仅需持久化
            Task {
                await sessionStore.persistSortOrder(in: targetSession.groupId)
            }
        } else if let draggedSession = draggedSession {
            // 跨组：移动到目标分组
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

        // 更新悬停指示器
        dropTargetSessionId = targetSession.id

        // 仅在同一分组内处理即时重排
        let draggedSession = sessionStore.filteredSessions.first { $0.id == draggedId }
        guard draggedSession?.groupId == targetSession.groupId else {
            return
        }

        let groupSessions = sessionStore.filteredSessions.filter { $0.groupId == targetSession.groupId }

        guard let sourceIndex = groupSessions.firstIndex(where: { $0.id == draggedId }),
              let destinationIndex = groupSessions.firstIndex(where: { $0.id == targetSession.id }),
              sourceIndex != destinationIndex else {
            return
        }

        // 仅做本地重排 + 动画，不触发持久化
        withAnimation(DesignTokens.Animation.spring) {
            sessionStore.reorderLocally(
                from: IndexSet(integer: sourceIndex),
                to: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex,
                in: targetSession.groupId
            )
        }
    }

    func dropExited(info: DropInfo) {
        // 离开当前目标时清除指示器
        if dropTargetSessionId == targetSession.id {
            dropTargetSessionId = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    // MARK: - 跨组拖拽兜底

    private func handleCrossGroupDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.text])
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
            let idString: String?
            if let data = item as? Data {
                idString = String(data: data, encoding: .utf8)
            } else if let str = item as? String {
                idString = str
            } else {
                idString = nil
            }
            // filteredSessions 是主 Actor 隔离属性，不能在 @Sendable 闭包内直接访问
            // 将 UUID 解析结果传入 Task { @MainActor in } 后再查找
            guard let str = idString,
                  let draggedId = UUID(uuidString: str),
                  draggedId != targetSession.id else { return }
            Task { @MainActor in
                guard let draggedSession = sessionStore.filteredSessions.first(where: { $0.id == draggedId }),
                      draggedSession.groupId != targetSession.groupId else { return }
                await sessionStore.moveSession(draggedSession, to: targetSession.groupId)
            }
        }
        return true
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
