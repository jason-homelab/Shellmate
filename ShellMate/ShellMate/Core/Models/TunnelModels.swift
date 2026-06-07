import Foundation
import Combine
import SwiftUI

// MARK: - 隧道类型

/// 端口转发类型
enum TunnelType: String, Codable, CaseIterable {
    /// 本地端口转发（ssh -L）
    case localForward
    /// 远程端口转发（ssh -R）
    case remoteForward
    /// SOCKS5 动态代理（ssh -D）
    case dynamicSocks

    var displayName: String {
        switch self {
        case .localForward:  return "本地转发"
        case .remoteForward: return "远程转发"
        case .dynamicSocks:  return "SOCKS 代理"
        }
    }

    var badgeLabel: String {
        switch self {
        case .localForward:  return "LOCAL"
        case .remoteForward: return "REMOTE"
        case .dynamicSocks:  return "SOCKS"
        }
    }

    var badgeColor: Color {
        switch self {
        case .localForward:  return DesignTokens.Semantic.tunnelLocal
        case .remoteForward: return DesignTokens.Semantic.tunnelRemote
        case .dynamicSocks:  return DesignTokens.Semantic.tunnelSocks
        }
    }
}

// MARK: - 隧道状态

/// 端口转发规则运行状态
enum TunnelStatus: Equatable {
    case stopped
    case starting
    case active
    case failed(String)

    var isActive: Bool { self == .active }
    var isStopped: Bool { self == .stopped }

    var displayName: String {
        switch self {
        case .stopped:        return "已停止"
        case .starting:       return "启动中"
        case .active:         return "运行中"
        case .failed(let r):  return "失败: \(r)"
        }
    }

    var statusColor: Color {
        switch self {
        case .active:   return DesignTokens.Colors.statusConnected
        case .starting: return DesignTokens.Colors.statusConnecting
        case .stopped:  return DesignTokens.Colors.textTertiary
        case .failed:   return DesignTokens.Colors.statusError
        }
    }
}

// MARK: - 端口转发规则

/// 端口转发规则
/// 对应 PRD §6.3 TunnelRule 数据模型
final class TunnelRule: Identifiable, ObservableObject {

    let id: UUID

    /// 转发类型
    @Published var type: TunnelType

    /// 本地绑定地址（默认 127.0.0.1）
    @Published var localBindAddress: String

    /// 本地端口
    @Published var localPort: Int

    /// 远端目标主机（dynamicSocks 时忽略）
    @Published var remoteHost: String

    /// 远端目标端口（dynamicSocks 时忽略）
    @Published var remotePort: Int

    /// 绑定会话 ID（nil = 未绑定）
    @Published var sessionID: UUID?

    /// 会话连接时是否自动启动
    @Published var autoStart: Bool

    /// 隧道名称（用于卡片显示，如"MySQL 数据库"）
    @Published var name: String

    /// 备注
    @Published var notes: String

    /// 当前运行状态（运行时状态，不持久化）
    @Published var status: TunnelStatus = .stopped

    init(
        id: UUID = UUID(),
        type: TunnelType = .localForward,
        localBindAddress: String = "127.0.0.1",
        localPort: Int = 8080,
        remoteHost: String = "",
        remotePort: Int = 80,
        sessionID: UUID? = nil,
        autoStart: Bool = false,
        name: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.type = type
        self.localBindAddress = localBindAddress
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.sessionID = sessionID
        self.autoStart = autoStart
        self.name = name
        self.notes = notes
    }

    /// 本地地址描述（用于列表显示）
    var localAddressDisplay: String {
        "\(localBindAddress):\(localPort)"
    }

    /// 远端目标描述（用于列表显示）
    var remoteAddressDisplay: String {
        type == .dynamicSocks ? "（动态）" : "\(remoteHost):\(remotePort)"
    }

    /// 卡片描述文字（按 Figma §11 §9 规则生成）
    var descriptionText: String {
        switch type {
        case .localForward:  return "本地 \(localPort) → \(remoteHost.isEmpty ? "localhost" : remoteHost):\(remotePort)"
        case .remoteForward: return "远程 \(remotePort) → localhost:\(localPort)"
        case .dynamicSocks:  return "动态 SOCKS 代理，端口 \(localPort)"
        }
    }

    /// 创建可编辑的独立副本（用于表单编辑，避免直接修改已启动规则）
    func editableCopy() -> TunnelRule {
        TunnelRule(
            id: id,
            type: type,
            localBindAddress: localBindAddress,
            localPort: localPort,
            remoteHost: remoteHost,
            remotePort: remotePort,
            sessionID: sessionID,
            autoStart: autoStart,
            name: name,
            notes: notes
        )
    }

    /// 将另一规则的字段值复制到本规则（不改变 id / status）
    func apply(from other: TunnelRule) {
        type = other.type
        localBindAddress = other.localBindAddress
        localPort = other.localPort
        remoteHost = other.remoteHost
        remotePort = other.remotePort
        sessionID = other.sessionID
        autoStart = other.autoStart
        name = other.name
        notes = other.notes
    }
}
