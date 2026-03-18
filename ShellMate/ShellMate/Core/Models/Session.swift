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
    /// Keychain 引用（用于存取密码/私钥密码）
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
        groupId: UUID? = nil
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
