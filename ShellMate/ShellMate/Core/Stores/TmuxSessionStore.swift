import Foundation
import Combine

/// tmux 会话运行时状态管理器
/// 每个活跃的 TerminalController 持有一个独立实例，负责：
/// - 检测远程 tmux 可用性
/// - 维护 tmux 会话列表
/// - 执行附加/分离/新建/终止操作
/// - 解析 TerminalController 转发来的带标记输出
@MainActor
final class TmuxSessionStore: ObservableObject {

    // MARK: - 发布属性

    /// tmux 可用性（检测状态）
    @Published private(set) var availability: TmuxAvailability = .unknown

    /// 当前已知的 tmux 会话列表
    @Published private(set) var sessions: [TmuxSession] = []

    /// 当前终端内附加的 tmux 会话名（nil 表示未附加）
    @Published private(set) var attachedSessionName: String? = nil

    /// 当前 tmux 活跃窗口索引（附加时有效）
    @Published private(set) var currentWindowIndex: Int? = nil

    /// 管理器面板是否显示（由 TerminalView 工具栏按钮控制）
    @Published var isManagerOpen: Bool = false

    /// 是否处于 tmux 输出收集状态（供数据管道快速判断是否需要行级过滤）
    var isInCollectionMode: Bool { collectingSessionList || collectingWindowList }

    // MARK: - 私有属性

    /// 持有 TerminalController 的弱引用，用于发送命令
    private weak var sendTarget: TmuxSendTarget?
    private let sessionId: UUID

    /// 累积的会话列表原始输出（等待 END 标记后一次性解析）
    private var sessionListBuffer: String = ""
    private var collectingSessionList: Bool = false

    /// 累积的窗口列表原始输出
    private var windowListBuffer: String = ""
    private var collectingWindowList: Bool = false
    private var windowListTargetSession: String = ""

    // MARK: - 初始化

    init(sessionId: UUID, sendTarget: TmuxSendTarget) {
        self.sessionId = sessionId
        self.sendTarget = sendTarget
    }

    // MARK: - tmux 版本警告

    /// tmux 版本低于最低支持时设为 true，供 UI 展示警告（24.4）
    @Published private(set) var isVersionTooOld: Bool = false

    // MARK: - tmux 检测

    /// 连接成功后触发：静默检测远程 tmux 可用性，并捕获版本号（24.4）
    func detectTmux() {
        guard availability == .unknown || availability == .unavailable else { return }
        availability = .checking
        // 捕获版本输出：成功时打印 __SM_TMUX_VER__<version>，失败时打印 __SM_TMUX_NA__
        let cmd = "V=$(tmux -V 2>/dev/null) && echo '\(TmuxOutputMarker.versionPrefix)'\"$V\" || echo '\(TmuxOutputMarker.checkNA)'\n"
        sendTarget?.sendTmuxCommand(cmd)
    }

    // MARK: - 会话列表刷新

    /// 请求刷新 tmux 会话列表（仅在 tmux 可用时调用）
    func refreshSessions() {
        guard case .available = availability else { return }
        let fmt = "#{session_name}|#{session_attached}|#{session_windows}|#{session_created}|#{session_width}x#{session_height}"
        let cmd = "echo '\(TmuxOutputMarker.sessionListStart)'; tmux ls -F '\(fmt)' 2>/dev/null || echo '\(TmuxOutputMarker.noSessions)'; echo '\(TmuxOutputMarker.sessionListEnd)'\n"
        sendTarget?.sendTmuxCommand(cmd)
    }

    /// 请求指定会话的窗口列表
    func refreshWindows(for sessionName: String) {
        guard case .available = availability else { return }
        windowListTargetSession = sessionName
        let escaped = shellEscape(sessionName)
        let cmd = "echo '\(TmuxOutputMarker.windowListStart)'; tmux list-windows -t \(escaped) -F '#{window_index}|#{window_name}|#{window_active}' 2>/dev/null; echo '\(TmuxOutputMarker.windowListEnd)'\n"
        sendTarget?.sendTmuxCommand(cmd)
    }

