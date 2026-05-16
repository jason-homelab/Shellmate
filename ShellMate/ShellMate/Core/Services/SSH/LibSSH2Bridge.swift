import Foundation
import Darwin

// MARK: - libssh2 类型别名

/// libssh2 会话指针类型
typealias SSH2Session = OpaquePointer

/// libssh2 通道指针类型
typealias SSH2Channel = OpaquePointer

/// Socket 文件描述符类型
typealias SocketFD = Int32

// MARK: - libssh2 常量

/// libssh2 错误码
struct SSH2ErrorCode {
    static let none: Int32 = 0
    static let socketNone: Int32 = -1
    static let bannerRecv: Int32 = -2
    static let bannerSend: Int32 = -3
    static let invalidMAC: Int32 = -4
    static let kexFailure: Int32 = -5
    static let alloc: Int32 = -6
    static let socketSend: Int32 = -7
    static let keyExchangeFailure: Int32 = -8
    static let timeout: Int32 = -9
    static let hostKeyInit: Int32 = -10
    static let hostKeySign: Int32 = -11
    static let decrypt: Int32 = -12
    static let socketDisconnect: Int32 = -13
    static let proto: Int32 = -14
    static let passwordExpired: Int32 = -15
    static let file: Int32 = -16
    static let methodNone: Int32 = -17
    static let authenticationFailed: Int32 = -18
    static let publicKeyUnverified: Int32 = -19
    static let channelOutOfOrder: Int32 = -20
    static let channelFailure: Int32 = -21
    static let channelRequestDenied: Int32 = -22
    static let channelUnknown: Int32 = -23
    static let channelWindowExceeded: Int32 = -24
    static let channelPacketExceeded: Int32 = -25
    static let channelClosed: Int32 = -26
    static let channelEOFSent: Int32 = -27
    static let sftpProtocol: Int32 = -31
    static let requestDenied: Int32 = -32
    static let methodNotSupported: Int32 = -33
    static let inval: Int32 = -34
    static let invalidPollType: Int32 = -35
    static let publicKeyProtocol: Int32 = -36
    static let eagain: Int32 = -37
    static let bufferTooSmall: Int32 = -38
    static let badUse: Int32 = -39
    static let compress: Int32 = -40
    static let outOfBoundary: Int32 = -41
    static let agentProtocol: Int32 = -42
    static let socketRecv: Int32 = -43
    static let encrypt: Int32 = -44
    static let badSocket: Int32 = -45
    static let knownHosts: Int32 = -46
    static let channelWindowFull: Int32 = -47
    static let keyfileAuthFailed: Int32 = -48
}

/// libssh2 阻塞模式
struct SSH2BlockDirections {
    static let none: Int32 = 0
    static let inbound: Int32 = 1
    static let outbound: Int32 = 2
    static let both: Int32 = 3
}

/// 主机密钥类型
enum SSH2HostKeyType: Int32 {
    case unknown = 0
    case rsa1 = 1
    case sshRSA = 2
    case sshDSS = 3
    case ecdsaSHA2NISTP256 = 4
    case ecdsaSHA2NISTP384 = 5
    case ecdsaSHA2NISTP521 = 6
    case ed25519 = 7

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .rsa1: return "RSA1"
        case .sshRSA: return "RSA"
        case .sshDSS: return "DSS"
        case .ecdsaSHA2NISTP256: return "ECDSA-256"
        case .ecdsaSHA2NISTP384: return "ECDSA-384"
        case .ecdsaSHA2NISTP521: return "ECDSA-521"
        case .ed25519: return "Ed25519"
        }
    }
}

// MARK: - 主机密钥信息

/// 主机密钥指纹信息
struct HostKeyFingerprint: Equatable {
    /// 密钥类型
    let keyType: SSH2HostKeyType

    /// SHA256 指纹（Base64 编码）
    let sha256: String

    /// MD5 指纹（十六进制格式）
    let md5: String

    /// 原始密钥数据
    let rawKey: Data

    /// 格式化的 SHA256 指纹显示
    var sha256Display: String {
        "SHA256:\(sha256)"
    }

    /// 格式化的 MD5 指纹显示（冒号分隔）
    var md5Display: String {
        md5.enumerated().map { index, char in
            index > 0 && index % 2 == 0 ? ":\(char)" : String(char)
        }.joined()
    }
}

