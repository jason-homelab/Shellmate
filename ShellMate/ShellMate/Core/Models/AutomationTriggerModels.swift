import Foundation

// MARK: - 自动化触发器数据模型（技术方案 §3.19）

/// 一条自动化触发器规则，支持全局或会话级作用域
struct AutomationTrigger: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var isEnabled: Bool = true
    var scope: TriggerScope
    var conditionType: TriggerConditionType
    var pattern: String?
    var caseSensitive: Bool = false
    var actionType: TriggerActionType
    /// 动作载荷：命令字符串 / URL / 通知文本 / 文件路径 / 脚本路径
    var actionPayload: String = ""
    /// 冷却秒数（0 = 不限制）
    var cooldownSeconds: Int = 60
    var createdAt: Date = Date()

    // MARK: - 作用域

    enum TriggerScope: Codable, Equatable, Hashable {
        case global
        case session(UUID)

        var displayName: String {
            switch self {
            case .global: return "全局"
            case .session: return "当前会话"
            }
        }
    }

    // MARK: - 条件类型

    enum TriggerConditionType: String, CaseIterable, Codable {
        case onConnect       = "SSH 连接建立后"
        case onDisconnect    = "SSH 连接断开时"
        case outputRegex     = "终端输出正则匹配"
        case outputKeyword   = "终端输出关键词匹配"

        /// 条件类型是否需要填写匹配模式
        var requiresPattern: Bool {
            switch self {
            case .outputRegex, .outputKeyword: return true
            case .onConnect, .onDisconnect:    return false
            }
        }
    }

    // MARK: - 动作类型

    enum TriggerActionType: String, CaseIterable, Codable {
        case sendCommand   = "发送命令"
        case notification  = "系统通知"
        case openURL       = "打开 URL"
        case writeLog      = "写入日志文件"
        case runScript     = "执行脚本（仅 Direct 版）"
        case highlightLine = "高亮匹配行"

        /// 动作载荷说明
        var payloadHint: String {
            switch self {
            case .sendCommand:   return "发送到终端的命令"
            case .notification:  return "通知正文（支持 {{MATCHED_TEXT}}）"
            case .openURL:       return "https://example.com/{{MATCHED_TEXT}}"
            case .writeLog:      return "日志文件路径（如 ~/logs/ssh.log）"
            case .runScript:     return "可执行脚本路径（如 ~/scripts/alert.sh）"
            case .highlightLine: return "高亮颜色（如 yellow / red / cyan）"
            }
        }
    }
}
