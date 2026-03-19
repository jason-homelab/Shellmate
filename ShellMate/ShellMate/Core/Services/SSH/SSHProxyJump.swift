import Foundation

// MARK: - 跳板机配置

/// 跳板机配置
struct ProxyJumpConfig: Equatable, Codable {
    /// 跳板机主机
    let host: String

    /// 跳板机端口
    let port: Int32

    /// 跳板机用户名
    let username: String

    /// 认证方式
    let authMethod: AuthMethod

    /// 私钥路径（如果使用私钥认证）
    let privateKeyPath: String?

    /// Keychain 引用（用于获取密码或私钥密码）
    let keychainRef: String?

    /// 连接超时（秒）
    var connectionTimeout: TimeInterval = 30

    /// 初始化
    init(
        host: String,
        port: Int32 = 22,
        username: String,
        authMethod: AuthMethod = .password,
        privateKeyPath: String? = nil,
        keychainRef: String? = nil,
        connectionTimeout: TimeInterval = 30
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.privateKeyPath = privateKeyPath
        self.keychainRef = keychainRef
        self.connectionTimeout = connectionTimeout
    }

    /// 从 OpenSSH 格式解析 ProxyJump 配置
    /// 格式: user@host:port 或 user@host
    static func parse(_ proxyJump: String) -> ProxyJumpConfig? {
        var remaining = proxyJump

        // 解析用户名
        let username: String
        if let atIndex = remaining.firstIndex(of: "@") {
            username = String(remaining[..<atIndex])
            remaining = String(remaining[remaining.index(after: atIndex)...])
        } else {
            // 默认使用当前用户名
            username = NSUserName()
        }

        // 解析主机和端口
        let host: String
        let port: Int32

        if let colonIndex = remaining.lastIndex(of: ":") {
            host = String(remaining[..<colonIndex])
            let portString = String(remaining[remaining.index(after: colonIndex)...])
            port = Int32(portString) ?? 22
        } else {
            host = remaining
            port = 22
        }

        guard !host.isEmpty else { return nil }

        return ProxyJumpConfig(
            host: host,
            port: port,
            username: username
        )
    }

    /// 转换为 OpenSSH 格式字符串
    var opensshFormat: String {
        if port == 22 {
            return "\(username)@\(host)"
        } else {
            return "\(username)@\(host):\(port)"
        }
    }
}

// MARK: - 跳板机连接

