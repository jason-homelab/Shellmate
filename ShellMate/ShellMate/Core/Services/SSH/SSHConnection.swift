import Foundation

/// SSH 通道类型
enum SSHChannelType {
    /// Shell 通道
    case shell
    /// 执行命令通道
    case exec(command: String)
    /// 子系统通道（如 SFTP）
    case subsystem(name: String)
    /// 直接 TCP 转发
    case directTCPIP(host: String, port: Int32)
}

/// SSH 连接 Actor
/// 使用 Swift Actor 隔离所有 SSH 操作，确保线程安全
actor SSHConnection {

    // MARK: - 类型定义

    /// 连接状态
    enum State: Equatable {
        case disconnected
        case connecting
        case authenticating
        case connected
        case disconnecting
        case failed(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected),
                 (.connecting, .connecting),
                 (.authenticating, .authenticating),
                 (.connected, .connected),
                 (.disconnecting, .disconnecting):
                return true
            case (.failed(let l), .failed(let r)):
                return l == r
            default:
                return false
            }
        }
    }

    /// 数据流
    struct DataStream: AsyncSequence {
        typealias Element = Data

        let connection: SSHConnection

        struct AsyncIterator: AsyncIteratorProtocol {
            let connection: SSHConnection

            mutating func next() async -> Data? {
                await connection.receiveData()
            }
        }

        func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator(connection: connection)
        }
    }

    // MARK: - 属性

    /// 会话配置
    private let config: SSHSessionConfig

    /// libssh2 桥接
    private var bridge: LibSSH2Bridge?

    /// 非阻塞 IO 管理器
    private var nonBlockingIO: SSHNonBlockingIO?

    /// 当前状态
    private(set) var state: State = .disconnected

    /// 当前通道指针（模拟）
    private var channel: OpaquePointer?

    /// 终端尺寸
    private var terminalSize: (columns: Int, rows: Int)

    /// 数据接收 continuation
    private var dataContinuation: AsyncStream<Data>.Continuation?

    /// 数据流
    private var dataStream: AsyncStream<Data>?

    /// 数据流迭代器（用于 receiveData() 串行消费）
    private var dataStreamIterator: AsyncStream<Data>.AsyncIterator?

    /// 连接 ID
    let connectionId: UUID

    // MARK: - 初始化

    init(config: SSHSessionConfig, connectionId: UUID = UUID()) {
        self.config = config
        self.connectionId = connectionId
        self.terminalSize = (config.terminalColumns, config.terminalRows)
    }

    // MARK: - 连接管理

    /// 建立连接
    func connect() async throws {
        // 使用 pattern matching 而非 == .failed("")（后者要求消息精确匹配空字符串，实际失败消息不为空）
        guard state == .disconnected || { if case .failed = state { return true }; return false }() else {
            throw SSHError.libssh2Error(code: -1, message: "连接已存在或正在连接")
        }

        state = .connecting

        do {
            // 创建桥接
            let bridge = LibSSH2Bridge()
            self.bridge = bridge

            // 初始化会话
            try bridge.sessionInit()

            // 设置超时
            bridge.setTimeout(Int(config.connectionTimeout * 1000))

            // 应用安全配置
            try bridge.applySecureDefaults()

            // TCP 连接
            try bridge.tcpConnect(host: config.host, port: config.port)

            // SSH 握手
            try bridge.handshake()

            // 验证主机密钥
            if config.verifyHostKey {
                try await verifyHostKey()
            }

            // 认证
            state = .authenticating
            try await authenticate()

            // 创建非阻塞 IO
            let io = SSHNonBlockingIO(bridge: bridge)
            io.setTimeout(config.readWriteTimeout)
            io.setKeepAliveInterval(TimeInterval(config.keepAliveInterval))
            self.nonBlockingIO = io

            // 设置数据流
            setupDataStream()

            state = .connected
            AppLogger.ssh.debug("[SSHConnection] 连接成功: \(self.config.host):\(self.config.port)")

        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    /// 断开连接
    func disconnect() async {
        guard state == .connected else { return }

        state = .disconnecting

        // 关闭通道
        closeChannel()

        // 停止非阻塞 IO
        nonBlockingIO?.stop()
        nonBlockingIO = nil

        // 断开 SSH
        bridge?.disconnect(reason: "用户断开连接")
        bridge = nil

        // 结束数据流，并释放 AsyncStream 缓冲区（防止重连后旧流缓冲区残留）
        dataContinuation?.finish()
        dataContinuation = nil
        dataStreamIterator = nil
        dataStream = nil

        state = .disconnected
        AppLogger.ssh.debug("[SSHConnection] 已断开连接")
    }

    // MARK: - 通道管理

    /// 打开 Shell 通道
    func openShell() async throws {
        guard state == .connected else {
            throw SSHError.sessionNotInitialized
        }

        // 在实际实现中：
        // channel = libssh2_channel_open_session(session)
        // guard channel != nil else {
        //     throw SSHError.channelOpenFailed(reason: bridge?.getLastErrorMessage() ?? "未知错误")
        // }
        //
        // // 请求 PTY
        // let rc = libssh2_channel_request_pty_ex(
        //     channel,
        //     config.terminalType,
        //     config.terminalType.count,
        //     nil, 0,
        //     terminalSize.columns,
        //     terminalSize.rows,
        //     0, 0
        // )
        // guard rc == 0 else {
        //     throw SSHError.ptyRequestFailed(reason: bridge?.getLastErrorMessage() ?? "未知错误")
        // }
        //
        // // 启动 Shell
        // let shellRc = libssh2_channel_shell(channel)
        // guard shellRc == 0 else {
        //     throw SSHError.shellStartFailed(reason: bridge?.getLastErrorMessage() ?? "未知错误")
        // }

        // 启动非阻塞 IO
        nonBlockingIO?.start()

        AppLogger.ssh.debug("[SSHConnection] Shell 通道已打开")
    }

    /// 打开执行命令通道
    /// - Parameter command: 要执行的命令
    func openExec(command: String) async throws {
        guard state == .connected else {
            throw SSHError.sessionNotInitialized
        }

        // 在实际实现中：
        // channel = libssh2_channel_open_session(session)
        // guard channel != nil else {
        //     throw SSHError.channelOpenFailed(reason: bridge?.getLastErrorMessage() ?? "未知错误")
        // }
        //
        // let rc = libssh2_channel_exec(channel, command)
        // guard rc == 0 else {
        //     throw SSHError.shellStartFailed(reason: "命令执行失败")
        // }

        nonBlockingIO?.start()
        AppLogger.ssh.debug("[SSHConnection] Exec 通道已打开: \(command)")
    }

    /// 关闭通道
    private func closeChannel() {
        guard channel != nil else { return }

        // 在实际实现中：
        // libssh2_channel_close(channel)
        // libssh2_channel_free(channel)

        channel = nil
        AppLogger.ssh.debug("[SSHConnection] 通道已关闭")
    }

    // MARK: - 数据读写

    /// 写入数据
    /// - Parameter data: 要发送的数据
    func write(_ data: Data) async throws {
        guard state == .connected else {
            throw SSHError.sessionClosed
        }

        nonBlockingIO?.write(data)
    }

    /// 写入字符串
    /// - Parameter string: 要发送的字符串
    func write(_ string: String) async throws {
        guard let data = string.data(using: .utf8) else {
            throw SSHError.libssh2Error(code: -1, message: "字符串编码失败")
        }
        try await write(data)
    }

    /// 获取数据流
    func getDataStream() -> DataStream {
        return DataStream(connection: self)
    }

    /// 接收数据（内部使用）
    fileprivate func receiveData() async -> Data? {
        guard state == .connected else { return nil }
        // 必须先拷贝到本地变量再调用 mutating async next()，
        // 避免 Swift actor 对 "actor-isolated property 上调用 mutating async" 的限制
        guard var iter = dataStreamIterator else { return nil }
        let data = await iter.next()
        dataStreamIterator = iter
        return data
    }

    /// 设置数据流
    private func setupDataStream() {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        self.dataStream = stream
        self.dataStreamIterator = stream.makeAsyncIterator()
        self.dataContinuation = continuation

        // 设置非阻塞 IO 的数据回调
        // 外层闭包持有 weak self；内层 Task 同样捕获 [weak self]，避免在 actor 释放后继续持有强引用
        nonBlockingIO?.onDataReceived = { [weak self] data in
            guard let self else { return }
            Task { [weak self] in await self?.dataContinuation?.yield(data) }
        }

        nonBlockingIO?.onError = { [weak self] error in
            guard let self else { return }
            AppLogger.ssh.debug("[SSHConnection] 错误: \(error.localizedDescription)")
            Task { [weak self] in
                await self?.handleError(error)
            }
        }

        nonBlockingIO?.onClose = { [weak self] in
            guard let self else { return }
            Task { [weak self] in
                await self?.disconnect()
            }
        }

        nonBlockingIO?.onKeepAliveRequired = { [weak self] in
            guard let self else { return }
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.sendKeepAlive()
                } catch {
                    // keepAlive 失败：触发错误状态，让 UI 感知到连接已中断
                    await self.handleError(SSHError.libssh2Error(code: -1, message: "保活失败，连接可能已中断"))
                }
            }
        }
    }

    // MARK: - 终端控制

    /// 调整终端尺寸
    /// - Parameters:
    ///   - columns: 列数
    ///   - rows: 行数
    func resizePTY(columns: Int, rows: Int) async throws {
        guard state == .connected, channel != nil else {
            throw SSHError.sessionClosed
        }

        // 在实际实现中：
        // let rc = libssh2_channel_request_pty_size_ex(
        //     channel,
        //     columns,
        //     rows,
        //     0, 0
        // )
        // guard rc == 0 else {
        //     throw SSHError.libssh2Error(code: rc, message: "调整终端尺寸失败")
        // }

        terminalSize = (columns, rows)
        AppLogger.ssh.debug("[SSHConnection] 终端尺寸已调整: \(columns)x\(rows)")
    }

    /// 获取当前终端尺寸
    func getTerminalSize() -> (columns: Int, rows: Int) {
        return terminalSize
    }

    // MARK: - 信号发送

    /// 发送信号
    /// - Parameter signal: 信号名称（如 "INT", "TERM", "KILL"）
    func sendSignal(_ signal: String) async throws {
        guard state == .connected, channel != nil else {
            throw SSHError.sessionClosed
        }

        // 在实际实现中：
        // let rc = libssh2_channel_signal(channel, signal)
        // guard rc == 0 else {
        //     throw SSHError.libssh2Error(code: rc, message: "发送信号失败")
        // }

        AppLogger.ssh.debug("[SSHConnection] 信号已发送: \(signal)")
    }

    /// 发送 EOF
    func sendEOF() async throws {
        guard state == .connected, channel != nil else {
            throw SSHError.sessionClosed
        }

        // 在实际实现中：
        // let rc = libssh2_channel_send_eof(channel)
        // guard rc == 0 else {
        //     throw SSHError.libssh2Error(code: rc, message: "发送 EOF 失败")
        // }

        AppLogger.ssh.debug("[SSHConnection] EOF 已发送")
    }

    // MARK: - 保活

    /// 发送保活
    func sendKeepAlive() async throws {
        guard state == .connected else {
            throw SSHError.sessionClosed
        }

        // 在实际实现中：
        // var secondsToNext: Int32 = 0
        // let rc = libssh2_keepalive_send(session, &secondsToNext)
        // guard rc == 0 else {
        //     throw SSHError.libssh2Error(code: rc, message: "发送保活失败")
        // }

        AppLogger.ssh.debug("[SSHConnection] 保活已发送")
    }

    // MARK: - 私有方法

    /// 验证主机密钥
    private func verifyHostKey() async throws {
        guard let bridge = bridge else {
            throw SSHError.sessionNotInitialized
        }

        let fingerprint = try bridge.getHostKeyFingerprint()

        // 检查 Known Hosts
        let result = KnownHostsManager.shared.check(
            host: config.host,
            port: config.port,
            fingerprint: fingerprint
        )

        switch result {
        case .match:
            // 密钥匹配，继续
            break

        case .mismatch(let existing):
            // 密钥不匹配，可能的中间人攻击
            throw SSHError.hostKeyChanged(
                oldFingerprint: existing.fingerprint,
                newFingerprint: fingerprint
            )

        case .notFound:
            // 新主机
            if config.autoAddHostKey {
                try KnownHostsManager.shared.add(
                    host: config.host,
                    port: config.port,
                    fingerprint: fingerprint
                )
            } else {
                throw SSHError.hostKeyVerificationFailed(fingerprint: fingerprint.sha256Display)
            }

        case .failure(let error):
            throw SSHError.unknown(underlying: error)
        }
    }

    /// 执行认证
    private func authenticate() async throws {
        guard let bridge = bridge else {
            throw SSHError.sessionNotInitialized
        }

        switch config.authMethod {
        case .password:
            guard let password = config.password else {
                throw SSHError.authenticationFailed(method: "password", reason: "密码未提供")
            }
            try bridge.authenticateWithPassword(
                username: config.username,
                password: password
            )

        case .privateKey:
            if let keyData = config.privateKeyData {
                try bridge.authenticateWithPublicKeyFromMemory(
                    username: config.username,
                    publicKeyData: nil,
                    privateKeyData: keyData,
                    passphrase: config.passphrase
                )
            } else if let keyPath = config.privateKeyPath {
                try bridge.authenticateWithPublicKey(
                    username: config.username,
                    publicKeyPath: nil,
                    privateKeyPath: keyPath,
                    passphrase: config.passphrase
                )
            } else {
                throw SSHError.invalidPrivateKey(reason: "未提供私钥")
            }

        case .sshAgent:
            try bridge.authenticateWithAgent(username: config.username)
        case .keyboardInteractive:
            throw SSHError.authMethodNotSupported(method: "keyboard-interactive")
        }
    }

    /// 处理错误
    private func handleError(_ error: SSHError) async {
        state = .failed(error.localizedDescription)
        // 可以在这里添加自动重连逻辑
    }
}

