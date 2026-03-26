import Foundation
import CoreData
import CryptoKit
import Security

/// 凭据金库错误类型
enum CredentialVaultError: Error, LocalizedError {
    case masterKeyUnavailable
    case encryptionFailed
    case decryptionFailed
    case credentialNotFound
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .masterKeyUnavailable:  return "无法访问主密钥"
        case .encryptionFailed:      return "凭据加密失败"
        case .decryptionFailed:      return "凭据解密失败"
        case .credentialNotFound:    return "凭据未找到"
        case .encodingFailed:        return "凭据编码失败"
        case .decodingFailed:        return "凭据解码失败"
        }
    }
}

/// 凭据金库
///
/// 采用 AES-256-GCM 加密所有 SSH 凭据，存储于本地 Core Data（CDCredential，不同步 CloudKit）。
/// 单枚 256-bit Master Key 存于 Keychain，无弹窗无 ACL，首次启动自动生成。
///
/// 架构：
///   CDCredential.encryptedPayload = nonce(12B) + AES-GCM(ciphertext) + tag(16B)
///   CredentialVault --[读/写]--> CDCredential（本地 SQLite）
///   CredentialVault --[取主密钥]--> Keychain 单条条目（app.shellmate.vault / master-key）
actor CredentialVault {

    // MARK: - 单例

    static let shared = CredentialVault()

    // MARK: - Keychain 常量

    private let vaultService = "app.shellmate.vault"
    private let masterKeyAccount = "master-key"

    // MARK: - 内存缓存主密钥（进程生命周期内）

    private var cachedMasterKey: SymmetricKey?

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开接口

    /// 保存（或覆盖）凭据
    func save(_ secret: String, sessionId: UUID, type: CredentialType) async throws {
        guard let data = secret.data(using: .utf8) else {
            throw CredentialVaultError.encodingFailed
        }
        let payload = try encrypt(data)

        let context = PersistenceController.shared.newBackgroundContext()
        try await context.perform {
            // 删除已有同类凭据，保证唯一
            let request = CDCredential.fetchRequest()
            request.predicate = NSPredicate(
                format: "sessionId == %@ AND credentialTypeRaw == %@",
                sessionId as CVarArg, type.rawValue
            )
            if let existing = try context.fetch(request).first {
                context.delete(existing)
            }

            // 插入新凭据
            let credential = CDCredential(context: context)
            credential.id = UUID()
            credential.sessionId = sessionId
            credential.credentialTypeRaw = type.rawValue
            credential.encryptedPayload = payload
            credential.createdAt = Date()
            credential.modifiedAt = Date()

            try context.save()
        }
    }

    /// 读取凭据
    /// 若金库中不存在，自动从旧版 Keychain 迁移（懒加载迁移，透明无感知）
    func load(sessionId: UUID, type: CredentialType) async throws -> String {
        // 第一步：在 Core Data context 中读取加密载荷
        let context = PersistenceController.shared.newBackgroundContext()
        let encryptedPayload: Data? = try? await context.perform {
            let request = CDCredential.fetchRequest()
            request.predicate = NSPredicate(
                format: "sessionId == %@ AND credentialTypeRaw == %@",
                sessionId as CVarArg, type.rawValue
            )
            request.fetchLimit = 1
            return try context.fetch(request).first?.encryptedPayload
        }

        // 第二步：若金库有数据，解密后返回
        if let payload = encryptedPayload {
            let plainData = try decrypt(payload)
            guard let secret = String(data: plainData, encoding: .utf8) else {
                throw CredentialVaultError.decodingFailed
            }
            return secret
        }

        // 第三步：金库中没有 → 尝试从旧版 Keychain 自动迁移（兼容升级前数据）
        if let legacy = try? KeychainService.shared.getPassword(for: sessionId, type: type) {
            try await save(legacy, sessionId: sessionId, type: type)
            try? KeychainService.shared.deletePassword(for: sessionId, type: type)
            return legacy
        }

        throw CredentialVaultError.credentialNotFound
    }

    /// 检查凭据是否存在
    func exists(sessionId: UUID, type: CredentialType) async -> Bool {
        do {
            _ = try await load(sessionId: sessionId, type: type)
            return true
        } catch {
            return false
        }
    }

    /// 删除指定凭据
    func delete(sessionId: UUID, type: CredentialType) async throws {
        let context = PersistenceController.shared.newBackgroundContext()
        try await context.perform {
            let request = CDCredential.fetchRequest()
            request.predicate = NSPredicate(
                format: "sessionId == %@ AND credentialTypeRaw == %@",
                sessionId as CVarArg, type.rawValue
            )
            for obj in try context.fetch(request) {
                context.delete(obj)
            }
            try context.save()
        }
    }

    /// 删除某会话的所有凭据
    func deleteAll(sessionId: UUID) async throws {
        let context = PersistenceController.shared.newBackgroundContext()
        try await context.perform {
            let request = CDCredential.fetchRequest()
            request.predicate = NSPredicate(format: "sessionId == %@", sessionId as CVarArg)
            for obj in try context.fetch(request) {
                context.delete(obj)
            }
            try context.save()
        }
    }

    // MARK: - 旧版 Keychain 迁移

    /// 从旧版 KeychainService 迁移凭据（幂等，已迁移则跳过）
    func migrateFromLegacyKeychain(for sessions: [Session]) async {
        let migrationKey = "vault.migrationDone"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        for session in sessions {
            for type in [CredentialType.password, .privateKey, .passphrase] {
                guard let secret = try? KeychainService.shared.getPassword(
                    for: session.id,
                    type: type
                ) else { continue }

                do {
                    try await save(secret, sessionId: session.id, type: type)
                    try? KeychainService.shared.deletePassword(for: session.id, type: type)
                } catch {
                    // 迁移单条失败不中断整体流程
                }
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // MARK: - AES-256-GCM 加解密

    private func encrypt(_ data: Data) throws -> Data {
        let key = try masterKey()
        do {
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else {
                throw CredentialVaultError.encryptionFailed
            }
            return combined
        } catch is CredentialVaultError {
            throw CredentialVaultError.encryptionFailed
        } catch {
            throw CredentialVaultError.encryptionFailed
        }
    }

    private func decrypt(_ data: Data) throws -> Data {
        let key = try masterKey()
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw CredentialVaultError.decryptionFailed
        }
    }

    // MARK: - Master Key 管理

    /// 获取 Master Key（内存缓存 → Keychain 读取 → 首次自动生成）
    private func masterKey() throws -> SymmetricKey {
        if let cached = cachedMasterKey {
            return cached
        }

        // 尝试从 Keychain 读取
        if let keyData = readMasterKeyFromKeychain() {
            let key = SymmetricKey(data: keyData)
            cachedMasterKey = key
            return key
        }

        // 首次：生成新密钥并持久化
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try writeMasterKeyToKeychain(keyData)
        cachedMasterKey = newKey
        return newKey
    }

    private func readMasterKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: vaultService,
            kSecAttrAccount as String: masterKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func writeMasterKeyToKeychain(_ keyData: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: vaultService,
            kSecAttrAccount as String: masterKeyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: kCFBooleanFalse as CFBoolean,
            kSecAttrLabel as String: "ShellMate Credential Vault Key"
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialVaultError.masterKeyUnavailable
        }
    }
}

