import Foundation
import Combine

// MARK: - 终端控制器委托

/// 终端控制器委托协议
protocol TerminalControllerDelegate: AnyObject {
    /// 连接状态变化
    func terminalController(_ controller: TerminalController, didChangeState state: TerminalController.State)

    /// 收到数据
    func terminalController(_ controller: TerminalController, didReceiveData data: Data)

    /// 收到错误数据（stderr）
    func terminalController(_ controller: TerminalController, didReceiveErrorData data: Data)

    /// 终端标题变化
    func terminalController(_ controller: TerminalController, didChangeTitle title: String)

    /// 连接错误
    func terminalController(_ controller: TerminalController, didFailWithError error: SSHError)

    /// 自动重连开始
    func terminalController(_ controller: TerminalController, willReconnect attempt: Int, of maxAttempts: Int)
}

// MARK: - 终端控制器

/// 终端控制器
/// 整合 SSH 连接、通道管理、终端视图交互
/// 实现自动重连和状态管理
@MainActor
final class TerminalController: ObservableObject {

    // MARK: - 类型定义

    /// 控制器状态
    enum State: Equatable {
        /// 断开连接
        case disconnected
        /// 正在连接
        case connecting
        /// 已连接
        case connected
        /// 正在重连
        case reconnecting(attempt: Int)
        /// 连接失败
        case failed(String)
    }

    /// 重连配置
    struct ReconnectConfig {
        /// 是否启用自动重连
        var enabled: Bool = true

        /// 最大重连次数
        var maxAttempts: Int = 3

        /// 基础延迟（秒）
        var baseDelay: TimeInterval = 1.0

        /// 最大延迟（秒）
        var maxDelay: TimeInterval = 30.0

        /// 指数退避因子
        var backoffFactor: Double = 2.0

        /// 计算第 N 次重连的延迟
        func delay(for attempt: Int) -> TimeInterval {
            let delay = baseDelay * pow(backoffFactor, Double(attempt - 1))
            return min(delay, maxDelay)
        }
    }

    // MARK: - 属性

    /// 会话配置
    private let session: Session

    /// SSH 连接（使用进程桥接实现真实连接）
    private var processConnection: SSHProcessConnection?

    /// 旧的 SSH 连接（保留用于 libssh2 实现）
    private var connection: SSHConnection?

    /// 通道管理器
    private var channelManager: SSHChannelManager?

    /// 是否使用进程桥接（临时方案，后续会替换为 libssh2）
    private let useProcessBridge: Bool = true

    /// 终端视图引用
    weak var terminalView: ShellMateTerminalView?

    /// 当前状态
    @Published private(set) var state: State = .disconnected

    /// 重连配置
    var reconnectConfig = ReconnectConfig()

    /// 当前终端尺寸
    @Published var terminalSize: TerminalSize = .default

    /// 委托
    weak var delegate: TerminalControllerDelegate?

    /// 重连任务
    private var reconnectTask: Task<Void, Never>?

    /// 数据读取任务
    private var dataReadTask: Task<Void, Never>?

    /// 是否由用户主动断开
    private var userDisconnected = false

