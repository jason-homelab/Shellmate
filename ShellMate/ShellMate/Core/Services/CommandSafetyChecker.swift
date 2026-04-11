import Foundation

// MARK: - AI-06 高风险命令安全审计（§21.1）

/// 表示命令风险评估结果
struct CommandRisk: Identifiable {
    let id: UUID = UUID()
    let command: String
    let level: Level
    let matchedPattern: String
    let reason: String

    enum Level {
        /// 高危：可能导致数据丢失或系统破坏，需强烈警告
        case danger
        /// 警告：可能有副作用，建议用户确认
        case warning

        var title: String {
            switch self {
            case .danger:  return "高危命令"
            case .warning: return "风险命令"
            }
        }

        var icon: String {
            switch self {
            case .danger:  return "exclamationmark.octagon.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }

        var color: String {
            switch self {
            case .danger:  return "#ff3b30"
            case .warning: return "#ff9500"
            }
        }
    }
}

/// 高风险命令静态检测器
/// 仅做本地 pattern 匹配，无网络请求；AI 分析作为可选增强
enum CommandSafetyChecker {

    // MARK: - 规则表

    private struct Rule {
        let pattern: String         // 正则匹配（小写命令）
        let level: CommandRisk.Level
        let label: String           // matchedPattern 描述
        let reason: String          // 向用户展示的风险说明
    }

    private static let rules: [Rule] = [
        // 文件递归删除
        Rule(pattern: #"\brm\b.*-[a-z]*r[a-z]*f|rm\b.*--recursive.*--force|rm\b.*--force.*--recursive"#,
             level: .danger,
             label: "rm -rf",
             reason: "将递归强制删除目录及其所有内容，操作不可恢复"),

        Rule(pattern: #"\bsudo\s+rm\b"#,
             level: .danger,
             label: "sudo rm",
             reason: "以 root 权限删除文件，误操作可能破坏系统关键文件"),

        // 磁盘直接写入
        Rule(pattern: #"\bdd\b.*\bif\s*=|>\s*/dev/sd[a-z]|>\s*/dev/nvme|>\s*/dev/disk"#,
             level: .danger,
             label: "dd / 直接写入块设备",
             reason: "直接向块设备写入数据会覆盖磁盘内容，可能导致数据完全丢失"),

        // 磁盘格式化
        Rule(pattern: #"\bmkfs\b|\bformat\b.*\b/dev/"#,
             level: .danger,
             label: "mkfs（格式化磁盘）",
             reason: "将格式化磁盘分区，该分区上的所有数据将被永久清除"),

        // 数据销毁
        Rule(pattern: #"\bshred\b"#,
             level: .danger,
             label: "shred（安全擦除）",
             reason: "对文件进行多次覆写擦除，数据无法恢复"),

        // Fork 炸弹
        Rule(pattern: #":\s*\(\s*\)\s*\{.*:\s*\|"#,
             level: .danger,
             label: "Fork 炸弹",
             reason: "将产生无限进程，导致系统资源耗尽，可能需要强制重启"),

        // chmod 777 递归
        Rule(pattern: #"\bchmod\b.*-[a-z]*r[a-z]*\s+[0-7]*7[0-7]*[0-7]|\bchmod\b.*777"#,
             level: .warning,
             label: "chmod 777 / 递归赋权",
             reason: "将文件或目录设置为任意用户可读写执行，可能造成安全漏洞"),

        // chown 递归到 root
        Rule(pattern: #"\bchown\b.*-[a-z]*r[a-z]*.*\broot\b"#,
             level: .warning,
             label: "chown -R root",
             reason: "递归将所有权变更为 root，可能导致普通用户无法访问相关文件"),

        // 大量文件查找并删除
        Rule(pattern: #"\bfind\b.*--delete\b|\bfind\b.*-exec\s+rm\b"#,
             level: .warning,
             label: "find … -delete / -exec rm",
             reason: "将批量删除匹配到的文件，操作范围可能超出预期"),

        // 文件内容清空
        Rule(pattern: #">\s*/etc/|\btruncate\b.*-s\s*0"#,
             level: .warning,
             label: "truncate / 重定向清空关键文件",
             reason: "可能清空系统关键配置文件，导致服务异常"),

        // SQL DROP
        Rule(pattern: #"\bdrop\s+(table|database|schema)\b"#,
             level: .danger,
             label: "DROP TABLE / DATABASE",
             reason: "将永久删除数据库表或整个数据库，数据无法恢复"),

        // Git 强制推送
        Rule(pattern: #"\bgit\b.*push.*(-f\b|--force\b)"#,
             level: .warning,
             label: "git push --force",
             reason: "强制推送将覆盖远程分支历史，可能导致团队成员丢失提交"),

        // kill -9 / pkill -9
        Rule(pattern: #"\bkill\b.*-9\s+1\b|\bkillall\b.*-9\b|\bpkill\b.*-9\b"#,
             level: .warning,
             label: "kill -9 / killall -9",
             reason: "强制终止进程，可能导致数据未保存或服务异常退出"),
    ]

    // MARK: - 检测入口

    /// 检测命令是否包含高风险模式
    /// - Parameter command: 用户输入的原始命令（含换行符/ANSI 等会被预处理）
    /// - Returns: 检测到风险时返回 `CommandRisk`，安全时返回 `nil`
    static func check(_ command: String) -> CommandRisk? {
        // 预处理：去除 ANSI 转义码、转小写、合并连续空白
        let cleaned = stripANSI(command)
            .lowercased()
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""

        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            if regex.firstMatch(in: cleaned, options: [], range: range) != nil {
                return CommandRisk(
                    command: command.trimmingCharacters(in: .whitespacesAndNewlines),
                    level: rule.level,
                    matchedPattern: rule.label,
                    reason: rule.reason
                )
            }
        }
        return nil
    }

    // MARK: - ANSI 剥离

    private static func stripANSI(_ text: String) -> String {
        let pattern = #"\x1B\[[0-9;]*[A-Za-z]|\x1B\][^\x07]*\x07"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }
}
