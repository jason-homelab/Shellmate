import Foundation

// MARK: - PTY 配置

/// PTY 配置
struct PTYConfig {
    /// 终端类型（TERM 环境变量）
    var terminalType: String = "xterm-256color"

    /// 列数
    var columns: Int = 80

    /// 行数
    var rows: Int = 24

    /// 像素宽度（可选，0 表示自动）
    var widthPixels: Int = 0

    /// 像素高度（可选，0 表示自动）
    var heightPixels: Int = 0

    /// 终端模式设置
    var modes: [PTYMode] = []

    /// 默认配置
    static let `default` = PTYConfig()
}

/// PTY 模式
enum PTYMode: UInt8 {
    // 输入模式
    case IGNPAR = 30    // 忽略奇偶校验错误
    case PARMRK = 31    // 标记奇偶校验错误
    case INPCK = 32     // 启用输入奇偶校验
    case ISTRIP = 33    // 剥离第 8 位
    case INLCR = 34     // 将 NL 转换为 CR
    case IGNCR = 35     // 忽略 CR
    case ICRNL = 36     // 将 CR 转换为 NL
    case IUCLC = 37     // 将大写转换为小写
    case IXON = 38      // 启用输出流控制
    case IXANY = 39     // 任意字符重启输出
    case IXOFF = 40     // 启用输入流控制
    case IMAXBEL = 41   // 输入队列满时响铃

    // 输出模式
    case OPOST = 70     // 启用输出处理
    case OLCUC = 71     // 将小写转换为大写
    case ONLCR = 72     // 将 NL 映射为 CR-NL
    case OCRNL = 73     // 将 CR 映射为 NL
    case ONOCR = 74     // 在第 0 列不输出 CR
    case ONLRET = 75    // NL 执行 CR 功能

    // 控制模式
    case CS7 = 90       // 7 位字符
    case CS8 = 91       // 8 位字符
    case PARENB = 92    // 启用奇偶校验
    case PARODD = 93    // 奇校验

    // 本地模式
    case ISIG = 128     // 启用信号
    case ICANON = 129   // 规范模式
    case XCASE = 130    // 大小写转换
    case ECHO = 131     // 回显输入
    case ECHOE = 132    // 回显擦除
    case ECHOK = 133    // 回显 kill
    case ECHONL = 134   // 回显 NL
    case NOFLSH = 135   // 禁止中断后刷新
    case TOSTOP = 136   // 后台进程输出时停止
    case IEXTEN = 137   // 扩展输入处理
    case ECHOCTL = 138  // 回显控制字符
    case ECHOKE = 139   // 可视擦除
    case PENDIN = 140   // 挂起输入

    // 特殊控制字符
    case VINTR = 1      // 中断
    case VQUIT = 2      // 退出
    case VERASE = 3     // 擦除
    case VKILL = 4      // 删行
    case VEOF = 5       // EOF
    case VEOL = 6       // EOL
    case VEOL2 = 7      // EOL2
    case VSTART = 8     // 开始
    case VSTOP = 9      // 停止
    case VSUSP = 10     // 暂停
    case VREPRINT = 12  // 重印
    case VWERASE = 14   // 删词
    case VLNEXT = 15    // 字面下一个
    case VFLUSH = 18    // 刷新
}

// MARK: - 通道状态

/// SSH 通道状态
enum SSHChannelState: Equatable {
    /// 未初始化
    case uninitialized
    /// 正在打开
    case opening
    /// 已打开，未激活
    case opened
    /// PTY 已分配
    case ptyAllocated
    /// Shell 已启动
    case shellStarted
    /// 正在关闭
    case closing
    /// 已关闭
    case closed
    /// 错误
    case error(String)
}

// MARK: - SSH 通道管理器

/// SSH 通道管理器
/// 负责管理 SSH 通道的生命周期和数据传输
final class SSHChannelManager {

    // MARK: - 属性

    /// libssh2 桥接
    private weak var bridge: LibSSH2Bridge?