// MARK: - LibSSH2Bridge

/// libssh2 桥接层
/// 封装 libssh2 的底层 C 接口，提供 Swift 友好的 API
///
/// 注意：此类不是线程安全的，所有操作应在同一线程/队列中执行
final class LibSSH2Bridge {

    // MARK: - 静态属性

    /// 全局初始化状态
    private static var isGloballyInitialized = false

    /// 全局初始化锁
    private static let initializationLock = NSLock()

    // MARK: - 实例属性

    /// libssh2 会话指针
    private var session: SSH2Session?

    /// Socket 文件描述符
    private var socketFD: SocketFD = -1

    /// 是否处于非阻塞模式
    private(set) var isNonBlocking: Bool = false

    /// 会话是否已初始化
    var isSessionInitialized: Bool {
        session != nil
    }

    /// 是否已连接
    var isConnected: Bool {
        socketFD >= 0 && session != nil
    }

    /// 连接的主机地址
    private(set) var connectedHost: String?

    /// 连接的端口号
    private(set) var connectedPort: Int32?

    // MARK: - 初始化

    init() {
        Self.ensureGlobalInitialization()
    }

    deinit {
        disconnect()
    }

    // MARK: - 全局初始化

    /// 确保 libssh2 全局初始化（线程安全）
    private static func ensureGlobalInitialization() {
        initializationLock.lock()
        defer { initializationLock.unlock() }

        guard !isGloballyInitialized else { return }

        // 调用 libssh2_init(0) 初始化库
        // 在实际实现中，这里会调用真正的 libssh2_init
        // let result = libssh2_init(0)
        // guard result == 0 else {
        //     fatalError("Failed to initialize libssh2: \(result)")
        // }

        isGloballyInitialized = true
        AppLogger.ssh.debug("[LibSSH2Bridge] 全局初始化完成")
    }

    // MARK: - 会话初始化

    /// 初始化 SSH 会话
    /// - Throws: SSHError 如果初始化失败
    func sessionInit() throws {
        guard session == nil else {
            AppLogger.ssh.debug("[LibSSH2Bridge] 会话已存在，跳过初始化")
            return
        }

        // 在实际实现中，这里会调用 libssh2_session_init()
        // session = libssh2_session_init()
        // guard session != nil else {
        //     throw SSHError.libssh2Error(code: -1, message: "无法创建 SSH 会话")
        // }

        // 模拟会话创建（实际实现时替换为真正的 libssh2 调用）
        // 这里我们创建一个占位符来表示会话已初始化
        // session = createMockSession()

        AppLogger.ssh.debug("[LibSSH2Bridge] SSH 会话初始化完成")
    }

    /// 设置会话阻塞模式
    /// - Parameter blocking: true 为阻塞模式，false 为非阻塞模式
    func setBlocking(_ blocking: Bool) {
        guard session != nil else { return }

        // 在实际实现中：
        // libssh2_session_set_blocking(session, blocking ? 1 : 0)

        isNonBlocking = !blocking
        AppLogger.ssh.debug("[LibSSH2Bridge] 设置阻塞模式: \(blocking ? "阻塞" : "非阻塞")")
    }

    /// 设置会话超时时间
    /// - Parameter timeout: 超时时间（毫秒）
    func setTimeout(_ timeout: Int) {
        guard session != nil else { return }

        // 在实际实现中：
        // libssh2_session_set_timeout(session, timeout)

        AppLogger.ssh.debug("[LibSSH2Bridge] 设置超时时间: \(timeout)ms")
    }

    // MARK: - TCP 连接

