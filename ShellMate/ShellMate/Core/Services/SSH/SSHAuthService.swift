import Foundation

/// SSH 认证结果
enum SSHAuthResult {
    /// 认证成功
    case success

    /// 需要用户确认主机密钥
    case hostKeyConfirmationRequired(fingerprint: HostKeyFingerprint)

    /// 主机密钥已变更，需要用户确认
    case hostKeyChangedWarning(oldFingerprint: String, newFingerprint: HostKeyFingerprint)

    /// 认证失败
    case failure(SSHError)
}

/// SSH 认证委托
protocol SSHAuthServiceDelegate: AnyObject {

    /// 请求密码
    /// - Parameters:
    ///   - service: 认证服务
    ///   - username: 用户名
    ///   - host: 主机
    /// - Returns: 密码，nil 表示取消
    func authService(
        _ service: SSHAuthService,
        requestPasswordFor username: String,
        host: String
    ) async -> String?

    /// 请求私钥密码
    /// - Parameters:
    ///   - service: 认证服务
    ///   - keyPath: 私钥路径
    /// - Returns: 密码，nil 表示取消
    func authService(
        _ service: SSHAuthService,
        requestPassphraseFor keyPath: String
    ) async -> String?

    /// 请求确认主机密钥
    /// - Parameters:
    ///   - service: 认证服务
    ///   - host: 主机
    ///   - fingerprint: 指纹
    /// - Returns: true 接受，false 拒绝
    func authService(
        _ service: SSHAuthService,
        shouldAcceptHostKey fingerprint: HostKeyFingerprint,
        for host: String
    ) async -> Bool

    /// 请求确认主机密钥变更
    /// - Parameters:
    ///   - service: 认证服务
    ///   - host: 主机
    ///   - oldFingerprint: 旧指纹
    ///   - newFingerprint: 新指纹
    /// - Returns: true 接受新密钥，false 拒绝
    func authService(
        _ service: SSHAuthService,
        hostKeyChangedFor host: String,
        from oldFingerprint: String,
        to newFingerprint: HostKeyFingerprint
    ) async -> Bool
}

/// SSH 认证服务
/// 统一处理所有 SSH 认证流程
final class SSHAuthService {

    // MARK: - 单例

    static let shared = SSHAuthService()

    // MARK: - 属性

    /// 委托
    weak var delegate: SSHAuthServiceDelegate?

    /// Keychain 服务
    private let keychainService = KeychainService.shared

    /// Known Hosts 管理器
    private let knownHostsManager = KnownHostsManager.shared

    // MARK: - 初始化

    private init() {}

    // MARK: - 主机密钥验证

    /// 验证主机密钥
    /// - Parameters:
    ///   - host: 主机名
    ///   - port: 端口号
    ///   - fingerprint: 主机密钥指纹
    /// - Returns: 验证结果
    func verifyHostKey(
        host: String,
        port: Int32,
        fingerprint: HostKeyFingerprint
    ) async -> SSHAuthResult {
        let checkResult = knownHostsManager.check(
            host: host,
            port: port,
            fingerprint: fingerprint
        )

        switch checkResult {
        case .match:
            // 密钥匹配，继续
            return .success

        case .mismatch(let existingEntry):
            // 密钥变更，需要用户确认
            if let delegate = delegate {
                let accepted = await delegate.authService(
                    self,
                    hostKeyChangedFor: host,
                    from: existingEntry.fingerprint,
                    to: fingerprint
                )

                if accepted {
                    // 用户确认，更新密钥
                    try? knownHostsManager.add(
                        host: host,
                        port: port,
                        fingerprint: fingerprint,
                        comment: "用户确认更新"
                    )
                    return .success
                } else {
                    return .failure(SSHError.hostKeyChanged(
                        oldFingerprint: existingEntry.fingerprint,
                        newFingerprint: fingerprint
                    ))
                }
            }
            return .hostKeyChangedWarning(
                oldFingerprint: existingEntry.fingerprint,
                newFingerprint: fingerprint
            )

        case .notFound:
            // 新主机，需要用户确认
            if let delegate = delegate {
                let accepted = await delegate.authService(
                    self,
                    shouldAcceptHostKey: fingerprint,
                    for: host
                )

                if accepted {
                    // 用户确认，保存密钥
                    try? knownHostsManager.add(
                        host: host,
                        port: port,
                        fingerprint: fingerprint
                    )
                    return .success
                } else {
                    return .failure(SSHError.hostKeyVerificationFailed(
                        fingerprint: fingerprint.sha256Display
                    ))
                }
            }
            return .hostKeyConfirmationRequired(fingerprint: fingerprint)

        case .failure(let error):
            return .failure(SSHError.unknown(underlying: error))
        }
    }