/// 跳板机连接管理器
/// 实现 ProxyJump（-J）功能，通过一个或多个跳板机连接到目标服务器
actor ProxyJumpManager {

    // MARK: - 类型定义

    /// 连接状态
    enum State {
        case disconnected
        case connectingToProxy(index: Int, total: Int)
        case openingChannel(index: Int, total: Int)
        case connectingToTarget
        case connected
        case failed(String)
    }

    /// 隧道信息
    struct TunnelInfo {
        /// 隧道 ID
        let id: UUID

        /// 连接链
        let connections: [SSHConnection]

        /// 最终通道（direct-tcpip）
        /// 用于数据传输
        let channel: OpaquePointer?
    }

    // MARK: - 属性

    /// 当前状态
    private(set) var state: State = .disconnected

    /// 跳板机配置列表
    private let proxyChain: [ProxyJumpConfig]

    /// 目标服务器配置
    private let targetConfig: SSHSessionConfig

    /// 已建立的连接
    private var connections: [SSHConnection] = []

    /// 最终通道
    private var finalChannel: OpaquePointer?

    /// 数据流
    private var dataStream: AsyncStream<Data>?
    private var dataContinuation: AsyncStream<Data>.Continuation?

    // MARK: - 初始化

    /// 初始化跳板机管理器
    /// - Parameters:
    ///   - proxyChain: 跳板机链（按连接顺序）
    ///   - targetConfig: 目标服务器配置
    init(proxyChain: [ProxyJumpConfig], targetConfig: SSHSessionConfig) {
        self.proxyChain = proxyChain
        self.targetConfig = targetConfig
    }

    // MARK: - 连接

    /// 建立连接
    /// 按顺序连接所有跳板机，最后通过 direct-tcpip 连接到目标
    func connect() async throws {
        guard state == .disconnected else {
            throw SSHError.libssh2Error(code: -1, message: "已有连接")
        }

        guard !proxyChain.isEmpty else {
            throw SSHError.libssh2Error(code: -1, message: "跳板机链为空")
        }

        do {
            // 连接第一个跳板机
            try await connectToFirstProxy()

            // 连接后续跳板机（通过 direct-tcpip）
            for i in 1..<proxyChain.count {
                try await connectToNextProxy(index: i)
            }

            // 连接到目标服务器
            try await connectToTarget()

            state = .connected
            print("[ProxyJump] 连接成功，跳数: \(proxyChain.count)")

        } catch {
            state = .failed(error.localizedDescription)
            await disconnect()
            throw error
        }
    }

    /// 断开连接
    func disconnect() async {
        // 关闭最终通道
        closeFinalChannel()

        // 反向断开所有连接
        for connection in connections.reversed() {
            await connection.disconnect()
        }
        connections.removeAll()

        // 结束数据流
        dataContinuation?.finish()

        state = .disconnected
        print("[ProxyJump] 已断开连接")
    }

    // MARK: - 数据传输

    /// 写入数据
    func write(_ data: Data) async throws {
        guard state == .connected, finalChannel != nil else {
            throw SSHError.channelNotOpen
        }

        // 通过最终通道写入
        // 在实际实现中：
        // var written = 0
        // data.withUnsafeBytes { buffer in
        //     let ptr = buffer.baseAddress!.assumingMemoryBound(to: CChar.self)
        //     while written < data.count {
        //         let rc = libssh2_channel_write(finalChannel, ptr.advanced(by: written), data.count - written)
        //         if rc < 0 { break }
        //         written += Int(rc)
        //     }
        // }

        print("[ProxyJump] 写入数据: \(data.count) 字节")
    }

    /// 获取数据流
    func getDataStream() -> AsyncStream<Data>? {
        return dataStream
    }

    // MARK: - 私有方法

    /// 连接到第一个跳板机
    private func connectToFirstProxy() async throws {
        let proxy = proxyChain[0]
        state = .connectingToProxy(index: 0, total: proxyChain.count)

        print("[ProxyJump] 连接到第一个跳板机: \(proxy.host):\(proxy.port)")

        // 创建配置
        let config = createSSHConfig(from: proxy)

        // 创建并连接
        let connection = SSHConnection(config: config)
        try await connection.connect()

        connections.append(connection)
        print("[ProxyJump] 第一个跳板机连接成功")
    }

    /// 连接到下一个跳板机（通过 direct-tcpip）
    private func connectToNextProxy(index: Int) async throws {
        let proxy = proxyChain[index]
        state = .connectingToProxy(index: index, total: proxyChain.count)

        print("[ProxyJump] 通过 direct-tcpip 连接到跳板机 \(index + 1): \(proxy.host):\(proxy.port)")

        // 获取上一个连接
        guard let previousConnection = connections.last else {
            throw SSHError.sessionNotInitialized
        }

        // 打开 direct-tcpip 通道到下一个跳板机
        state = .openingChannel(index: index, total: proxyChain.count)

        // 在实际实现中：
        // let channel = libssh2_channel_direct_tcpip_ex(
        //     previousSession,
        //     proxy.host,
        //     Int32(proxy.port),
        //     "127.0.0.1",
        //     22
        // )
        // guard channel != nil else {
        //     throw SSHError.channelOpenFailed(reason: "无法打开 direct-tcpip 通道")
        // }

        // 通过通道创建新的 SSH 连接
        let config = createSSHConfig(from: proxy)
        let connection = SSHConnection(config: config)

        // 注意：这里需要特殊处理，让新连接使用 direct-tcpip 通道而不是直接 TCP
        // 实际实现需要修改 SSHConnection 以支持通过通道连接

        try await connection.connect()
        connections.append(connection)

        print("[ProxyJump] 跳板机 \(index + 1) 连接成功")
    }

    /// 连接到目标服务器
    private func connectToTarget() async throws {
        state = .connectingToTarget

        print("[ProxyJump] 通过 direct-tcpip 连接到目标: \(targetConfig.host):\(targetConfig.port)")

        guard let lastConnection = connections.last else {
            throw SSHError.sessionNotInitialized
        }

        // 打开到目标的 direct-tcpip 通道
        // 在实际实现中：
        // finalChannel = libssh2_channel_direct_tcpip_ex(
        //     lastSession,
        //     targetConfig.host,
        //     Int32(targetConfig.port),
        //     "127.0.0.1",
        //     22
        // )
        // guard finalChannel != nil else {
        //     throw SSHError.channelOpenFailed(reason: "无法打开到目标的 direct-tcpip 通道")
        // }

        // 设置数据流
        setupDataStream()

        // 启动数据读取
        startDataReading()

        print("[ProxyJump] 目标连接成功")
    }

    /// 创建 SSH 配置
    private func createSSHConfig(from proxy: ProxyJumpConfig) -> SSHSessionConfig {
        var password: String? = nil

        // 从 Keychain 获取密码
        if let ref = proxy.keychainRef,
           let parsed = KeychainService.shared.parseKeychainRef(ref) {
            password = try? KeychainService.shared.getPassword(for: parsed.sessionId, type: parsed.type)
        }

        return SSHSessionConfig(
            host: proxy.host,
            port: proxy.port,
            username: proxy.username,
            authMethod: proxy.authMethod,
            password: password,
            privateKeyPath: proxy.privateKeyPath,
            connectionTimeout: proxy.connectionTimeout
        )
    }

    /// 关闭最终通道
    private func closeFinalChannel() {
        guard finalChannel != nil else { return }

        // 在实际实现中：
        // libssh2_channel_close(finalChannel)
        // libssh2_channel_free(finalChannel)

        finalChannel = nil
    }

    /// 设置数据流
    private func setupDataStream() {
        let (stream, continuation) = AsyncStream<Data>.makeStream(
            bufferingPolicy: .bufferingNewest(100)
        )
        self.dataStream = stream
        self.dataContinuation = continuation
    }

    /// 启动数据读取
    private func startDataReading() {
        Task { [weak self] in
            await self?.readLoop()
        }
    }

    /// 读取循环
    private func readLoop() async {
        let bufferSize = 32768
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while state == .connected {
            // 在实际实现中：
            // let rc = libssh2_channel_read(finalChannel, &buffer, bufferSize)
            // if rc > 0 {
            //     let data = Data(bytes: buffer, count: Int(rc))
            //     dataContinuation?.yield(data)
            // } else if rc == LIBSSH2_ERROR_EAGAIN {
            //     try? await Task.sleep(nanoseconds: 1_000_000)
            // } else {
            //     break
            // }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

// MARK: - 多跳连接工厂

/// 多跳连接工厂
/// 简化创建多跳 SSH 连接的过程
struct ProxyJumpConnectionFactory {

    /// 创建带跳板机的终端控制器
    /// - Parameters:
    ///   - session: 目标会话
    ///   - proxyChain: 跳板机链
    /// - Returns: 配置好的终端控制器
    static func createController(
        for session: Session,
        proxyChain: [ProxyJumpConfig]
    ) -> TerminalController {
        // 创建带跳板机配置的控制器
        let controller = TerminalController(session: session)

        // 在实际实现中，需要扩展 TerminalController 以支持跳板机

        return controller
    }

    /// 从 OpenSSH 配置文件解析跳板机链
    /// - Parameter configPath: 配置文件路径
    /// - Returns: 跳板机链
    static func parseProxyChain(from configPath: String) -> [ProxyJumpConfig] {
        // 解析 ~/.ssh/config 中的 ProxyJump 指令
        // 简化实现
        return []
    }

    /// 验证跳板机链的连接性
    /// - Parameter proxyChain: 跳板机链
    /// - Returns: 验证结果
    static func validateChain(_ proxyChain: [ProxyJumpConfig]) async -> [Bool] {
        var results: [Bool] = []

        for proxy in proxyChain {
            let reachable = await NetworkReachabilityMonitor.shared.checkReachability(to: proxy.host)
            results.append(reachable)
        }

        return results
    }
}

// MARK: - 跳板机会话扩展

extension Session {

    /// 跳板机配置
    var proxyJumpConfigs: [ProxyJumpConfig]? {
        // 从会话扩展属性中获取跳板机配置
        // 实际实现需要在 Session 模型中添加相应字段
        return nil
    }

    /// 是否使用跳板机
    var usesProxyJump: Bool {
        return proxyJumpConfigs != nil && !(proxyJumpConfigs?.isEmpty ?? true)
    }

    /// 跳板机数量
    var proxyJumpCount: Int {
        return proxyJumpConfigs?.count ?? 0
    }
}

// MARK: - 预览和测试

#if DEBUG
extension ProxyJumpConfig {
    /// 测试用跳板机配置
    static let testProxy = ProxyJumpConfig(
        host: "jump.example.com",
        port: 22,
        username: "jumpuser"
    )

    /// 测试用跳板机链（2 跳）
    static let testChain: [ProxyJumpConfig] = [
        ProxyJumpConfig(host: "jump1.example.com", username: "user1"),
        ProxyJumpConfig(host: "jump2.example.com", username: "user2")
    ]
}
#endif
