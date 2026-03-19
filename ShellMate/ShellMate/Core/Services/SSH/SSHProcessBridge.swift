import Foundation
import Darwin

// MARK: - SSH 进程桥接

/// 使用系统 ssh 命令的 SSH 连接桥接
/// 这是一个临时实现，使用 macOS 内置的 ssh 命令进行连接
/// 后续会替换为 libssh2 的直接调用
final class SSHProcessBridge {

    // MARK: - 属性

    /// SSH 进程
    private var process: Process?

    /// PTY 主端文件描述符
    private var masterFD: Int32 = -1

    /// PTY 从端文件描述符
    private var slaveFD: Int32 = -1

    /// 输入管道
    private var inputPipe: Pipe?

    /// 输出管道
    private var outputPipe: Pipe?

    /// 错误管道
    private var errorPipe: Pipe?

    /// 数据接收回调
    var onDataReceived: ((Data) -> Void)?

    /// 错误数据接收回调
    var onErrorReceived: ((Data) -> Void)?

    /// 连接关闭回调
    var onDisconnected: (() -> Void)?

    /// 是否已连接
    private(set) var isConnected: Bool = false

    /// 连接的主机
    private(set) var host: String?

    /// 读取队列
    private let readQueue = DispatchQueue(label: "app.shellmate.ssh.read")

    // MARK: - 初始化

    init() {}

    deinit {
        disconnect()
    }

    // MARK: - 连接方法

    /// 使用密码连接
    /// - Parameters:
    ///   - host: 主机地址
    ///   - port: 端口号
    ///   - username: 用户名
    ///   - password: 密码（注意：使用 sshpass 或交互式输入）
    ///   - terminalSize: 终端尺寸
    func connect(
        host: String,
        port: Int32,
        username: String,
        password: String? = nil,
        terminalSize: TerminalSize = .default
    ) throws {
        guard !isConnected else {
            throw SSHError.libssh2Error(code: -1, message: "已连接")
        }

        self.host = host

        // 创建 PTY
        try createPTY()

        // 设置终端尺寸
        setTerminalSize(columns: terminalSize.columns, rows: terminalSize.rows)

        // 创建并启动 SSH 进程
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

        // 构建参数
        var args: [String] = []

        // 禁用严格主机密钥检查（仅用于开发测试，生产环境应该启用）
        args.append("-o")
        args.append("StrictHostKeyChecking=ask")

        // 指定端口
        if port != 22 {
            args.append("-p")
            args.append(String(port))
        }

        // 强制使用伪终端
        args.append("-tt")

        // 用户名@主机
        args.append("\(username)@\(host)")

        proc.arguments = args

        // 设置 PTY 作为标准 IO
        proc.standardInput = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        proc.standardOutput = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        proc.standardError = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)

        // 设置环境变量
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["LC_ALL"] = "en_US.UTF-8"
        proc.environment = environment

