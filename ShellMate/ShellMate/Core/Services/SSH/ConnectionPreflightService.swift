import Foundation
import Network
import SwiftUI

// W4 新增：连接测试服务（解 UE-P0#2 测试连接按钮）
// 分阶段 preflight：DNS → TCP → SSH 握手 → 认证
// 与 SSHConnectionManager 解耦，独立 Socket，5s 超时强制释放

protocol ConnectionPreflightServicing: Sendable {
    func preflight(host: String, port: Int, username: String, authMethod: PreflightAuthMethod) async -> PreflightResult
}

enum PreflightAuthMethod: Sendable {
    case password(String)
    case privateKey(path: String, passphrase: String?)
    case agent
    case skipAuth   // 仅测试到握手阶段
}

// MARK: - 阶段定义

enum PreflightStage: Int, CaseIterable, Identifiable, Sendable {
    case dns       = 1
    case tcp       = 2
    case handshake = 3
    case auth      = 4

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .dns:       return "preflight.stage.dns"
        case .tcp:       return "preflight.stage.tcp"
        case .handshake: return "preflight.stage.handshake"
        case .auth:      return "preflight.stage.auth"
        }
    }
}

enum PreflightStageStatus: Equatable, Sendable {
    case pending
    case inProgress
    case success(elapsedMs: Int)
    case failed(error: PreflightError)
    case skipped
}

enum PreflightError: Error, Equatable, Sendable {
    case dnsResolution(String)
    case tcpTimeout
    case tcpRefused
    case sshHandshake(String)
    case authentication(String)
    case unknown(String)

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .dnsResolution: return "preflight.error.dns"
        case .tcpTimeout:    return "preflight.error.tcp_timeout"
        case .tcpRefused:    return "preflight.error.tcp_refused"
        case .sshHandshake:  return "preflight.error.handshake"
        case .authentication: return "preflight.error.auth"
        case .unknown:       return "preflight.error.unknown"
        }
    }

    var suggestions: [LocalizedStringKey] {
        switch self {
        case .dnsResolution:
            return ["preflight.suggest.check_host", "preflight.suggest.check_dns"]
        case .tcpTimeout:
            return ["preflight.suggest.check_firewall", "preflight.suggest.check_port"]
        case .tcpRefused:
            return ["preflight.suggest.check_port", "preflight.suggest.check_service_running"]
        case .sshHandshake:
            return ["preflight.suggest.check_ssh_service", "preflight.suggest.check_protocol_version"]
        case .authentication:
            return ["preflight.suggest.check_username", "preflight.suggest.check_password", "preflight.suggest.check_key_permissions"]
        case .unknown:
            return ["preflight.suggest.retry"]
        }
    }
}

// MARK: - 结果

struct PreflightResult: Sendable {
    var stages: [PreflightStage: PreflightStageStatus]
    var summary: Summary
    var totalElapsedMs: Int

    enum Summary: Equatable, Sendable {
        case success
        case failedAt(stage: PreflightStage, error: PreflightError)
        case cancelled
    }

    var firstFailure: (stage: PreflightStage, error: PreflightError)? {
        if case .failedAt(let stage, let error) = summary { return (stage, error) }
        return nil
    }
}

// MARK: - 默认实现

final class ConnectionPreflightService: ConnectionPreflightServicing {

    static let shared = ConnectionPreflightService()

    private static let stageTimeout: TimeInterval = 5.0

    private init() {}

    func preflight(
        host: String,
        port: Int,
        username: String,
        authMethod: PreflightAuthMethod
    ) async -> PreflightResult {
        let startTime = Date()
        var stages: [PreflightStage: PreflightStageStatus] = [
            .dns: .pending, .tcp: .pending, .handshake: .pending, .auth: .pending
        ]

        // Stage 1: DNS
        let dnsStart = Date()
        switch await resolveDNS(host: host) {
        case .success:
            stages[.dns] = .success(elapsedMs: msSince(dnsStart))
        case .failure(let err):
            stages[.dns] = .failed(error: err)
            stages[.tcp] = .skipped
            stages[.handshake] = .skipped
            stages[.auth] = .skipped
            return PreflightResult(
                stages: stages,
                summary: .failedAt(stage: .dns, error: err),
                totalElapsedMs: msSince(startTime)
            )
        }

        // Stage 2: TCP
        let tcpStart = Date()
        switch await tcpReachability(host: host, port: port) {
        case .success:
            stages[.tcp] = .success(elapsedMs: msSince(tcpStart))
        case .failure(let err):
            stages[.tcp] = .failed(error: err)
            stages[.handshake] = .skipped
            stages[.auth] = .skipped
            return PreflightResult(
                stages: stages,
                summary: .failedAt(stage: .tcp, error: err),
                totalElapsedMs: msSince(startTime)
            )
        }

        // Stage 3 + 4: SSH 握手与认证（libssh2 实测）
        let probe = await handshakeAndAuthProbe(
            host: host, port: port, username: username, authMethod: authMethod
        )
        stages[.handshake] = probe.handshake
        stages[.auth] = probe.auth

        if let failure = probe.summaryFailure {
            return PreflightResult(
                stages: stages,
                summary: .failedAt(stage: failure.stage, error: failure.error),
                totalElapsedMs: msSince(startTime)
            )
        }

        return PreflightResult(
            stages: stages,
            summary: .success,
            totalElapsedMs: msSince(startTime)
        )
    }

