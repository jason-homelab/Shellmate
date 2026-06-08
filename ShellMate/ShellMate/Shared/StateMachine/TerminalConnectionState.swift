import Foundation
import SwiftUI

// W2 新增：终端连接状态机（10 态）
// 详见 docs/design-specs/W0_设计规格统一交付.md §6.1

enum TerminalConnectionState: UIState {

    case idle
    case connecting(stage: ConnectStage)
    case connected(since: Date)
    case reconnecting(attempt: Int, maxAttempts: Int)
    case disconnected(reason: DisconnectReason)
    case failed(reason: FailureReason)

    static var initial: TerminalConnectionState { .idle }

    enum ConnectStage: Int, Equatable, Sendable {
        case dns = 1
        case tcp = 2
        case handshake = 3
        case auth = 4

        var label: LocalizedStringKey {
            switch self {
            case .dns:       return "terminal.stage.dns"
            case .tcp:       return "terminal.stage.tcp"
            case .handshake: return "terminal.stage.handshake"
            case .auth:      return "terminal.stage.auth"
            }
        }
    }

    enum DisconnectReason: Equatable, Sendable {
        case userInitiated
        case networkLost
        case serverClosed
        case idleTimeout
    }

    enum FailureReason: Equatable, Sendable {
        case authentication
        case hostKeyMismatch
        case tcpRefused
        case dnsFailed
        case unknown
    }

    enum Event: Sendable {
        case connectRequested
        case stageAdvanced(ConnectStage)
        case authSucceeded
        case networkLost
        case userCancelled
        case retryRequested
        case failed(FailureReason)
        case disconnected(DisconnectReason)
    }

    mutating func reduce(_ event: Event) {
        switch (self, event) {
        case (.idle, .connectRequested),
             (.disconnected, .connectRequested),
             (.failed, .connectRequested):
            self = .connecting(stage: .dns)

        case (.connecting, .stageAdvanced(let stage)):
            self = .connecting(stage: stage)

        case (.connecting, .authSucceeded):
            self = .connected(since: Date())

        case (.connected, .networkLost):
            self = .reconnecting(attempt: 1, maxAttempts: 5)

        case (.reconnecting(let n, let max), .retryRequested) where n < max:
            self = .reconnecting(attempt: n + 1, maxAttempts: max)

        case (.reconnecting, .authSucceeded):
            self = .connected(since: Date())

        // P1#5 单测暴露的 bug：原代码在 reconnecting 达 max 时丢弃实际 reason 改为 .unknown
        // 修正：保留事件中携带的真实 reason，便于诊断与 UI 展示
        case (.reconnecting(let n, let max), .failed(let reason)) where n >= max:
            self = .failed(reason: reason)

        case (_, .failed(let reason)):
            self = .failed(reason: reason)

        case (_, .disconnected(let reason)):
            self = .disconnected(reason: reason)

        case (_, .userCancelled):
            self = .idle

        default:
            break
        }
    }
}

// MARK: - UI 派生属性

extension TerminalConnectionState {

    var displayBadge: ConnectionUIState {
        switch self {
        case .connected: return .connected
        case .connecting, .reconnecting: return .connecting
        case .disconnected: return .disconnected
        case .failed: return .error
        case .idle: return .disconnected
        }
    }

    var allowsTabClose: Bool {
        switch self {
        case .connected, .reconnecting: return false  // 活动会话关闭需 confirm
        default: return true
        }
    }

    var showsReconnectOverlay: Bool {
        switch self {
        case .disconnected(.networkLost), .disconnected(.serverClosed):
            return true
        case .failed: return true
        default: return false
        }
    }

    var pulseFrequency: Double {
        switch self {
        case .connecting: return 1.0
        case .reconnecting: return 0.6
        default: return 0
        }
    }
}