    // MARK: - 输出过滤（由 TerminalController 数据管道调用）

    /// 判断某行是否应从终端输出中隐藏，并在内部处理 tmux 协议行
    /// - Returns: true = 该行已被 tmux 模块消耗，不应显示在终端；false = 正常显示
    func filterLine(_ line: String) -> Bool {
        // 收集阶段：START/END 之间的数据行也需要隐藏
        if collectingSessionList || collectingWindowList {
            processMarkerLine(line)
            return true
        }
        // 含 __SM_TMUX_ 标记的行
        if TmuxOutputMarker.containsMarker(line) {
            processMarkerLine(line)
            return true
        }
        return false
    }

    // MARK: - 输出解析（由 TerminalController 转发）

    /// 处理来自 SSH 输出流中检测到的 tmux 协议行（内部使用）
    private func processMarkerLine(_ line: String) {
        // --- 可用性检测 ---
        if line.contains(TmuxOutputMarker.checkNA) {
            availability = .unavailable
            return
        }

        // --- 版本解析（24.4）---
        if line.contains(TmuxOutputMarker.versionPrefix) {
            // 提取版本字符串，格式：__SM_TMUX_VER__tmux 3.4
            let versionStr = line.components(separatedBy: TmuxOutputMarker.versionPrefix).last ?? "tmux"
            let trimmed = versionStr.trimmingCharacters(in: .whitespacesAndNewlines)
            isVersionTooOld = !TmuxOutputMarker.isVersionSupported(trimmed)
            if case .available = availability { } else {
                availability = .available(version: trimmed.isEmpty ? "tmux" : trimmed)
            }
            refreshSessions()
            return
        }

        if line.contains(TmuxOutputMarker.checkOK) {
            // 兼容旧标记（不应出现，但保留防御）
            if case .available = availability { } else {
                availability = .available(version: "tmux")
            }
            refreshSessions()
            return
        }

        // --- 会话列表 ---
        if line.contains(TmuxOutputMarker.sessionListStart) {
            collectingSessionList = true
            sessionListBuffer = ""
            return
        }
        if line.contains(TmuxOutputMarker.sessionListEnd) {
            collectingSessionList = false
            parseSessionList(sessionListBuffer)
            sessionListBuffer = ""
            // 自动应用策略（若首次检测成功）
            if case .available = availability {
                let config = TmuxConfigStore.load(sessionId: sessionId)
                if config.autoShowManager && !sessions.isEmpty {
                    isManagerOpen = true
                }
                Task { await applyAutoAttach(config: config) }
            }
            return
        }
        if collectingSessionList {
            sessionListBuffer += line + "\n"
            return
        }
        if line.contains(TmuxOutputMarker.noSessions) {
            sessions = []
            return
        }

        // --- 窗口列表 ---
        if line.contains(TmuxOutputMarker.windowListStart) {
            collectingWindowList = true
            windowListBuffer = ""
            return
        }
        if line.contains(TmuxOutputMarker.windowListEnd) {
            collectingWindowList = false
            parseWindowList(windowListBuffer, for: windowListTargetSession)
            windowListBuffer = ""
            windowListTargetSession = ""
            return
        }
        if collectingWindowList {
            windowListBuffer += line + "\n"
            return
        }
    }

    // MARK: - 解析辅助

