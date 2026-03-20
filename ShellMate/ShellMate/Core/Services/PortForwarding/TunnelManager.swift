import Foundation
import Combine

// MARK: - 隧道管理器

/// 端口转发规则管理器
/// 负责所有 TunnelRule 的生命周期管理：添加、删除、启动、停止
/// @MainActor 保证 @Published 属性的线程安全
@MainActor
final class TunnelManager: ObservableObject {

    // MARK: - 属性

    /// 所有规则列表（含已停止的历史规则）
    @Published private(set) var rules: [TunnelRule] = []

    /// 当前关联的 SSH 会话配置（由 TerminalController 在连接后注入）
    var sessionConfig: SSHSessionConfig?

    // 活跃的转发器（私有，按规则 id 索引）
    private var localForwarders:  [UUID: LocalPortForwarder]  = [:]
    private var remoteForwarders: [UUID: RemotePortForwarder] = [:]
    private var socks5Proxies:    [UUID: Socks5Proxy]         = [:]

    // MARK: - 规则 CRUD

    func addRule(_ rule: TunnelRule) {
        rules.append(rule)
    }

    func removeRule(_ rule: TunnelRule) {
        stopTunnel(rule)
        rules.removeAll { $0.id == rule.id }
    }

    /// 将表单编辑完的副本写回原规则，若原来是运行中则重启
    func applyEdit(from edited: TunnelRule) {
        guard let original = rules.first(where: { $0.id == edited.id }) else { return }
        let wasActive = original.status == .active
        if wasActive { stopTunnel(original) }
        original.apply(from: edited)
        if wasActive { _ = try? startTunnel(original) }
    }

    // MARK: - 启动 / 停止

    /// 启动指定规则的端口转发
    @discardableResult
    func startTunnel(_ rule: TunnelRule) throws -> Bool {
        guard let config = sessionConfig else {
            rule.status = .failed("SSH 会话未连接")
            throw SSHError.tunnelSessionNotConnected
        }
        guard rule.status != .active else { return true }

        rule.status = .starting

        do {
            switch rule.type {
            case .localForward:
                let forwarder = LocalPortForwarder(rule: rule, sessionConfig: config)
                try forwarder.start()
                localForwarders[rule.id] = forwarder

            case .remoteForward:
                let forwarder = RemotePortForwarder(rule: rule, sessionConfig: config)
                forwarder.start()       // 异步启动，状态由内部更新
                remoteForwarders[rule.id] = forwarder

            case .dynamicSocks:
                let proxy = Socks5Proxy(rule: rule, sessionConfig: config)
                try proxy.start()
                socks5Proxies[rule.id] = proxy
            }
            return true
        } catch {
            rule.status = .failed(error.localizedDescription)
            throw error
        }
    }

    /// 停止指定规则的端口转发
    func stopTunnel(_ rule: TunnelRule) {
        localForwarders[rule.id]?.stop()
        localForwarders.removeValue(forKey: rule.id)

        remoteForwarders[rule.id]?.stop()
        remoteForwarders.removeValue(forKey: rule.id)

        socks5Proxies[rule.id]?.stop()
        socks5Proxies.removeValue(forKey: rule.id)

        rule.status = .stopped
    }

    /// 切换隧道运行状态（用于 UI 一键切换）
    func toggleTunnel(_ rule: TunnelRule) {
        if rule.status == .active {
            stopTunnel(rule)
        } else {
            try? startTunnel(rule)
        }
    }

    // MARK: - 批量操作

    /// 启动所有未运行的规则
    func startAll() {
        for rule in rules where !rule.status.isActive {
            try? startTunnel(rule)
        }
    }

    /// 停止所有正在运行的规则
    func stopAll() {
        for rule in rules {
            stopTunnel(rule)
        }
    }

    /// SSH 断开时停止全部隧道并清除 sessionConfig
    func handleSSHDisconnected() {
        stopAll()
        sessionConfig = nil
    }

    // MARK: - autoStart

    /// 在 SSH 连接成功后，自动启动带有 autoStart 标记的规则
    func handleSSHConnected(config: SSHSessionConfig, sessionID: UUID) {
        sessionConfig = config
        for rule in rules where rule.autoStart && (rule.sessionID == nil || rule.sessionID == sessionID) {
            try? startTunnel(rule)
        }
    }
}