    /// 取消订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init(session: Session) {
        self.session = session
        setupObservers()
    }

    deinit {
        Task { [weak self] in
            await self?.disconnect()
        }
    }

    /// 设置观察者
    private func setupObservers() {
        // 监听终端尺寸变化
        $terminalSize
            .removeDuplicates()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] newSize in
                Task {
                    try? await self?.resizePTY(columns: newSize.columns, rows: newSize.rows)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 连接管理

    /// 连接到服务器
    func connect() async throws {
        guard state == .disconnected || state.isFailed else {
            return
        }

        userDisconnected = false
        state = .connecting
        delegate?.terminalController(self, didChangeState: state)

        do {
            // 创建 SSH 配置
            let config = createSSHConfig()

            if useProcessBridge {
                // 使用进程桥接（调用系统 ssh 命令）实现真实连接
                let procConnection = SSHProcessConnection(config: config)
                self.processConnection = procConnection

                // 建立连接
                try await procConnection.connect()

                state = .connected
                delegate?.terminalController(self, didChangeState: state)

                // 启动数据读取
                startDataReadingFromProcess()

                print("[TerminalController] 使用进程桥接连接成功")

            } else {
                // 使用 libssh2 实现（目前是模拟）
                let sshConnection = SSHConnection(config: config)
                self.connection = sshConnection

                try await sshConnection.connect()
                try await sshConnection.openShell()

                state = .connected
                delegate?.terminalController(self, didChangeState: state)

                startDataReading()

                print("[TerminalController] 使用 libssh2 连接成功")
            }

        } catch let error as SSHError {
            state = .failed(error.localizedDescription)
            delegate?.terminalController(self, didChangeState: state)
            delegate?.terminalController(self, didFailWithError: error)

            // 尝试自动重连
            if shouldAutoReconnect(after: error) {
                scheduleReconnect()
            }

            throw error
        } catch {
            let sshError = SSHError.connectionFailed(host: session.host, port: session.port, underlying: error)
            state = .failed(error.localizedDescription)
            delegate?.terminalController(self, didChangeState: state)
            delegate?.terminalController(self, didFailWithError: sshError)
            throw sshError
        }
    }

    /// 断开连接
    func disconnect() async {
        userDisconnected = true

        // 取消重连
        reconnectTask?.cancel()
        reconnectTask = nil

        // 取消数据读取
        dataReadTask?.cancel()
        dataReadTask = nil

        // 关闭通道
        await channelManager?.close()
        channelManager = nil

        // 断开进程连接
        await processConnection?.disconnect()
        processConnection = nil

        // 断开 SSH 连接
        await connection?.disconnect()
        connection = nil

        state = .disconnected
        delegate?.terminalController(self, didChangeState: state)

        print("[TerminalController] 已断开连接")
    }

    /// 重新连接
    func reconnect() async throws {
        await disconnect()
        try await connect()
    }

    // MARK: - 数据传输（W8.4 输入回显）

    /// 发送数据到服务器
    /// - Parameter data: 要发送的数据
    func send(_ data: Data) async throws {
        guard state == .connected else {
            throw SSHError.sessionClosed
        }

        if useProcessBridge {
            try await processConnection?.write(data)
        } else {
            try await connection?.write(data)
        }
    }

    /// 发送字符串到服务器
    /// - Parameter string: 要发送的字符串
    func send(_ string: String) async throws {
        guard let data = string.data(using: .utf8) else {
            throw SSHError.libssh2Error(code: -1, message: "字符串编码失败")
        }
        try await send(data)
    }

    /// 发送控制字符
    /// - Parameter control: 控制字符（如 Ctrl+C = 0x03）
    func sendControl(_ control: UInt8) async throws {
        try await send(Data([control]))
    }

    /// 发送信号
    /// - Parameter signal: 信号名称
    func sendSignal(_ signal: String) async throws {
        try channelManager?.sendSignal(signal)
    }

    // MARK: - PTY 控制（W8.5 PTY resize）

    /// 调整 PTY 尺寸
    /// - Parameters:
    ///   - columns: 列数
    ///   - rows: 行数
    func resizePTY(columns: Int, rows: Int) async throws {
        guard state == .connected else { return }

        if useProcessBridge {
            await processConnection?.resizePTY(columns: columns, rows: rows)
        } else {
            try await connection?.resizePTY(columns: columns, rows: rows)
        }

        terminalSize = TerminalSize(columns: columns, rows: rows)

        print("[TerminalController] PTY 尺寸已调整: \(columns)x\(rows)")
    }

    // MARK: - 自动重连（W8.6）

    /// 判断是否应该自动重连
    private func shouldAutoReconnect(after error: SSHError) -> Bool {
        guard reconnectConfig.enabled && !userDisconnected else {
            return false
        }

        // 某些错误不应该重连
        switch error {
        case .authenticationFailed, .hostKeyVerificationFailed, .hostKeyChanged:
            // 认证或密钥问题，不自动重连
            return false
        case .connectionFailed, .connectionTimeout, .networkUnreachable, .sessionClosed:
            // 网络问题，可以重连
            return true
        default:
            return true
        }
    }

    /// 安排重连
    private func scheduleReconnect() {
        guard case .failed = state else { return }

        reconnectTask = Task { [weak self] in
            guard let self = self else { return }

            for attempt in 1...self.reconnectConfig.maxAttempts {
                guard !Task.isCancelled && !self.userDisconnected else { break }

                await MainActor.run {
                    self.state = .reconnecting(attempt: attempt)
                    self.delegate?.terminalController(self, didChangeState: self.state)
                    self.delegate?.terminalController(self, willReconnect: attempt, of: self.reconnectConfig.maxAttempts)
                }

                // 计算延迟（指数退避）
                let delay = self.reconnectConfig.delay(for: attempt)
                print("[TerminalController] 将在 \(delay) 秒后进行第 \(attempt) 次重连")

                // 等待
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard !Task.isCancelled && !self.userDisconnected else { break }

                // 尝试重连
                do {
                    try await self.connect()
                    print("[TerminalController] 重连成功")
                    return
                } catch {
                    print("[TerminalController] 第 \(attempt) 次重连失败: \(error.localizedDescription)")

                    if attempt == self.reconnectConfig.maxAttempts {
                        await MainActor.run {
                            self.state = .failed("重连失败：已达最大重试次数")
                            self.delegate?.terminalController(self, didChangeState: self.state)
                        }
                    }
                }
            }
        }
    }

    /// 取消重连
    func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil

        if case .reconnecting = state {
            state = .disconnected
            delegate?.terminalController(self, didChangeState: state)
        }
    }

    // MARK: - 数据读取

    /// 启动数据读取（进程桥接模式）
    private func startDataReadingFromProcess() {
        dataReadTask = Task { [weak self] in
            guard let self = self else { return }

            // 使用 SSHProcessConnection 的数据流
            guard let stream = await self.processConnection?.getDataStream() else {
                print("[TerminalController] 无法获取数据流")
                return
            }

            for await data in stream {
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    // 传递给终端视图
                    self.terminalView?.feed(data)

                    // 通知委托
                    self.delegate?.terminalController(self, didReceiveData: data)
                }
            }

            // 流结束，可能是连接断开
            if !Task.isCancelled && !self.userDisconnected {
                await MainActor.run {
                    self.handleConnectionLost()
                }
            }
        }
    }

    /// 启动数据读取（libssh2 模式）
    private func startDataReading() {
        dataReadTask = Task { [weak self] in
            guard let self = self else { return }

            // 使用 SSHConnection 的数据流
            let dataStream = await self.connection?.getDataStream()

            guard let stream = dataStream else { return }

            for await data in stream {
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    // 传递给终端视图
                    self.terminalView?.feed(data)

                    // 通知委托
                    self.delegate?.terminalController(self, didReceiveData: data)
                }
            }

            // 流结束，可能是连接断开
            if !Task.isCancelled && !self.userDisconnected {
                await MainActor.run {
                    self.handleConnectionLost()
                }
            }
        }
    }

    /// 处理连接丢失
    private func handleConnectionLost() {
        guard state == .connected else { return }

        state = .failed("连接已断开")
        delegate?.terminalController(self, didChangeState: state)

        // 尝试重连
        if reconnectConfig.enabled && !userDisconnected {
            scheduleReconnect()
        }
    }

    // MARK: - 私有方法

    /// 创建 SSH 配置
    private func createSSHConfig() -> SSHSessionConfig {
        var password: String? = nil
        var privateKeyPath: String? = nil
        var passphrase: String? = nil

        // 根据认证方式获取凭据
        switch session.authMethod {
        case .password:
            // 从 Keychain 获取密码
            password = try? KeychainService.shared.getPassword(for: session.id, type: .password)
        case .privateKey:
            privateKeyPath = session.privateKeyPath
            passphrase = try? KeychainService.shared.getPassword(for: session.id, type: .passphrase)
        case .sshAgent:
            break
        }

        return SSHSessionConfig(
            host: session.host,
            port: session.port,
            username: session.username,
            authMethod: session.authMethod,
            password: password,
            privateKeyPath: privateKeyPath,
            passphrase: passphrase,
            keepAliveInterval: session.keepAliveInterval,
            terminalColumns: terminalSize.columns,
            terminalRows: terminalSize.rows
        )
    }
}