    /// 建立 TCP 连接
    /// - Parameters:
    ///   - host: 主机地址
    ///   - port: 端口号
    /// - Throws: SSHError 如果连接失败
    func tcpConnect(host: String, port: Int32) throws {
        guard socketFD < 0 else {
            AppLogger.ssh.debug("[LibSSH2Bridge] TCP 已连接，跳过")
            return
        }

        // DNS 解析
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?
        let portString = String(port)

        let resolveResult = getaddrinfo(host, portString, &hints, &result)
        guard resolveResult == 0, let addrInfo = result else {
            throw SSHError.dnsResolutionFailed(host: host)
        }
        defer { freeaddrinfo(result) }

        // 创建 socket
        let fd = socket(addrInfo.pointee.ai_family, addrInfo.pointee.ai_socktype, addrInfo.pointee.ai_protocol)
        guard fd >= 0 else {
            throw SSHError.connectionFailed(host: host, port: port, underlying: nil)
        }

        // 连接
        let connectResult = connect(fd, addrInfo.pointee.ai_addr, addrInfo.pointee.ai_addrlen)
        guard connectResult == 0 else {
            close(fd)
            if errno == ECONNREFUSED {
                throw SSHError.connectionRefused(host: host, port: port)
            } else if errno == ENETUNREACH || errno == EHOSTUNREACH {
                throw SSHError.networkUnreachable
            } else if errno == ETIMEDOUT {
                throw SSHError.connectionTimeout(host: host, port: port)
            }
            throw SSHError.connectionFailed(host: host, port: port, underlying: nil)
        }

        socketFD = fd
        connectedHost = host
        connectedPort = port

        AppLogger.ssh.debug("[LibSSH2Bridge] TCP 连接成功: \(host):\(port)")
    }

    // MARK: - SSH 握手

    /// 执行 SSH 握手
    /// - Throws: SSHError 如果握手失败
    func handshake() throws {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        guard socketFD >= 0 else {
            throw SSHError.connectionFailed(host: connectedHost ?? "unknown", port: connectedPort ?? 22, underlying: nil)
        }

        // 在实际实现中：
        // var rc: Int32
        // repeat {
        //     rc = libssh2_session_handshake(session, socketFD)
        // } while rc == SSH2ErrorCode.eagain
        //
        // guard rc == 0 else {
        //     throw SSHError.handshakeFailed(reason: getLastErrorMessage())
        // }

        AppLogger.ssh.debug("[LibSSH2Bridge] SSH 握手完成")
    }

    /// 获取主机密钥指纹
    /// - Returns: 主机密钥指纹信息
    /// - Throws: SSHError 如果获取失败
    func getHostKeyFingerprint() throws -> HostKeyFingerprint {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        // 在实际实现中：
        // var keyLen: Int = 0
        // var keyType: Int32 = 0
        // guard let key = libssh2_session_hostkey(session, &keyLen, &keyType) else {
        //     throw SSHError.hostKeyVerificationFailed(fingerprint: "无法获取主机密钥")
        // }
        //
        // let keyData = Data(bytes: key, count: keyLen)
        // let sha256 = keyData.sha256().base64EncodedString()
        // let md5 = keyData.md5().hexEncodedString()

        // 模拟返回（实际实现时替换）
        return HostKeyFingerprint(
            keyType: .ed25519,
            sha256: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            md5: "00000000000000000000000000000000",
            rawKey: Data()
        )
    }

    // MARK: - 认证

    /// 获取支持的认证方法列表
    /// - Parameter username: 用户名
    /// - Returns: 认证方法列表（逗号分隔）
    func getUserAuthList(username: String) throws -> String {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        // 在实际实现中：
        // guard let authList = libssh2_userauth_list(session, username, UInt32(username.count)) else {
        //     return ""
        // }
        // return String(cString: authList)

        // 模拟返回
        return "publickey,password,keyboard-interactive"
    }

    /// 使用密码认证
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    /// - Throws: SSHError 如果认证失败
    func authenticateWithPassword(username: String, password: String) throws {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        // 在实际实现中：
        // var rc: Int32
        // repeat {
        //     rc = libssh2_userauth_password(session, username, password)
        // } while rc == SSH2ErrorCode.eagain
        //
        // guard rc == 0 else {
        //     if rc == SSH2ErrorCode.authenticationFailed {
        //         throw SSHError.invalidPassword
        //     }
        //     throw SSHError.authenticationFailed(method: "password", reason: getLastErrorMessage())
        // }

        AppLogger.ssh.debug("[LibSSH2Bridge] 密码认证成功: \(username)")
    }