    // MARK: - 认证方法

    /// 获取会话的认证凭据
    /// - Parameter session: 会话
    /// - Returns: 认证凭据
    func getCredentials(for session: Session) async throws -> AuthCredentials {
        switch session.authMethod {
        case .password:
            return try await getPasswordCredentials(for: session)

        case .privateKey:
            return try await getPrivateKeyCredentials(for: session)

        case .sshAgent:
            return .sshAgent
        }
    }

    /// 获取密码凭据
    private func getPasswordCredentials(for session: Session) async throws -> AuthCredentials {
        // 尝试从 Keychain 获取
        if let password = try? keychainService.getPassword(
            for: session.id,
            type: .password
        ) {
            return .password(password)
        }

        // 请求用户输入
        if let delegate = delegate {
            if let password = await delegate.authService(
                self,
                requestPasswordFor: session.username,
                host: session.host
            ) {
                return .password(password)
            }
        }

        throw SSHError.authenticationFailed(method: "password", reason: "未提供密码")
    }

    /// 获取私钥凭据
    private func getPrivateKeyCredentials(for session: Session) async throws -> AuthCredentials {
        // 获取私钥数据
        let privateKeyData: Data

        if let keyPath = session.privateKeyPath {
            // 从文件读取
            let keyURL = URL(fileURLWithPath: keyPath)
            privateKeyData = try Data(contentsOf: keyURL)
        } else if let keyData = try? keychainService.getPrivateKeyData(for: session.id) {
            // 从 Keychain 读取
            privateKeyData = keyData
        } else {
            throw SSHError.invalidPrivateKey(reason: "未找到私钥")
        }

        // 获取密码（如果需要）
        var passphrase: String? = nil

        // 检查私钥是否加密
        if isPrivateKeyEncrypted(privateKeyData) {
            // 尝试从 Keychain 获取
            passphrase = try? keychainService.getPassword(
                for: session.id,
                type: .passphrase
            )

            // 请求用户输入
            if passphrase == nil, let delegate = delegate {
                passphrase = await delegate.authService(
                    self,
                    requestPassphraseFor: session.privateKeyPath ?? "Keychain"
                )
            }
        }

        return .privateKey(data: privateKeyData, passphrase: passphrase)
    }

    /// 检查私钥是否加密
    private func isPrivateKeyEncrypted(_ data: Data) -> Bool {
        guard let content = String(data: data, encoding: .utf8) else {
            return false
        }

        // 检查 OpenSSH 格式
        if content.contains("ENCRYPTED") {
            return true
        }

        // 检查 PEM 格式
        if content.contains("Proc-Type: 4,ENCRYPTED") {
            return true
        }

        // 检查新版 OpenSSH 格式（bcrypt 加密）
        if content.contains("-----BEGIN OPENSSH PRIVATE KEY-----") {
            // 解码并检查加密标志
            // 简化处理：假设新格式默认可能加密
            return content.contains("aes") || content.contains("bcrypt")
        }

        return false
    }

    // MARK: - 凭据保存

    /// 保存密码到 Keychain
    func savePassword(_ password: String, for session: Session) throws {
        try keychainService.savePassword(password, for: session.id, type: .password)
    }

    /// 保存私钥到 Keychain
    func savePrivateKey(_ data: Data, for session: Session) throws {
        try keychainService.savePrivateKey(data, for: session.id)
    }

    /// 保存私钥密码到 Keychain
    func savePassphrase(_ passphrase: String, for session: Session) throws {
        try keychainService.savePassword(passphrase, for: session.id, type: .passphrase)
    }

    /// 删除会话的所有凭据
    func deleteCredentials(for session: Session) {
        keychainService.deleteAllCredentials(for: session.id)
    }
}