        // 进程终止处理
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleDisconnection()
            }
        }

        // 启动进程
        do {
            try proc.run()
            self.process = proc
            self.isConnected = true

            // 开始读取数据
            startReading()

            print("[SSHProcessBridge] SSH 进程已启动 PID: \(proc.processIdentifier)")

        } catch {
            closePTY()
            throw SSHError.connectionFailed(host: host, port: port, underlying: error)
        }
    }

    /// 使用私钥连接
    func connectWithKey(
        host: String,
        port: Int32,
        username: String,
        privateKeyPath: String,
        passphrase: String? = nil,
        terminalSize: TerminalSize = .default
    ) throws {
        guard !isConnected else {
            throw SSHError.libssh2Error(code: -1, message: "已连接")
        }

        self.host = host

        // 创建 PTY
        try createPTY()

        // 设置终端尺寸
        setTerminalSize(columns: terminalSize.columns, rows: terminalSize.rows)

        // 创建进程
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

        var args: [String] = []

        // 指定私钥
        args.append("-i")
        args.append(privateKeyPath)

        // 禁用密码认证（仅使用密钥）
        args.append("-o")
        args.append("PasswordAuthentication=no")

        // 端口
        if port != 22 {
            args.append("-p")
            args.append(String(port))
        }

        // 强制 PTY
        args.append("-tt")

        // 用户名@主机
        args.append("\(username)@\(host)")

        proc.arguments = args

        // 设置 PTY
        proc.standardInput = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        proc.standardOutput = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        proc.standardError = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)

        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        proc.environment = environment

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleDisconnection()
            }
        }

        do {
            try proc.run()
            self.process = proc
            self.isConnected = true
            startReading()

            print("[SSHProcessBridge] SSH 密钥连接已启动")

        } catch {
            closePTY()
            throw SSHError.connectionFailed(host: host, port: port, underlying: error)
        }
    }

    /// 断开连接
    func disconnect() {
        guard isConnected else { return }

        isConnected = false

        // 终止进程
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil

        // 关闭 PTY
        closePTY()

        print("[SSHProcessBridge] 已断开连接")
    }

    // MARK: - 数据传输

    /// 写入数据
    func write(_ data: Data) throws {
        guard isConnected, masterFD >= 0 else {
            throw SSHError.sessionClosed
        }

        data.withUnsafeBytes { buffer in
            guard let ptr = buffer.baseAddress else { return }
            let _ = Darwin.write(masterFD, ptr, data.count)
        }
    }

    /// 写入字符串
    func write(_ string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw SSHError.libssh2Error(code: -1, message: "字符串编码失败")
        }
        try write(data)
    }

    // MARK: - PTY 控制

    /// 调整终端尺寸
    func resizeTerminal(columns: Int, rows: Int) {
        guard masterFD >= 0 else { return }

        var winSize = winsize()
        winSize.ws_col = UInt16(columns)
        winSize.ws_row = UInt16(rows)
        winSize.ws_xpixel = 0
        winSize.ws_ypixel = 0

        _ = ioctl(masterFD, TIOCSWINSZ, &winSize)

        print("[SSHProcessBridge] 终端尺寸已调整: \(columns)x\(rows)")
    }

    // MARK: - 私有方法

    /// 创建 PTY
    private func createPTY() throws {
        // 使用 openpty 创建伪终端
        var master: Int32 = -1
        var slave: Int32 = -1
        var winSize = winsize()
        winSize.ws_col = 80
        winSize.ws_row = 24

        let result = openpty(&master, &slave, nil, nil, &winSize)

        guard result == 0 else {
            throw SSHError.ptyRequestFailed(reason: "openpty 失败: \(errno)")
        }

        masterFD = master
        slaveFD = slave

        // 设置非阻塞模式
        var flags = fcntl(masterFD, F_GETFL, 0)
        fcntl(masterFD, F_SETFL, flags | O_NONBLOCK)

        print("[SSHProcessBridge] PTY 已创建 master=\(masterFD) slave=\(slaveFD)")
    }

    /// 关闭 PTY
    private func closePTY() {
        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }
        if slaveFD >= 0 {
            close(slaveFD)
            slaveFD = -1
        }
    }

    /// 设置终端尺寸
    private func setTerminalSize(columns: Int, rows: Int) {
        guard masterFD >= 0 else { return }

        var winSize = winsize()
        winSize.ws_col = UInt16(columns)
        winSize.ws_row = UInt16(rows)

        _ = ioctl(masterFD, TIOCSWINSZ, &winSize)
    }

    /// 开始读取数据
    private func startReading() {
        readQueue.async { [weak self] in
            self?.readLoop()
        }
    }

    /// 读取循环
    private func readLoop() {
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while isConnected && masterFD >= 0 {
            let bytesRead = read(masterFD, &buffer, bufferSize)

            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)

                DispatchQueue.main.async { [weak self] in
                    self?.onDataReceived?(data)
                }
            } else if bytesRead == 0 {
                // EOF
                break
            } else {
                // 错误或 EAGAIN
                if errno != EAGAIN && errno != EWOULDBLOCK {
                    break
                }
                // 短暂等待
                usleep(10000) // 10ms
            }
        }
    }

    /// 处理断开连接
    private func handleDisconnection() {
        isConnected = false
        closePTY()
        onDisconnected?()
    }
}