// MARK: - TerminalViewDelegate 实现

extension TerminalController: TerminalViewDelegate {

    nonisolated func terminalView(_ view: ShellMateTerminalView, send data: Data) {
        Task { @MainActor in
            try? await send(data)
        }
    }

    nonisolated func terminalView(_ view: ShellMateTerminalView, send string: String) {
        Task { @MainActor in
            try? await send(string)
        }
    }

    nonisolated func terminalView(_ view: ShellMateTerminalView, sizeChanged newSize: TerminalSize) {
        Task { @MainActor in
            terminalSize = newSize
        }
    }

    nonisolated func terminalView(_ view: ShellMateTerminalView, titleChanged newTitle: String) {
        Task { @MainActor in
            delegate?.terminalController(self, didChangeTitle: newTitle)
        }
    }

    nonisolated func terminalViewBell(_ view: ShellMateTerminalView) {
        // 播放系统响铃
        NSSound.beep()
    }

    nonisolated func terminalView(_ view: ShellMateTerminalView, selectionChanged selection: String?) {
        // 选择变化，可以用于更新剪贴板
    }
}

// MARK: - State 扩展

extension TerminalController.State {
    /// 是否为失败状态
    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }

    /// 是否正在重连
    var isReconnecting: Bool {
        if case .reconnecting = self {
            return true
        }
        return false
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "正在连接..."
        case .connected:
            return "已连接"
        case .reconnecting(let attempt):
            return "正在重连 (\(attempt))..."
        case .failed(let reason):
            return "连接失败: \(reason)"
        }
    }

    /// 状态颜色
    var stateColor: ConnectionState {
        switch self {
        case .disconnected:
            return .offline
        case .connecting, .reconnecting:
            return .connecting
        case .connected:
            return .connected
        case .failed:
            return .error
        }
    }
}

