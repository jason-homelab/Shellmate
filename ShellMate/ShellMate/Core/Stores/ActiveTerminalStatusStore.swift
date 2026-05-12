import SwiftUI

/// 活跃终端状态共享存储
/// 由活跃 TerminalView（isSelected == true）持续推送数据；
/// ContentView 共享底栏消费，实现侧边栏 footer 与终端状态栏严格对齐。
@MainActor
final class ActiveTerminalStatusStore: ObservableObject {

    static let shared = ActiveTerminalStatusStore()
    private init() {}

    @Published var connectionState: ConnectionState = .offline
    @Published var session: Session? = nil
    @Published var serverMetrics: ServerMetrics? = nil
    @Published var terminalColumns: Int = 80
    @Published var terminalRows: Int = 24
    @Published var encoding: String = "UTF-8"
    @Published var connectedAt: Date? = nil
    /// TCP 握手延迟（毫秒），用于状态栏"·Xms"显示；nil 表示未连接或不适用
    @Published var latencyMs: Int? = nil
    @Published var tmuxAttachedSession: String? = nil
    @Published var tmuxSessionCount: Int = 0
    @Published var tmuxWindows: [TmuxWindow] = []

    /// 底栏点击指标区域时置为 true，活跃 TerminalView 消费后归零
    @Published var shouldShowMonitorPanel: Bool = false

    /// 切换 tmux 窗口（由活跃 TerminalView 在推送时设置）
    var onSelectTmuxWindow: ((Int) -> Void)? = nil

    func clear() {
        connectionState = .offline
        session = nil
        serverMetrics = nil
        terminalColumns = 80
        terminalRows = 24
        encoding = "UTF-8"
        connectedAt = nil
        latencyMs = nil
        tmuxAttachedSession = nil
        tmuxSessionCount = 0
        tmuxWindows = []
        shouldShowMonitorPanel = false
        onSelectTmuxWindow = nil
    }
}
