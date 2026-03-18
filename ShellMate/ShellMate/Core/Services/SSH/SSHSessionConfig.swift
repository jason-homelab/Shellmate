import Foundation

/// SSH 会话配置
/// 包含建立 SSH 连接所需的所有配置信息
struct SSHSessionConfig {

    // MARK: - 基本连接信息

    /// 主机地址
    let host: String

    /// 端口号
    let port: Int32

    /// 用户名
    let username: String

    // MARK: - 认证信息

    /// 认证方式
    let authMethod: AuthMethod

    /// 密码（密码认证时使用）
    var password: String?

    /// 私钥数据（公钥认证时使用）
    var privateKeyData: Data?

    /// 私钥文件路径（公钥认证时使用）
    var privateKeyPath: String?

    /// 私钥密码
    var passphrase: String?

    // MARK: - 超时设置

    /// 连接超时时间（秒）
    var connectionTimeout: TimeInterval = 30

    /// 读写超时时间（秒）
    var readWriteTimeout: TimeInterval = 60

    // MARK: - 保活设置

    /// 保活间隔（秒），0 表示禁用
    var keepAliveInterval: Int = 60

    /// 最大保活无响应次数
    var keepAliveMaxCount: Int = 3

    // MARK: - 终端设置

    /// 终端类型
    var terminalType: String = "xterm-256color"

    /// 终端初始列数
    var terminalColumns: Int = 80

    /// 终端初始行数
    var terminalRows: Int = 24

    // MARK: - 算法设置

    /// 首选加密算法（nil 使用默认值）
    var preferredCiphers: String?

    /// 首选 MAC 算法（nil 使用默认值）
    var preferredMACs: String?

    /// 首选密钥交换算法（nil 使用默认值）
    var preferredKeyExchange: String?

    /// 首选主机密钥类型（nil 使用默认值）
    var preferredHostKeyTypes: String?

    // MARK: - 代理/跳板机设置

    /// 跳板机配置（用于 ProxyJump）
    var proxyJump: SSHSessionConfig?

    // MARK: - 其他设置

    /// 字符编码
    var encoding: String.Encoding = .utf8

    /// 是否启用压缩
    var compression: Bool = false

    /// 是否自动添加主机密钥
    var autoAddHostKey: Bool = false

    /// 是否验证主机密钥
    var verifyHostKey: Bool = true

    // MARK: - 初始化

    init(
        host: String,
        port: Int32 = 22,
        username: String,
        authMethod: AuthMethod = .password
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
    }

    // MARK: - 便捷初始化

    /// 从 Session 模型创建配置
    /// - Parameters:
    ///   - session: 会话模型
    ///   - password: 密码（从 Keychain 获取）
    ///   - privateKeyData: 私钥数据（从 Keychain 获取）
    ///   - passphrase: 私钥密码（从 Keychain 获取）
    static func from(
        session: Session,
        password: String? = nil,
        privateKeyData: Data? = nil,
        passphrase: String? = nil
    ) -> SSHSessionConfig {
        var config = SSHSessionConfig(
            host: session.host,
            port: session.port,
            username: session.username,
            authMethod: session.authMethod
        )

        config.password = password
        config.privateKeyData = privateKeyData
        config.privateKeyPath = session.privateKeyPath
        config.passphrase = passphrase
        config.keepAliveInterval = Int(session.keepAliveInterval)
        config.encoding = String.Encoding(rawValue: UInt(session.encoding.hashValue)) ?? .utf8

        return config
    }
}

// MARK: - 连接状态回调

/// SSH 连接状态委托
protocol SSHSessionDelegate: AnyObject {

    /// 连接状态变更
    func sshSession(_ session: SSHSessionWrapper, didChangeState state: ConnectionState)

    /// 需要验证主机密钥
    /// - Returns: true 接受密钥，false 拒绝
    func sshSession(_ session: SSHSessionWrapper, shouldAcceptHostKey fingerprint: HostKeyFingerprint) -> Bool

    /// 主机密钥已变更
    /// - Returns: true 接受新密钥，false 拒绝（强烈建议返回 false）
    func sshSession(_ session: SSHSessionWrapper, hostKeyChangedFrom oldFingerprint: String, to newFingerprint: HostKeyFingerprint) -> Bool

    /// 接收到数据
    func sshSession(_ session: SSHSessionWrapper, didReceiveData data: Data)

    /// 连接错误
    func sshSession(_ session: SSHSessionWrapper, didEncounterError error: SSHError)

    /// 连接关闭
    func sshSessionDidClose(_ session: SSHSessionWrapper)
}

// MARK: - 默认实现