// MARK: - 连接池

/// SSH 连接池
/// 管理多个 SSH 连接
actor SSHConnectionPool {

    // MARK: - 属性

    /// 活动连接
    private var connections: [UUID: SSHConnection] = [:]

    /// 最大连接数
    let maxConnections: Int

    // MARK: - 初始化

    init(maxConnections: Int = 10) {
        self.maxConnections = maxConnections
    }

    // MARK: - 连接管理

    /// 创建新连接
    func createConnection(config: SSHSessionConfig) async throws -> SSHConnection {
        guard connections.count < maxConnections else {
            throw SSHError.libssh2Error(code: -1, message: "已达到最大连接数限制")
        }

        let connection = SSHConnection(config: config)
        try await connection.connect()

        connections[connection.connectionId] = connection
        return connection
    }

    /// 获取连接
    func getConnection(id: UUID) -> SSHConnection? {
        return connections[id]
    }

    /// 移除连接
    func removeConnection(id: UUID) async {
        if let connection = connections[id] {
            await connection.disconnect()
            connections.removeValue(forKey: id)
        }
    }

    /// 关闭所有连接
    func closeAll() async {
        for (_, connection) in connections {
            await connection.disconnect()
        }
        connections.removeAll()
    }

    /// 获取活动连接数
    var activeConnectionCount: Int {
        return connections.count
    }

    /// 获取所有连接 ID
    var connectionIds: [UUID] {
        return Array(connections.keys)
    }
}