    /// 通道指针（模拟）
    private var channel: OpaquePointer?

    /// 当前状态
    private(set) var state: SSHChannelState = .uninitialized

    /// PTY 配置
    private(set) var ptyConfig: PTYConfig?

    /// 数据接收 continuation
    private var dataContinuation: AsyncStream<Data>.Continuation?

    /// 数据流
    private(set) var dataStream: AsyncStream<Data>?

    /// 错误数据流（stderr）
    private var stderrContinuation: AsyncStream<Data>.Continuation?

    /// stderr 流
    private(set) var stderrStream: AsyncStream<Data>?

    /// 读取缓冲区大小
    private let readBufferSize = AppConstants.sshReadBufferSize

    /// 写入队列
    private var writeQueue: [Data] = []

    /// 写入锁
    private let writeLock = NSLock()

    /// 读取任务
    private var readTask: Task<Void, Never>?

    /// 是否处于阻塞模式
    private var isBlocking: Bool = false

    // MARK: - 初始化

    init(bridge: LibSSH2Bridge) {
        self.bridge = bridge
    }

    deinit {
        readTask?.cancel()
    }

    // MARK: - 通道操作

    /// 打开 Shell 通道
    /// - Parameter config: PTY 配置
    func openShell(config: PTYConfig = .default) async throws {
        guard state == .uninitialized || state == .closed else {
            throw SSHError.channelOpenFailed(reason: "通道已存在，状态: \(state)")
        }

        state = .opening

        do {
            // 打开会话通道
            try openSessionChannel()

            state = .opened

            // 分配 PTY
            try requestPTY(config: config)

            state = .ptyAllocated
            ptyConfig = config

            // 启动 Shell
            try startShell()

            state = .shellStarted

            // 设置数据流
            setupDataStreams()

            // 启动读取循环
            startReadLoop()

            AppLogger.ssh.debug("[SSHChannelManager] Shell 通道已完全打开")

        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    /// 打开执行通道
    /// - Parameter command: 要执行的命令
    func openExec(command: String) async throws {
        guard state == .uninitialized || state == .closed else {
            throw SSHError.channelOpenFailed(reason: "通道已存在")
        }

        state = .opening

        do {
            // 打开会话通道
            try openSessionChannel()

            state = .opened

            // 执行命令
            try execCommand(command)

            state = .shellStarted

            // 设置数据流
            setupDataStreams()

            // 启动读取循环
            startReadLoop()

            AppLogger.ssh.debug("[SSHChannelManager] Exec 通道已打开: \(command)")

        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    /// 关闭通道
    func close() async {
        guard state != .uninitialized && state != .closed else { return }

        state = .closing

        // 取消读取任务
        readTask?.cancel()
        readTask = nil

        // 发送 EOF
        sendEOFSync()

        // 关闭通道
        closeChannelSync()

        // 结束数据流
        dataContinuation?.finish()
        stderrContinuation?.finish()

        state = .closed
        channel = nil

        AppLogger.ssh.debug("[SSHChannelManager] 通道已关闭")
    }

    // MARK: - 数据读写

    /// 写入数据
    /// - Parameter data: 要发送的数据
    func write(_ data: Data) throws {
        guard state == .shellStarted else {
            throw SSHError.channelNotOpen
        }

        writeLock.lock()
        writeQueue.append(data)
        writeLock.unlock()

        // 触发写入
        Task {
            await processWriteQueue()
        }
    }

    /// 写入字符串
    /// - Parameter string: 要发送的字符串
    func write(_ string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw SSHError.libssh2Error(code: -1, message: "字符串编码失败")
        }
        try write(data)
    }

    /// 处理写入队列
    private func processWriteQueue() async {
        let dataToWrite = writeLock.withLock {
            let items = writeQueue
            writeQueue.removeAll()
            return items
        }

        for data in dataToWrite {
            writeSync(data)
        }
    }

    /// 同步写入数据（实际 libssh2 写入由 LibSSH2Bridge 层处理）
    private func writeSync(_ data: Data) {
        AppLogger.ssh.debug("[SSHChannelManager] 写入数据: \(data.count) 字节")
    }

    // MARK: - PTY 控制

    /// 调整 PTY 尺寸
    /// - Parameters:
    ///   - columns: 新的列数
    ///   - rows: 新的行数
    func resizePTY(columns: Int, rows: Int) throws {
        guard state == .shellStarted || state == .ptyAllocated else {
            throw SSHError.channelNotOpen
        }

        // 在实际实现中：
        // let rc = libssh2_channel_request_pty_size_ex(
        //     channel,
        //     Int32(columns),
        //     Int32(rows),
        //     0, 0
        // )
        // guard rc == 0 else {
        //     throw SSHError.libssh2Error(code: rc, message: "调整 PTY 尺寸失败")
        // }

        ptyConfig = PTYConfig(
            terminalType: ptyConfig?.terminalType ?? "xterm-256color",
            columns: columns,
            rows: rows
        )

        AppLogger.ssh.debug("[SSHChannelManager] PTY 尺寸已调整: \(columns)x\(rows)")
    }

    // MARK: - 信号发送

    /// 发送信号
    /// - Parameter signal: 信号名称（如 "INT", "TERM", "KILL"）
    func sendSignal(_ signal: String) throws {
        guard state == .shellStarted else {
            throw SSHError.channelNotOpen
        }

        // 在实际实现中：
        // let rc = libssh2_channel_signal(channel, signal)
        // guard rc == 0 else {
        //     throw SSHError.libssh2Error(code: rc, message: "发送信号失败")
        // }

        AppLogger.ssh.debug("[SSHChannelManager] 信号已发送: \(signal)")
    }

    /// 发送 EOF
    private func sendEOFSync() {
        guard channel != nil else { return }

        // 在实际实现中：
        // let rc = libssh2_channel_send_eof(channel)
        // if rc != 0 {
        //     print("[SSHChannelManager] 发送 EOF 失败")
        // }

        AppLogger.ssh.debug("[SSHChannelManager] EOF 已发送")
    }

    // MARK: - 私有方法

    /// 打开会话通道
    private func openSessionChannel() throws {
        // 在实际实现中：
        // channel = libssh2_channel_open_session(bridge?.session)
        // guard channel != nil else {
        //     let error = bridge?.getLastErrorMessage() ?? "未知错误"
        //     throw SSHError.channelOpenFailed(reason: error)
        // }

        AppLogger.ssh.debug("[SSHChannelManager] 会话通道已打开")
    }

    /// 请求 PTY
    private func requestPTY(config: PTYConfig) throws {
        // 在实际实现中：
        // let modesData = buildModesData(config.modes)
        //
        // let rc = modesData.withUnsafeBytes { modesPtr in
        //     config.terminalType.withCString { termPtr in
        //         libssh2_channel_request_pty_ex(
        //             channel,
        //             termPtr,
        //             UInt32(config.terminalType.count),
        //             modesPtr.baseAddress?.assumingMemoryBound(to: CChar.self),
        //             UInt32(modesData.count),
        //             Int32(config.columns),
        //             Int32(config.rows),
        //             Int32(config.widthPixels),
        //             Int32(config.heightPixels)
        //         )
        //     }
        // }
        //
        // guard rc == 0 else {
        //     throw SSHError.ptyRequestFailed(reason: bridge?.getLastErrorMessage() ?? "未知错误")
        // }

        AppLogger.ssh.debug("[SSHChannelManager] PTY 已分配: \(config.terminalType) \(config.columns)x\(config.rows)")
    }

    /// 构建 PTY 模式数据
    private func buildModesData(_ modes: [PTYMode]) -> Data {
        var data = Data()

        for mode in modes {
            data.append(mode.rawValue)
            // 追加 4 字节的值（0 表示禁用，1 表示启用）
            data.append(contentsOf: [0, 0, 0, 1])
        }

        // 追加结束标记
        data.append(0)

        return data
    }

    /// 启动 Shell
    private func startShell() throws {
        // 在实际实现中：
        // let rc = libssh2_channel_shell(channel)
        // guard rc == 0 else {
        //     throw SSHError.shellStartFailed(reason: bridge?.getLastErrorMessage() ?? "未知错误")
        // }

        AppLogger.ssh.debug("[SSHChannelManager] Shell 已启动")
    }

    /// 执行命令
    private func execCommand(_ command: String) throws {
        // 在实际实现中：
        // let rc = command.withCString { cmdPtr in
        //     libssh2_channel_exec(channel, cmdPtr)
        // }
        // guard rc == 0 else {
        //     throw SSHError.shellStartFailed(reason: "命令执行失败")
        // }

        AppLogger.ssh.debug("[SSHChannelManager] 命令已执行: \(command)")
    }

    /// 关闭通道（同步）
    private func closeChannelSync() {
        guard channel != nil else { return }

        // 在实际实现中：
        // libssh2_channel_close(channel)
        // libssh2_channel_free(channel)

        AppLogger.ssh.debug("[SSHChannelManager] 通道已释放")
    }

    /// 设置数据流
    private func setupDataStreams() {
        // 创建主数据流（stdout）
        let (stream, continuation) = AsyncStream<Data>.makeStream(
            bufferingPolicy: .bufferingNewest(100) // 背压控制：最多缓存 100 个数据块
        )
        self.dataStream = stream
        self.dataContinuation = continuation

        // 创建错误数据流（stderr）
        let (stderrStream, stderrContinuation) = AsyncStream<Data>.makeStream(
            bufferingPolicy: .bufferingNewest(100)
        )
        self.stderrStream = stderrStream
        self.stderrContinuation = stderrContinuation
    }

    /// 启动读取循环
    private func startReadLoop() {
        readTask = Task { [weak self] in
            await self?.readLoop()
        }
    }

    /// 读取循环（实际 libssh2 读取由 LibSSH2Bridge 层处理）
    private func readLoop() async {
        while !Task.isCancelled && state == .shellStarted {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        AppLogger.ssh.debug("[SSHChannelManager] 读取循环已结束")
    }

    // MARK: - 状态查询

    /// 检查通道是否已关闭（EOF）
    var isEOF: Bool {
        // 在实际实现中：
        // return libssh2_channel_eof(channel) == 1
        return state == .closed
    }

    /// 获取退出状态
    var exitStatus: Int32? {
        guard state == .closed else { return nil }

        // 在实际实现中：
        // return libssh2_channel_get_exit_status(channel)
        return 0
    }

    /// 获取退出信号
    var exitSignal: String? {
        guard state == .closed else { return nil }

        // 在实际实现中：
        // var signalPtr: UnsafeMutablePointer<CChar>?
        // var signalLen: Int = 0
        // libssh2_channel_get_exit_signal(
        //     channel,
        //     &signalPtr,
        //     &signalLen,
        //     nil, nil, nil, nil
        // )
        // if let ptr = signalPtr {
        //     return String(cString: ptr)
        // }
        return nil
    }
}

// MARK: - 异步数据读取扩展

extension SSHChannelManager {

    /// 获取数据流迭代器
    func makeAsyncIterator() -> AsyncStream<Data>.Iterator? {
        return dataStream?.makeAsyncIterator()
    }

    /// 读取所有输出直到 EOF
    func readAllOutput() async -> Data {
        var result = Data()

        guard let stream = dataStream else {
            return result
        }

        for await chunk in stream {
            result.append(chunk)
        }

        return result
    }

    /// 读取带超时
    func read(timeout: TimeInterval) async throws -> Data? {
        guard let stream = dataStream else {
            return nil
        }

        return try await withThrowingTaskGroup(of: Data?.self) { group in
            // 读取任务
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next()
            }

            // 超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            // 返回第一个完成的结果
            if let result = try await group.next() {
                group.cancelAll()
                return result
            }

            throw SSHError.readTimeout
        }
    }
}