    // MARK: - SSH 握手 + 认证探测（libssh2）

    /// 探测结果（Sendable：可从 detached task 返回）
    private struct ProbeOutcome: Sendable {
        let handshake: PreflightStageStatus
        let auth: PreflightStageStatus
        /// 失败时的阶段与错误（用于 summary）；成功则为 nil
        let summaryFailure: (stage: PreflightStage, error: PreflightError)?
    }

    /// 使用 LibSSH2BridgeReal 做一次轻量探测：仅到握手 + 认证即断开，不开 Shell 通道。
    /// 序列与 SSH2Connection 一致（已对真机验证），但不做 known-hosts 校验（预检只确认服务端可握手）。
    private func handshakeAndAuthProbe(
        host: String,
        port: Int,
        username: String,
        authMethod: PreflightAuthMethod
    ) async -> ProbeOutcome {
        let timeoutMs = Int(Self.stageTimeout * 1000) * 2   // 握手+认证合计上限（约 10s）
        return await Task.detached(priority: .userInitiated) {
            let bridge = LibSSH2BridgeReal()
            defer { bridge.disconnect(reason: "preflight 探测完成") }

            // --- Stage 3: SSH 握手 ---
            let hsStart = Date()
            do {
                try bridge.sessionInit()
                bridge.setTimeout(timeoutMs)
                try bridge.tcpConnect(host: host, port: Int32(port))
                try bridge.handshake()
                _ = try bridge.getHostKeyFingerprint()   // 确认能取到主机密钥 = 服务端 SSH 正常
            } catch {
                let err = PreflightError.sshHandshake(Self.message(from: error))
                return ProbeOutcome(handshake: .failed(error: err), auth: .skipped,
                                    summaryFailure: (.handshake, err))
            }
            let hsStatus = PreflightStageStatus.success(elapsedMs: Int(Date().timeIntervalSince(hsStart) * 1000))

            // --- Stage 4: 身份认证 ---
            if case .skipAuth = authMethod {
                return ProbeOutcome(handshake: hsStatus, auth: .skipped, summaryFailure: nil)
            }

            let authStart = Date()
            do {
                switch authMethod {
                case .password(let pw):
                    try bridge.authenticateWithPassword(username: username, password: pw)
                case .privateKey(let path, let passphrase):
                    try bridge.authenticateWithPublicKey(
                        username: username, publicKeyPath: nil,
                        privateKeyPath: path, passphrase: passphrase
                    )
                case .agent:
                    try bridge.authenticateWithAgent(username: username)
                case .skipAuth:
                    break   // 已在上方提前返回
                }
            } catch {
                let err = PreflightError.authentication(Self.message(from: error))
                return ProbeOutcome(handshake: hsStatus, auth: .failed(error: err),
                                    summaryFailure: (.auth, err))
            }
            let authStatus = PreflightStageStatus.success(elapsedMs: Int(Date().timeIntervalSince(authStart) * 1000))
            return ProbeOutcome(handshake: hsStatus, auth: authStatus, summaryFailure: nil)
        }.value
    }

    /// 将底层错误转为简短描述
    private static func message(from error: Error) -> String {
        if let sshError = error as? SSHError { return sshError.localizedDescription }
        return "\(error)"
    }

    // MARK: - DNS

    private func resolveDNS(host: String) async -> Result<Void, PreflightError> {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "preflight.dns")
            queue.async {
                var hints = addrinfo(
                    ai_flags: 0,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: IPPROTO_TCP,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, nil, &hints, &result)
                if status == 0 {
                    freeaddrinfo(result)
                    continuation.resume(returning: .success(()))
                } else {
                    let errStr = String(cString: gai_strerror(status))
                    continuation.resume(returning: .failure(.dnsResolution(errStr)))
                }
            }
        }
    }

    // MARK: - TCP Reachability

    private func tcpReachability(host: String, port: Int) async -> Result<Void, PreflightError> {
        await withCheckedContinuation { continuation in
            let nwHost = NWEndpoint.Host(host)
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
                continuation.resume(returning: .failure(.tcpRefused))
                return
            }
            let parameters = NWParameters.tcp
            let connection = NWConnection(host: nwHost, port: nwPort, using: parameters)

            let timeoutWork = DispatchWorkItem {
                connection.cancel()
                continuation.resume(returning: .failure(.tcpTimeout))
            }
            DispatchQueue.global().asyncAfter(
                deadline: .now() + Self.stageTimeout,
                execute: timeoutWork
            )

            let hasResumed = Mutex(initial: false)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if hasResumed.tryMarkResumed() {
                        timeoutWork.cancel()
                        connection.cancel()
                        continuation.resume(returning: .success(()))
                    }
                case .failed:
                    if hasResumed.tryMarkResumed() {
                        timeoutWork.cancel()
                        connection.cancel()
                        continuation.resume(returning: .failure(.tcpRefused))
                    }
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }

    // MARK: - Helpers

    private func msSince(_ start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}

// 简易线程安全标志位，防止 continuation 重复 resume
private final class Mutex: @unchecked Sendable {
    private var value: Bool
    private let lock = NSLock()
    init(initial: Bool) { self.value = initial }

    func tryMarkResumed() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if value { return false }
        value = true
        return true
    }
}
