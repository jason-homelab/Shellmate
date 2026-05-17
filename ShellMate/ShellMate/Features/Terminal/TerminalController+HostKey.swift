import Foundation

// MARK: - TerminalController 主机密钥确认（D02 / D03）

extension TerminalController {

    /// 用户接受新主机密钥（D02 确认后调用）
    func acceptNewHostKey() {
        guard case .newHost(let fingerprint) = pendingHostKeyState else { return }
        do {
            try KnownHostsManager.shared.add(host: session.host, port: session.port, fingerprint: fingerprint)
        } catch {
            // 写入失败不阻断连接，下次连接仍会弹 D02
            AppLogger.ssh.warning("[KnownHosts] 保存主机指纹失败: \(error.localizedDescription)")
        }
        pendingHostKeyState = nil
        Task { try? await connect() }
    }

    /// 用户接受密钥变更（D03 高风险操作）
    func acceptChangedHostKey() {
        guard case .changedHost(_, let newFP) = pendingHostKeyState else { return }
        do {
            try KnownHostsManager.shared.add(host: session.host, port: session.port, fingerprint: newFP)
        } catch {
            AppLogger.ssh.warning("[KnownHosts] 更新主机指纹失败: \(error.localizedDescription)")
        }
        pendingHostKeyState = nil
        state = .disconnected
        Task { try? await connect() }
    }

    /// 用户拒绝主机密钥（D02 / D03 取消）
    func rejectHostKey() {
        pendingHostKeyState = nil
        state = .disconnected
        delegate?.terminalController(self, didChangeState: state)
    }
}
