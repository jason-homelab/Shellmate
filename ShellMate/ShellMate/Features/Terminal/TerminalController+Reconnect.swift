import Foundation
import Network

// MARK: - 自动重连

extension TerminalController {

    // MARK: - 重连资格判断

    /// 综合判断：会话级开关 + 全局开关 + 非用户主动断开
    private var canAutoReconnect: Bool {
        guard !userDisconnected else { return false }
        guard reconnectConfig.enabled else { return false }
        return UserDefaults.standard.bool(forKey: "general.autoReconnect")
    }

    // MARK: - 公开操作

    func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        if case .reconnecting = state {
            state = .disconnected
            delegate?.terminalController(self, didChangeState: state)
        }
    }

    /// 检查特定错误类型是否允许自动重连（认证失败/主机密钥问题不重连）
    func shouldAutoReconnect(after error: SSHError) -> Bool {
        guard canAutoReconnect else { return false }
        switch error {
        case .authenticationFailed, .hostKeyVerificationFailed, .hostKeyChanged:
            return false
        default:
            return true
        }
    }

    func scheduleReconnect() {
        // 接受 .failed 和 .disconnected 两种初始状态（网络恢复时可能是 disconnected）
        guard state.isFailed || state == .disconnected else { return }
        // P1-3：取消已有任务，防止双重重连竞态
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            for attempt in 1...self.reconnectConfig.maxAttempts {
                guard !Task.isCancelled && !self.userDisconnected else { break }
                await MainActor.run {
                    self.state = .reconnecting(attempt: attempt)
                    self.delegate?.terminalController(self, didChangeState: self.state)
                    self.delegate?.terminalController(self, willReconnect: attempt, of: self.reconnectConfig.maxAttempts)
                }
                let delay = self.reconnectConfig.delay(for: attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled && !self.userDisconnected else { break }
                do {
                    try await self.connect()
                    // P1-2：成功后清空引用，允许后续网络事件再次触发重连
                    await MainActor.run { self.reconnectTask = nil }
                    return
                } catch {
                    if attempt == self.reconnectConfig.maxAttempts {
                        await MainActor.run {
                            // P2：并发保护——若其他路径已连接成功，不覆写 connected 状态
                            guard self.state != .connected else { return }
                            self.state = .failed("重连失败：已达最大重试次数")
                            self.delegate?.terminalController(self, didChangeState: self.state)
                        }
                    }
                }
            }
        }
    }

    func handleConnectionLost() {
        guard state == .connected else { return }
        tmuxStore.handleSSHDisconnected()
        // 清理旧连接对象，确保重连时从干净状态建立新连接
        sshConnection?.disconnect()
        sshConnection = nil
        telnetConnection = nil
        serialConnection = nil

        if userExiting || userDisconnected {
            // 用户主动执行 exit/logout/quit，SSH channel 正常关闭——静默回到断开状态，不显示错误面板
            logSystemEvent("用户主动断开连接")
            userExiting = false
            inputLineBuffer = ""
            state = .disconnected
        } else {
            // 意外断线（网络中断、服务器宕机等）——显示错误面板
            logSystemEvent("连接意外断开")
            state = .failed("连接已断开")
        }
        delegate?.terminalController(self, didChangeState: state)
        if canAutoReconnect { scheduleReconnect() }
    }

    /// TC-005：启动网络路径监控，网络恢复时自动触发重连
    func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let newStatus = path.status
                defer { self.lastNetworkStatus = newStatus }
                // P1-1：同时处理 failed 和 disconnected 两种断开状态
                guard newStatus == .satisfied,
                      self.lastNetworkStatus != .satisfied,
                      self.canAutoReconnect,
                      self.reconnectTask == nil,
                      self.state.isFailed || self.state == .disconnected else { return }
                self.scheduleReconnect()
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.shellmate.networkmonitor", qos: .utility))
    }
}
