import SwiftUI

// MARK: - 生命周期与通知处理 ViewModifier

/// 将数据加载和菜单栏通知处理拆分为独立 ViewModifier，
/// 避免 ContentView.body 中链式修饰符过多导致 Swift 类型检查超时
struct ContentViewLifecycleModifier: ViewModifier {

    let sessionStore: SessionStore
    let groupStore: GroupStore
    let tabBarStore: TabBarStore
    let onConnect: (Session) -> Void

    func body(content: Content) -> some View {
        content
            // 会话 / 分组操作
            .onReceive(NotificationCenter.default.publisher(for: .newSessionRequested)) { _ in
                sessionStore.showNewSessionForm()
            }
            .onReceive(NotificationCenter.default.publisher(for: .newGroupRequested)) { _ in
                groupStore.showNewGroupForm()
            }
            .onReceive(NotificationCenter.default.publisher(for: .connectSessionRequested)) { _ in
                if let session = sessionStore.selectedSession { onConnect(session) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .disconnectSessionRequested)) { _ in
                if let sessionId = tabBarStore.selectedTab?.sessionId {
                    NotificationCenter.default.post(
                        name: .disconnectActiveTerminalRequested,
                        object: nil,
                        userInfo: ["sessionId": sessionId]
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .disconnectAllRequested)) { _ in
                for tab in tabBarStore.tabs {
                    NotificationCenter.default.post(
                        name: .disconnectActiveTerminalRequested,
                        object: nil,
                        userInfo: ["sessionId": tab.sessionId]
                    )
                }
            }
            // 标签页操作
            .onReceive(NotificationCenter.default.publisher(for: .newTabRequested)) { _ in
                if let session = sessionStore.selectedSession {
                    onConnect(session)
                } else {
                    sessionStore.showNewSessionForm()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .closeTabRequested)) { _ in
                if let tab = tabBarStore.selectedTab { tabBarStore.requestCloseTab(tab) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .nextTabRequested)) { _ in
                tabBarStore.selectNextTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: .previousTabRequested)) { _ in
                tabBarStore.selectPreviousTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: .selectTabRequested)) { notification in
                if let index = notification.userInfo?["index"] as? Int {
                    tabBarStore.selectTab(at: index)
                }
            }
    }
}
