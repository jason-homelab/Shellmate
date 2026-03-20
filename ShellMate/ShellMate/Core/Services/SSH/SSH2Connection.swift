import Foundation
import Darwin

// MARK: - libssh2 常量
private let LIBSSH2_ERROR_EAGAIN: Int32 = -37

/// 基于 libssh2 的 SSH 连接
/// 提供完整的 SSH 会话管理，包括连接、认证、通道操作
final class SSH2Connection {

    // MARK: - 属性

    /// libssh2 桥接
    private let bridge: LibSSH2BridgeReal

    /// 当前通道
    private var channel: OpaquePointer?

    /// 数据接收回调
    var onDataReceived: ((Data) -> Void)?

    /// 连接关闭回调
    var onDisconnected: (() -> Void)?

    /// 主机密钥验证回调（在握手后、认证前调用）
    /// 回调应检查 KnownHostsManager；如需拒绝连接，应 throw 相应的 SSHError
    var onVerifyHostKey: ((HostKeyFingerprint) throws -> Void)?

    /// 是否已连接
    var isConnected: Bool {
        bridge.isConnected && channel != nil
    }

    /// 读取队列
    private let readQueue = DispatchQueue(label: "app.shellmate.ssh2.read")

    /// 是否正在读取
    private var isReading = false

    /// 终端尺寸
    private var terminalCols: Int = 80
    private var terminalRows: Int = 24

    // MARK: - 初始化

    init() {
        self.bridge = LibSSH2BridgeReal()
    }

    deinit {
        disconnect()
    }

    // MARK: - 连接方法

    /// 使用密码连接
    /// - Parameters:
    ///   - host: 主机地址
    ///   - port: 端口号
    ///   - username: 用户名
    ///   - password: 密码
    func connect(
        host: String,
        port: Int32,
        username: String,
        password: String
    ) throws {
        // 初始化会话
        try bridge.sessionInit()

        // 设置超时
        bridge.setTimeout(30000)

        // TCP 连接
        try bridge.tcpConnect(host: host, port: port)

        // SSH 握手
        try bridge.handshake()

        // 获取主机密钥指纹并校验
        let fingerprint = try bridge.getHostKeyFingerprint()
        print("[SSH2Connection] 主机密钥: \(fingerprint.sha256Display)")
        try onVerifyHostKey?(fingerprint)

        // 密码认证
        try bridge.authenticateWithPassword(username: username, password: password)

        // 打开 Shell 通道
        channel = try bridge.openShellChannel()

        // 请求 PTY
        try bridge.requestPTY(channel: channel!, term: "xterm-256color", cols: terminalCols, rows: terminalRows)

        // 启动 Shell
        try bridge.startShell(channel: channel!)

        // 设置非阻塞模式
        bridge.setBlocking(false)

        // 开始读取数据
        startReading()

        print("[SSH2Connection] 连接成功: \(username)@\(host):\(port)")
    }

    /// 使用私钥连接
    /// - Parameters:
    ///   - host: 主机地址
    ///   - port: 端口号
    ///   - username: 用户名
    ///   - privateKeyPath: 私钥文件路径
    ///   - passphrase: 私钥密码（可选）
    func connectWithKey(
        host: String,
        port: Int32,
        username: String,
        privateKeyPath: String,
        passphrase: String? = nil
    ) throws {
        // 初始化会话
        try bridge.sessionInit()

        // 设置超时
        bridge.setTimeout(30000)

        // TCP 连接
        try bridge.tcpConnect(host: host, port: port)

        // SSH 握手
        try bridge.handshake()

        // 获取主机密钥指纹并校验
        let fingerprint = try bridge.getHostKeyFingerprint()
        print("[SSH2Connection] 主机密钥: \(fingerprint.sha256Display)")
        try onVerifyHostKey?(fingerprint)

        // 公钥认证
        try bridge.authenticateWithPublicKey(
            username: username,
            publicKeyPath: nil,
            privateKeyPath: privateKeyPath,
            passphrase: passphrase
        )

        // 打开 Shell 通道
        channel = try bridge.openShellChannel()

        // 请求 PTY
        try bridge.requestPTY(channel: channel!, term: "xterm-256color", cols: terminalCols, rows: terminalRows)

        // 启动 Shell
        try bridge.startShell(channel: channel!)

        // 设置非阻塞模式
        bridge.setBlocking(false)

        // 开始读取数据
        startReading()

        print("[SSH2Connection] 私钥连接成功: \(username)@\(host):\(port)")
    }

