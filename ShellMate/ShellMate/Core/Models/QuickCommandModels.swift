import Foundation
import CoreData

// MARK: - 快捷命令

/// 单条快捷命令
/// 对应 PRD §3.7.1 快捷命令配置字段
struct QuickCommand: Identifiable, Codable, Equatable {

    var id: UUID

    /// 按钮显示名称（最多 20 字符）
    var name: String

    /// 命令内容（支持多行，多行按序发送）
    var content: String

    /// 末尾是否自动追加回车（\\r）
    var appendNewline: Bool

    /// 是否逐行发送（多行内容）
    var sendLineByLine: Bool

    /// 逐行发送时的行间延迟（毫秒）
    var lineDelay: Int

    /// 全局快捷键描述（如 "⌘⇧1"），nil 表示无快捷键
    var shortcut: String?

    /// 排序权重
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String = "",
        content: String = "",
        appendNewline: Bool = true,
        sendLineByLine: Bool = false,
        lineDelay: Int = 50,
        shortcut: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.appendNewline = appendNewline
        self.sendLineByLine = sendLineByLine
        self.lineDelay = lineDelay
        self.shortcut = shortcut
        self.sortOrder = sortOrder
    }

    /// 从 Core Data 实体构造
    init(from entity: CDQuickCommand) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.content = entity.commandText ?? ""
        self.appendNewline = entity.appendNewline
        self.sendLineByLine = entity.lineByLine
        self.lineDelay = Int(entity.lineDelay)
        self.shortcut = entity.shortcut
        self.sortOrder = Int(entity.sortOrder)
    }
}

// MARK: - 快捷命令集

/// 快捷命令集（一组相关的命令）
struct QuickCommandSet: Identifiable, Codable, Equatable {

    var id: UUID

    /// 命令集名称
    var name: String

    /// 包含的命令列表（按 sortOrder 排序）
    var commands: [QuickCommand]

    /// 排序权重
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String = "新建命令集",
        commands: [QuickCommand] = [],
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.commands = commands
        self.sortOrder = sortOrder
    }

    /// 按 sortOrder 排序后的命令列表
    var sortedCommands: [QuickCommand] {
        commands.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 从 Core Data 实体构造
    init(from entity: CDQuickCommandSet) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.sortOrder = Int(entity.sortOrder)
        let cmds = (entity.commands as? Set<CDQuickCommand>) ?? []
        self.commands = cmds.map { QuickCommand(from: $0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 默认命令集（含常用系统命令示例）
    static var defaultSet: QuickCommandSet {
        QuickCommandSet(
            name: "默认命令集",
            commands: [
                QuickCommand(name: "查看进程",   content: "ps aux",                    sortOrder: 0),
                QuickCommand(name: "磁盘用量",   content: "df -h",                     sortOrder: 1),
                QuickCommand(name: "内存信息",   content: "free -h",                   sortOrder: 2),
                QuickCommand(name: "系统日志",   content: "tail -n 50 /var/log/syslog", sortOrder: 3),
                QuickCommand(name: "网络连接",   content: "ss -tunlp",                 sortOrder: 4),
                QuickCommand(name: "当前用户",   content: "whoami && id",              sortOrder: 5),
            ],
            sortOrder: 0
        )
    }
}
