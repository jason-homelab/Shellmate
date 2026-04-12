import Foundation

// MARK: - TerminalControllerRegistry

/// 全局注册表：session.id → TerminalController
/// 每个 TerminalView 在 onAppear 时注册，onDisappear 时注销。
/// ContentView / Toolbar 通过此注册表查找活跃会话的 controller，
/// 从而访问 recorder、isRecordingDialogOpen 等属性。
@MainActor
final class TerminalControllerRegistry {

    static let shared = TerminalControllerRegistry()
    private init() {}

    // 弱引用字典（TerminalController 由 TerminalView 的 @StateObject 持有，生命周期一致）
    private var registry: [UUID: WeakController] = [:]

    private struct WeakController {
        weak var value: TerminalController?
    }

    func register(_ controller: TerminalController, for sessionId: UUID) {
        registry[sessionId] = WeakController(value: controller)
    }

    func unregister(sessionId: UUID) {
        registry.removeValue(forKey: sessionId)
    }

    func controller(for sessionId: UUID) -> TerminalController? {
        registry[sessionId]?.value
    }
}
