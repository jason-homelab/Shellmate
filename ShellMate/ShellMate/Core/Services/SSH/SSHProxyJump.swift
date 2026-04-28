import Foundation
import Darwin

/// 用于在 @Sendable 闭包中安全传递 OpaquePointer 的包装类型
private struct SendableOpaquePointer: @unchecked Sendable {
    let value: OpaquePointer
}

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

    /// 凭据金库中的 Session/JumpHost ID（用于异步预取密码）
    let vaultId: UUID?

    /// 连接超时（秒）
    var connectionTimeout: TimeInterval = 30

    /// 预加载的密码（由 TerminalController 在异步阶段填入，同步连接阶段直接使用）
    var resolvedPassword: String?

    /// 初始化
    init(
        host: String,
        port: Int32 = 22,
        username: String,
        authMethod: AuthMethod = .password,
        privateKeyPath: String? = nil,
        vaultId: UUID? = nil,
        connectionTimeout: TimeInterval = 30
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.privateKeyPath = privateKeyPath
        self.vaultId = vaultId
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
/// 技术路径：libssh2 direct-tcpip 通道 + socketpair 桥接线程
actor ProxyJumpManager {

    // MARK: - 类型定义

    enum State: Equatable {
        case disconnected
        case connectingToProxy(index: Int, total: Int)
        case openingChannel(index: Int, total: Int)
        case connectingToTarget
        case connected
        case failed(String)
    }

    // MARK: - 属性

    private(set) var state: State = .disconnected
    private let proxyChain: [ProxyJumpConfig]
    private let targetConfig: SSHSessionConfig

    /// 每一跳的 SSH 桥接（hopBridges[0] = 第一个跳板机 ...）
    private var hopBridges: [LibSSH2BridgeReal] = []

    /// 每两跳之间的 socketpair：[bridgeSide fd, sessionSide fd]
    private var socketPairs: [[Int32]] = []

    /// 目标服务器的 SSH 桥接与 Shell 通道
    private var targetBridge: LibSSH2BridgeReal?
    private var targetShellChannel: OpaquePointer?

    /// 目标读取 Task（用于取消）
    private var readTask: Task<Void, Never>?

    /// 数据流（向 SwiftTerm 输送终端数据）
    private var dataStream: AsyncStream<Data>?
    private var dataContinuation: AsyncStream<Data>.Continuation?

    // MARK: - 初始化

    init(proxyChain: [ProxyJumpConfig], targetConfig: SSHSessionConfig) {
        self.proxyChain = proxyChain
        self.targetConfig = targetConfig
    }

    // MARK: - 连接

    /// 最大允许的跳板机跳数（超出则拒绝连接，防止无限递归或配置错误）
    static let maxHops: Int = 10

    func connect() async throws {
        guard state == .disconnected else {
            throw SSHError.libssh2Error(code: -1, message: "已有连接")
        }
        guard !proxyChain.isEmpty else {
            throw SSHError.libssh2Error(code: -1, message: "跳板机链为空")
        }
        guard proxyChain.count <= Self.maxHops else {
            throw SSHError.libssh2Error(
                code: -1,
                message: "跳板机链过长（\(proxyChain.count) 跳），最多允许 \(Self.maxHops) 跳"
            )
        }

        do {
            // ── 步骤 1：直接 TCP 连接第一个跳板机 ──────────────────────────
            state = .connectingToProxy(index: 0, total: proxyChain.count)
            let bridge0 = LibSSH2BridgeReal()
            try bridge0.sessionInit()
            bridge0.setTimeout(30_000)
            let p0 = proxyChain[0]
            try bridge0.tcpConnect(host: p0.host, port: p0.port)
            try bridge0.handshake()
            try authenticateProxy(bridge: bridge0, config: p0)
            hopBridges.append(bridge0)
            AppLogger.ssh.debug("[ProxyJump] 跳板机 0 (\(p0.host):\(p0.port)) 认证成功")

            // ── 步骤 2：通过 direct-tcpip 链接后续跳板机（多跳）────────────
            for i in 1..<proxyChain.count {
                let pCurrent = proxyChain[i]
                let prevBridge = hopBridges[i - 1]
                state = .openingChannel(index: i - 1, total: proxyChain.count)

                guard let ch = prevBridge.openDirectTCPIPChannel(
                    host: pCurrent.host, port: pCurrent.port,
                    sourceHost: "127.0.0.1", sourcePort: 0
                ) else {
                    throw SSHError.channelOpenFailed(
                        reason: "无法打开到跳板机 \(i) (\(pCurrent.host):\(pCurrent.port)) 的直连通道"
                    )
                }

                // 建立 socketpair 并在后台线程桥接通道 I/O
                let pairFDs = try makeSocketPairBridge(channel: ch, bridge: prevBridge)
                socketPairs.append(pairFDs)

                // 在 socketpair 会话侧建立新 SSH 会话
                state = .connectingToProxy(index: i, total: proxyChain.count)
                let newBridge = LibSSH2BridgeReal()
                try newBridge.sessionInit()
                newBridge.setTimeout(30_000)
                try newBridge.handshakeOnFD(pairFDs[1])
                try authenticateProxy(bridge: newBridge, config: pCurrent)
                hopBridges.append(newBridge)
                AppLogger.ssh.debug("[ProxyJump] 跳板机 \(i) (\(pCurrent.host):\(pCurrent.port)) 认证成功")
            }

            // ── 步骤 3：direct-tcpip 通道连接目标 ────────────────────────────
            state = .connectingToTarget
            let lastBridge = hopBridges.last!

            guard let targetChannel = lastBridge.openDirectTCPIPChannel(
                host: targetConfig.host, port: targetConfig.port,
                sourceHost: "127.0.0.1", sourcePort: 0
            ) else {
                throw SSHError.channelOpenFailed(
                    reason: "无法打开到目标 \(targetConfig.host):\(targetConfig.port) 的直连通道"
                )
            }

            let targetPairFDs = try makeSocketPairBridge(channel: targetChannel, bridge: lastBridge)
            socketPairs.append(targetPairFDs)

            // 在目标通道上建立完整 SSH 会话 + Shell
            let tBridge = LibSSH2BridgeReal()
            try tBridge.sessionInit()
            tBridge.setTimeout(30_000)
            try tBridge.handshakeOnFD(targetPairFDs[1])
            try authenticateTarget(bridge: tBridge)

            let shellCh = try tBridge.openShellChannel()
            try tBridge.requestPTY(
                channel: shellCh,
                term: targetConfig.terminalType,
                cols: targetConfig.terminalColumns,
                rows: targetConfig.terminalRows
            )
            try tBridge.startShell(channel: shellCh)
            tBridge.setBlocking(false)

            targetBridge = tBridge
            targetShellChannel = shellCh
            setupDataStream()
            startReadTask()

            state = .connected
            AppLogger.ssh.debug("[ProxyJump] 连接成功，跳数: \(self.proxyChain.count)")

        } catch {
            state = .failed(error.localizedDescription)
            await disconnect()
            throw error
        }
    }

    // MARK: - 断开

    func disconnect() async {
        readTask?.cancel()
        readTask = nil

        if let ch = targetShellChannel, let bridge = targetBridge {
            bridge.closeChannel(channel: ch)
        }
        targetShellChannel = nil
        targetBridge = nil

        // 关闭 socketpair 两侧 fd（桥接线程因 fd 关闭而自然退出）
        for pair in socketPairs {
            Darwin.close(pair[0])
            Darwin.close(pair[1])
        }
        socketPairs.removeAll()

        for bridge in hopBridges.reversed() {
            bridge.disconnect()
        }
        hopBridges.removeAll()

        dataContinuation?.finish()
        dataContinuation = nil
        dataStream = nil

        state = .disconnected
        AppLogger.ssh.debug("[ProxyJump] 已断开连接")
    }

    // MARK: - 数据传输

    func write(_ data: Data) async throws {
        guard state == .connected,
              let ch = targetShellChannel,
              let bridge = targetBridge else {
            throw SSHError.channelNotOpen
        }
        let localBridge = bridge
        let localChannel = ch
        try await Task.detached(priority: .userInitiated) {
            try data.withUnsafeBytes { rawBuf in
                guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                var sent = 0
                while sent < data.count {
                    let rc = localBridge.writeChannel(
                        channel: localChannel,
                        data: ptr.advanced(by: sent),
                        length: data.count - sent
                    )
                    if rc > 0 {
                        sent += rc
                    } else if rc == -37 { // LIBSSH2_ERROR_EAGAIN
                        usleep(1_000)
                    } else {
                        throw SSHError.writeFailed(reason: localBridge.getLastErrorMessage())
                    }
                }
            }
        }.value
    }

    func getDataStream() -> AsyncStream<Data>? {
        return dataStream
    }

    func resizeTerminal(cols: Int, rows: Int) {
        guard let ch = targetShellChannel, let bridge = targetBridge else { return }
        bridge.resizePTY(channel: ch, cols: cols, rows: rows)
    }

    // MARK: - 私有：socketpair 桥接

    /// 创建 socketpair 并启动后台桥接线程，双向转发 direct-tcpip 通道 I/O
    /// - Returns: [bridgeSide fd, sessionSide fd]
    private func makeSocketPairBridge(
        channel: OpaquePointer,
        bridge: LibSSH2BridgeReal
    ) throws -> [Int32] {
        var fds = [Int32](repeating: -1, count: 2)
        let result = fds.withUnsafeMutableBufferPointer { ptr in
            Darwin.socketpair(AF_UNIX, SOCK_STREAM, 0, ptr.baseAddress)
        }
        guard result == 0 else {
            throw SSHError.connectionFailed(host: "socketpair", port: 0, underlying: nil)
        }

        let capturedBridge = bridge
        let capturedChannel = SendableOpaquePointer(value: channel)
        let bridgeFD = fds[0]
        Thread.detachNewThread {
            Self.channelSocketBridgeLoop(
                channel: capturedChannel.value,
                bridge: capturedBridge,
                socketFD: bridgeFD
            )
        }
        return fds
    }

    /// 后台线程：在 direct-tcpip 通道和 socketpair 之间双向转发数据
    private static func channelSocketBridgeLoop(
        channel: OpaquePointer,
        bridge: LibSSH2BridgeReal,
        socketFD: Int32
    ) {
        var channelBuf = [UInt8](repeating: 0, count: 32_768)
        var socketBuf = [UInt8](repeating: 0, count: 32_768)

        while true {
            var didWork = false

            // 方向 1：channel → socketFD
            let n = bridge.readChannel(channel: channel, buffer: &channelBuf, bufferSize: channelBuf.count)
            if n > 0 {
                channelBuf.withUnsafeBytes { rawPtr in
                    _ = Darwin.send(socketFD, rawPtr.baseAddress!, n, 0)
                }
                didWork = true
            } else if n != -37 && n < 0 {
                break // 非 EAGAIN 的真实错误，退出
            }

            // 方向 2：socketFD → channel（非阻塞 poll）
            var pfd = pollfd(fd: socketFD, events: Int16(POLLIN), revents: 0)
            if Darwin.poll(&pfd, 1, 0) > 0 && (pfd.revents & Int16(POLLIN)) != 0 {
                let m = Darwin.recv(socketFD, &socketBuf, socketBuf.count, 0)
                if m > 0 {
                    socketBuf.withUnsafeBytes { rawPtr in
                        _ = bridge.writeChannel(
                            channel: channel,
                            data: rawPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                            length: m
                        )
                    }
                    didWork = true
                } else if m == 0 {
                    break // socketFD 对端已关闭
                }
            }

            if !didWork {
                usleep(500) // 0.5ms 空转防止 CPU 满载
            }
        }
    }

    // MARK: - 私有：认证

    private func authenticateProxy(bridge: LibSSH2BridgeReal, config: ProxyJumpConfig) throws {
        let password = config.resolvedPassword

        switch config.authMethod {
        case .password, .keyboardInteractive:
            guard let pwd = password else {
                throw SSHError.authenticationFailed(method: "password", reason: "跳板机 \(config.host) 密码未提供")
            }
            try bridge.authenticateWithPassword(username: config.username, password: pwd)

        case .privateKey:
            guard let keyPath = config.privateKeyPath, !keyPath.isEmpty else {
                throw SSHError.invalidPrivateKey(reason: "跳板机 \(config.host) 私钥路径未提供")
            }
            try bridge.authenticateWithPublicKey(
                username: config.username,
                publicKeyPath: nil,
                privateKeyPath: keyPath,
                passphrase: password
            )

        case .sshAgent:
            try bridge.authenticateWithAgent(username: config.username)
        }
    }

    private func authenticateTarget(bridge: LibSSH2BridgeReal) throws {
        switch targetConfig.authMethod {
        case .password, .keyboardInteractive:
            guard let pwd = targetConfig.password else {
                throw SSHError.authenticationFailed(method: "password", reason: "目标服务器密码未提供")
            }
            try bridge.authenticateWithPassword(username: targetConfig.username, password: pwd)

        case .privateKey:
            guard let keyPath = targetConfig.privateKeyPath, !keyPath.isEmpty else {
                throw SSHError.invalidPrivateKey(reason: "目标私钥路径未提供")
            }
            try bridge.authenticateWithPublicKey(
                username: targetConfig.username,
                publicKeyPath: nil,
                privateKeyPath: keyPath,
                passphrase: targetConfig.passphrase
            )

        case .sshAgent:
            try bridge.authenticateWithAgent(username: targetConfig.username)
        }
    }

    // MARK: - 私有：数据流与读取

    private func setupDataStream() {
        let (stream, continuation) = AsyncStream<Data>.makeStream(
            bufferingPolicy: .bufferingNewest(200)
        )
        self.dataStream = stream
        self.dataContinuation = continuation
    }

    private func startReadTask() {
        let capturedBridge = targetBridge!
        let capturedChannel = targetShellChannel!
        let capturedContinuation = dataContinuation!

        readTask = Task.detached(priority: .userInitiated) {
            var buffer = [UInt8](repeating: 0, count: 4_096)

            while !Task.isCancelled {
                let n = capturedBridge.readChannel(
                    channel: capturedChannel,
                    buffer: &buffer,
                    bufferSize: buffer.count
                )
                if n > 0 {
                    let data = Data(bytes: buffer, count: n)
                    capturedContinuation.yield(data)
                } else if n == -37 { // LIBSSH2_ERROR_EAGAIN
                    usleep(5_000) // 5ms
                } else if n == 0 {
                    break // EOF
                } else {
                    break // 读取错误
                }
            }

            capturedContinuation.finish()
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
    @MainActor
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
