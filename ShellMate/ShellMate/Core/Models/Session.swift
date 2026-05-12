import Foundation

/// SSH 会话模型
/// 对应 Core Data 实体 CDSession 的 Swift 业务模型
struct Session: Identifiable, Hashable {
    /// 唯一标识符
    let id: UUID
    /// 会话名称
    var name: String
    /// 主机地址
    var host: String
    /// 端口号
    var port: Int32
    /// 用户名
    var username: String
    /// 认证方式
    var authMethod: AuthMethod
    /// 旧版 Keychain 引用（保留用于迁移兼容，新数据由 CredentialVault 管理）
    var keychainRef: String?
    /// 私钥文件路径
    var privateKeyPath: String?
    /// 保活间隔（秒）
    var keepAliveInterval: Int32
    /// 是否自动重连
    var autoReconnect: Bool
    /// 字符编码
    var encoding: String
    /// 标签列表
    var tags: [String]
    /// 排序顺序
    var sortOrder: Int32
    /// 颜色（十六进制）
    var colorHex: String?
    /// 最后连接时间
    var lastConnectedAt: Date?
    /// 创建时间
    let createdAt: Date
    /// 修改时间
    var modifiedAt: Date
    /// 是否已删除（软删除）
    var isSoftDeleted: Bool
    /// 所属分组 ID
    var groupId: UUID?

    /// 跳板机简易字符串（如 "user@host:22"，逗号分隔多跳板机）
    var proxyJumpString: String?
    /// 连接超时（秒）
    var connectTimeout: Int32
    /// 最大重连次数
    var maxReconnectRetries: Int32
    /// 重连间隔（秒）
    var reconnectInterval: Int32
    /// 环境变量（JSON 序列化，key-value 对）
    var envVars: [String: String]
    /// 启动后自动执行的命令
    var startupCommand: String?
    /// 覆盖全局主题 ID（空字符串表示跟随全局）
    var overrideThemeId: String?
    /// 覆盖全局字号（0 表示跟随全局）
    var overrideFontSize: Int32

    // MARK: - 连接协议

    /// 连接协议类型（SSH / Telnet / Serial）
    var connectionType: ConnectionType

    // MARK: - 串口参数（connectionType == .serial 时有效）

    /// 串口设备路径（如 /dev/cu.usbserial-1）
    var serialPortPath: String?
    /// 波特率（默认 9600）
    var serialBaudRate: Int32
    /// 数据位（5/6/7/8，默认 8）
    var serialDataBits: Int32
    /// 奇偶校验（none/odd/even）
    var serialParity: String
    /// 停止位（1/2）
    var serialStopBits: Int32
    /// 流控（none/hardware/software）
    var serialFlowControl: String

    /// 跳板机链配置（运行时从 CDJumpHost 加载，不单独存 Keychain）
    var jumpHosts: [ProxyJumpConfig]

    // MARK: - 运行时状态（非持久化）

    /// 当前连接状态
    var connectionState: ConnectionState = .offline