    /// 使用公钥认证
    /// - Parameters:
    ///   - username: 用户名
    ///   - publicKeyPath: 公钥文件路径（可选）
    ///   - privateKeyPath: 私钥文件路径
    ///   - passphrase: 私钥密码（可选）
    /// - Throws: SSHError 如果认证失败
    func authenticateWithPublicKey(
        username: String,
        publicKeyPath: String?,
        privateKeyPath: String,
        passphrase: String?
    ) throws {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        // 检查私钥文件是否存在
        guard FileManager.default.fileExists(atPath: privateKeyPath) else {
            throw SSHError.invalidPrivateKey(reason: "私钥文件不存在: \(privateKeyPath)")
        }

        // 在实际实现中：
        // var rc: Int32
        // repeat {
        //     rc = libssh2_userauth_publickey_fromfile(
        //         session,
        //         username,
        //         publicKeyPath,
        //         privateKeyPath,
        //         passphrase
        //     )
        // } while rc == SSH2ErrorCode.eagain
        //
        // guard rc == 0 else {
        //     if rc == SSH2ErrorCode.keyfileAuthFailed {
        //         throw SSHError.invalidPassphrase
        //     }
        //     throw SSHError.authenticationFailed(method: "publickey", reason: getLastErrorMessage())
        // }

        AppLogger.ssh.debug("[LibSSH2Bridge] 公钥认证成功: \(username)")
    }

    /// 使用内存中的公钥认证
    /// - Parameters:
    ///   - username: 用户名
    ///   - publicKeyData: 公钥数据
    ///   - privateKeyData: 私钥数据
    ///   - passphrase: 私钥密码（可选）
    /// - Throws: SSHError 如果认证失败
    func authenticateWithPublicKeyFromMemory(
        username: String,
        publicKeyData: Data?,
        privateKeyData: Data,
        passphrase: String?
    ) throws {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        // 在实际实现中：
        // let rc = privateKeyData.withUnsafeBytes { privateKeyPtr in
        //     publicKeyData?.withUnsafeBytes { publicKeyPtr in
        //         libssh2_userauth_publickey_frommemory(
        //             session,
        //             username,
        //             username.count,
        //             publicKeyPtr?.baseAddress,
        //             publicKeyData?.count ?? 0,
        //             privateKeyPtr.baseAddress,
        //             privateKeyData.count,
        //             passphrase
        //         )
        //     } ?? libssh2_userauth_publickey_frommemory(
        //         session,
        //         username,
        //         username.count,
        //         nil,
        //         0,
        //         privateKeyPtr.baseAddress,
        //         privateKeyData.count,
        //         passphrase
        //     )
        // }
        //
        // guard rc == 0 else {
        //     throw SSHError.authenticationFailed(method: "publickey", reason: getLastErrorMessage())
        // }

        AppLogger.ssh.debug("[LibSSH2Bridge] 内存公钥认证成功: \(username)")
    }

    /// 使用 SSH Agent 认证
    /// - Parameter username: 用户名
    /// - Throws: SSHError 如果认证失败
    func authenticateWithAgent(username: String) throws {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        // 检查 SSH_AUTH_SOCK 环境变量
        guard let _ = ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] else {
            throw SSHError.agentNotAvailable
        }

        // 在实际实现中：
        // guard let agent = libssh2_agent_init(session) else {
        //     throw SSHError.agentNotAvailable
        // }
        // defer { libssh2_agent_free(agent) }
        //
        // guard libssh2_agent_connect(agent) == 0 else {
        //     throw SSHError.agentNotAvailable
        // }
        // defer { libssh2_agent_disconnect(agent) }
        //
        // guard libssh2_agent_list_identities(agent) == 0 else {
        //     throw SSHError.agentAuthFailed(reason: "无法列出 Agent 身份")
        // }
        //
        // var identity: OpaquePointer?
        // var prevIdentity: OpaquePointer?
        //
        // while libssh2_agent_get_identity(agent, &identity, prevIdentity) == 1 {
        //     if libssh2_agent_userauth(agent, username, identity) == 0 {
        //         return // 认证成功
        //     }
        //     prevIdentity = identity
        // }
        //
        // throw SSHError.agentAuthFailed(reason: "没有可用的身份")