// MARK: - SSHProcessConnection

/// 基于进程的 SSH 连接
/// 使用 SSHProcessBridge 实现真实的 SSH 连接
actor SSHProcessConnection {

    // MARK: - 属性

    /// 进程桥接
    private var bridge: SSHProcessBridge?

    /// 会话配置
    private let config: SSHSessionConfig

    /// 连接状态
    private(set) var state: SSHConnection.State = .disconnected

    /// 数据流
    private var dataStream: AsyncStream<Data>?
    private var dataContinuation: AsyncStream<Data>.Continuation?

    // MARK: - 初始化

    init(config: SSHSessionConfig) {
        self.config = config
    }

    // MARK: - 连接

    /// 建立连接
    func connect() async throws {
        guard state == .disconnected else { return }

        state = .connecting

        let processBridge = SSHProcessBridge()

        // 设置数据流
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        self.dataStream = stream
        self.dataContinuation = continuation

        processBridge.onDataReceived = { [weak self] data in
            Task { await self?.handleData(data) }
        }

        processBridge.onDisconnected = { [weak self] in
            Task { await self?.handleDisconnection() }
        }

        // 根据认证方式连接
        switch config.authMethod {
        case .password:
            try processBridge.connect(
                host: config.host,
                port: config.port,
                username: config.username,
                password: config.password,
                terminalSize: TerminalSize(
                    columns: config.terminalColumns,
                    rows: config.terminalRows
                )
            )

        case .privateKey:
            if let keyPath = config.privateKeyPath {
                try processBridge.connectWithKey(
                    host: config.host,
                    port: config.port,
                    username: config.username,
                    privateKeyPath: keyPath,
                    passphrase: config.passphrase,
                    terminalSize: TerminalSize(
                        columns: config.terminalColumns,
                        rows: config.terminalRows
                    )
                )
            } else {
                throw SSHError.invalidPrivateKey(reason: "未指定私钥路径")
            }

        case .sshAgent:
            // SSH Agent 使用默认 ssh 命令（会自动使用 agent）
            try processBridge.connect(
                host: config.host,
                port: config.port,
                username: config.username,
                terminalSize: TerminalSize(
                    columns: config.terminalColumns,
                    rows: config.terminalRows
                )
            )
        }

        self.bridge = processBridge
        state = .connected

        print("[SSHProcessConnection] 连接成功")
    }

    /// 断开连接
    func disconnect() async {
        bridge?.disconnect()
        bridge = nil
        dataContinuation?.finish()
        state = .disconnected
    }

    /// 写入数据
    func write(_ data: Data) async throws {
        guard let bridge = bridge else {
            throw SSHError.sessionClosed
        }
        try bridge.write(data)
    }

    /// 写入字符串
    func write(_ string: String) async throws {
        guard let data = string.data(using: .utf8) else {
            throw SSHError.libssh2Error(code: -1, message: "编码失败")
        }
        try await write(data)
    }

    /// 调整终端尺寸
    func resizePTY(columns: Int, rows: Int) {
        bridge?.resizeTerminal(columns: columns, rows: rows)
    }

    /// 获取数据流
    func getDataStream() -> AsyncStream<Data>? {
        return dataStream
    }

    // MARK: - 私有方法

    private func handleData(_ data: Data) {
        dataContinuation?.yield(data)
    }

    private func handleDisconnection() {
        state = .disconnected
        dataContinuation?.finish()
    }
}
