import Foundation
import Combine

// MARK: - 同步输入管理器

/// 终端同步输入模式管理器（O03）
/// 在多个终端标签页之间广播键盘输入
@MainActor
final class SyncInputStore: ObservableObject {

    static let shared = SyncInputStore()

    // MARK: - 已注册会话信息

    struct SessionInfo: Identifiable {
        let id: UUID        // sessionId
        let title: String
        let state: TerminalController.State
    }

    // MARK: - 发布属性

    /// 当前参与同步的 Session ID 集合
    @Published private(set) var syncedSessionIds: Set<UUID> = []

    /// 是否处于激活状态
    var isActive: Bool { !syncedSessionIds.isEmpty }

    /// 参与同步的终端数量
    var syncCount: Int { syncedSessionIds.count }

    // MARK: - 私有属性

    /// Session ID → TerminalController 弱引用
    private var registry: [UUID: WeakRef] = [:]

    private init() {}

    // MARK: - 注册 / 注销

    /// 注册 TerminalController，连接到指定 Session
    func register(_ controller: TerminalController, for sessionId: UUID) {
        registry[sessionId] = WeakRef(controller)
    }

    /// 注销指定 Session（控制器销毁时调用）
    func unregister(sessionId: UUID) {
        registry.removeValue(forKey: sessionId)
        syncedSessionIds.remove(sessionId)
    }

    // MARK: - 同步状态管理

    /// 激活同步输入，指定参与的 Session ID 集合
    func activate(sessionIds: Set<UUID>) {
        syncedSessionIds = sessionIds
    }

    /// 关闭所有同步
    func deactivate() {
        syncedSessionIds = []
    }

    /// 查询指定 Session 是否处于同步模式
    func isSynced(_ sessionId: UUID) -> Bool {
        syncedSessionIds.contains(sessionId)
    }

    // MARK: - 会话信息查询

    /// 返回当前所有已注册（且控制器仍存活）的会话信息
    func registeredSessionInfos() -> [SessionInfo] {
        // 清理失效引用
        registry = registry.filter { $0.value.controller != nil }
        return registry.compactMap { id, ref in
            guard let ctrl = ref.controller else { return nil }
            return SessionInfo(id: id, title: ctrl.sessionTitle, state: ctrl.state)
        }.sorted { $0.title < $1.title }
    }

    // MARK: - 输入广播

    /// 将来自 senderId 的输入数据广播到其他参与同步的终端
    func broadcast(data: Data, from senderId: UUID) {
        guard syncedSessionIds.contains(senderId) else { return }
        for id in syncedSessionIds where id != senderId {
            registry[id]?.controller?.broadcastReceive(data: data)
        }
    }

    // MARK: - 弱引用容器

    private final class WeakRef {
        weak var controller: TerminalController?
        init(_ controller: TerminalController) { self.controller = controller }
    }
}
