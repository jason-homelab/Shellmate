import Foundation
import Combine

/// 会话状态管理器
/// 负责管理会话列表的状态和业务逻辑
@MainActor
final class SessionStore: ObservableObject {

    // MARK: - 发布属性

    /// 所有会话列表
    @Published private(set) var sessions: [Session] = []

    /// 搜索过滤后的会话列表
    @Published private(set) var filteredSessions: [Session] = []

    /// 搜索关键词
    @Published var searchQuery: String = "" {
        didSet {
            // BUG-003：取消前一个搜索 Task，防止多个并发任务以不确定顺序覆盖 filteredSessions
            searchTask?.cancel()
            searchTask = Task { await performSearch() }
        }
    }

    /// 当前搜索任务（用于取消旧任务）
    private var searchTask: Task<Void, Never>?

    /// 当前选中的会话 ID
    @Published var selectedSessionId: UUID?

    /// 正在编辑的会话（用于弹窗）
    @Published var editingSession: Session?

    /// 是否显示新建/编辑弹窗
    @Published var isShowingSessionForm: Bool = false

    /// 新建会话时预设的分组 ID（来自右键"新建会话"）
    @Published var defaultGroupId: UUID? = nil

    /// 是否正在加载
    @Published private(set) var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    private let repository: SessionRepository
    private var cancellables = Set<AnyCancellable>()

    /// BUG-005：拖拽进行中的本地排序快照（UUID → sortOrder）
    /// loadSessions() 检测到此快照非 nil 时会恢复拖拽顺序，防止 Core Data 刷新回弹
    private var dragSortOrders: [UUID: Int32]?

    // MARK: - 计算属性

    /// 当前选中的会话
    var selectedSession: Session? {
        guard let id = selectedSessionId else { return nil }
        return sessions.first { $0.id == id }
    }

    // MARK: - 初始化

    init(repository: SessionRepository? = nil) {
        self.repository = repository ?? SessionRepository()
    }

    // MARK: - 加载方法

