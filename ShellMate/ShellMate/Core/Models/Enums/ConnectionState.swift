import Foundation
import SwiftUI

/// SSH 连接状态枚举
/// 用于表示会话的实时连接状态
enum ConnectionState: Int, CaseIterable, Identifiable {
    /// 离线状态（未连接）
    case offline = 0
    /// 正在连接
    case connecting = 1
    /// 已连接
    case connected = 2
    /// 连接错误
    case error = 3
    /// 正在断开
    case disconnecting = 4

    var id: Int { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .offline:
            return "离线"
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .error:
            return "错误"
        case .disconnecting:
            return "断开中"
        }
    }

    /// 状态点颜色
    var dotColor: Color {
        switch self {
        case .offline:
            return Color(hex: "#6B6A78") // 灰色
        case .connecting:
            return Color(hex: "#F0A500") // 黄色
        case .connected:
            return Color(hex: "#34D399") // Figma #34d399 connected green
        case .error:
            return Color(hex: "#F04060") // 红色
        case .disconnecting:
            return Color(hex: "#F0A500") // 黄色
        }
    }

    /// 是否需要动画效果
    var needsAnimation: Bool {
        switch self {
        case .connecting, .disconnecting:
            return true
        default:
            return false
        }
    }

    /// 是否需要外发光效果
    var needsGlow: Bool {
        self == .connected
    }
}

/// 隧道类型枚举（Core Data 存储用，与 TunnelModels.TunnelType 区分）
enum CDTunnelType: Int16, CaseIterable, Identifiable {
    /// 本地端口转发
    case local = 0
    /// 远程端口转发
    case remote = 1
    /// 动态端口转发（SOCKS）
    case dynamic = 2

    var id: Int16 { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .local:
            return "本地转发"
        case .remote:
            return "远程转发"
        case .dynamic:
            return "动态转发"
        }
    }

    /// 图标名称
    var iconName: String {
        switch self {
        case .local:
            return "arrow.right.circle"
        case .remote:
            return "arrow.left.circle"
        case .dynamic:
            return "arrow.triangle.2.circlepath"
        }
    }
}

/// 外观模式枚举
enum AppearanceMode: Int16, CaseIterable, Identifiable {
    /// 跟随系统
    case system = 0
    /// 浅色模式
    case light = 1
    /// 深色模式
    case dark = 2

    var id: Int16 { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        }
    }
}
