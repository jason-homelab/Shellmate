import Foundation

/// Known Hosts 条目
/// 表示一个已知主机的记录
struct KnownHostEntry: Identifiable, Codable, Equatable {
    /// 唯一标识
    let id: UUID

    /// 主机名或 IP 地址
    let host: String

    /// 端口号（非标准端口时使用）
    let port: Int32?

    /// 密钥类型
    let keyType: String

    /// 密钥指纹（SHA256）
    let fingerprint: String

    /// 原始公钥（Base64 编码）
    let publicKey: String

    /// 添加时间
    let addedAt: Date

    /// 最后验证时间
    var lastVerifiedAt: Date

    /// 是否为通配符匹配
    let isWildcard: Bool

    /// 备注
    var comment: String?

    // MARK: - 初始化

    init(
        id: UUID = UUID(),
        host: String,
        port: Int32? = nil,
        keyType: String,
        fingerprint: String,
        publicKey: String,
        addedAt: Date = Date(),
        lastVerifiedAt: Date = Date(),
        isWildcard: Bool = false,
        comment: String? = nil
    ) {
        self.id = id
        self.host = host
        self.port = port
        self.keyType = keyType
        self.fingerprint = fingerprint
        self.publicKey = publicKey
        self.addedAt = addedAt
        self.lastVerifiedAt = lastVerifiedAt
        self.isWildcard = isWildcard
        self.comment = comment
    }

    /// 主机标识符（用于匹配）
    var hostIdentifier: String {
        if let port = port, port != 22 {
            return "[\(host)]:\(port)"
        }
        return host
    }
}

/// Known Hosts 检查结果
enum KnownHostCheckResult {
    /// 主机密钥匹配
    case match
    /// 主机密钥不匹配（可能的中间人攻击）
    case mismatch(existing: KnownHostEntry)
    /// 未找到主机记录
    case notFound
    /// 检查失败
    case failure(Error)
}

/// Known Hosts 管理器
/// 负责管理已知主机密钥的存储和验证
final class KnownHostsManager {

    // MARK: - 单例

    static let shared = KnownHostsManager()

    // MARK: - 属性

    /// 存储文件路径
    private let storagePath: URL

    /// 已知主机列表
    private var knownHosts: [KnownHostEntry] = []

    /// 访问锁
    private let lock = NSLock()

    /// 是否已加载
    private var isLoaded = false

    // MARK: - 初始化

    private init() {
        // 使用应用支持目录存储 known_hosts
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("ShellMate", isDirectory: true)

        // 确保目录存在
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        self.storagePath = appFolder.appendingPathComponent("known_hosts.json")
    }

    // MARK: - 公共方法

    /// 检查主机密钥
    /// - Parameters:
    ///   - host: 主机名
    ///   - port: 端口号
    ///   - fingerprint: 主机密钥指纹
    /// - Returns: 检查结果
    func check(host: String, port: Int32, fingerprint: HostKeyFingerprint) -> KnownHostCheckResult {
        lock.lock()
        defer { lock.unlock() }

        ensureLoaded()

        // 查找匹配的条目
        if let entry = findEntry(host: host, port: port) {
            if entry.fingerprint == fingerprint.sha256 {
                // 更新最后验证时间
                updateLastVerified(entry: entry)
                return .match
            } else {
                return .mismatch(existing: entry)
            }
        }

        return .notFound
    }

    /// 添加主机密钥
    /// - Parameters:
    ///   - host: 主机名
    ///   - port: 端口号
    ///   - fingerprint: 主机密钥指纹
    ///   - comment: 备注
    func add(host: String, port: Int32, fingerprint: HostKeyFingerprint, comment: String? = nil) throws {
        lock.lock()
        defer { lock.unlock() }

        ensureLoaded()

        // 检查是否已存在
        if let existingIndex = knownHosts.firstIndex(where: { matchesHost($0, host: host, port: port) }) {
            // 更新现有条目
            knownHosts[existingIndex] = KnownHostEntry(
                id: knownHosts[existingIndex].id,
                host: host,
                port: port != 22 ? port : nil,
                keyType: fingerprint.keyType.displayName,
                fingerprint: fingerprint.sha256,
                publicKey: fingerprint.rawKey.base64EncodedString(),
                addedAt: knownHosts[existingIndex].addedAt,
                lastVerifiedAt: Date(),
                comment: comment
            )
        } else {
            // 添加新条目
            let entry = KnownHostEntry(
                host: host,
                port: port != 22 ? port : nil,
                keyType: fingerprint.keyType.displayName,
                fingerprint: fingerprint.sha256,
                publicKey: fingerprint.rawKey.base64EncodedString(),
                comment: comment
            )
            knownHosts.append(entry)
        }

        try save()
    }