// MARK: - 认证凭据

/// 认证凭据
enum AuthCredentials {
    /// 密码认证
    case password(String)

    /// 私钥认证
    case privateKey(data: Data, passphrase: String?)

    /// SSH Agent 认证
    case sshAgent
}

// MARK: - SSH Agent 可用性检查

extension SSHAuthService {

    /// 检查 SSH Agent 是否可用
    var isSSHAgentAvailable: Bool {
        guard let socketPath = ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] else {
            return false
        }

        return FileManager.default.fileExists(atPath: socketPath)
    }

    /// 检查是否为 App Store 版本（禁用 SSH Agent）
    var isAppStoreVersion: Bool {
        // 检查是否在沙箱中运行
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return homeDir.contains("/Library/Containers/")
    }

    /// SSH Agent 是否在当前版本可用
    var canUseSSHAgent: Bool {
        // App Store 版本禁用 SSH Agent
        if isAppStoreVersion {
            return false
        }
        return isSSHAgentAvailable
    }
}

// MARK: - 算法配置

extension SSHAuthService {

    /// 安全算法配置
    struct SecureAlgorithms {
        /// 允许的加密算法
        static let ciphers = [
            "chacha20-poly1305@openssh.com",
            "aes256-gcm@openssh.com",
            "aes128-gcm@openssh.com",
            "aes256-ctr",
            "aes192-ctr",
            "aes128-ctr"
        ]

        /// 禁止的加密算法
        static let disabledCiphers = [
            "3des-cbc",
            "aes128-cbc",
            "aes192-cbc",
            "aes256-cbc",
            "blowfish-cbc",
            "cast128-cbc",
            "arcfour",
            "arcfour128",
            "arcfour256"
        ]

        /// 允许的 MAC 算法
        static let macs = [
            "hmac-sha2-512-etm@openssh.com",
            "hmac-sha2-256-etm@openssh.com",
            "umac-128-etm@openssh.com",
            "hmac-sha2-512",
            "hmac-sha2-256"
        ]

        /// 禁止的 MAC 算法
        static let disabledMACs = [
            "hmac-md5",
            "hmac-md5-96",
            "hmac-sha1",
            "hmac-sha1-96"
        ]

        /// 允许的密钥交换算法
        static let keyExchange = [
            "curve25519-sha256",
            "curve25519-sha256@libssh.org",
            "ecdh-sha2-nistp521",
            "ecdh-sha2-nistp384",
            "ecdh-sha2-nistp256",
            "diffie-hellman-group18-sha512",
            "diffie-hellman-group16-sha512",
            "diffie-hellman-group14-sha256"
        ]

        /// 允许的主机密钥类型
        static let hostKeyTypes = [
            "ssh-ed25519",
            "ecdsa-sha2-nistp521",
            "ecdsa-sha2-nistp384",
            "ecdsa-sha2-nistp256",
            "rsa-sha2-512",
            "rsa-sha2-256"
        ]

        /// 获取加密算法字符串
        static var ciphersString: String {
            ciphers.joined(separator: ",")
        }

        /// 获取 MAC 算法字符串
        static var macsString: String {
            macs.joined(separator: ",")
        }

        /// 获取密钥交换算法字符串
        static var keyExchangeString: String {
            keyExchange.joined(separator: ",")
        }

        /// 获取主机密钥类型字符串
        static var hostKeyTypesString: String {
            hostKeyTypes.joined(separator: ",")
        }
    }

    /// 验证算法是否安全
    func isAlgorithmSecure(_ algorithm: String, type: AlgorithmType) -> Bool {
        switch type {
        case .cipher:
            return SecureAlgorithms.ciphers.contains(algorithm)
                && !SecureAlgorithms.disabledCiphers.contains(algorithm)

        case .mac:
            return SecureAlgorithms.macs.contains(algorithm)
                && !SecureAlgorithms.disabledMACs.contains(algorithm)

        case .keyExchange:
            return SecureAlgorithms.keyExchange.contains(algorithm)

        case .hostKey:
            return SecureAlgorithms.hostKeyTypes.contains(algorithm)
        }
    }

    /// 算法类型
    enum AlgorithmType {
        case cipher
        case mac
        case keyExchange
        case hostKey
    }
}