        AppLogger.ssh.debug("[LibSSH2Bridge] SSH Agent 认证成功: \(username)")
    }

    // MARK: - 断开连接

    /// 断开 SSH 连接
    /// - Parameter reason: 断开原因描述（可选）
    func disconnect(reason: String = "正常断开") {
        // 关闭会话
        if session != nil {
            // 在实际实现中：
            // libssh2_session_disconnect(session, reason)
            // libssh2_session_free(session)
            self.session = nil
            AppLogger.ssh.debug("[LibSSH2Bridge] SSH 会话已关闭")
        }

        // 关闭 socket
        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
            AppLogger.ssh.debug("[LibSSH2Bridge] TCP 连接已关闭")
        }

        connectedHost = nil
        connectedPort = nil
    }

    // MARK: - 辅助方法

    /// 获取最后一次错误信息
    func getLastErrorMessage() -> String {
        guard session != nil else {
            return "会话未初始化"
        }

        // 在实际实现中：
        // var errorMsg: UnsafeMutablePointer<CChar>?
        // var errorMsgLen: Int32 = 0
        // libssh2_session_last_error(session, &errorMsg, &errorMsgLen, 0)
        // if let errorMsg = errorMsg {
        //     return String(cString: errorMsg)
        // }

        return "未知错误"
    }

    /// 获取阻塞方向（用于非阻塞模式的事件循环）
    func getBlockDirections() -> Int32 {
        guard session != nil else {
            return SSH2BlockDirections.none
        }

        // 在实际实现中：
        // return libssh2_session_block_directions(session)

        return SSH2BlockDirections.none
    }

    /// 获取 Socket 文件描述符
    func getSocketFD() -> SocketFD {
        return socketFD
    }
}

// MARK: - 扩展：算法配置

extension LibSSH2Bridge {

    /// 设置首选加密算法
    /// - Parameter algorithms: 算法列表（逗号分隔）
    func setPreferredCiphers(_ algorithms: String) throws {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        // 在实际实现中：
        // let rc = libssh2_session_method_pref(session, LIBSSH2_METHOD_CRYPT_CS, algorithms)
        // guard rc == 0 else {
        //     throw SSHError.algorithmNegotiationFailed(type: "cipher")
        // }
        // libssh2_session_method_pref(session, LIBSSH2_METHOD_CRYPT_SC, algorithms)

        AppLogger.ssh.debug("[LibSSH2Bridge] 设置加密算法: \(algorithms)")
    }

    /// 设置首选 MAC 算法
    /// - Parameter algorithms: 算法列表（逗号分隔）
    func setPreferredMACs(_ algorithms: String) throws {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        // 在实际实现中：
        // libssh2_session_method_pref(session, LIBSSH2_METHOD_MAC_CS, algorithms)
        // libssh2_session_method_pref(session, LIBSSH2_METHOD_MAC_SC, algorithms)

        AppLogger.ssh.debug("[LibSSH2Bridge] 设置 MAC 算法: \(algorithms)")
    }

    /// 设置首选密钥交换算法
    /// - Parameter algorithms: 算法列表（逗号分隔）
    func setPreferredKeyExchange(_ algorithms: String) throws {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        // 在实际实现中：
        // libssh2_session_method_pref(session, LIBSSH2_METHOD_KEX, algorithms)

        AppLogger.ssh.debug("[LibSSH2Bridge] 设置密钥交换算法: \(algorithms)")
    }

    /// 设置首选主机密钥类型
    /// - Parameter algorithms: 算法列表（逗号分隔）
    func setPreferredHostKeyTypes(_ algorithms: String) throws {
        guard session != nil else {
            throw SSHError.sessionNotInitialized
        }

        // 在实际实现中：
        // libssh2_session_method_pref(session, LIBSSH2_METHOD_HOSTKEY, algorithms)

        AppLogger.ssh.debug("[LibSSH2Bridge] 设置主机密钥类型: \(algorithms)")
    }

    /// 获取安全的默认算法配置
    static var secureAlgorithmDefaults: (ciphers: String, macs: String, keyExchange: String, hostKeys: String) {
        return (
            ciphers: "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr",
            macs: "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256",
            keyExchange: "curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group18-sha512,diffie-hellman-group16-sha512",
            hostKeys: "ssh-ed25519,ecdsa-sha2-nistp521,ecdsa-sha2-nistp384,ecdsa-sha2-nistp256,rsa-sha2-512,rsa-sha2-256"
        )
    }

    /// 应用安全的默认算法配置
    func applySecureDefaults() throws {
        let defaults = Self.secureAlgorithmDefaults
        try setPreferredCiphers(defaults.ciphers)
        try setPreferredMACs(defaults.macs)
        try setPreferredKeyExchange(defaults.keyExchange)
        try setPreferredHostKeyTypes(defaults.hostKeys)
    }
}