    /// 使用 SSH Agent 连接
    /// - Parameters:
    ///   - host: 主机地址
    ///   - port: 端口号
    ///   - username: 用户名
    func connectWithAgent(
        host: String,
        port: Int32,
        username: String
    ) throws {
        // 初始化会话
        try bridge.sessionInit()

        // 设置超时
        bridge.setTimeout(30000)

        // TCP 连接
        try bridge.tcpConnect(host: host, port: port)

        // SSH 握手
        try bridge.handshake()

        // 获取主机密钥指纹并校验
        let fingerprint = try bridge.getHostKeyFingerprint()
        print("[SSH2Connection] 主机密钥: \(fingerprint.sha256Display)")
        try onVerifyHostKey?(fingerprint)

        // SSH Agent 认证
        try bridge.authenticateWithAgent(username: username)

        // 打开 Shell 通道
        channel = try bridge.openShellChannel()

        // 请求 PTY
        try bridge.requestPTY(channel: channel!, term: "xterm-256color", cols: terminalCols, rows: terminalRows)

        // 启动 Shell
        try bridge.startShell(channel: channel!)

        // 设置非阻塞模式
        bridge.setBlocking(false)

        // 开始读取数据
        startReading()

        print("[SSH2Connection] Agent 连接成功: \(username)@\(host):\(port)")
    }

    // MARK: - 数据操作

    /// 写入数据
    /// - Parameter data: 要发送的数据
    func write(_ data: Data) throws {
        guard let channel = channel else {
            throw SSHError.channelNotOpen
        }

        try data.withUnsafeBytes { buffer in
            guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            var sent = 0
            while sent < data.count {
                let result = bridge.writeChannel(channel: channel, data: ptr.advanced(by: sent), length: data.count - sent)
                if result > 0 {
                    sent += result
                } else if result == Int(LIBSSH2_ERROR_EAGAIN) {
                    // 非阻塞模式，等待重试
                    usleep(1000)
                } else {
                    throw SSHError.writeFailed(reason: bridge.getLastErrorMessage())
                }
            }
        }
    }

    /// 写入字符串
    /// - Parameter string: 要发送的字符串
    func write(_ string: String) throws {
        guard let data = string.data(using: .utf8) else { return }
        try write(data)
    }

    /// 调整终端尺寸
    /// - Parameters:
    ///   - cols: 列数
    ///   - rows: 行数
    func resizeTerminal(cols: Int, rows: Int) {
        guard let channel = channel else { return }
        terminalCols = cols
        terminalRows = rows
        bridge.resizePTY(channel: channel, cols: cols, rows: rows)
    }

    // MARK: - 断开连接

    /// 断开连接
    func disconnect() {
        isReading = false

        if let channel = channel {
            bridge.closeChannel(channel: channel)
            self.channel = nil
        }

        bridge.disconnect()

        DispatchQueue.main.async { [weak self] in
            self?.onDisconnected?()
        }
    }

    // MARK: - 私有方法

    /// 开始读取数据
    private func startReading() {
        guard !isReading else { return }
        isReading = true

        readQueue.async { [weak self] in
            self?.readLoop()
        }
    }

    /// 读取循环
    private func readLoop() {
        // W15.5 优化：32KB 缓冲区减少 libssh2_channel_read 系统调用次数（原 4KB）
        // 回调直接在后台线程触发，由 TerminalDataCoalescer 聚合到 16ms 窗口后渲染
        let bufferSize = 32768
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while isReading, let channel = channel {
            let bytesRead = bridge.readChannel(channel: channel, buffer: &buffer, bufferSize: bufferSize)

            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)
                // 直接在后台线程回调，无需跳转主线程（TerminalController 的 coalescer 处理线程安全）
                onDataReceived?(data)
            } else if bytesRead == Int(LIBSSH2_ERROR_EAGAIN) {
                // 非阻塞模式，使用 select 等待数据
                waitForData()
            } else if bytesRead == 0 {
                // EOF，连接关闭
                break
            } else {
                // 错误
                print("[SSH2Connection] 读取错误: \(bytesRead)")
                break
            }
        }

        // 读取结束，断开连接
        if isReading {
            isReading = false
            DispatchQueue.main.async { [weak self] in
                self?.onDisconnected?()
            }
        }
    }

    /// 使用 select 等待数据
    private func waitForData() {
        let socketFD = bridge.getSocketFD()
        guard socketFD >= 0 else { return }

        var readSet = fd_set()
        var writeSet = fd_set()

        // 初始化 fd_set
        fdZero(&readSet)
        fdZero(&writeSet)

        let directions = bridge.getBlockDirections()

        if directions & 1 != 0 { // LIBSSH2_SESSION_BLOCK_INBOUND
            fdSet(socketFD, &readSet)
        }
        if directions & 2 != 0 { // LIBSSH2_SESSION_BLOCK_OUTBOUND
            fdSet(socketFD, &writeSet)
        }

        // 超时 50ms
        var timeout = timeval(tv_sec: 0, tv_usec: 50000)

        _ = select(socketFD + 1, &readSet, &writeSet, nil, &timeout)
    }
}

// MARK: - fd_set 辅助函数

private func fdZero(_ set: inout fd_set) {
    set = fd_set()
}

private func fdSet(_ fd: Int32, _ set: inout fd_set) {
    let intOffset = Int(fd / 32)
    let bitOffset = Int(fd % 32)
    let mask = Int32(1 << bitOffset)
    withUnsafeMutableBytes(of: &set.fds_bits) { rawBuffer in
        let ptr = rawBuffer.baseAddress!.assumingMemoryBound(to: Int32.self)
        ptr[intOffset] |= mask
    }
}
