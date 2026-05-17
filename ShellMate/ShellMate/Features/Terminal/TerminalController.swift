import Foundation
import AppKit
import Combine
import Network
import SwiftTerm

// 支撑类型已迁至 TerminalControllerTypes.swift：
//   TerminalSize / TerminalDataCoalescer / TerminalControllerDelegate

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

    /// 会话配置（internal：RecordingDialogView 通过 activeController.session.name 访问）
    let session: Session

    /// 会话 ID 缓存（供 deinit 安全访问，避免在任意线程访问 Core Data 对象）
    let sessionId: UUID

    /// libssh2 SSH 连接
    var sshConnection: SSH2Connection?
    /// Telnet 连接（connectionType == .telnet 时使用）
    var telnetConnection: TelnetConnection?
    /// 串口连接（connectionType == .serial 时使用）
    var serialConnection: SerialConnection?

    /// SwiftTerm 终端视图（弱引用，由 TerminalView 持有）
    weak var terminalView: SwiftTerm.TerminalView?

    @Published var state: State = .disconnected
    /// 连接成功时间（用于状态栏显示已连接时长）
    @Published var connectedAt: Date? = nil
    /// TCP 握手延迟（毫秒），用于状态栏显示网络 RTT；nil 表示未测量或已断开
    @Published var latencyMs: Int? = nil
    var reconnectConfig = ReconnectConfig()
    @Published var terminalSize: TerminalSize = .default
    @Published var terminalTitle: String = ""
    weak var delegate: TerminalControllerDelegate?

    /// 待用户确认的主机密钥状态（nil = 无待确认）
    @Published var pendingHostKeyState: PendingHostKeyState?

    /// 终端当前工作目录（由 OSC 7 序列更新，nil = 尚未感知）
    /// SFTP 面板观察此值实现目录同步
    @Published var currentRemoteDirectory: String? = nil

    /// 凭据缺失：需要用户通过向导输入密码（password / keyboard-interactive）
    @Published var needsCredentialInput: Bool = false
    /// 凭据缺失：私钥路径未配置，需要前往编辑会话
    @Published var needsCredentialEdit: Bool = false
    /// 临时密码（向导输入后一次性使用，connect() 读取后主动清零）
    /// 使用 ContiguousArray<UInt8> 以便手动清零，避免 Swift String 堆内存残留明文
    private var temporaryPassword: ContiguousArray<UInt8>?

    /// ProxyJump 连接管理器（多跳场景使用）
    var proxyJumpManager: ProxyJumpManager?

    /// SFTP 会话（独立 SSH 连接）
    @Published var sftpSession: SFTPSession?

    /// SFTP 传输队列
    @Published var sftpTransferQueue: SFTPTransferQueue?

    /// SFTP 面板是否显示
    @Published var isSFTPPanelOpen: Bool = false

    /// 端口转发隧道管理器
    let tunnelManager = TunnelManager()

    /// tmux 会话状态管理器（懒初始化，需要 self 已准备好）
    private(set) lazy var tmuxStore: TmuxSessionStore = TmuxSessionStore(sessionId: sessionId, sendTarget: self)

    /// Compose Pane 是否显示（转发到 terminalVM）
    var isComposePaneOpen: Bool {
        get { terminalVM.isComposePaneOpen }
        set { terminalVM.isComposePaneOpen = newValue }
    }

    // MARK: - 终端录制（W13）

    /// 当前会话的录制器（每个 Tab 独立实例，RecordingDialogView 通过此引用控制录制）
    let recorder = SessionRecorder()

    /// 录制对话框是否显示（转发到 terminalVM）
    var isRecordingDialogOpen: Bool {
        get { terminalVM.isRecordingDialogOpen }
        set { terminalVM.isRecordingDialogOpen = newValue }
    }

    // MARK: - 面板 ViewModel（AI 错误侦探、性能指标、输出缓冲区）

    /// 终端 ViewModel：持有性能指标、AI 错误侦探、输出缓冲区、面板可见性
    let terminalVM = TerminalViewModel()

    /// 服务器实时性能指标（快速访问入口，实际存储在 terminalVM）
    var serverMetrics: ServerMetrics? { terminalVM.serverMetrics }

    /// AI 检测错误文本（快速访问入口）
    var detectedErrorText: String? { terminalVM.detectedErrorText }

    /// 返回最近终端输出（供 AI 命令补全使用）
    func recentTerminalOutput() -> String { terminalVM.recentTerminalOutput() }

    /// 清除已检测的错误
    func clearDetectedError() { terminalVM.clearDetectedError() }

    // MARK: - 会话日志（terminal.loggingEnabled）——方法实现在 TerminalController+SessionLog.swift

    /// 当前会话的日志文件句柄（lazy，首次写入时创建）
    var sessionLogHandle: FileHandle?
    /// 是否已打开日志文件（避免重复尝试）
    var sessionLogOpened = false

    var reconnectTask: Task<Void, Never>?
    var userDisconnected = false
    private var cancellables = Set<AnyCancellable>()

    /// TC-005：网络路径监控（网络恢复时自动触发重连）
    var networkMonitor: NWPathMonitor?
    var lastNetworkStatus: NWPath.Status = .requiresConnection

    // MARK: - 初始化

    init(session: Session) {
        self.session = session
        self.sessionId = session.id
        reconnectConfig.enabled = session.autoReconnect
        setupObservers()
        startNetworkMonitoring()
        // W12.6：注册到同步输入管理器
        SyncInputStore.shared.register(self, for: session.id)
    }

    deinit {
        // NWPathMonitor / Task 取消是线程安全的，可在 deinit 直接调用
        networkMonitor?.cancel()  // 停止网络路径监控，释放关联 DispatchQueue
        reconnectTask?.cancel()   // 取消待执行的重连 Task
        let id = sessionId
        Task { @MainActor in
            SyncInputStore.shared.unregister(sessionId: id)
        }
        // 注意：disconnect() 不在此处调用——实际断连由 TerminalView.onDisappear 负责，
        // 确保 SSH 连接在对象释放前关闭；TerminalControllerRegistry.unregister 同样由
        // TerminalView.onDisappear 管理，生命周期与视图绑定。
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

        // 将 TerminalViewModel 的 @Published 变化（serverMetrics 等）转发到本 controller 的
        // objectWillChange，确保 TerminalView 在指标更新时重渲染，onChange(of:) 能正确触发
        terminalVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - 连接管理

    func connect() async throws {
        guard state == .disconnected || state.isFailed || state.isReconnecting else { return }
        // SEC-002：所有退出路径（正常 return / throw）都清零临时密码，防止明文凭证在堆上残留
        defer { zeroTemporaryPassword() }

        // Telnet / Serial 走独立连接路径（无主机密钥校验、无凭据金库查询）
        switch session.connectionType {
        case .telnet:
            try await connectTelnet()
            return
        case .serial:
            try await connectSerial()
            return
        case .ssh:
            break
        }

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
        if let tempBytes = temporaryPassword {
            password = String(bytes: tempBytes, encoding: .utf8)
            zeroTemporaryPassword()
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
                        self.terminalVM.updateOutputBuffer(decoded)
                        self.logOutputLines(decoded)
                        Task { await self.recorder.appendOutput(decoded) }
                        if AISettingsStore.shared.isEnabled && AISettingsStore.shared.errorDetectiveEnabled {
                            self.terminalVM.detectErrors(in: decoded)
                        }
                        AutomationTriggerEngine.shared.process(output: decoded, sessionId: self.sessionId, controller: self)
                    } else {
                        // 直接透传路径：保留原始字节（含非 UTF-8 字符），性能最优
                        let processed = HighlightEngine.shared.process(Data(flushed))
                        self.terminalView?.feed(byteArray: [UInt8](processed)[...])
                        self.delegate?.terminalController(self, didReceiveData: Data(flushed))
                        self.appendToSessionLog(flushed)
                        let decoded2 = String(bytes: flushed, encoding: .utf8) ?? ""
                        self.terminalVM.updateOutputBuffer(decoded2)
                        self.logOutputLines(decoded2)
                        Task { await self.recorder.appendOutput(decoded2) }
                        if AISettingsStore.shared.isEnabled && AISettingsStore.shared.errorDetectiveEnabled {
                            self.terminalVM.detectErrors(in: decoded2)
                        }
                        AutomationTriggerEngine.shared.process(output: decoded2, sessionId: self.sessionId, controller: self)
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
                // SEC-001：KnownHostsManager 查询失败时拒绝连接，不静默放行
                // 放行将允许 MITM 攻击者通过诱导数据库损坏绕过主机密钥验证
                throw SSHError.hostKeyVerificationFailed(fingerprint: fingerprint.sha256Display)
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
            latencyMs = sshConnection?.connectionLatencyMs
            delegate?.terminalController(self, didChangeState: state)
            logSystemEvent("已连接至 \(session.host):\(session.port)（用户：\(session.username)）")
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
                    await MainActor.run {
                        // 守卫：用户可能在 1.5s 内已主动断开，不向已断连的连接发送探测命令
                        guard self?.state == .connected else { return }
                        self?.tmuxStore.detectTmux()
                    }
                }
            }
            // §3.19：触发 onConnect 自动化规则
            AutomationTriggerEngine.shared.processEvent(.onConnect, sessionId: sessionId, controller: self)

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
        temporaryPassword = ContiguousArray(password.utf8)
        needsCredentialInput = false
        try await connect()
    }

    private func zeroTemporaryPassword() {
        guard temporaryPassword != nil else { return }
        for i in 0..<temporaryPassword!.count { temporaryPassword![i] = 0 }
        temporaryPassword = nil
    }

    func disconnect() async {
        userDisconnected = true
        reconnectTask?.cancel()
        reconnectTask = nil
        sshConnection?.disconnect()
        sshConnection = nil
        if let conn = telnetConnection { await conn.disconnect() }
        telnetConnection = nil
        if let conn = serialConnection { await conn.disconnect() }
        serialConnection = nil
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
        // §3.19：触发 onDisconnect 自动化规则
        AutomationTriggerEngine.shared.processEvent(.onDisconnect, sessionId: sessionId, controller: self)
        // 关闭会话日志文件句柄
        try? sessionLogHandle?.close()
        sessionLogHandle = nil
        sessionLogOpened = false
        logSystemEvent("连接已正常断开")
        state = .disconnected
        connectedAt = nil
        latencyMs = nil
        delegate?.terminalController(self, didChangeState: state)
    }

    // MARK: - 性能指标监控（委托给 terminalVM）

    func startMetricsMonitor() {
        Task { [weak self] in
            guard let self else { return }
            let password = try? await CredentialVault.shared.load(sessionId: session.id, type: .password)
            let passphrase = try? await CredentialVault.shared.load(sessionId: session.id, type: .passphrase)
            terminalVM.startMetricsMonitor(for: session, password: password, passphrase: passphrase)
        }
    }

    private func stopMetricsMonitor() {
        terminalVM.stopMetricsMonitor()
    }

    func reconnect() async throws {
        await disconnect()
        try await connect()
    }

}
