import Foundation

// MARK: - tmux 会话

/// 远程服务器上的一个 tmux 会话
struct TmuxSession: Identifiable, Equatable {
    /// 本地唯一标识（不跟远程 tmux 概念绑定）
    let id: UUID = UUID()
    /// tmux 会话名（服务器端唯一标识）
    var name: String
    /// 是否有客户端正在附加
    var isAttached: Bool
    /// 窗口数量
    var windowCount: Int
    /// 会话创建时间（来自 tmux ls -F #{session_created}）
    var createdAt: Date?
    /// 终端尺寸描述，如 "180×50"
    var dimensions: String
    /// 窗口列表（可选，需单独请求 tmux list-windows）
    var windows: [TmuxWindow]

    /// 相对创建时间描述，如 "3h 前"
    var relativeCreatedTime: String {
        guard let date = createdAt else { return "" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))min 前" }
        if interval < 86400 { return "\(Int(interval / 3600))h 前" }
        return "\(Int(interval / 86400))d 前"
    }
}

// MARK: - tmux 窗口

/// tmux 会话内的一个窗口
struct TmuxWindow: Identifiable, Equatable {
    let id: UUID = UUID()
    /// 窗口编号（tmux 内部索引）
    var index: Int
    /// 窗口名（可重命名）
    var name: String
    /// 是否是当前激活的窗口
    var isActive: Bool
}

// MARK: - tmux 配置

/// tmux 自动附加策略
enum TmuxAutoAttach: String, CaseIterable, Codable {
    case none    = "不自动附加"
    case latest  = "附加最近使用的会话"
    case named   = "附加指定会话名"
    case create  = "创建新会话"
}

/// SSH 断开连接时对 tmux 会话的处理行为
enum TmuxDisconnectBehavior: String, CaseIterable, Codable {
    case detach = "仅分离（保留 tmux 会话）"
    case kill   = "终止 tmux 会话"
}

/// 每个 Session 的 tmux 集成配置（持久化至 UserDefaults，与 Core Data 独立）
struct TmuxConfig: Codable, Equatable {
    /// 是否启用 tmux 检测（连接后自动检查远程 tmux 可用性）
    var enabled: Bool = true
    /// 自动附加策略
    var autoAttach: TmuxAutoAttach = .none
    /// 附加指定会话名（autoAttach == .named 时使用）
    var sessionName: String = ""
    /// 新建会话名（autoAttach == .create 时使用，空则使用 tmux 默认编号）
    var newSessionName: String = ""
    /// SSH 断开时的行为
    var disconnectBehavior: TmuxDisconnectBehavior = .detach
    /// 有已有会话时是否自动弹出管理器
    var autoShowManager: Bool = false
}

// MARK: - tmux 可用性

/// 远程服务器上 tmux 的可用性状态
enum TmuxAvailability: Equatable {
    case unknown                           // 尚未检测
    case checking                          // 检测中
    case available(version: String)        // 可用，附带版本字符串（如 "tmux 3.4"）
    case unavailable                       // 不可用（未安装或命令执行失败）
}

// MARK: - 输出标记

/// TerminalController 数据管道用于过滤 tmux 检测输出的标记前缀
enum TmuxOutputMarker {
    static let checkOK         = "__SM_TMUX_OK__"
    static let checkNA         = "__SM_TMUX_NA__"
    static let sessionListStart = "__SM_TMUX_LS_START__"
    static let sessionListEnd   = "__SM_TMUX_LS_END__"
    static let windowListStart  = "__SM_TMUX_WL_START__"
    static let windowListEnd    = "__SM_TMUX_WL_END__"
    static let noSessions       = "__SM_TMUX_NO_SESSIONS__"

    /// 判断一行文本是否包含任一 tmux 标记
    static func containsMarker(_ line: String) -> Bool {
        line.contains("__SM_TMUX_")
    }
}
