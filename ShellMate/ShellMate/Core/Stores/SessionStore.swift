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
            Task { await performSearch() }
        }
    }

    /// 当前选中的会话 ID
    @Published var selectedSessionId: UUID?

    /// 正在编辑的会话（用于弹窗）
    @Published var editingSession: Session?

    /// 是否显示新建/编辑弹窗
    @Published var isShowingSessionForm: Bool = false

    /// 是否正在加载
    @Published private(set) var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    private let repository: SessionRepository
    private var cancellables = Set<AnyCancellable>()

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

        do {
            sessions = try await repository.fetchAll()
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
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            filteredSessions = sessions
        } else {
            do {
                filteredSessions = try await repository.search(query: query)
            } catch {
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

    /// 更新会话排序
    func updateSortOrder(from source: IndexSet, to destination: Int, in groupId: UUID?) async {
        var groupSessions = sessions.filter { $0.groupId == groupId }

        groupSessions.move(fromOffsets: source, toOffset: destination)

        for (index, var session) in groupSessions.enumerated() {
            session.sortOrder = Int32(index)
            groupSessions[index] = session
        }

        do {
            try await repository.updateSortOrder(sessions: groupSessions)
            await loadSessions()
        } catch {
            errorMessage = "更新排序失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 弹窗方法

    /// 显示新建会话弹窗
    func showNewSessionForm() {
        editingSession = nil
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
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].connectionState = state
        }
        if let index = filteredSessions.firstIndex(where: { $0.id == sessionId }) {
            filteredSessions[index].connectionState = state
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
