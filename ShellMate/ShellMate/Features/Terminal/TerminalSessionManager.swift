import Foundation

// MARK: - 终端会话管理器

/// 管理所有活跃 TerminalController 的生命周期（创建 / 查询 / 关闭）
/// 单例模式，由 ContentView 通过 TerminalControllerRegistry 访问
@MainActor
final class TerminalSessionManager: ObservableObject {

    static let shared = TerminalSessionManager()

    @Published private(set) var controllers: [UUID: TerminalController] = [:]
    @Published var selectedControllerId: UUID?

    let maxConnections: Int = 10

    private init() {}

    func createController(for session: Session) throws -> TerminalController {
        guard controllers.count < maxConnections else {
            throw SSHError.libssh2Error(code: -1, message: "已达到最大连接数限制")
        }
        let controller = TerminalController(session: session)
        controllers[session.id] = controller
        selectedControllerId = session.id
        return controller
    }

    func getController(for sessionId: UUID) -> TerminalController? {
        controllers[sessionId]
    }

    func closeController(for sessionId: UUID) async {
        if let controller = controllers[sessionId] {
            await controller.disconnect()
            controllers.removeValue(forKey: sessionId)
            if selectedControllerId == sessionId {
                selectedControllerId = controllers.keys.first
            }
        }
    }

    func closeAll() async {
        for (_, controller) in controllers { await controller.disconnect() }
        controllers.removeAll()
        selectedControllerId = nil
    }

    var selectedController: TerminalController? {
        guard let id = selectedControllerId else { return nil }
        return controllers[id]
    }

    var activeConnectionCount: Int {
        controllers.values.filter { $0.state == .connected }.count
    }
}