    /// 移除主机密钥
    /// - Parameters:
    ///   - host: 主机名
    ///   - port: 端口号
    func remove(host: String, port: Int32) throws {
        lock.lock()
        defer { lock.unlock() }

        ensureLoaded()

        knownHosts.removeAll { matchesHost($0, host: host, port: port) }

        try save()
    }

    /// 移除指定条目
    /// - Parameter entry: 要移除的条目
    func remove(entry: KnownHostEntry) throws {
        lock.lock()
        defer { lock.unlock() }

        ensureLoaded()

        knownHosts.removeAll { $0.id == entry.id }

        try save()
    }

    /// 获取所有已知主机
    /// - Returns: 已知主机列表
    func getAll() -> [KnownHostEntry] {
        lock.lock()
        defer { lock.unlock() }

        ensureLoaded()

        return knownHosts
    }

    /// 清除所有已知主机
    func clear() throws {
        lock.lock()
        defer { lock.unlock() }

        knownHosts.removeAll()

        try save()
    }

    // MARK: - OpenSSH 格式支持

    /// 从 OpenSSH known_hosts 文件导入
    /// - Parameter fileURL: 文件路径
    /// - Returns: 导入的条目数量
    func importFromOpenSSH(fileURL: URL) throws -> Int {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        var importedCount = 0

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 跳过空行和注释
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // 解析 OpenSSH 格式: host keytype base64key [comment]
            let parts = trimmed.components(separatedBy: .whitespaces)
            guard parts.count >= 3 else { continue }

            let hostPart = parts[0]
            let keyType = parts[1]
            let publicKey = parts[2]
            let comment = parts.count > 3 ? parts.dropFirst(3).joined(separator: " ") : nil

            // 解析主机（可能包含端口）
            var host = hostPart
            var port: Int32? = nil

            if hostPart.hasPrefix("[") {
                // 格式: [host]:port
                if let closeBracket = hostPart.firstIndex(of: "]") {
                    host = String(hostPart[hostPart.index(after: hostPart.startIndex)..<closeBracket])
                    let portPart = hostPart[hostPart.index(after: closeBracket)...]
                    if portPart.hasPrefix(":") {
                        port = Int32(portPart.dropFirst())
                    }
                }
            }

            // 创建条目
            let entry = KnownHostEntry(
                host: host,
                port: port,
                keyType: keyType,
                fingerprint: "", // OpenSSH 格式不直接包含指纹
                publicKey: publicKey,
                comment: comment
            )

            lock.lock()
            knownHosts.append(entry)
            lock.unlock()

            importedCount += 1
        }

        try save()
        return importedCount
    }

    /// 导出为 OpenSSH known_hosts 格式
    /// - Returns: OpenSSH 格式的内容
    func exportToOpenSSH() -> String {
        lock.lock()
        defer { lock.unlock() }

        ensureLoaded()

        var lines: [String] = []
        lines.append("# ShellMate Known Hosts")
        lines.append("# 导出时间: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("")

        for entry in knownHosts {
            var line = entry.hostIdentifier
            line += " \(entry.keyType)"
            line += " \(entry.publicKey)"

            if let comment = entry.comment {
                line += " \(comment)"
            }

            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 私有方法

    /// 确保数据已加载
    private func ensureLoaded() {
        guard !isLoaded else { return }

        do {
            try load()
        } catch {
            print("[KnownHostsManager] 加载失败: \(error.localizedDescription)")
            knownHosts = []
        }

        isLoaded = true
    }

    /// 加载数据
    private func load() throws {
        guard FileManager.default.fileExists(atPath: storagePath.path) else {
            knownHosts = []
            return
        }

        let data = try Data(contentsOf: storagePath)
        knownHosts = try JSONDecoder().decode([KnownHostEntry].self, from: data)
    }

    /// 保存数据
    private func save() throws {
        let data = try JSONEncoder().encode(knownHosts)
        try data.write(to: storagePath, options: .atomic)
    }

    /// 查找匹配的条目
    private func findEntry(host: String, port: Int32) -> KnownHostEntry? {
        return knownHosts.first { matchesHost($0, host: host, port: port) }
    }

    /// 检查条目是否匹配主机
    private func matchesHost(_ entry: KnownHostEntry, host: String, port: Int32) -> Bool {
        // 检查主机名
        guard entry.host.lowercased() == host.lowercased() else {
            return false
        }

        // 检查端口
        let entryPort = entry.port ?? 22
        return entryPort == port
    }

    /// 更新最后验证时间
    private func updateLastVerified(entry: KnownHostEntry) {
        guard let index = knownHosts.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        knownHosts[index].lastVerifiedAt = Date()

        // 异步保存，不阻塞
        DispatchQueue.global(qos: .utility).async { [weak self] in
            try? self?.save()
        }
    }
}