// MARK: - 终端会话管理器

/// 终端会话管理器
/// 管理多个终端控制器实例
@MainActor
final class TerminalSessionManager: ObservableObject {

    // MARK: - 单例

    static let shared = TerminalSessionManager()

    // MARK: - 属性

    /// 活动的终端控制器
    @Published private(set) var controllers: [UUID: TerminalController] = [:]

    /// 当前选中的控制器 ID
    @Published var selectedControllerId: UUID?

    /// 最大同时连接数
    let maxConnections: Int = 10

    // MARK: - 初始化

    private init() {}

    // MARK: - 管理方法

    /// 创建新的终端控制器
    /// - Parameter session: 会话
    /// - Returns: 终端控制器
    func createController(for session: Session) throws -> TerminalController {
        guard controllers.count < maxConnections else {
            throw SSHError.libssh2Error(code: -1, message: "已达到最大连接数限制")
        }

        let controller = TerminalController(session: session)
        controllers[session.id] = controller

        // 自动选中新创建的控制器
        selectedControllerId = session.id

        return controller
    }

    /// 获取控制器
    /// - Parameter sessionId: 会话 ID
    /// - Returns: 终端控制器
    func getController(for sessionId: UUID) -> TerminalController? {
        return controllers[sessionId]
    }

    /// 关闭控制器
    /// - Parameter sessionId: 会话 ID
    func closeController(for sessionId: UUID) async {
        if let controller = controllers[sessionId] {
            await controller.disconnect()
            controllers.removeValue(forKey: sessionId)

            // 如果关闭的是当前选中的，选择另一个
            if selectedControllerId == sessionId {
                selectedControllerId = controllers.keys.first
            }
        }
    }

    /// 关闭所有控制器
    func closeAll() async {
        for (_, controller) in controllers {
            await controller.disconnect()
        }
        controllers.removeAll()
        selectedControllerId = nil
    }

    /// 当前选中的控制器
    var selectedController: TerminalController? {
        guard let id = selectedControllerId else { return nil }
        return controllers[id]
    }

    /// 活动连接数
    var activeConnectionCount: Int {
        return controllers.values.filter { $0.state == .connected }.count
    }
}
