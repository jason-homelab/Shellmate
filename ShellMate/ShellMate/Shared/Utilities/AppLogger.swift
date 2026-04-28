import Foundation
import OSLog

/// ShellMate 统一日志门面
///
/// 使用 Apple Unified Logging（os.Logger）替代裸 print()：
/// - Release 构建中调试日志不进入控制台（不泄漏敏感信息）
/// - 支持 Console.app / Instruments 过滤订阅
/// - 按子系统分类，便于故障排查
///
/// 用法：
/// ```swift
/// AppLogger.ssh.debug("握手完成")
/// AppLogger.sftp.error("连接失败: \(error.localizedDescription)")
/// ```
enum AppLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.shellmate.app"

    /// SSH 核心层（libssh2 桥接 / 连接 / 通道 / 事件循环）
    static let ssh     = Logger(subsystem: subsystem, category: "SSH")

    /// SFTP 文件传输
    static let sftp    = Logger(subsystem: subsystem, category: "SFTP")

    /// 端口转发（Local / Remote / SOCKS5）
    static let tunnel  = Logger(subsystem: subsystem, category: "Tunnel")

    /// Core Data 持久化
    static let db      = Logger(subsystem: subsystem, category: "Database")

    /// UI / 视图层（SessionForm、SessionFormSheet 等）
    static let ui      = Logger(subsystem: subsystem, category: "UI")

    /// 通用 / 其他
    static let general = Logger(subsystem: subsystem, category: "General")
}
