import Foundation
import Security

/// Keychain 错误类型
enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case invalidData
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Keychain 项未找到"
        case .duplicateItem:
            return "Keychain 项已存在"
        case .unexpectedStatus(let status):
            return "Keychain 操作失败，状态码: \(status)"
        case .invalidData:
            return "无效的数据格式"
        case .encodingFailed:
            return "数据编码失败"
        case .decodingFailed:
            return "数据解码失败"
        }
    }
}

/// Keychain 凭证类型
enum CredentialType: String {
    case password = "password"
    case privateKey = "privateKey"
    case passphrase = "passphrase"
}

/// Keychain 服务
/// 负责安全地存储和检索 SSH 凭证
/// 使用 kSecAttrAccessibleWhenUnlockedThisDeviceOnly 确保凭证仅在设备解锁时可访问
final class KeychainService {

    // MARK: - 单例

    static let shared = KeychainService()

    // MARK: - 常量

    /// 服务标识符前缀
    private let servicePrefix = "app.shellmate"

    /// 访问组（用于应用间共享，暂时不启用）
    private let accessGroup: String? = nil

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 保存密码到 Keychain
    /// - Parameters:
    ///   - password: 要保存的密码
    ///   - sessionId: 会话 ID
    ///   - type: 凭证类型
    /// - Throws: KeychainError
    func savePassword(_ password: String, for sessionId: UUID, type: CredentialType = .password) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let account = makeAccount(sessionId: sessionId, type: type)
        let service = makeService(type: type)

        // 先尝试删除已存在的项
        try? deletePassword(for: sessionId, type: type)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrLabel as String: "ShellMate SSH Credential"
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 从 Keychain 获取密码
    /// - Parameters:
    ///   - sessionId: 会话 ID
    ///   - type: 凭证类型
    /// - Returns: 密码字符串
    /// - Throws: KeychainError
    func getPassword(for sessionId: UUID, type: CredentialType = .password) throws -> String {
        let account = makeAccount(sessionId: sessionId, type: type)
        let service = makeService(type: type)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return password
    }

    /// 更新 Keychain 中的密码
    /// - Parameters:
    ///   - password: 新密码
    ///   - sessionId: 会话 ID
    ///   - type: 凭证类型
    /// - Throws: KeychainError
    func updatePassword(_ password: String, for sessionId: UUID, type: CredentialType = .password) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let account = makeAccount(sessionId: sessionId, type: type)
        let service = makeService(type: type)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 从 Keychain 删除密码
    /// - Parameters:
    ///   - sessionId: 会话 ID
    ///   - type: 凭证类型
    /// - Throws: KeychainError
    func deletePassword(for sessionId: UUID, type: CredentialType = .password) throws {
        let account = makeAccount(sessionId: sessionId, type: type)
        let service = makeService(type: type)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 删除会话的所有凭证
    /// - Parameter sessionId: 会话 ID
    func deleteAllCredentials(for sessionId: UUID) {
        for type in [CredentialType.password, .privateKey, .passphrase] {
            try? deletePassword(for: sessionId, type: type)
        }
    }

    /// 检查凭证是否存在
    /// - Parameters:
    ///   - sessionId: 会话 ID
    ///   - type: 凭证类型
    /// - Returns: 是否存在
    func hasCredential(for sessionId: UUID, type: CredentialType = .password) -> Bool {
        do {
            _ = try getPassword(for: sessionId, type: type)
            return true
        } catch {
            return false
        }
    }

    /// 保存或更新密码（智能方法）
    /// - Parameters:
    ///   - password: 密码
    ///   - sessionId: 会话 ID
    ///   - type: 凭证类型
    /// - Throws: KeychainError
    func saveOrUpdate(_ password: String, for sessionId: UUID, type: CredentialType = .password) throws {
        if hasCredential(for: sessionId, type: type) {
            try updatePassword(password, for: sessionId, type: type)
        } else {
            try savePassword(password, for: sessionId, type: type)
        }
    }

    // MARK: - 私钥专用方法

    /// 保存私钥到 Keychain
    /// - Parameters:
    ///   - privateKey: 私钥内容
    ///   - sessionId: 会话 ID
    /// - Throws: KeychainError
    func savePrivateKey(_ privateKey: String, for sessionId: UUID) throws {
        try savePassword(privateKey, for: sessionId, type: .privateKey)
    }

    /// 获取私钥
    /// - Parameter sessionId: 会话 ID
    /// - Returns: 私钥内容
    /// - Throws: KeychainError
    func getPrivateKey(for sessionId: UUID) throws -> String {
        try getPassword(for: sessionId, type: .privateKey)
    }

    /// 保存私钥密码短语
    /// - Parameters:
    ///   - passphrase: 密码短语
    ///   - sessionId: 会话 ID
    /// - Throws: KeychainError
    func savePassphrase(_ passphrase: String, for sessionId: UUID) throws {
        try savePassword(passphrase, for: sessionId, type: .passphrase)
    }

    /// 获取私钥密码短语
    /// - Parameter sessionId: 会话 ID
    /// - Returns: 密码短语
    /// - Throws: KeychainError
    func getPassphrase(for sessionId: UUID) throws -> String {
        try getPassword(for: sessionId, type: .passphrase)
    }

    // MARK: - 私有方法

    /// 生成账户标识符
    private func makeAccount(sessionId: UUID, type: CredentialType) -> String {
        return "\(sessionId.uuidString).\(type.rawValue)"
    }

    /// 生成服务标识符
    private func makeService(type: CredentialType) -> String {
        return "\(servicePrefix).\(type.rawValue)"
    }
}

// MARK: - Keychain 引用生成器

extension KeychainService {

    /// 生成 Keychain 引用字符串（用于存储在 Core Data 中）
    /// - Parameters:
    ///   - sessionId: 会话 ID
    ///   - type: 凭证类型
    /// - Returns: Keychain 引用字符串
    func makeKeychainRef(sessionId: UUID, type: CredentialType = .password) -> String {
        return "keychain://\(makeService(type: type))/\(makeAccount(sessionId: sessionId, type: type))"
    }

    /// 解析 Keychain 引用字符串
    /// - Parameter ref: Keychain 引用字符串
    /// - Returns: (sessionId, type) 元组，解析失败返回 nil
    func parseKeychainRef(_ ref: String) -> (sessionId: UUID, type: CredentialType)? {
        guard ref.hasPrefix("keychain://") else { return nil }

        let path = String(ref.dropFirst("keychain://".count))
        let components = path.split(separator: "/")

        guard components.count == 2 else { return nil }

        let accountParts = components[1].split(separator: ".")
        guard accountParts.count == 2,
              let sessionId = UUID(uuidString: String(accountParts[0])),
              let type = CredentialType(rawValue: String(accountParts[1])) else {
            return nil
        }

        return (sessionId, type)
    }
}