extension SSHSessionDelegate {
    func sshSession(_ session: SSHSessionWrapper, didChangeState state: ConnectionState) {}
    func sshSession(_ session: SSHSessionWrapper, shouldAcceptHostKey fingerprint: HostKeyFingerprint) -> Bool { return false }
    func sshSession(_ session: SSHSessionWrapper, hostKeyChangedFrom oldFingerprint: String, to newFingerprint: HostKeyFingerprint) -> Bool { return false }
    func sshSession(_ session: SSHSessionWrapper, didReceiveData data: Data) {}
    func sshSession(_ session: SSHSessionWrapper, didEncounterError error: SSHError) {}
    func sshSessionDidClose(_ session: SSHSessionWrapper) {}
}

// MARK: - SSHSessionWrapper

/// SSH 会话包装器
/// 提供高级的 SSH 连接管理 API
final class SSHSessionWrapper {

    // MARK: - 属性

    /// 会话配置
    let config: SSHSessionConfig

    /// 底层桥接
    private let bridge: LibSSH2Bridge

    /// 当前连接状态
    private(set) var connectionState: ConnectionState = .offline

    /// 委托
    weak var delegate: SSHSessionDelegate?

    /// 会话 ID（用于标识）
    let sessionId: UUID

    // MARK: - 初始化

    init(config: SSHSessionConfig, sessionId: UUID = UUID()) {
        self.config = config
        self.sessionId = sessionId
        self.bridge = LibSSH2Bridge()
    }

    // MARK: - 连接方法

    /// 建立 SSH 连接
    /// - Throws: SSHError 如果连接失败
    func connect() async throws {
        // 更新状态
        updateState(.connecting)

        do {
            // 1. 初始化会话
            try bridge.sessionInit()

            // 2. 设置超时和阻塞模式
            bridge.setTimeout(Int(config.connectionTimeout * 1000))
            bridge.setBlocking(true) // 初始使用阻塞模式

            // 3. 应用安全算法配置
            try bridge.applySecureDefaults()

            // 应用自定义算法配置
            if let ciphers = config.preferredCiphers {
                try bridge.setPreferredCiphers(ciphers)
            }
            if let macs = config.preferredMACs {
                try bridge.setPreferredMACs(macs)
            }
            if let kex = config.preferredKeyExchange {
                try bridge.setPreferredKeyExchange(kex)
            }
            if let hostKeys = config.preferredHostKeyTypes {
                try bridge.setPreferredHostKeyTypes(hostKeys)
            }

            // 4. 建立 TCP 连接
            try bridge.tcpConnect(host: config.host, port: config.port)

            // 5. SSH 握手
            try bridge.handshake()

            // 6. 验证主机密钥
            if config.verifyHostKey {
                let fingerprint = try bridge.getHostKeyFingerprint()

                // TODO: 检查已知主机列表
                // 如果是新主机，询问用户是否接受
                if let delegate = delegate {
                    let accepted = delegate.sshSession(self, shouldAcceptHostKey: fingerprint)
                    if !accepted {
                        throw SSHError.hostKeyVerificationFailed(fingerprint: fingerprint.sha256Display)
                    }
                } else if !config.autoAddHostKey {
                    throw SSHError.hostKeyVerificationFailed(fingerprint: fingerprint.sha256Display)
                }
            }

            // 7. 认证
            try authenticate()

            // 8. 连接成功
            updateState(.connected)

        } catch let error as SSHError {
            updateState(.error)
            delegate?.sshSession(self, didEncounterError: error)
            throw error
        } catch {
            updateState(.error)
            let sshError = SSHError.unknown(underlying: error)
            delegate?.sshSession(self, didEncounterError: sshError)
            throw sshError
        }
    }

    /// 执行认证
    private func authenticate() throws {
        switch config.authMethod {
        case .password:
            guard let password = config.password else {
                throw SSHError.authenticationFailed(method: "password", reason: "密码未提供")
            }
            try bridge.authenticateWithPassword(username: config.username, password: password)

        case .privateKey:
            if let privateKeyData = config.privateKeyData {
                try bridge.authenticateWithPublicKeyFromMemory(
                    username: config.username,
                    publicKeyData: nil,
                    privateKeyData: privateKeyData,
                    passphrase: config.passphrase
                )
            } else if let privateKeyPath = config.privateKeyPath {
                try bridge.authenticateWithPublicKey(
                    username: config.username,
                    publicKeyPath: nil,
                    privateKeyPath: privateKeyPath,
                    passphrase: config.passphrase
                )
            } else {
                throw SSHError.invalidPrivateKey(reason: "未提供私钥")
            }

        case .sshAgent:
            try bridge.authenticateWithAgent(username: config.username)
        }
    }

    /// 断开连接
    func disconnect() {
        guard connectionState != .offline else { return }

        updateState(.disconnecting)
        bridge.disconnect(reason: "用户断开连接")
        updateState(.offline)
        delegate?.sshSessionDidClose(self)
    }

    // MARK: - 私有方法

    /// 更新连接状态
    private func updateState(_ state: ConnectionState) {
        connectionState = state
        delegate?.sshSession(self, didChangeState: state)
    }
}