    /// 加载所有会话
    func loadSessions() async {
        isLoading = true
        errorMessage = nil

        // BUG-005：快照拖拽中的本地排序，防止 Core Data 刷新覆盖尚未持久化的重排
        let liveDragOrder = dragSortOrders

        do {
            var fetched = try await repository.fetchAll()
                .sorted { $0.sortOrder < $1.sortOrder }

            // 在 await 返回后从当前 sessions 读取最新连接状态：
            // SSH 连接可能在 repository.fetchAll() 挂起期间完成，此时 updateConnectionState 已
            // 将 sessions[i].connectionState 置为 .connected。若在 await 前快照，则会错过这次更新，
            // 导致 sessions = fetched 将状态覆盖回 .offline，引发侧边栏计数器永远显示 0。
            for i in fetched.indices {
                if let current = sessions.first(where: { $0.id == fetched[i].id }),
                   current.connectionState != .offline {
                    fetched[i].connectionState = current.connectionState
                }
                // 恢复拖拽排序（拖拽结束前 persistSortOrder 未调用时保持本地顺序）
                if let dragOrder = liveDragOrder?[fetched[i].id] {
                    fetched[i].sortOrder = dragOrder
                }
            }
            // 若拖拽进行中，按本地排序重新排列
            if liveDragOrder != nil {
                fetched.sort { $0.sortOrder < $1.sortOrder }
            }
            sessions = fetched
            await performSearch()
        } catch {
            errorMessage = "加载会话失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 根据分组加载会话
    func loadSessions(forGroup groupId: UUID?) async -> [Session] {
        do {
            return try await repository.fetchByGroup(groupId: groupId)
        } catch {
            errorMessage = "加载分组会话失败: \(error.localizedDescription)"
            return []
        }
    }

    // MARK: - 搜索方法

    /// 执行搜索
    private func performSearch() async {
        guard !Task.isCancelled else { return }  // BUG-003：被新搜索任务取消时提前退出
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            filteredSessions = sessions
        } else {
            do {
                filteredSessions = try await repository.search(query: query)
            } catch {
                // 仅在 sessions 已加载完成时才使用内存过滤兜底，
                // 避免初次加载尚未完成时将 filteredSessions 错误地置为空列表
                guard !sessions.isEmpty else { return }
                filteredSessions = sessions.filter { session in
                    session.name.localizedCaseInsensitiveContains(query) ||
                    session.host.localizedCaseInsensitiveContains(query) ||
                    session.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                }
            }
        }
    }

    // MARK: - CRUD 方法

    /// 保存会话
    func saveSession(_ session: Session) async {
        do {
            try await repository.save(session)
            await loadSessions()
        } catch {
            errorMessage = "保存会话失败: \(error.localizedDescription)"
        }
    }

    /// 删除会话
    func deleteSession(_ session: Session) async {
        do {
            try await repository.delete(session)
            if selectedSessionId == session.id {
                selectedSessionId = nil
            }
            await loadSessions()
        } catch {
            errorMessage = "删除会话失败: \(error.localizedDescription)"
        }
    }

    /// 永久删除会话
    func permanentlyDeleteSession(_ session: Session) async {
        do {
            try await repository.permanentlyDelete(session)
            if selectedSessionId == session.id {
                selectedSessionId = nil
            }
            await loadSessions()
        } catch {
            errorMessage = "永久删除会话失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 移动方法

    /// 移动会话到指定分组
    func moveSession(_ session: Session, to groupId: UUID?) async {
        do {
            try await repository.move(session: session, to: groupId)
            await loadSessions()
        } catch {
            errorMessage = "移动会话失败: \(error.localizedDescription)"
        }
    }

    /// 仅在内存中重排会话顺序（拖拽悬停时调用，不触发持久化）
    func reorderLocally(from source: IndexSet, to destination: Int, in groupId: UUID?) {
        var groupSessions = sessions.filter { $0.groupId == groupId }

        groupSessions.move(fromOffsets: source, toOffset: destination)

        for (index, var session) in groupSessions.enumerated() {
            session.sortOrder = Int32(index)
            groupSessions[index] = session
        }

        let updatedIds = Dictionary(uniqueKeysWithValues: groupSessions.map { ($0.id, $0) })
        sessions = sessions.map { updatedIds[$0.id] ?? $0 }
        filteredSessions = filteredSessions.map { updatedIds[$0.id] ?? $0 }

        // BUG-005：记录拖拽中的排序快照，供 loadSessions() 恢复使用，防止 Core Data 刷新回弹
        dragSortOrders = Dictionary(uniqueKeysWithValues: groupSessions.map { ($0.id, $0.sortOrder) })
    }

    /// 将当前内存中的排序持久化到 Core Data（拖拽结束时调用）
    func persistSortOrder(in groupId: UUID?) async {
        let groupSessions = sessions.filter { $0.groupId == groupId }
            .sorted { $0.sortOrder < $1.sortOrder }

        do {
            try await repository.updateSortOrder(sessions: groupSessions)
            dragSortOrders = nil  // BUG-005：持久化成功后清除快照
        } catch {
            errorMessage = "更新排序失败: \(error.localizedDescription)"
            dragSortOrders = nil
            await loadSessions()
        }
    }

    /// 更新会话排序（完整流程：本地重排 + 持久化）
    func updateSortOrder(from source: IndexSet, to destination: Int, in groupId: UUID?) async {
        reorderLocally(from: source, to: destination, in: groupId)

        do {
            let groupSessions = sessions.filter { $0.groupId == groupId }
            try await repository.updateSortOrder(sessions: groupSessions)
            dragSortOrders = nil  // 持久化成功后清除快照，防止后续 loadSessions 重复叠加旧排序
            await loadSessions()
        } catch {
            errorMessage = "更新排序失败: \(error.localizedDescription)"
            dragSortOrders = nil
            await loadSessions()
        }
    }

    // MARK: - 弹窗方法

    /// 显示新建会话弹窗
    /// - Parameter groupId: 可选，预设分组（来自分组右键菜单"新建会话"）
    func showNewSessionForm(groupId: UUID? = nil) {
        editingSession = nil
        defaultGroupId = groupId
        isShowingSessionForm = true
    }

    /// 显示编辑会话弹窗
    func showEditSessionForm(for session: Session) {
        editingSession = session
        isShowingSessionForm = true
    }

    /// 关闭弹窗
    func dismissSessionForm() {
        isShowingSessionForm = false
        editingSession = nil
    }

    // MARK: - 连接状态更新

    /// 更新会话连接状态
    func updateConnectionState(for sessionId: UUID, state: ConnectionState) {
        // 使用 map 整体替换数组，确保 @Published 的 objectWillChange 一定触发
        sessions = sessions.map { s in
            guard s.id == sessionId else { return s }
            var copy = s; copy.connectionState = state; return copy
        }
        filteredSessions = filteredSessions.map { s in
            guard s.id == sessionId else { return s }
            var copy = s; copy.connectionState = state; return copy
        }
    }

    /// 更新最后连接时间
    func updateLastConnectedAt(for sessionId: UUID) async {
        if var session = sessions.first(where: { $0.id == sessionId }) {
            session.lastConnectedAt = Date()
            await saveSession(session)
        }
    }
}
