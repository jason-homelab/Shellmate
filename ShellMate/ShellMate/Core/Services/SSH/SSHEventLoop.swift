import Foundation
import Dispatch

/// SSH 事件循环状态
enum SSHEventLoopState {
    /// 已停止
    case stopped
    /// 运行中
    case running
    /// 暂停中
    case paused
}

/// SSH 事件类型
enum SSHEventType {
    /// 可读取数据
    case readable
    /// 可写入数据
    case writable
    /// 连接错误
    case error(Error)
    /// 连接关闭
    case closed
    /// 超时
    case timeout
}

/// SSH 事件回调
typealias SSHEventHandler = (SSHEventType) -> Void

/// SSH 事件循环
/// 使用 DispatchSource 实现非阻塞的 Socket 事件监听
final class SSHEventLoop {

    // MARK: - 属性

    /// Socket 文件描述符
    private let socketFD: Int32

    /// 事件处理队列
    private let queue: DispatchQueue

    /// 读取事件源
    private var readSource: DispatchSourceRead?

    /// 写入事件源
    private var writeSource: DispatchSourceWrite?

    /// 定时器（用于超时和保活）
    private var timer: DispatchSourceTimer?

    /// 当前状态
    private(set) var state: SSHEventLoopState = .stopped

    /// 事件回调
    var eventHandler: SSHEventHandler?

    /// 超时时间（秒）
    var timeout: TimeInterval = 30

    /// 保活间隔（秒），0 表示禁用
    var keepAliveInterval: TimeInterval = 60

    /// 最后活动时间
    private var lastActivityTime: Date = Date()

    /// 状态锁
    private let stateLock = NSLock()

    // MARK: - 初始化

    /// 初始化事件循环
    /// - Parameters:
    ///   - socketFD: Socket 文件描述符
    ///   - queue: 事件处理队列（默认创建新队列）
    init(socketFD: Int32, queue: DispatchQueue? = nil) {
        self.socketFD = socketFD
        self.queue = queue ?? DispatchQueue(
            label: "app.shellmate.ssh.eventloop",
            qos: .userInitiated
        )
    }

    deinit {
        stop()
    }

    // MARK: - 生命周期

    /// 启动事件循环
    func start() {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard state == .stopped else {
            print("[SSHEventLoop] 事件循环已在运行")
            return
        }

        setupReadSource()
        setupWriteSource()
        setupTimer()

        state = .running
        lastActivityTime = Date()

        print("[SSHEventLoop] 事件循环已启动")
    }

    /// 停止事件循环
    func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard state != .stopped else { return }

        // 取消读取源
        if let readSource = readSource {
            readSource.cancel()
            self.readSource = nil
        }

        // 取消写入源
        if let writeSource = writeSource {
            writeSource.cancel()
            self.writeSource = nil
        }

        // 取消定时器
        if let timer = timer {
            timer.cancel()
            self.timer = nil
        }

        state = .stopped
        print("[SSHEventLoop] 事件循环已停止")
    }

    /// 暂停事件循环
    func pause() {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard state == .running else { return }

        readSource?.suspend()
        writeSource?.suspend()
        timer?.suspend()

        state = .paused
        print("[SSHEventLoop] 事件循环已暂停")
    }

    /// 恢复事件循环
    func resume() {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard state == .paused else { return }

        readSource?.resume()
        writeSource?.resume()
        timer?.resume()

        state = .running
        lastActivityTime = Date()
        print("[SSHEventLoop] 事件循环已恢复")
    }

    // MARK: - 事件源设置

    /// 设置读取事件源
    private func setupReadSource() {
        let source = DispatchSource.makeReadSource(
            fileDescriptor: socketFD,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.lastActivityTime = Date()
            self.eventHandler?(.readable)
        }

        source.setCancelHandler { [weak self] in
            print("[SSHEventLoop] 读取源已取消")
        }

        source.resume()
        readSource = source
    }

    /// 设置写入事件源
    private func setupWriteSource() {
        let source = DispatchSource.makeWriteSource(
            fileDescriptor: socketFD,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.lastActivityTime = Date()
            self.eventHandler?(.writable)
        }

        source.setCancelHandler { [weak self] in
            print("[SSHEventLoop] 写入源已取消")
        }

        // 写入源初始挂起，需要时再激活
        // source.resume()
        writeSource = source
    }

    /// 设置定时器
    private func setupTimer() {
        let source = DispatchSource.makeTimerSource(queue: queue)

        // 每秒检查一次
        source.schedule(
            deadline: .now() + 1,
            repeating: .seconds(1),
            leeway: .milliseconds(100)
        )

        source.setEventHandler { [weak self] in
            self?.handleTimer()
        }

        source.resume()
        timer = source
    }

    /// 处理定时器事件
    private func handleTimer() {
        let now = Date()
        let idleTime = now.timeIntervalSince(lastActivityTime)

        // 检查超时
        if timeout > 0 && idleTime > timeout {
            eventHandler?(.timeout)
            return
        }

        // 发送保活（如果启用）
        if keepAliveInterval > 0 && idleTime > keepAliveInterval {
            // 触发保活检查
            // 实际保活数据包由 SSHConnection 发送
            lastActivityTime = now
        }
    }

    // MARK: - 写入控制

    /// 启用写入监听
    func enableWriteMonitoring() {
        writeSource?.resume()
    }

    /// 禁用写入监听
    func disableWriteMonitoring() {
        writeSource?.suspend()
    }

    /// 标记活动（重置超时计时器）
    func markActivity() {
        lastActivityTime = Date()
    }
}

