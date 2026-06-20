import Foundation

/// 连接协议类型
enum ConnectionType: Int16, CaseIterable, Identifiable, Codable {
    case ssh    = 0
    case telnet = 1
    case serial = 2

    var id: Int16 { rawValue }

    var displayName: String {
        switch self {
        case .ssh:    return "SSH"
        case .telnet: return "Telnet"
        case .serial: return "Serial"
        }
    }

    /// 侧边栏/表单图标（AppIcon，ADR-005）
    var appIcon: AppIcon {
        switch self {
        case .ssh:    return .serverRack
        case .telnet: return .networkIcon
        case .serial: return .cableConnector
        }
    }

    /// 默认端口（Serial 无端口概念，返回 0）
    var defaultPort: Int32 {
        switch self {
        case .ssh:    return 22
        case .telnet: return 23
        case .serial: return 0
        }
    }

    /// 是否需要主机地址
    var requiresHost: Bool {
        switch self {
        case .ssh, .telnet: return true
        case .serial:       return false
        }
    }

    /// 是否需要用户认证配置
    var requiresAuth: Bool {
        switch self {
        case .ssh:           return true
        case .telnet, .serial: return false
        }
    }
}

// MARK: - 串口波特率

enum SerialBaudRate: Int32, CaseIterable {
    case b1200   = 1200
    case b2400   = 2400
    case b4800   = 4800
    case b9600   = 9600
    case b19200  = 19200
    case b38400  = 38400
    case b57600  = 57600
    case b115200 = 115200
    case b230400 = 230400

    var displayName: String { "\(rawValue)" }
}

// MARK: - 串口奇偶校验

enum SerialParity: String, CaseIterable {
    case none = "none"
    case odd  = "odd"
    case even = "even"

    var displayName: String {
        switch self {
        case .none: return "无"
        case .odd:  return "奇校验"
        case .even: return "偶校验"
        }
    }
}

// MARK: - 串口流控

enum SerialFlowControl: String, CaseIterable {
    case none     = "none"
    case hardware = "hardware"
    case software = "software"

    var displayName: String {
        switch self {
        case .none:     return "无"
        case .hardware: return "硬件 (RTS/CTS)"
        case .software: return "软件 (XON/XOFF)"
        }
    }
}
