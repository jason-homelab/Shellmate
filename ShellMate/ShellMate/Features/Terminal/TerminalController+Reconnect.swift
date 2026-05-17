import Foundation
import Network

// MARK: - 自动重连

extension TerminalController {

    func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        if case .reconnecting = state {
            state = .disconnected
            delegate?.terminalController(self, didChangeState: state)
        }
    }

    /// W12.3：检查本设备是否缺少凭据（iCloud 同步后首次连接场景）
    func shouldAutoReconnect(after error: SSHError) -> Bool {
        guard reconnectConfig.enabled && !userDisconnected else { return false }
        switch error {
        case .authenticationFailed, .hostKeyVerificationFailed, .hostKeyChanged:
            return false
        default:
            return true
        }
    }

    func scheduleReconnect() {
        guard case .failed = state else { return }
        reconnectTask = Task { [weak self] in
            guard let self = self else { return }
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
                    return
                } catch {
                    if attempt == self.reconnectConfig.maxAttempts {
                        await MainActor.run {
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
        logSystemEvent("连接意外断开")
        // 清理旧连接对象，确保重连时从干净状态建立新连接
        sshConnection?.disconnect()
        sshConnection = nil
        telnetConnection = nil
        serialConnection = nil
        state = .failed("连接已断开")
        delegate?.terminalController(self, didChangeState: state)
        if reconnectConfig.enabled && !userDisconnected { scheduleReconnect() }
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
                guard newStatus == .satisfied,
                      self.lastNetworkStatus != .satisfied,
                      self.reconnectConfig.enabled,
                      !self.userDisconnected,
                      self.reconnectTask == nil else { return }
                if case .failed = self.state { self.scheduleReconnect() }
                else if case .disconnected = self.state { self.scheduleReconnect() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.shellmate.networkmonitor", qos: .utility))
    }
}