// MARK: - SSH 非阻塞 IO 管理器

/// SSH 非阻塞 IO 管理器
/// 封装非阻塞模式下的读写操作
final class SSHNonBlockingIO {

    // MARK: - 属性

    /// libssh2 桥接
    private let bridge: LibSSH2Bridge

    /// 事件循环
    private let eventLoop: SSHEventLoop

    /// 读取缓冲区
    private var readBuffer: Data = Data()

    /// 写入队列
    private var writeQueue: [Data] = []

    /// 写入队列锁
    private let writeLock = NSLock()

    /// 读取回调
    var onDataReceived: ((Data) -> Void)?

    /// 错误回调
    var onError: ((SSHError) -> Void)?

    /// 关闭回调
    var onClose: (() -> Void)?

    /// 缓冲区大小
    private let bufferSize = 32768 // 32KB

    // MARK: - 初始化

    init(bridge: LibSSH2Bridge) {
        self.bridge = bridge
        self.eventLoop = SSHEventLoop(socketFD: bridge.getSocketFD())

        setupEventHandlers()
    }

    // MARK: - 设置

    /// 设置事件处理
    private func setupEventHandlers() {
        eventLoop.eventHandler = { [weak self] event in
            guard let self = self else { return }

            switch event {
            case .readable:
                self.handleReadable()

            case .writable:
                self.handleWritable()

            case .error(let error):
                self.onError?(SSHError.unknown(underlying: error))

            case .closed:
                self.onClose?()

            case .timeout:
                self.onError?(SSHError.connectionTimeout(
                    host: self.bridge.connectedHost ?? "unknown",
                    port: self.bridge.connectedPort ?? 22
                ))
            }
        }
    }

    // MARK: - 生命周期

    /// 启动非阻塞 IO
    func start() {
        // 设置为非阻塞模式
        bridge.setBlocking(false)
        eventLoop.start()
    }

    /// 停止非阻塞 IO
    func stop() {
        eventLoop.stop()
    }

    // MARK: - 读取处理

    /// 处理可读事件
    private func handleReadable() {
        // 在实际实现中，这里会调用 libssh2_channel_read
        // var buffer = [UInt8](repeating: 0, count: bufferSize)
        // let bytesRead = libssh2_channel_read(channel, &buffer, bufferSize)
        //
        // if bytesRead > 0 {
        //     let data = Data(bytes: buffer, count: Int(bytesRead))
        //     onDataReceived?(data)
        // } else if bytesRead == SSH2ErrorCode.eagain {
        //     // 需要等待更多数据
        // } else if bytesRead < 0 {
        //     // 错误
        //     onError?(SSHError.libssh2Error(code: Int32(bytesRead), message: "读取失败"))
        // }

        // 模拟数据接收
        eventLoop.markActivity()
    }

    /// 处理可写事件
    private func handleWritable() {
        writeLock.lock()
        defer { writeLock.unlock() }

        guard !writeQueue.isEmpty else {
            // 没有待写入数据，禁用写入监听
            eventLoop.disableWriteMonitoring()
            return
        }

        // 获取待写入数据
        var data = writeQueue.removeFirst()

        // 在实际实现中，这里会调用 libssh2_channel_write
        // let bytesWritten = data.withUnsafeBytes { ptr in
        //     libssh2_channel_write(channel, ptr.baseAddress, data.count)
        // }
        //
        // if bytesWritten > 0 {
        //     if bytesWritten < data.count {
        //         // 部分写入，剩余部分重新入队
        //         data = data.dropFirst(Int(bytesWritten))
        //         writeQueue.insert(data, at: 0)
        //     }
        // } else if bytesWritten == SSH2ErrorCode.eagain {
        //     // 需要重试，重新入队
        //     writeQueue.insert(data, at: 0)
        // } else {
        //     // 错误
        //     onError?(SSHError.libssh2Error(code: Int32(bytesWritten), message: "写入失败"))
        // }

        eventLoop.markActivity()

        // 如果队列为空，禁用写入监听
        if writeQueue.isEmpty {
            eventLoop.disableWriteMonitoring()
        }
    }

    // MARK: - 写入方法

    /// 写入数据
    /// - Parameter data: 要写入的数据
    func write(_ data: Data) {
        writeLock.lock()
        writeQueue.append(data)
        writeLock.unlock()

        // 启用写入监听
        eventLoop.enableWriteMonitoring()
    }

    /// 写入字符串
    /// - Parameter string: 要写入的字符串
    func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        write(data)
    }

    // MARK: - 配置

    /// 设置超时时间
    func setTimeout(_ timeout: TimeInterval) {
        eventLoop.timeout = timeout
    }

    /// 设置保活间隔
    func setKeepAliveInterval(_ interval: TimeInterval) {
        eventLoop.keepAliveInterval = interval
    }
}
