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

        // Stage 3 + 4: SSH 握手与认证
        // 注：完整 libssh2 集成在 W5 阶段接入；当前阶段先返回"已跳过"占位
        // 这允许 PreflightProgressView UI 与表单接入提前完成，业务层后续填入
        stages[.handshake] = .skipped
        stages[.auth] = .skipped

        return PreflightResult(
            stages: stages,
            summary: .success,
            totalElapsedMs: msSince(startTime)
        )
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