    // MARK: - 初始化

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int32 = 22,
        username: String,
        authMethod: AuthMethod = .password,
        keychainRef: String? = nil,
        privateKeyPath: String? = nil,
        keepAliveInterval: Int32 = 60,
        autoReconnect: Bool = true,
        encoding: String = "UTF-8",
        tags: [String] = [],
        sortOrder: Int32 = 0,
        colorHex: String? = nil,
        lastConnectedAt: Date? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isSoftDeleted: Bool = false,
        groupId: UUID? = nil,
        proxyJumpString: String? = nil,
        connectTimeout: Int32 = 30,
        maxReconnectRetries: Int32 = 3,
        reconnectInterval: Int32 = 5,
        envVars: [String: String] = [:],
        startupCommand: String? = nil,
        overrideThemeId: String? = nil,
        overrideFontSize: Int32 = 0,
        connectionType: ConnectionType = .ssh,
        serialPortPath: String? = nil,
        serialBaudRate: Int32 = 9600,
        serialDataBits: Int32 = 8,
        serialParity: String = "none",
        serialStopBits: Int32 = 1,
        serialFlowControl: String = "none",
        jumpHosts: [ProxyJumpConfig] = []
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.keychainRef = keychainRef
        self.privateKeyPath = privateKeyPath
        self.keepAliveInterval = keepAliveInterval
        self.autoReconnect = autoReconnect
        self.encoding = encoding
        self.tags = tags
        self.sortOrder = sortOrder
        self.colorHex = colorHex
        self.lastConnectedAt = lastConnectedAt
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isSoftDeleted = isSoftDeleted
        self.groupId = groupId
        self.proxyJumpString = proxyJumpString
        self.connectTimeout = connectTimeout
        self.maxReconnectRetries = maxReconnectRetries
        self.reconnectInterval = reconnectInterval
        self.envVars = envVars
        self.startupCommand = startupCommand
        self.overrideThemeId = overrideThemeId
        self.overrideFontSize = overrideFontSize
        self.connectionType = connectionType
        self.serialPortPath = serialPortPath
        self.serialBaudRate = serialBaudRate
        self.serialDataBits = serialDataBits
        self.serialParity = serialParity
        self.serialStopBits = serialStopBits
        self.serialFlowControl = serialFlowControl
        self.jumpHosts = jumpHosts
    }

    // MARK: - 从 Core Data 实体转换

    init(from entity: CDSession) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.host = entity.host ?? ""
        self.port = entity.port
        self.username = entity.username ?? ""
        self.authMethod = AuthMethod(rawValue: entity.authMethodRaw) ?? .password
        self.keychainRef = entity.keychainRef
        self.privateKeyPath = entity.privateKeyPath
        self.keepAliveInterval = entity.keepAliveInterval
        self.autoReconnect = entity.autoReconnect
        self.encoding = entity.encoding ?? "UTF-8"
        self.tags = Session.parseTags(from: entity.tagsJSON)
        self.sortOrder = entity.sortOrder
        self.colorHex = entity.colorHex
        self.lastConnectedAt = entity.lastConnectedAt
        self.createdAt = entity.createdAt ?? Date()
        self.modifiedAt = entity.modifiedAt ?? Date()
        self.isSoftDeleted = entity.isSoftDeleted
        self.groupId = entity.group?.id
        self.proxyJumpString = entity.proxyJumpString
        self.connectTimeout = entity.connectTimeout
        self.maxReconnectRetries = entity.maxReconnectRetries
        self.reconnectInterval = entity.reconnectInterval
        self.envVars = Session.parseEnvVars(from: entity.envVarsJSON)
        self.startupCommand = entity.startupCommand
        self.overrideThemeId = entity.overrideThemeId
        self.overrideFontSize = entity.overrideFontSize
        self.connectionType = ConnectionType(rawValue: entity.connectionTypeRaw) ?? .ssh
        self.serialPortPath = entity.serialPortPath
        self.serialBaudRate = entity.serialBaudRate == 0 ? 9600 : entity.serialBaudRate
        self.serialDataBits = entity.serialDataBits == 0 ? 8 : entity.serialDataBits
        self.serialParity = (entity.serialParity ?? "").isEmpty ? "none" : (entity.serialParity ?? "none")
        self.serialStopBits = entity.serialStopBits == 0 ? 1 : entity.serialStopBits
        self.serialFlowControl = (entity.serialFlowControl ?? "").isEmpty ? "none" : (entity.serialFlowControl ?? "none")

        // 从 CDJumpHost 关系加载跳板机链（按 sortOrder 排序）
        let jumpHostEntities = (entity.jumpHosts as? Set<CDJumpHost>)?
            .sorted { $0.sortOrder < $1.sortOrder } ?? []
        self.jumpHosts = jumpHostEntities.map { jh in
            ProxyJumpConfig(
                host: jh.host ?? "",
                port: jh.port,
                username: jh.username ?? "",
                authMethod: AuthMethod(rawValue: jh.authMethodRaw) ?? .password,
                privateKeyPath: nil,
                vaultId: jh.id
            )
        }
    }

    // MARK: - 辅助方法

    /// 解析标签 JSON 字符串
    private static func parseTags(from json: String?) -> [String] {
        guard let json = json,
              let data = json.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }

    /// 解析环境变量 JSON 字符串
    private static func parseEnvVars(from json: String?) -> [String: String] {
        guard let json = json,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    /// 将环境变量转换为 JSON 字符串
    func envVarsToJSON() -> String? {
        guard !envVars.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(envVars),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// 将标签转换为 JSON 字符串
    func tagsToJSON() -> String? {
        guard !tags.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(tags),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// 更新 Core Data 实体
    func update(entity: CDSession) {
        entity.id = id
        entity.name = name
        entity.host = host
        entity.port = port
        entity.username = username
        entity.authMethodRaw = authMethod.rawValue
        entity.keychainRef = keychainRef
        entity.privateKeyPath = privateKeyPath
        entity.keepAliveInterval = keepAliveInterval
        entity.autoReconnect = autoReconnect
        entity.encoding = encoding
        entity.tagsJSON = tagsToJSON()
        entity.sortOrder = sortOrder
        entity.colorHex = colorHex
        entity.lastConnectedAt = lastConnectedAt
        entity.modifiedAt = Date()
        entity.isSoftDeleted = isSoftDeleted
        entity.proxyJumpString = proxyJumpString
        entity.connectTimeout = connectTimeout
        entity.maxReconnectRetries = maxReconnectRetries
        entity.reconnectInterval = reconnectInterval
        entity.envVarsJSON = envVarsToJSON()
        entity.startupCommand = startupCommand
        entity.overrideThemeId = overrideThemeId
        entity.overrideFontSize = overrideFontSize
        entity.connectionTypeRaw = connectionType.rawValue
        entity.serialPortPath = serialPortPath
        entity.serialBaudRate = serialBaudRate
        entity.serialDataBits = serialDataBits
        entity.serialParity = serialParity
        entity.serialStopBits = serialStopBits
        entity.serialFlowControl = serialFlowControl
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 预览数据

extension Session {
    /// 预览用示例会话
    static let preview = Session(
        name: "生产服务器",
        host: "192.168.1.100",
        port: 22,
        username: "root",
        authMethod: .privateKey,
        tags: ["生产", "Linux"],
        groupId: nil
    )

    /// 预览用示例会话列表
    static let previewList: [Session] = [
        Session(name: "开发服务器", host: "dev.example.com", username: "developer", sortOrder: 0),
        Session(name: "测试服务器", host: "test.example.com", username: "tester", sortOrder: 1),
        Session(name: "生产服务器", host: "prod.example.com", username: "admin", sortOrder: 2),
    ]
}