    private func parseSessionList(_ raw: String) {
        var result: [TmuxSession] = []
        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.contains("__SM_TMUX") else { continue }
            let parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 4 else { continue }
            let name = parts[0]
            guard !name.isEmpty else { continue }
            let isAttached = parts[1] == "1"
            let windowCount = Int(parts[2]) ?? 0
            let ts = TimeInterval(parts[3]) ?? 0
            let createdAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
            let dims = parts.count >= 5 ? parts[4] : ""
            result.append(TmuxSession(
                name: name,
                isAttached: isAttached,
                windowCount: windowCount,
                createdAt: createdAt,
                dimensions: dims,
                windows: []
            ))
        }
        sessions = result
    }

    private func parseWindowList(_ raw: String, for sessionName: String) {
        var windows: [TmuxWindow] = []
        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.contains("__SM_TMUX") else { continue }
            let parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 3 else { continue }
            let index = Int(parts[0]) ?? 0
            let name = parts[1]
            let isActive = parts[2] == "1"
            windows.append(TmuxWindow(index: index, name: name, isActive: isActive))
        }
        if let i = sessions.firstIndex(where: { $0.name == sessionName }) {
            sessions[i].windows = windows
            if let active = windows.first(where: { $0.isActive }) {
                currentWindowIndex = active.index
            }
        }
    }

    // MARK: - 操作

    /// 附加到指定 tmux 会话
    func attach(to session: TmuxSession) {
        let cmd = "tmux attach-session -t \(shellEscape(session.name))\n"
        sendTarget?.sendTmuxCommand(cmd)
        attachedSessionName = session.name
    }

    /// 分离当前 tmux 会话（仍在 tmux 环境内）
    func detach() {
        sendTarget?.sendTmuxCommand("tmux detach-client\n")
        attachedSessionName = nil
        refreshSessions()
    }

    /// 新建 tmux 会话并附加
    func createSession(name: String, windowName: String) {
        var parts = ["tmux", "new-session"]
        if !name.isEmpty { parts += ["-s", shellEscape(name)] }
        if !windowName.isEmpty { parts += ["-n", shellEscape(windowName)] }
        let cmd = parts.joined(separator: " ") + "\n"
        sendTarget?.sendTmuxCommand(cmd)
        attachedSessionName = name.isEmpty ? nil : name
        // 稍后刷新列表
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            self?.refreshSessions()
        }
    }

    /// 终止指定 tmux 会话
    func kill(session: TmuxSession) {
        let cmd = "tmux kill-session -t \(shellEscape(session.name))\n"
        sendTarget?.sendTmuxCommand(cmd)
        if attachedSessionName == session.name {
            attachedSessionName = nil
            currentWindowIndex = nil
        }
        refreshSessions()
    }

    /// 切换 tmux 窗口
    func selectWindow(index: Int) {
        sendTarget?.sendTmuxCommand("tmux select-window -t :\(index)\n")
        currentWindowIndex = index
    }

    /// 发送 Quick Actions tab 中的快捷命令
    func sendQuickCommand(_ command: String) {
        sendTarget?.sendTmuxCommand(command + "\n")
    }

    // MARK: - 自动附加策略

    /// 连接成功 + 会话列表拉取完成后，按 TmuxConfig 执行自动附加
    private func applyAutoAttach(config: TmuxConfig) async {
        guard config.autoAttach != .none else { return }
        // 等待一帧让终端稳定
        try? await Task.sleep(nanoseconds: 300_000_000)
        switch config.autoAttach {
        case .none: break
        case .latest:
            if let first = sessions.first { attach(to: first) }
        case .named:
            if !config.sessionName.isEmpty,
               let target = sessions.first(where: { $0.name == config.sessionName }) {
                attach(to: target)
            }
        case .create:
            createSession(name: config.newSessionName, windowName: "")
        }
    }

    // MARK: - 断开清理

    /// SSH 断开时根据配置决定是否终止 tmux 会话
    func handleSSHDisconnected() {
        let config = TmuxConfigStore.load(sessionId: sessionId)
        if config.disconnectBehavior == .kill, let name = attachedSessionName {
            // 连接已断，无法再发送命令；此处仅清理本地状态
            _ = name
        }
        attachedSessionName = nil
        currentWindowIndex = nil
        sessions = []
        availability = .unknown
    }

    // MARK: - 辅助

    /// 对 tmux 会话名进行 shell 单引号转义
    private func shellEscape(_ str: String) -> String {
        "'" + str.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

// MARK: - TmuxSendTarget 协议

/// TmuxSessionStore 用于向终端发送命令的协议
/// TerminalController 实现此协议
/// @MainActor：TerminalController 是 @MainActor，协议标注后消除 Swift 6 并发警告
@MainActor
protocol TmuxSendTarget: AnyObject {
    func sendTmuxCommand(_ command: String)
}
