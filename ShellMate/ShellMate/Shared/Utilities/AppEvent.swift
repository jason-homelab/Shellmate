import Foundation

// MARK: - 类型安全通知事件命名空间
//
// 替代 NotificationCenter 裸 userInfo 字典，消除运行时类型转换风险。
// 每种携带 payload 的通知都提供一对静态方法：
//   - post*(…)      → 发送，键名由 Key 常量保证，无拼写风险
//   - extract*(…)   → 接收，返回 Optional 强类型，失败即 nil

enum AppEvent {

    // MARK: - sessionConnectionStateChanged
    // 发送方：TerminalView（state 变化 / onDisappear）
    // 接收方：ContentView（同步 SessionStore + TabBarStore）

    static func postConnectionState(sessionId: UUID, state: ConnectionState) {
        NotificationCenter.default.post(
            name: .sessionConnectionStateChanged,
            object: nil,
            userInfo: [Key.sessionId: sessionId, Key.connectionState: state.rawValue]
        )
    }

    static func extractConnectionState(from n: Notification) -> (sessionId: UUID, state: ConnectionState)? {
        guard let id    = n.userInfo?[Key.sessionId]       as? UUID,
              let raw   = n.userInfo?[Key.connectionState] as? Int,
              let state = ConnectionState(rawValue: raw)   else { return nil }
        return (id, state)
    }

    // MARK: - splitSessionRequested
    // 发送方：SessionListView（右键菜单）
    // 接收方：ContentView（设置分屏布局）

    static func postSplitSession(sessionId: UUID, layout: String) {
        NotificationCenter.default.post(
            name: .splitSessionRequested,
            object: nil,
            userInfo: [Key.sessionId: sessionId, Key.layout: layout]
        )
    }

    static func extractSplitSession(from n: Notification) -> (sessionId: UUID, layout: String)? {
        guard let id     = n.userInfo?[Key.sessionId] as? UUID,
              let layout = n.userInfo?[Key.layout]    as? String else { return nil }
        return (id, layout)
    }

    // MARK: - disconnectActiveTerminalRequested
    // 发送方：ContentViewToolbar / ContentViewLifecycleModifier
    // 接收方：TerminalView（精确路由到目标 sessionId 的 controller）

    static func postDisconnectTerminal(sessionId: UUID) {
        NotificationCenter.default.post(
            name: .disconnectActiveTerminalRequested,
            object: nil,
            userInfo: [Key.sessionId: sessionId]
        )
    }

    static func extractDisconnectTerminal(from n: Notification) -> UUID? {
        n.userInfo?[Key.sessionId] as? UUID
    }

    // MARK: - selectTabRequested
    // 发送方：ShellMateApp（菜单栏 ⌘1-⌘9）
    // 接收方：ContentViewLifecycleModifier（切换 TabBarStore）

    static func postSelectTab(index: Int) {
        NotificationCenter.default.post(
            name: .selectTabRequested,
            object: nil,
            userInfo: [Key.tabIndex: index]
        )
    }

    static func extractSelectTab(from n: Notification) -> Int? {
        n.userInfo?[Key.tabIndex] as? Int
    }

    // MARK: - runScriptRequested
    // 发送方：ScriptLibraryView（脚本库执行）
    // 接收方：TerminalView（逐行写入活跃终端）

    static func postRunScript(content: String, name: String) {
        NotificationCenter.default.post(
            name: .runScriptRequested,
            object: nil,
            userInfo: [Key.scriptContent: content, Key.scriptName: name]
        )
    }

    static func extractRunScript(from n: Notification) -> (content: String, name: String)? {
        guard let content = n.userInfo?[Key.scriptContent] as? String else { return nil }
        let name = n.userInfo?[Key.scriptName] as? String ?? ""
        return (content, name)
    }

    // MARK: - userInfo 键常量（消除字符串字面量散落各处）

    enum Key {
        static let sessionId       = "sessionId"
        static let connectionState = "connectionState"
        static let layout          = "layout"
        static let tabIndex        = "index"
        static let scriptContent   = "scriptContent"
        static let scriptName      = "scriptName"
    }
}
