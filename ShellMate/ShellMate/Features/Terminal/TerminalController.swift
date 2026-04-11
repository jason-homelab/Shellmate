import Foundation
import AppKit
import Combine
import Network
import SwiftTerm

// MARK: - 终端尺寸

/// 终端尺寸（列数 × 行数）
struct TerminalSize: Equatable {
    let columns: Int
    let rows: Int

    static let `default` = TerminalSize(columns: 80, rows: 24)
}

// MARK: - 终端数据合并器（W15.2 60fps 优化）

/// 将高频 SSH 数据包合并到 16ms 窗口后批量喂给 SwiftTerm
/// 防止每个 SSH 包单独创建 MainActor Task，避免主线程微任务积压
/// 原理：首个数据包触发一次 16ms sleep Task；窗口内后续包只追加缓冲区；
///       sleep 结束后一次性 flush 所有积累字节 → 最多 60fps
private actor TerminalDataCoalescer {

    private var buffer: [UInt8] = []
    private var hasPendingFlush = false

    /// 追加字节；返回 true 表示调用方需要调度一次 flush
    func append(_ bytes: [UInt8]) -> Bool {
        buffer.append(contentsOf: bytes)
        if hasPendingFlush { return false }
        hasPendingFlush = true
        return true
    }

    /// 取出并清空缓冲区，重置 flush 标志
    func drain() -> [UInt8] {
        hasPendingFlush = false
        let result = buffer
        buffer = []
        return result
    }
}

// MARK: - 终端控制器委托

/// 终端控制器委托协议
protocol TerminalControllerDelegate: AnyObject {
    func terminalController(_ controller: TerminalController, didChangeState state: TerminalController.State)
    func terminalController(_ controller: TerminalController, didReceiveData data: Data)
    func terminalController(_ controller: TerminalController, didReceiveErrorData data: Data)
    func terminalController(_ controller: TerminalController, didChangeTitle title: String)
    func terminalController(_ controller: TerminalController, didFailWithError error: SSHError)
    func terminalController(_ controller: TerminalController, willReconnect attempt: Int, of maxAttempts: Int)
}

// MARK: - 终端控制器

/// 终端控制器
/// 整合 SSH2Connection（libssh2）+ SwiftTerm 终端渲染 + 自动重连
@MainActor
final class TerminalController: ObservableObject {

    // MARK: - 类型定义

