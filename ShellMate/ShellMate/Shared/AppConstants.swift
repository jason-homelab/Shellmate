import Foundation

// MARK: - 应用全局常量（任务 15.8）
// 集中管理性能调优参数，避免硬编码散落各处

enum AppConstants {

    // MARK: - SSH / 终端 读取缓冲区

    /// SSH 数据读取缓冲区大小（32KB）
    /// 适用：SSH2Connection / SSHEventLoop / SSHChannelManager / SSHProcessBridge
    /// 优化背景：W15.5 从 4KB 升为 32KB，减少系统调用频率
    static let sshReadBufferSize: Int = 32_768

    // MARK: - SFTP 传输

    /// SFTP 文件传输缓冲区大小（128KB）
    /// 适用：SFTPSession 上传/下载循环
    /// 优化背景：W15.4 从 32KB 升为 128KB，降低 libssh2 调用次数与 CPU 占用
    static let sftpTransferBufferSize: Int = 131_072

    /// SFTP 最大并发传输数
    /// 适用：SFTPTransferQueue 初始化默认值
    static let sftpMaxConcurrentTransfers: Int = 3

    // MARK: - 终端渲染 / 数据合并

    /// TerminalDataCoalescer 合并窗口（纳秒），对应 ~60fps（16ms）
    /// 适用：TerminalController / LocalTerminalController
    /// 优化背景：W15.2 将高频 SSH 数据包合并到 16ms 窗口后批量送入 SwiftTerm
    static let terminalCoalescerIntervalNs: UInt64 = 16_000_000

    // MARK: - 服务器监控

    /// 服务器性能指标轮询间隔（秒）
    /// 适用：ServerMetricsMonitor
    static let serverMetricsPollInterval: TimeInterval = 2.0

    // MARK: - AI

    /// AI 请求最大 Token 数
    /// 适用：AIService Claude/OpenAI 请求 body
    static let aiMaxTokens: Int = 4096

    /// AI 上下文：发送给 AI 的终端历史最大行数
    static let aiTerminalContextLines: Int = 50
}
