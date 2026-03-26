import Foundation

/// SSH 认证方式枚举
/// 对应数据库中 CDSession.authMethodRaw 字段
enum AuthMethod: Int16, CaseIterable, Identifiable, Codable {
    /// 密码认证
    case password = 0
    /// 私钥认证
    case privateKey = 1
    /// SSH Agent 认证
    case sshAgent = 2
    /// 键盘交互认证
    case keyboardInteractive = 3

    var id: Int16 { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .password:
            return "密码"
        case .privateKey:
            return "私钥"
        case .sshAgent:
            return "SSH Agent"
        case .keyboardInteractive:
            return "键盘交互"
        }
    }

    /// 图标名称（SF Symbols）
    var iconName: String {
        switch self {
        case .password:
            return "key.fill"
        case .privateKey:
            return "doc.text.fill"
        case .sshAgent:
            return "person.badge.key.fill"
        case .keyboardInteractive:
            return "keyboard.fill"
        }
    }

    /// 描述说明
    var description: String {
        switch self {
        case .password:
            return "使用用户名和密码进行认证"
        case .privateKey:
            return "使用 SSH 私钥文件进行认证"
        case .sshAgent:
            return "使用系统 SSH Agent 进行认证"
        case .keyboardInteractive:
            return "服务器要求的交互式认证"
        }
    }
}