    enum State: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed(String)
    }

    /// 待确认的主机密钥状态
    enum PendingHostKeyState {
        /// 首次连接新主机（对应 D02 弹窗）
        case newHost(fingerprint: HostKeyFingerprint)
        /// 主机密钥已变更（对应 D03 弹窗）
        case changedHost(oldFingerprint: String, newFingerprint: HostKeyFingerprint)
    }

    struct ReconnectConfig {
        var enabled: Bool = true
        var maxAttempts: Int = 3
        var baseDelay: TimeInterval = 1.0
        var maxDelay: TimeInterval = 30.0
        var backoffFactor: Double = 2.0

        func delay(for attempt: Int) -> TimeInterval {
            let d = baseDelay * pow(backoffFactor, Double(attempt - 1))
            return min(d, maxDelay)
        }
    }

    // MARK: - 属性

    /// 会话配置
    private let session: Session

    /// 会话 ID 缓存（供 deinit 安全访问，避免在任意线程访问 Core Data 对象）
    private let sessionId: UUID

    /// libssh2 SSH 连接
    private var sshConnection: SSH2Connection?

    /// SwiftTerm 终端视图（弱引用，由 TerminalView 持有）
    weak var terminalView: SwiftTerm.TerminalView?

    @Published private(set) var state: State = .disconnected
    /// 连接成功时间（用于状态栏显示已连接时长）
    @Published private(set) var connectedAt: Date? = nil
    var reconnectConfig = ReconnectConfig()
    @Published var terminalSize: TerminalSize = .default
    @Published var terminalTitle: String = ""
    weak var delegate: TerminalControllerDelegate?

    /// 待用户确认的主机密钥状态（nil = 无待确认）
    @Published var pendingHostKeyState: PendingHostKeyState?

    /// 终端当前工作目录（由 OSC 7 序列更新，nil = 尚未感知）
    /// SFTP 面板观察此值实现目录同步
    @Published private(set) var currentRemoteDirectory: String? = nil

    /// 凭据缺失：需要用户通过向导输入密码（password / keyboard-interactive）
    @Published var needsCredentialInput: Bool = false
    /// 凭据缺失：私钥路径未配置，需要前往编辑会话
    @Published var needsCredentialEdit: Bool = false
    /// 临时密码（向导输入后一次性使用，connect() 读取后立即清空）
    private var temporaryPassword: String?

    /// ProxyJump 连接管理器（多跳场景使用）
    private var proxyJumpManager: ProxyJumpManager?

    /// SFTP 会话（独立 SSH 连接）
    @Published var sftpSession: SFTPSession?

    /// SFTP 传输队列
    @Published var sftpTransferQueue: SFTPTransferQueue?

    /// SFTP 面板是否显示
    @Published var isSFTPPanelOpen: Bool = false

    /// 端口转发隧道管理器
    let tunnelManager = TunnelManager()

    /// 隧道管理器面板是否显示
    @Published var isTunnelManagerOpen: Bool = false

    /// tmux 会话状态管理器（懒初始化，需要 self 已准备好）
    private(set) lazy var tmuxStore: TmuxSessionStore = TmuxSessionStore(sessionId: sessionId, sendTarget: self)

    /// Compose Pane 是否显示
    @Published var isComposePaneOpen: Bool = false

    /// AI 命令补全上下文缓冲（最近 N 行终端输出，任务 14.8）
    private var _outputBuffer: String = ""
    private let _outputBufferMaxChars = 8_000   // ~50 行 × 160 字符

    /// 返回最近终端输出（供 AI 命令补全使用）
    func recentTerminalOutput() -> String {
        _outputBuffer
    }

    /// 服务器实时性能指标（仅私钥/SSH Agent 认证时可用）
    @Published private(set) var serverMetrics: ServerMetrics?

    /// 服务器指标监控器
    private var metricsMonitor: ServerMetricsMonitor?

    // MARK: - 会话日志（terminal.loggingEnabled）

    /// 当前会话的日志文件句柄（lazy，首次写入时创建）
    private var sessionLogHandle: FileHandle?
    /// 是否已打开日志文件（避免重复尝试）
    private var sessionLogOpened = false

    /// 将原始终端字节追加到日志文件（仅 terminal.loggingEnabled=true 时生效）
    private func appendToSessionLog(_ bytes: [UInt8]) {
        let enabled = UserDefaults.standard.object(forKey: "terminal.loggingEnabled") as? Bool ?? false
        guard enabled else { return }

        if !sessionLogOpened {
            sessionLogOpened = true
            sessionLogHandle = openSessionLogFile()
        }
        guard let handle = sessionLogHandle else { return }
        let data = Data(bytes)
        try? handle.write(contentsOf: data)
    }

    /// 创建并打开会话日志文件，返回 FileHandle
    private func openSessionLogFile() -> FileHandle? {
        var logDir = UserDefaults.standard.string(forKey: "terminal.logDirectory") ?? "~/Documents/ShellMate/Logs/"
        logDir = (logDir as NSString).expandingTildeInPath

        var fmt = UserDefaults.standard.string(forKey: "terminal.logFilenameFormat") ?? "{session}_{date}.log"
        let dateStr = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd_HHmmss"
            return f.string(from: Date())
        }()
        fmt = fmt
            .replacingOccurrences(of: "{session}", with: session.name.replacingOccurrences(of: "/", with: "-"))
            .replacingOccurrences(of: "{date}", with: dateStr)
            .replacingOccurrences(of: "{host}", with: session.host)

        let url = URL(fileURLWithPath: logDir).appendingPathComponent(fmt)
        do {
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: logDir),
                                                    withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            return try FileHandle(forWritingTo: url)
        } catch {
            AppLogger.general.debug("[SessionLog] 无法创建日志文件 \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - AI 错误侦探

    /// 最近检测到的错误摘要文本（非 nil 时显示错误徽章）
    @Published private(set) var detectedErrorText: String? = nil

    /// 用于错误检测的输出滚动缓冲区（最近 1024 字节）
    private var errorOutputBuffer: String = ""

    private static let errorPatterns: [String] = [
        "command not found", "No such file or directory", "Permission denied",
        "Connection refused", "No route to host",
        ": error:", "Error:", "ERROR:", "FATAL:", "fatal error:",
        "Traceback (most recent call last)", "npm ERR!", "yarn error",
        "SyntaxError:", "NameError:", "TypeError:", "ValueError:",
        "ModuleNotFoundError:", "ImportError:", "FileNotFoundError:",
        "Exception in thread main",
    ]

    /// 清除已检测的错误（用户手动关闭徽章后调用）
    func clearDetectedError() {
        detectedErrorText = nil
        errorOutputBuffer = ""
    }

    /// 追加终端输出到 AI 补全上下文缓冲，保持最大长度（任务 14.8）
    private func appendToOutputBuffer(_ text: String) {
        guard !text.isEmpty else { return }
        _outputBuffer += text
        if _outputBuffer.count > _outputBufferMaxChars {
            _outputBuffer = String(_outputBuffer.suffix(_outputBufferMaxChars))
        }
    }

    private func detectErrors(in text: String) {
        errorOutputBuffer += text
        if errorOutputBuffer.count > 1024 {
            errorOutputBuffer = String(errorOutputBuffer.suffix(1024))
        }
        let stripped = stripANSI(errorOutputBuffer)
        let lines = stripped.components(separatedBy: "\n")
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if Self.errorPatterns.contains(where: { trimmed.contains($0) }) {
                if trimmed != detectedErrorText {
                    detectedErrorText = String(trimmed.prefix(120))
                }
                return
            }
        }
    }

    private func stripANSI(_ str: String) -> String {
        let pattern = "\u{1B}\\[[0-9;]*[A-Za-z]|\u{1B}\\][^\u{0007}]*\u{0007}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return str }
        let range = NSRange(str.startIndex..., in: str)
        return regex.stringByReplacingMatches(in: str, options: [], range: range, withTemplate: "")
    }

    private var reconnectTask: Task<Void, Never>?
    private var userDisconnected = false
    private var cancellables = Set<AnyCancellable>()

    /// TC-005：网络路径监控（网络恢复时自动触发重连）
    private var networkMonitor: NWPathMonitor?
    private var lastNetworkStatus: NWPath.Status = .requiresConnection

    // MARK: - 初始化

    init(session: Session) {
        self.session = session
        self.sessionId = session.id
        setupObservers()
        startNetworkMonitoring()
        // W12.6：注册到同步输入管理器
        SyncInputStore.shared.register(self, for: session.id)
    }

    deinit {
        let id = sessionId
        Task { @MainActor in
            SyncInputStore.shared.unregister(sessionId: id)
        }
        Task { [weak self] in
            await self?.disconnect()
        }
    }

    /// W12.6：供外部查询的会话标题（用于 SyncInputStore.SessionInfo）
    var sessionTitle: String { session.name }

    private func setupObservers() {
        $terminalSize
            .removeDuplicates()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] newSize in
                guard let self = self else { return }
                self.sshConnection?.resizeTerminal(cols: newSize.columns, rows: newSize.rows)
                if let pm = self.proxyJumpManager {
                    Task { await pm.resizeTerminal(cols: newSize.columns, rows: newSize.rows) }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 连接管理

    func connect() async throws {
        guard state == .disconnected || state.isFailed else { return }

        // 凭据预检查：根据认证方式决定是否需要向导或编辑
        switch session.authMethod {
        case .password, .keyboardInteractive:
            let hasCred = await CredentialVault.shared.exists(sessionId: session.id, type: .password)
            if !hasCred && temporaryPassword == nil {
                needsCredentialInput = true
                return
            }
        case .privateKey:
            if session.privateKeyPath == nil || (session.privateKeyPath?.isEmpty ?? true) {
                needsCredentialEdit = true
                return
            }
        case .sshAgent:
            break
        }

        userDisconnected = false
        pendingHostKeyState = nil
        state = .connecting
        delegate?.terminalController(self, didChangeState: state)

        // 若有跳板机，走 ProxyJump 路径
        if !session.jumpHosts.isEmpty {
            try await connectViaProxyJump()
            return
        }

        // 从凭据金库读取凭据（向导输入的临时密码优先）
        let password: String?
        if let tempPass = temporaryPassword {
            password = tempPass
            temporaryPassword = nil
        } else {
            password = try? await CredentialVault.shared.load(sessionId: session.id, type: .password)
        }
        let passphrase = try? await CredentialVault.shared.load(sessionId: session.id, type: .passphrase)
        let privateKeyPath = session.privateKeyPath
        let authMethod = session.authMethod
        let host = session.host
        let port = session.port
        let username = session.username
        let cols = terminalSize.columns
        let rows = terminalSize.rows

        // 构建 SSHSessionConfig 供 TunnelManager 使用
        let sessionConfig = SSHSessionConfig(
            host: host, port: port, username: username, authMethod: authMethod,
            password: password, privateKeyPath: privateKeyPath, passphrase: passphrase
        )

        let conn = SSH2Connection()

        // W15.2：每条连接独享一个合并器，闭包直接捕获 actor 引用（无需主 Actor 跳转）
        let coalescer = TerminalDataCoalescer()

        // 数据回调：SSH 读取线程直接触发，通过 coalescer 将高频包合并到 16ms 窗口
        // 每个窗口只创建一次 MainActor.run，避免主线程微任务积压
        conn.onDataReceived = { [weak self] data in
            let bytes = [UInt8](data)
            Task { [weak self] in
                // append 在 TerminalDataCoalescer actor 上执行，不占用主线程
                let shouldFlush = await coalescer.append(bytes)
                guard shouldFlush else { return }
                // 窗口期：16ms ≈ 1 帧 @ 60fps
                try? await Task.sleep(nanoseconds: AppConstants.terminalCoalescerIntervalNs)
                let flushed = await coalescer.drain()
                guard !flushed.isEmpty else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    // 智能过滤：仅在 tmux 收集阶段或数据含标记时进行行级处理；
                    // 其余情况直接透传原始字节，避免 UTF-8 转换丢失数据或引入多余 \n
                    if let text = String(bytes: flushed, encoding: .utf8),
                       self.tmuxStore.isInCollectionMode || text.contains("__SM_TMUX_") {
                        // 行过滤路径：逐行判断是否为 tmux 标记/收集数据
                        // 被过滤行分两类：
                        //   - 纯标记行（__SM_TMUX_ 开头）或收集阶段数据行 → 完全丢弃
                        //   - 命令回显行（含标记但有其他前缀，如 shell 提示符）→ 只输出 \r 使
                        //     光标回到行首，下一个 prompt 覆写同行，不产生多余空行或重复 prompt
                        var terminalBytes: [UInt8] = []
                        let parts = text.components(separatedBy: "\n")
                        for (i, line) in parts.enumerated() {
                            let wasCollecting = self.tmuxStore.isInCollectionMode
                            if !self.tmuxStore.filterLine(line) {
                                terminalBytes.append(contentsOf: Array(line.utf8))
                                if i < parts.count - 1 {
                                    terminalBytes.append(UInt8(ascii: "\n"))
                                }
                            } else {
                                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                // 命令回显行：非纯标记、非收集阶段、非空行
                                if !trimmed.hasPrefix("__SM_TMUX_") && !wasCollecting && !trimmed.isEmpty {
                                    terminalBytes.append(UInt8(ascii: "\r"))
                                }
                            }
                        }
                        guard !terminalBytes.isEmpty else { return }
                        let processed = HighlightEngine.shared.process(Data(terminalBytes))
                        self.terminalView?.feed(byteArray: [UInt8](processed)[...])
                        self.delegate?.terminalController(self, didReceiveData: Data(terminalBytes))
                        self.appendToSessionLog(terminalBytes)
                        let decoded = String(bytes: terminalBytes, encoding: .utf8) ?? ""
                        self.appendToOutputBuffer(decoded)
                        if AISettingsStore.shared.isEnabled && AISettingsStore.shared.errorDetectiveEnabled {
                            self.detectErrors(in: decoded)
                        }
                    } else {
                        // 直接透传路径：保留原始字节（含非 UTF-8 字符），性能最优
                        let processed = HighlightEngine.shared.process(Data(flushed))
                        self.terminalView?.feed(byteArray: [UInt8](processed)[...])
                        self.delegate?.terminalController(self, didReceiveData: Data(flushed))
                        self.appendToSessionLog(flushed)
                        let decoded2 = String(bytes: flushed, encoding: .utf8) ?? ""
                        self.appendToOutputBuffer(decoded2)
                        if AISettingsStore.shared.isEnabled && AISettingsStore.shared.errorDetectiveEnabled {
                            self.detectErrors(in: decoded2)
                        }
                    }
                }
            }
        }

        // 断开回调
        conn.onDisconnected = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleConnectionLost()
            }
        }

        // 主机密钥验证回调（在握手后、认证前同步调用）
        // host/port 为值类型，在 Task.detached 内安全访问
        conn.onVerifyHostKey = { fingerprint in
            let result = KnownHostsManager.shared.check(
                host: host,
                port: port,
                fingerprint: fingerprint
            )
            switch result {
            case .match:
                return
            case .notFound:
                // 将指纹携带在 error 中传回 MainActor
                throw SSHError.hostKeyUnknown(fingerprint)
            case .mismatch(let existing):
                throw SSHError.hostKeyChanged(
                    oldFingerprint: existing.fingerprint,
                    newFingerprint: fingerprint
                )
            case .failure:
                return // 校验失败时放行，不阻止连接
            }
        }

        self.sshConnection = conn

        do {
            // SSH2Connection 的 connect 方法会阻塞，在后台线程运行
            try await Task.detached(priority: .userInitiated) {
                switch authMethod {
                case .password:
                    guard let pass = password else {
                        throw SSHError.authenticationFailed(method: "password", reason: "密码未提供")
                    }
                    try conn.connect(host: host, port: port, username: username, password: pass)
                    conn.resizeTerminal(cols: cols, rows: rows)

                case .privateKey:
                    guard let keyPath = privateKeyPath, !keyPath.isEmpty else {
                        throw SSHError.invalidPrivateKey(reason: "未提供私钥路径")
                    }
                    try conn.connectWithKey(
                        host: host,
                        port: port,
                        username: username,
                        privateKeyPath: keyPath,
                        passphrase: passphrase
                    )
                    conn.resizeTerminal(cols: cols, rows: rows)

                case .sshAgent:
                    try conn.connectWithAgent(host: host, port: port, username: username)
                    conn.resizeTerminal(cols: cols, rows: rows)

                case .keyboardInteractive:
                    // keyboard-interactive 底层复用密码认证通道
                    guard let pass = password else {
                        throw SSHError.authenticationFailed(method: "keyboard-interactive", reason: "密码未提供")
                    }
                    try conn.connect(host: host, port: port, username: username, password: pass)
                    conn.resizeTerminal(cols: cols, rows: rows)
                }
            }.value

            state = .connected
            connectedAt = Date()
            delegate?.terminalController(self, didChangeState: state)
            // 连接成功后通知 TunnelManager，触发 autoStart 规则
            tunnelManager.handleSSHConnected(config: sessionConfig, sessionID: session.id)
            // 启动性能指标轮询
            startMetricsMonitor()
            // 12.10：连接后自动执行 Login Script（延迟 1.0s 等待 shell 就绪）
            executeStartupCommandIfNeeded()
            // tmux 可用性检测（延迟 1.5s 等待 shell 完成 MOTD 初始化输出）
            let tmuxCfg = TmuxConfigStore.load(sessionId: sessionId)
            if tmuxCfg.enabled {
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run { self?.tmuxStore.detectTmux() }
                }
            }

        } catch let error as SSHError {
            switch error {
            case .hostKeyUnknown(let fingerprint):
                // D02: 新主机，等待用户确认，不标记为 failed
                pendingHostKeyState = .newHost(fingerprint: fingerprint)
                state = .disconnected
                delegate?.terminalController(self, didChangeState: state)
                return
            case .hostKeyChanged(let oldFP, let newFP):
                // D03: 密钥变更，标记为 failed + 显示安全警告
                pendingHostKeyState = .changedHost(oldFingerprint: oldFP, newFingerprint: newFP)
                state = .failed(error.localizedDescription)
                delegate?.terminalController(self, didChangeState: state)
                delegate?.terminalController(self, didFailWithError: error)
                return
            default:
                state = .failed(error.localizedDescription)
                delegate?.terminalController(self, didChangeState: state)
                delegate?.terminalController(self, didFailWithError: error)
                if shouldAutoReconnect(after: error) { scheduleReconnect() }
                throw error
            }
        } catch {
            let sshError = SSHError.connectionFailed(host: session.host, port: session.port, underlying: error)
            state = .failed(error.localizedDescription)
            delegate?.terminalController(self, didChangeState: state)
            delegate?.terminalController(self, didFailWithError: sshError)
            throw sshError
        }
    }

    /// 用户通过向导输入密码后调用：临时存入密码并触发连接
    /// - Parameters:
    ///   - password: 用户在向导中输入的密码
    ///   - save: 是否持久化到本地凭据金库
    func connectWithTemporaryPassword(_ password: String, save: Bool) async throws {
        if save {
            try? await CredentialVault.shared.save(password, sessionId: session.id, type: .password)
        }
        temporaryPassword = password
        needsCredentialInput = false
        try await connect()
    }

    func disconnect() async {
        userDisconnected = true
        reconnectTask?.cancel()
        reconnectTask = nil
        sshConnection?.disconnect()
        sshConnection = nil
        if let pm = proxyJumpManager {
            await pm.disconnect()
            proxyJumpManager = nil
        }
        // 断开时同步关闭 SFTP 会话
        await closeSFTPPanel()
        // 断开时停止所有隧道
        tunnelManager.handleSSHDisconnected()
        // 停止性能指标监控
        stopMetricsMonitor()
        // 通知 tmux 状态管理器清理状态
        tmuxStore.handleSSHDisconnected()
        // 关闭会话日志文件句柄
        try? sessionLogHandle?.close()
        sessionLogHandle = nil
        sessionLogOpened = false
        state = .disconnected
        connectedAt = nil
        delegate?.terminalController(self, didChangeState: state)
    }

    // MARK: - 性能指标监控

    private func startMetricsMonitor() {
        Task {
            // 从凭据金库加载认证凭据，传入监控器（安全只在内存中使用）
            let password = try? await CredentialVault.shared.load(sessionId: session.id, type: .password)
            let passphrase = try? await CredentialVault.shared.load(sessionId: session.id, type: .passphrase)

            let monitor = ServerMetricsMonitor(
                session: session,
                password: password,
                passphrase: passphrase
            )
            monitor.onUpdate = { [weak self] metrics in
                self?.serverMetrics = metrics
            }
            metricsMonitor = monitor
            monitor.start()
        }
    }

    private func stopMetricsMonitor() {
        metricsMonitor?.stop()
        metricsMonitor = nil
        serverMetrics = nil
    }

    // MARK: - SFTP 面板管理

    /// 打开 SFTP 面板（建立独立 SFTP 连接）
    func openSFTPPanel() async throws {
        guard state == .connected else { throw SSHError.sessionClosed }
        guard sftpSession == nil else {
            // 已连接，仅显示面板
            isSFTPPanelOpen = true
            return
        }

        // 从凭据金库读取凭据
        let password = try? await CredentialVault.shared.load(sessionId: session.id, type: .password)
        let passphrase = try? await CredentialVault.shared.load(sessionId: session.id, type: .passphrase)

        let newSFTPSession = SFTPSession()
        try await newSFTPSession.connect(
            host: session.host,
            port: session.port,
            username: session.username,
            authMethod: session.authMethod,
            password: password,
            privateKeyPath: session.privateKeyPath,
            passphrase: passphrase
        )

        sftpSession = newSFTPSession
        sftpTransferQueue = SFTPTransferQueue(sftpSession: newSFTPSession)
        isSFTPPanelOpen = true
        AppLogger.general.debug("[TerminalController] SFTP 面板已打开")
    }

    /// 关闭 SFTP 面板
    func closeSFTPPanel() async {
        if let session = sftpSession {
            await session.disconnect()
        }
        sftpSession = nil
        sftpTransferQueue = nil
        isSFTPPanelOpen = false
    }

    func reconnect() async throws {
        await disconnect()
        try await connect()
    }

    // MARK: - 主机密钥确认（D02 / D03）

    /// 用户接受新主机的密钥（D02 确认后调用）
    func acceptNewHostKey() {
        guard case .newHost(let fingerprint) = pendingHostKeyState else { return }
        try? KnownHostsManager.shared.add(
            host: session.host,
            port: session.port,
            fingerprint: fingerprint
        )
        pendingHostKeyState = nil
        Task { try? await connect() }
    }

    /// 用户接受密钥变更并继续连接（D03 高风险操作）
    func acceptChangedHostKey() {
        guard case .changedHost(_, let newFP) = pendingHostKeyState else { return }
        // 更新 KnownHosts 为新密钥
        try? KnownHostsManager.shared.add(
            host: session.host,
            port: session.port,
            fingerprint: newFP
        )
        pendingHostKeyState = nil
        state = .disconnected
        Task { try? await connect() }
    }

    /// 用户拒绝主机密钥（D02 / D03 取消）
    func rejectHostKey() {
        pendingHostKeyState = nil
        state = .disconnected
        delegate?.terminalController(self, didChangeState: state)
    }

    // MARK: - ProxyJump 连接

    /// 通过跳板机链连接目标服务器（9.1/9.2 ProxyJump）
    private func connectViaProxyJump() async throws {
        let password = try? await CredentialVault.shared.load(sessionId: session.id, type: .password)
        let passphrase = try? await CredentialVault.shared.load(sessionId: session.id, type: .passphrase)

        // 预加载各跳板机密码（异步，避免同步连接阶段调用 Keychain/Vault）
        var resolvedChain: [ProxyJumpConfig] = []
        for var hop in session.jumpHosts {
            if let vid = hop.vaultId {
                hop.resolvedPassword = try? await CredentialVault.shared.load(
                    sessionId: vid, type: .password
                )
            }
            resolvedChain.append(hop)
        }

        var targetConfig = SSHSessionConfig.from(
            session: session,
            password: password,
            passphrase: passphrase
        )
        targetConfig.terminalColumns = terminalSize.columns
        targetConfig.terminalRows = terminalSize.rows

        let manager = ProxyJumpManager(
            proxyChain: resolvedChain,
            targetConfig: targetConfig
        )

        do {
            try await manager.connect()
        } catch {
            let sshError: SSHError
            if let e = error as? SSHError {
                sshError = e
            } else {
                sshError = SSHError.connectionFailed(host: session.host, port: session.port, underlying: error)
            }
            state = .failed(sshError.localizedDescription)
            delegate?.terminalController(self, didChangeState: state)
            delegate?.terminalController(self, didFailWithError: sshError)
            throw sshError
        }

        proxyJumpManager = manager

        // 将数据流桥接到 SwiftTerm（W12.4 高亮 + W15.2 ProxyJump 路径合并器）
        if let stream = await manager.getDataStream() {
            Task { [weak self] in
                let coalescer = TerminalDataCoalescer()
                for await data in stream {
                    guard self != nil else { return }
                    let bytes = [UInt8](data)
                    let shouldFlush = await coalescer.append(bytes)
                    guard shouldFlush else { continue }
                    try? await Task.sleep(nanoseconds: AppConstants.terminalCoalescerIntervalNs)
                    let flushed = await coalescer.drain()
                    guard !flushed.isEmpty else { continue }
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        // ProxyJump 路径：同样使用智能过滤
                        if let text = String(bytes: flushed, encoding: .utf8),
                           self.tmuxStore.isInCollectionMode || text.contains("__SM_TMUX_") {
                            var terminalBytes: [UInt8] = []
                            let parts = text.components(separatedBy: "\n")
                            for (i, line) in parts.enumerated() {
                                let wasCollecting = self.tmuxStore.isInCollectionMode
                                if !self.tmuxStore.filterLine(line) {
                                    terminalBytes.append(contentsOf: Array(line.utf8))
                                    if i < parts.count - 1 {
                                        terminalBytes.append(UInt8(ascii: "\n"))
                                    }
                                } else {
                                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.hasPrefix("__SM_TMUX_") && !wasCollecting && !trimmed.isEmpty {
                                        terminalBytes.append(UInt8(ascii: "\r"))
                                    }
                                }
                            }
                            guard !terminalBytes.isEmpty else { return }
                            let processed = HighlightEngine.shared.process(Data(terminalBytes))
                            self.terminalView?.feed(byteArray: [UInt8](processed)[...])
                        } else {
                            let processed = HighlightEngine.shared.process(Data(flushed))
                            self.terminalView?.feed(byteArray: [UInt8](processed)[...])
                        }
                    }
                }
            }
        }

        state = .connected
        connectedAt = Date()
        delegate?.terminalController(self, didChangeState: state)
        // 启动性能指标轮询（ProxyJump 路径）
        startMetricsMonitor()
        // 12.10：连接后自动执行 Login Script（ProxyJump 路径）
        executeStartupCommandIfNeeded()
        // tmux 可用性检测（ProxyJump 路径，同样延迟 1.5s）
        let tmuxCfgPJ = TmuxConfigStore.load(sessionId: sessionId)
        if tmuxCfgPJ.enabled {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { self?.tmuxStore.detectTmux() }
            }
        }
    }

    // MARK: - 数据传输

    func send(_ data: Data) async throws {
        guard state == .connected else {
            throw SSHError.sessionClosed
        }
        if let pm = proxyJumpManager {
            try await pm.write(data)
        } else {
            guard let conn = sshConnection else {
                throw SSHError.sessionClosed
            }
            try await Task.detached(priority: .userInitiated) {
                try conn.write(data)
            }.value
        }
        // W12.6：将输入广播到同步组中的其他终端
        SyncInputStore.shared.broadcast(data: data, from: sessionId)
    }

    /// 12.10：连接成功后自动执行 Login Script（startupCommand）
    /// 延迟 1.0s 等待 shell 完成 MOTD/初始化输出，然后逐行发送命令
    private func executeStartupCommandIfNeeded() {
        guard let cmd = session.startupCommand, !cmd.isEmpty else { return }
        Task { [weak self] in
            // 等待 1.0s，确保 shell 已就绪（MOTD 输出完毕）
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, self.state == .connected else { return }
            // 逐行发送，每行末尾附加换行符
            let lines = cmd.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let toSend = line + "\n"
                guard let data = toSend.data(using: .utf8) else { continue }
                try? await self.send(data)
                // 多行命令之间添加 100ms 间隔，避免 shell 缓冲区溢出
                if index < lines.count - 1 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            AppLogger.ssh.info("[\(self.session.name)] Login Script 执行完毕（\(lines.count) 行）")
        }
    }

    /// W12.6：接收来自同步组其他终端的广播输入，直接写入 SSH（不再二次广播）
    func broadcastReceive(data: Data) {
        Task {
            guard state == .connected else { return }
            do {
                if let pm = proxyJumpManager {
                    try await pm.write(data)
                } else if let conn = sshConnection {
                    try await Task.detached(priority: .userInitiated) {
                        try conn.write(data)
                    }.value
                }
            } catch {
                AppLogger.general.debug("[SyncInput] 广播接收写入失败: \(error.localizedDescription)")
            }
        }
    }

    func send(_ string: String) async throws {
        guard let data = string.data(using: .utf8) else {
            throw SSHError.libssh2Error(code: -1, message: "字符串编码失败")
        }
        try await send(data)
    }

    func sendControl(_ control: UInt8) async throws {
        try await send(Data([control]))
    }

    // MARK: - Compose Pane

    /// 发送 Compose Pane 中的命令内容到当前终端
    func sendComposeContent(_ text: String) {
        Task { try? await send(text) }
    }

    /// 发送快捷命令到当前终端（支持逐行模式）
    func sendQuickCommand(_ command: QuickCommand) {
        let lines = command.content.components(separatedBy: "\n")
        if command.sendLineByLine && lines.count > 1 {
            Task { [weak self] in
                guard let self else { return }
                for (index, line) in lines.enumerated() {
                    if index > 0 {
                        let delayNs = UInt64(command.lineDelay) * 1_000_000
                        try? await Task.sleep(nanoseconds: delayNs)
                    }
                    let content = command.appendNewline ? line + "\r" : line
                    try? await self.send(content)
                }
            }
        } else {
            let content = command.appendNewline ? command.content + "\r" : command.content
            Task { try? await send(content) }
        }
    }

    // MARK: - 隧道管理器面板

    func openTunnelManager() {
        isTunnelManagerOpen = true
    }

    func closeTunnelManager() {
        isTunnelManagerOpen = false
    }

    // MARK: - 终端操作

    /// 清屏：向本地 SwiftTerm 发送 RIS（Reset to Initial State）
    func clearTerminal() {
        let bytes = [UInt8]("\u{1B}c".utf8)
        terminalView?.feed(byteArray: bytes[...])
    }

    // MARK: - PTY 控制

    func resizePTY(columns: Int, rows: Int) {
        guard state == .connected else { return }
        sshConnection?.resizeTerminal(cols: columns, rows: rows)
        if let pm = proxyJumpManager {
            Task { await pm.resizeTerminal(cols: columns, rows: rows) }
        }
        terminalSize = TerminalSize(columns: columns, rows: rows)
    }

    // MARK: - 自动重连

    func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        if case .reconnecting = state {
            state = .disconnected
            delegate?.terminalController(self, didChangeState: state)
        }
    }

    /// W12.3：检查本设备是否缺少凭据（iCloud 同步后首次连接场景）
    private func shouldAutoReconnect(after error: SSHError) -> Bool {
        guard reconnectConfig.enabled && !userDisconnected else { return false }
        switch error {
        case .authenticationFailed, .hostKeyVerificationFailed, .hostKeyChanged:
            return false
        default:
            return true
        }
    }

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
                let delay = self.reconnectConfig.delay(for: attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled && !self.userDisconnected else { break }
                do {
                    try await self.connect()
                    return
                } catch {
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

    private func handleConnectionLost() {
        guard state == .connected else { return }
        tmuxStore.handleSSHDisconnected()
        state = .failed("连接已断开")
        delegate?.terminalController(self, didChangeState: state)
        if reconnectConfig.enabled && !userDisconnected { scheduleReconnect() }
    }

    /// TC-005：启动网络路径监控，网络恢复时自动触发重连
    private func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let newStatus = path.status
                defer { self.lastNetworkStatus = newStatus }
                guard newStatus == .satisfied,
                      self.lastNetworkStatus != .satisfied,
                      self.reconnectConfig.enabled,
                      !self.userDisconnected,
                      self.reconnectTask == nil else { return }
                if case .failed = self.state { self.scheduleReconnect() }
                else if case .disconnected = self.state { self.scheduleReconnect() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.shellmate.networkmonitor", qos: .utility))
    }
}

// MARK: - TmuxSendTarget

extension TerminalController: TmuxSendTarget {
    /// 发送 tmux 内部命令：直接写入 SSH 连接，不经过 SyncInputStore 广播
    func sendTmuxCommand(_ command: String) {
        guard let data = command.data(using: .utf8) else { return }
        Task {
            guard state == .connected else { return }
            if let pm = proxyJumpManager {
                try? await pm.write(data)
            } else if let conn = sshConnection {
                try? await Task.detached(priority: .userInitiated) {
                    try conn.write(data)
                }.value
            }
        }
    }
}

// MARK: - SwiftTerm TerminalViewDelegate

extension TerminalController: SwiftTerm.TerminalViewDelegate {

    nonisolated func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        let d = Data(data)
        Task { @MainActor in
            try? await send(d)
        }
    }

    nonisolated func scrolled(source: SwiftTerm.TerminalView, position: Double) {}

    nonisolated func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {
        Task { @MainActor in
            self.terminalTitle = title
            delegate?.terminalController(self, didChangeTitle: title)
        }
    }

    nonisolated func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
        Task { @MainActor in
            terminalSize = TerminalSize(columns: newCols, rows: newRows)
        }
    }

    nonisolated func bell(source: SwiftTerm.TerminalView) {
        // 默认 true；UserDefaults.object 为 nil 表示未设置，则遵从默认值
        let enabled = UserDefaults.standard.object(forKey: "terminal.bellEnabled") as? Bool ?? true
        guard enabled else { return }
        let visual = UserDefaults.standard.bool(forKey: "terminal.visualBell")
        if visual {
            Task { @MainActor in
                source.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    source.layer?.backgroundColor = .clear
                }
            }
        } else {
            NSSound.beep()
        }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
        // OSC 7 序列：shells 在 cd 后发出 \e]7;file://host/path\a
        // directory 可能是 "file:///home/user" 或 "/home/user"
        guard let raw = directory, !raw.isEmpty else { return }
        let path: String
        if raw.hasPrefix("file://") {
            // 去掉 file://host 或 file:// 前缀，保留 path 部分
            if let url = URL(string: raw), !url.path.isEmpty {
                path = url.path
            } else {
                path = raw
            }
        } else {
            path = raw
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.currentRemoteDirectory != path {
                self.currentRemoteDirectory = path
                AppLogger.ssh.debug("[PWD] OSC-7 目录更新: \(path)")
            }
        }
    }

    nonisolated func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {}

    nonisolated func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}

    nonisolated func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {}

    nonisolated func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {}

    nonisolated func mouseModeChanged(source: SwiftTerm.TerminalView) {}
}

