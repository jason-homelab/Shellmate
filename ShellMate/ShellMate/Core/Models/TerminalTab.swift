import Foundation

/// 终端标签页模型
/// 表示一个终端会话标签页
struct TerminalTab: Identifiable, Equatable, Hashable {

    // MARK: - 属性

    /// 唯一标识符
    let id: UUID

    /// 关联的会话 ID（本地终端标签页时为占位 UUID，不对应任何 Session）
    let sessionId: UUID

    /// 标签标题
    var title: String

    /// 连接状态
    var connectionState: ConnectionState

    /// 是否正在加载
    var isLoading: Bool

    /// 创建时间
    let createdAt: Date

    /// 是否可关闭
    var isClosable: Bool

    /// 是否为本地终端模式（无需 SSH 连接，直接运行本地 Shell）
    var isLocalTerminal: Bool

    // MARK: - 初始化

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        title: String,
        connectionState: ConnectionState = .offline,
        isLoading: Bool = false,
        createdAt: Date = Date(),
        isClosable: Bool = true,
        isLocalTerminal: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.title = title
        self.connectionState = connectionState
        self.isLoading = isLoading
        self.createdAt = createdAt
        self.isClosable = isClosable
        self.isLocalTerminal = isLocalTerminal
    }

    // MARK: - 便捷初始化

    /// 从 Session 创建标签页
    init(session: Session) {
        self.id = UUID()
        self.sessionId = session.id
        self.title = session.name
        self.connectionState = session.connectionState
        self.isLoading = false
        self.createdAt = Date()
        self.isClosable = true
        self.isLocalTerminal = false
    }

    /// 创建本地终端标签页
    static func localTerminal() -> TerminalTab {
        TerminalTab(
            sessionId: UUID(),    // 占位 UUID，不对应任何 Session
            title: "本地 Shell",
            connectionState: .connected,
            isLocalTerminal: true
        )
    }
}

// MARK: - 预览数据

extension TerminalTab {
    static var preview: TerminalTab {
        TerminalTab(
            sessionId: UUID(),
            title: "开发服务器",
            connectionState: .connected
        )
    }

    static var previewTabs: [TerminalTab] {
        [
            TerminalTab(sessionId: UUID(), title: "开发服务器", connectionState: .connected),
            TerminalTab(sessionId: UUID(), title: "生产服务器", connectionState: .connecting),
            TerminalTab(sessionId: UUID(), title: "测试环境", connectionState: .offline),
            TerminalTab(sessionId: UUID(), title: "数据库服务器", connectionState: .error)
        ]
    }
}
