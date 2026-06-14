import SwiftUI

// Phase 9：从 TerminalView.swift 抽出的 ViewModifier 与 helper view
// 原文件 1299 → ~1180 行（降幅 119 行）
// 这些是 W5 架构方案 §2 "TerminalView 拆分 Phase 1" 的最低风险一步

// MARK: - 通知处理 ViewModifier

/// 将 TerminalView 的菜单栏通知处理提取为独立 ViewModifier，
/// 避免 TerminalView.body 链式修饰符过多导致 Swift 类型检查超时
struct TerminalViewNotificationModifier: ViewModifier {

    let sessionId: UUID
    let isSelected: Bool
    let controller: TerminalController
    @Binding var showSearch: Bool
    @Binding var fontSize: Double
    @Binding var isAIPanelOpen: Bool
    @Binding var aiInitialError: String?
    let minFontSize: Double
    let maxFontSize: Double
    let onToggleSFTP: () -> Void
    @EnvironmentObject private var panels: ContentViewModel

    func body(content: Content) -> some View {
        content
            // 断开连接（通过 sessionId 精确路由）
            .onReceive(NotificationCenter.default.publisher(for: .disconnectActiveTerminalRequested)) { notification in
                guard let targetId = AppEvent.extractDisconnectTerminal(from: notification),
                      targetId == sessionId else { return }
                Task { await controller.disconnect() }
            }
            // 面板控制
            .onReceive(NotificationCenter.default.publisher(for: .sftpPanelRequested)) { _ in
                guard isSelected else { return }
                onToggleSFTP()
                panels.showSFTPPanel = controller.isSFTPPanelOpen
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiPanelRequested)) { _ in
                guard isSelected else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAIPanelOpen.toggle()
                    if !isAIPanelOpen { aiInitialError = nil }
                }
                panels.showAIPanel = isAIPanelOpen
            }
            .onReceive(NotificationCenter.default.publisher(for: .composePaneRequested)) { _ in
                guard isSelected else { return }
                withAnimation(.easeInOut(duration: 0.2)) { controller.isComposePaneOpen.toggle() }
            }
            // 终端控制（仅作用于当前活跃 Tab，其余 Tab 的 TerminalView 虽然存活在 ZStack 中也不响应）
            .onReceive(NotificationCenter.default.publisher(for: .clearTerminalRequested)) { _ in
                guard isSelected else { return }
                controller.clearTerminal()
            }
            .onReceive(NotificationCenter.default.publisher(for: .searchTerminalRequested)) { _ in
                guard isSelected else { return }
                withAnimation { showSearch.toggle() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .increaseFontRequested)) { _ in
                fontSize = min(maxFontSize, fontSize + 1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .decreaseFontRequested)) { _ in
                fontSize = max(minFontSize, fontSize - 1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetFontRequested)) { _ in
                fontSize = 13
            }
            // 脚本库：将脚本内容逐行发送到活跃终端
            .onReceive(NotificationCenter.default.publisher(for: .runScriptRequested)) { notification in
                guard isSelected,
                      let (content, _) = AppEvent.extractRunScript(from: notification) else { return }
                Task {
                    let lines = content.components(separatedBy: "\n")
                    for line in lines {
                        guard !line.hasPrefix("#") else { continue } // 跳过注释行
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { continue }
                        try? await controller.send(trimmed + "\r")
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms 行间延迟
                    }
                }
            }
    }
}

// MARK: - 多终端标签视图

struct MultiTerminalView: View {

    @ObservedObject var sessionManager: TerminalSessionManager
    let sessions: [Session]

    var body: some View {
        if let selectedId = sessionManager.selectedControllerId,
           let session = sessions.first(where: { $0.id == selectedId }) {
            TerminalView(session: session)
        } else {
            Text("请从侧边栏选择会话")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 连接相关 Alert 修饰符（拆分以避免类型检查超时）

struct TerminalViewAlertModifier: ViewModifier {
    @Binding var showSFTPError: Bool
    let sftpErrorMessage: String
    @Binding var showTunnelError: Bool
    let tunnelErrorMessage: String

    func body(content: Content) -> some View {
        content
            .alert("SFTP 连接失败", isPresented: $showSFTPError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(sftpErrorMessage)
            }
            .alert("隧道启动失败", isPresented: $showTunnelError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(tunnelErrorMessage)
            }
    }
}