// MARK: - State 扩展

extension TerminalController.State {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }

    var displayName: String {
        switch self {
        case .disconnected:  return "未连接"
        case .connecting:    return "正在连接..."
        case .connected:     return "已连接"
        case .reconnecting(let attempt): return "正在重连 (\(attempt))..."
        case .failed(let reason): return "连接失败: \(reason)"
        }
    }

    var stateColor: ConnectionState {
        switch self {
        case .disconnected:        return .offline
        case .connecting, .reconnecting: return .connecting
        case .connected:           return .connected
        case .failed:              return .error
        }
    }
}

// MARK: - 终端会话管理器

@MainActor
final class TerminalSessionManager: ObservableObject {

    static let shared = TerminalSessionManager()

    @Published private(set) var controllers: [UUID: TerminalController] = [:]
    @Published var selectedControllerId: UUID?

    let maxConnections: Int = 10

    private init() {}

    func createController(for session: Session) throws -> TerminalController {
        guard controllers.count < maxConnections else {
            throw SSHError.libssh2Error(code: -1, message: "已达到最大连接数限制")
        }
        let controller = TerminalController(session: session)
        controllers[session.id] = controller
        selectedControllerId = session.id
        return controller
    }

    func getController(for sessionId: UUID) -> TerminalController? {
        controllers[sessionId]
    }

    func closeController(for sessionId: UUID) async {
        if let controller = controllers[sessionId] {
            await controller.disconnect()
            controllers.removeValue(forKey: sessionId)
            if selectedControllerId == sessionId {
                selectedControllerId = controllers.keys.first
            }
        }
    }

    func closeAll() async {
        for (_, controller) in controllers { await controller.disconnect() }
        controllers.removeAll()
        selectedControllerId = nil
    }

    var selectedController: TerminalController? {
        guard let id = selectedControllerId else { return nil }
        return controllers[id]
    }

    var activeConnectionCount: Int {
        controllers.values.filter { $0.state == .connected }.count
    }
}
