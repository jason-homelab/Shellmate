import Foundation
import AppKit
import Combine
import SwiftTerm

// MARK: - 终端尺寸

/// 终端尺寸（列数 × 行数）
struct TerminalSize: Equatable {
    let columns: Int
    let rows: Int

    static let `default` = TerminalSize(columns: 80, rows: 24)
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

    /// libssh2 SSH 连接
    private var sshConnection: SSH2Connection?

    /// SwiftTerm 终端视图（弱引用，由 TerminalView 持有）
    weak var terminalView: SwiftTerm.TerminalView?

    @Published private(set) var state: State = .disconnected
    var reconnectConfig = ReconnectConfig()
    @Published var terminalSize: TerminalSize = .default
    weak var delegate: TerminalControllerDelegate?

    private var reconnectTask: Task<Void, Never>?
    private var userDisconnected = false
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

    private func setupObservers() {
        $terminalSize
            .removeDuplicates()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] newSize in
                guard let self = self else { return }
                self.sshConnection?.resizeTerminal(cols: newSize.columns, rows: newSize.rows)
            }
            .store(in: &cancellables)
    }

    // MARK: - 连接管理

    func connect() async throws {
        guard state == .disconnected || state.isFailed else { return }

        userDisconnected = false
        state = .connecting
        delegate?.terminalController(self, didChangeState: state)

        // 从 Keychain 读取凭据
        let password = try? KeychainService.shared.getPassword(for: session.id, type: .password)
        let passphrase = try? KeychainService.shared.getPassword(for: session.id, type: .passphrase)
        let privateKeyPath = session.privateKeyPath
        let authMethod = session.authMethod
        let host = session.host
        let port = Int32(session.port)
        let username = session.username
        let cols = terminalSize.columns
        let rows = terminalSize.rows

        let conn = SSH2Connection()

        // 数据回调：从 libssh2 读取线程分发到主线程喂给 SwiftTerm
        conn.onDataReceived = { [weak self] data in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.terminalView?.feed(byteArray: [UInt8](data))
                self.delegate?.terminalController(self, didReceiveData: data)
            }
        }

        // 断开回调
        conn.onDisconnected = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleConnectionLost()
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
                }
            }.value

            state = .connected
            delegate?.terminalController(self, didChangeState: state)

        } catch let error as SSHError {
            state = .failed(error.localizedDescription)
            delegate?.terminalController(self, didChangeState: state)
            delegate?.terminalController(self, didFailWithError: error)
            if shouldAutoReconnect(after: error) { scheduleReconnect() }
            throw error
        } catch {
            let sshError = SSHError.connectionFailed(host: session.host, port: session.port, underlying: error)
            state = .failed(error.localizedDescription)
            delegate?.terminalController(self, didChangeState: state)
            delegate?.terminalController(self, didFailWithError: sshError)
            throw sshError
        }
    }

    func disconnect() async {
        userDisconnected = true
        reconnectTask?.cancel()
        reconnectTask = nil
        sshConnection?.disconnect()
        sshConnection = nil
        state = .disconnected
        delegate?.terminalController(self, didChangeState: state)
    }

    func reconnect() async throws {
        await disconnect()
        try await connect()
    }

    // MARK: - 数据传输

    func send(_ data: Data) async throws {
        guard state == .connected, let conn = sshConnection else {
            throw SSHError.sessionClosed
        }
        try await Task.detached(priority: .userInitiated) {
            try conn.write(data)
        }.value
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

    // MARK: - 终端操作

    /// 清屏：向本地 SwiftTerm 发送 RIS（Reset to Initial State）
    func clearTerminal() {
        terminalView?.feed(byteArray: [UInt8]("\u{1B}c".utf8))
    }

    // MARK: - PTY 控制

    func resizePTY(columns: Int, rows: Int) {
        guard state == .connected else { return }
        sshConnection?.resizeTerminal(cols: columns, rows: rows)
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
        state = .failed("连接已断开")
        delegate?.terminalController(self, didChangeState: state)
        if reconnectConfig.enabled && !userDisconnected { scheduleReconnect() }
    }
}

// MARK: - SwiftTerm TerminalViewDelegate

extension TerminalController: TerminalViewDelegate {

    nonisolated func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        let d = Data(data)
        Task { @MainActor in
            try? await send(d)
        }
    }

    nonisolated func scrolled(source: SwiftTerm.TerminalView, position: Double) {}

    nonisolated func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {
        Task { @MainActor in
            delegate?.terminalController(self, didChangeTitle: title)
        }
    }

    nonisolated func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
        Task { @MainActor in
            terminalSize = TerminalSize(columns: newCols, rows: newRows)
        }
    }

    nonisolated func bell(source: SwiftTerm.TerminalView) {
        NSSound.beep()
    }

    nonisolated func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

    nonisolated func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {}

    nonisolated func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}

    nonisolated func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {}

    nonisolated func iTermContent(source: SwiftTerm.TerminalView, content: Data) {}

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
