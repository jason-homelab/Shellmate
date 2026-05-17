import SwiftUI

// MARK: - 生命周期与通知处理 ViewModifier

/// 将数据加载和菜单栏通知处理拆分为独立 ViewModifier，
/// 避免 ContentView.body 中链式修饰符过多导致 Swift 类型检查超时
struct ContentViewLifecycleModifier: ViewModifier {

    let sessionStore: SessionStore
    let groupStore: GroupStore
    let tabBarStore: TabBarStore
    let onConnect: (Session) -> Void
    let panels: ContentViewModel
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
                    AppEvent.postDisconnectTerminal(sessionId: sessionId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .disconnectAllRequested)) { _ in
                for tab in tabBarStore.tabs {
                    AppEvent.postDisconnectTerminal(sessionId: tab.sessionId)
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
                if let index = AppEvent.extractSelectTab(from: notification) {
                    tabBarStore.selectTab(at: index)
                }
            }
            // 同步 TerminalController 实际连接状态到 SessionStore（侧边栏计数器）和 TabBarStore（标签点颜色）
            .onReceive(NotificationCenter.default.publisher(for: .sessionConnectionStateChanged)) { notification in
                guard let (sessionId, state) = AppEvent.extractConnectionState(from: notification) else { return }
                sessionStore.updateConnectionState(for: sessionId, state: state)
                if let tab = tabBarStore.tabs.first(where: { $0.sessionId == sessionId }) {
                    tabBarStore.updateConnectionState(for: tab.id, state: state)
                }
            }
            // 侧边栏右键"分屏打开"
            .onReceive(NotificationCenter.default.publisher(for: .splitSessionRequested)) { notification in
                guard let (sessionId, layoutStr) = AppEvent.extractSplitSession(from: notification),
                      sessionStore.sessions.contains(where: { $0.id == sessionId }) else { return }
                let layout: SplitLayout = layoutStr == "horizontal" ? .horizontal : .vertical
                panels.splitLayout = layout
                panels.splitSessionId = sessionId
            }
            // 工具面板（由菜单栏 / 快捷键触发，统一在 ContentView 级别响应）
            .onReceive(NotificationCenter.default.publisher(for: .tunnelManagerRequested)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { panels.showTunnelPanel.toggle() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickCommandsRequested)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { panels.showQuickCommandPanel.toggle() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .tmuxManagerRequested)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { panels.showTmuxPanel.toggle() }
            }
    }
}

// MARK: - AI / SFTP 面板同步 ViewModifier
//
// 独立拆分，避免 ContentViewLifecycleModifier 修饰符链过长导致 Swift 类型检查超时。

struct ContentViewPanelSyncModifier: ViewModifier {

    let panels: ContentViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .aiPanelRequested)) { _ in
                panels.showAIPanel.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .sftpPanelRequested)) { _ in
                panels.showSFTPPanel.toggle()
            }
    }
}

// MARK: - 录制状态刷新 ViewModifier
//
// 独立于 ContentViewLifecycleModifier，避免修饰符链过长导致 Swift 类型检查超时。

struct ContentViewRecordingStateModifier: ViewModifier {

    let tabBarStore: TabBarStore
    let panels: ContentViewModel
    @Binding var isRecordingActive: Bool

    func body(content: Content) -> some View {
        content
            .task(id: tabBarStore.selectedTabId) {
                isRecordingActive = await recordingState()
            }
            .onChange(of: panels.showRecordingDialog) { _ in
                Task { isRecordingActive = await recordingState() }
            }
    }

    private func recordingState() async -> Bool {
        guard let sessionId = tabBarStore.selectedTab?.sessionId else { return false }
        return await TerminalControllerRegistry.shared.controller(for: sessionId)?.recorder.isRecording ?? false
    }
}
