import SwiftUI
import Darwin

// MARK: - SSH 进程桥接（内嵌实现）

/// 使用系统 ssh 命令的 SSH 连接桥接
final class SSHProcessBridge {

    /// SSH 进程
    private var process: Process?

    /// PTY 主端文件描述符
    private var masterFD: Int32 = -1

    /// PTY 从端文件描述符
    private var slaveFD: Int32 = -1

    /// 数据接收回调
    var onDataReceived: ((Data) -> Void)?

    /// 连接关闭回调
    var onDisconnected: (() -> Void)?

    /// 是否已连接
    private(set) var isConnected: Bool = false

    /// 读取队列
    private let readQueue = DispatchQueue(label: "app.shellmate.ssh.read")

    init() {}

    deinit {
        disconnect()
    }

    /// 使用密码连接
    func connect(
        host: String,
        port: Int32,
        username: String,
        password: String? = nil
    ) throws {
        guard !isConnected else { return }

        // 创建 PTY
        try createPTY()

        // 创建 SSH 进程
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

        var args: [String] = []
        // 跳过主机密钥验证（开发测试用，生产环境需要实现自定义 known_hosts 管理）
        args.append("-o")
        args.append("StrictHostKeyChecking=no")
        args.append("-o")
        args.append("UserKnownHostsFile=/dev/null")

        if port != 22 {
            args.append("-p")
            args.append(String(port))
        }

        args.append("-tt")
        args.append("\(username)@\(host)")

        proc.arguments = args

        // 设置 PTY 作为标准 IO
        proc.standardInput = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        proc.standardOutput = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        proc.standardError = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)

        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["LC_ALL"] = "en_US.UTF-8"
        proc.environment = environment

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleDisconnection()
            }
        }

        try proc.run()
        self.process = proc
        self.isConnected = true

        startReading()
    }

    /// 使用私钥连接
    func connectWithKey(
        host: String,
        port: Int32,
        username: String,
        privateKeyPath: String,
        passphrase: String? = nil
    ) throws {
        guard !isConnected else { return }

        try createPTY()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

        var args: [String] = []
        args.append("-i")
        args.append(privateKeyPath)
        args.append("-o")
        args.append("PasswordAuthentication=no")
        // 跳过主机密钥验证（开发测试用）
        args.append("-o")
        args.append("StrictHostKeyChecking=no")
        args.append("-o")
        args.append("UserKnownHostsFile=/dev/null")

        if port != 22 {
            args.append("-p")
            args.append(String(port))
        }

        args.append("-tt")
        args.append("\(username)@\(host)")

        proc.arguments = args

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

        try proc.run()
        self.process = proc
        self.isConnected = true
        startReading()
    }

    /// 断开连接
    func disconnect() {
        guard isConnected else { return }

        isConnected = false

        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil

        closePTY()
    }

    /// 写入数据
    func write(_ data: Data) throws {
        guard isConnected, masterFD >= 0 else { return }

        data.withUnsafeBytes { buffer in
            guard let ptr = buffer.baseAddress else { return }
            let _ = Darwin.write(masterFD, ptr, data.count)
        }
    }

    /// 写入字符串
    func write(_ string: String) throws {
        guard let data = string.data(using: .utf8) else { return }
        try write(data)
    }

    // MARK: - 私有方法

    private func createPTY() throws {
        var master: Int32 = -1
        var slave: Int32 = -1
        var winSize = winsize()
        winSize.ws_col = 80
        winSize.ws_row = 24

        let result = openpty(&master, &slave, nil, nil, &winSize)
        guard result == 0 else {
            throw NSError(domain: "SSHProcessBridge", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "无法创建 PTY"])
        }

        masterFD = master
        slaveFD = slave

        var flags = fcntl(masterFD, F_GETFL, 0)
        fcntl(masterFD, F_SETFL, flags | O_NONBLOCK)
    }

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

    private func startReading() {
        readQueue.async { [weak self] in
            self?.readLoop()
        }
    }

    private func readLoop() {
        // W15.5：与 SSHProcessBridge 对齐，32KB 缓冲区
        let bufferSize = 32768
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while isConnected && masterFD >= 0 {
            let bytesRead = read(masterFD, &buffer, bufferSize)

            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)
                DispatchQueue.main.async { [weak self] in
                    self?.onDataReceived?(data)
                }
            } else if bytesRead == 0 {
                break
            } else {
                if errno != EAGAIN && errno != EWOULDBLOCK {
                    break
                }
                usleep(10000)
            }
        }
    }

    private func handleDisconnection() {
        isConnected = false
        closePTY()
        onDisconnected?()
    }
}

// MARK: - 终端占位视图

/// 终端占位视图
/// 在终端功能实现前显示的占位界面，支持基础 SSH 连接测试
struct TerminalPlaceholderView: View {

    // MARK: - 属性

    /// 当前选中的会话（可选）
    var session: Session?

    /// 连接回调
    var onConnect: (() -> Void)?

    /// SSH 连接桥接（系统 ssh 命令）
    @State private var sshBridge: SSHProcessBridge?

    /// SSH2 连接（libssh2 实现）
    @State private var ssh2Connection: SSH2Connection?

    /// 是否使用 libssh2（默认为 true）
    @State private var useLibSSH2: Bool = true

    /// 连接状态
    @State private var connectionState: ConnectionState = .offline

    /// 终端视图引用（用于直接喂入 ANSI 数据）
    @State private var terminalViewRef: ShellMateTerminalView?

    /// 终端委托（将键盘输入转发至 SSH 连接）
    @State private var terminalDelegate: SSHTerminalDelegate = SSHTerminalDelegate()

    /// 是否显示密码输入
    @State private var showPasswordPrompt: Bool = false

    /// 密码
    @State private var password: String = ""

    /// 是否已发送密码
    @State private var passwordSent: Bool = false

    /// 等待密码提示
    @State private var waitingForPassword: Bool = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            if let session = session {
                // 连接/连接中/错误状态时显示终端视图
                if connectionState != .offline {
                    terminalView(session)
                } else {
                    // 显示选中会话的信息
                    sessionInfoView(session)
                }
            } else {
                // 显示空状态
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow)
        .sheet(isPresented: $showPasswordPrompt) {
            passwordPromptSheet
        }
    }

    // MARK: - 终端视图

    /// 终端焦点状态
    @FocusState private var isTerminalFocused: Bool

    @ViewBuilder
    private func terminalView(_ session: Session) -> some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                StatusDotView(state: connectionState)
                Text("\(session.username)@\(session.host)")
                    .font(DesignTokens.Typography.codeMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Spacer()

                Button("断开") {
                    disconnect()
                }
                .buttonStyle(.bordered)
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.surfacePanel)

            // 终端区域：使用 ShellMateTerminalView 处理 ANSI 序列
            ShellMateTerminalViewRepresentable(
                terminalView: $terminalViewRef,
                theme: .darkDefault,
                delegate: terminalDelegate
            )
        }
    }

    // MARK: - 密码输入弹窗

    private var passwordPromptSheet: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("输入密码")
                .font(DesignTokens.Typography.titleMedium)

            if let session = session {
                Text("\(session.username)@\(session.host)")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack {
                Button("取消") {
                    showPasswordPrompt = false
                    password = ""
                }
                .buttonStyle(.bordered)

                Button("连接") {
                    showPasswordPrompt = false
                    performConnect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignTokens.Spacing.xxl)
        .frame(width: 320, height: 200)
    }

    // MARK: - 会话信息视图

    @ViewBuilder
    private func sessionInfoView(_ session: Session) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.surfaceCard)
                    .frame(width: 80, height: 80)

                Image(systemName: "terminal.fill")
                    .font(.system(size: 32))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }

            // 会话名称
            Text(session.name)
                .font(DesignTokens.Typography.titleLarge)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // 连接信息
            Text("\(session.username)@\(session.host):\(session.port)")
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // 连接状态
            HStack(spacing: DesignTokens.Spacing.sm) {
                StatusDotView(state: session.connectionState)

                Text(session.connectionState.displayName)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(session.connectionState.dotColor)
            }
            .padding(.top, DesignTokens.Spacing.sm)

            // 连接按钮
            if connectionState == .offline {
                Button(action: {
                    initiateConnect()
                }) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "bolt.fill")
                        Text("连接")
                    }
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.accentPrimary)
                    .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
                }
                .buttonStyle(.plain)
                .padding(.top, DesignTokens.Spacing.lg)
            } else if connectionState == .connecting {
                ProgressView()
                    .padding(.top, DesignTokens.Spacing.lg)
                Text("正在连接...")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }

    // MARK: - 连接方法

    private func initiateConnect() {
        guard let session = session else { return }

        // 如果是密码认证，显示密码输入弹窗
        if session.authMethod == .password {
            showPasswordPrompt = true
        } else {
            performConnect()
        }
    }

    private func performConnect() {
        guard let session = session else { return }

        connectionState = .connecting
        terminalViewRef?.clear()

        if useLibSSH2 {
            performConnectWithLibSSH2(session: session)
        } else {
            performConnectWithSystemSSH(session: session)
        }
    }

    /// 使用 libssh2 连接
    private func performConnectWithLibSSH2(session: Session) {
        let savedPassword = password
        password = "" // 清除密码

        // 在后台线程执行连接
        DispatchQueue.global(qos: .userInitiated).async {
            let connection = SSH2Connection()

            // 设置回调
            connection.onDataReceived = { data in
                DispatchQueue.main.async {
                    // 直接喂给终端仿真器（自动处理 ANSI 序列）
                    terminalViewRef?.feed(data)

                    // 检测连接成功（从原始字节扫描 shell 提示符）
                    if connectionState == .connecting,
                       let text = String(data: data, encoding: .utf8) {
                        if text.contains("$") || text.contains("#") || text.contains("%") ||
                           text.contains("Last login") || text.contains("Welcome") {
                            connectionState = .connected
                        }
                    }
                }
            }

            connection.onDisconnected = {
                DispatchQueue.main.async {
                    if connectionState == .connecting {
                        connectionState = .error
                    } else {
                        connectionState = .offline
                    }
                    terminalViewRef?.feed("\r\n[连接已断开]\r\n".data(using: .utf8) ?? Data())
                }
            }

            // 执行连接
            do {
                if session.authMethod == .privateKey, let keyPath = session.privateKeyPath {
                    try connection.connectWithKey(
                        host: session.host,
                        port: session.port,
                        username: session.username,
                        privateKeyPath: keyPath,
                        passphrase: nil
                    )
                } else {
                    try connection.connect(
                        host: session.host,
                        port: session.port,
                        username: session.username,
                        password: savedPassword
                    )
                }

                DispatchQueue.main.async {
                    ssh2Connection = connection
                    // 连接成功后绑定键盘输入 → SSH 写入
                    terminalDelegate.sshWriter = { [weak connection] text in
                        try? connection?.write(text)
                    }
                    terminalDelegate.onSizeChanged = { [weak connection] size in
                        connection?.resizeTerminal(cols: size.columns, rows: size.rows)
                    }
                }

            } catch {
                DispatchQueue.main.async {
                    connectionState = .error
                    terminalViewRef?.feed("连接失败: \(error.localizedDescription)\r\n".data(using: .utf8) ?? Data())
                }
            }
        }
    }

    /// 使用系统 ssh 命令连接
    private func performConnectWithSystemSSH(session: Session) {
        let bridge = SSHProcessBridge()
        sshBridge = bridge

        // 保存密码用于自动输入
        let savedPassword = password
        waitingForPassword = !password.isEmpty
        passwordSent = false

        // 绑定键盘输入 → SSH 写入
        terminalDelegate.sshWriter = { [weak bridge] text in
            try? bridge?.write(text)
        }

        // 设置数据接收回调
        bridge.onDataReceived = { data in
            DispatchQueue.main.async {
                // 直接喂给终端仿真器（自动处理 ANSI 序列）
                terminalViewRef?.feed(data)

                // 检测密码提示并自动输入密码
                if waitingForPassword && !passwordSent,
                   let text = String(data: data, encoding: .utf8) {
                    let lowerText = text.lowercased()
                    if lowerText.contains("password") || lowerText.contains("密码") {
                        passwordSent = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            try? bridge.write(savedPassword + "\n")
                        }
                    }
                }

                // 检测连接成功（shell 提示符）
                if connectionState == .connecting,
                   let text = String(data: data, encoding: .utf8) {
                    if text.contains("$") || text.contains("#") || text.contains("%") ||
                       text.contains("Last login") || text.contains("Welcome") {
                        connectionState = .connected
                    }
                }
            }
        }

        bridge.onDisconnected = {
            DispatchQueue.main.async {
                if connectionState == .connecting {
                    connectionState = .error
                    terminalViewRef?.feed("\r\n[SSH 进程已退出 - 连接可能失败]\r\n".data(using: .utf8) ?? Data())
                } else {
                    connectionState = .offline
                    terminalViewRef?.feed("\r\n[连接已断开]\r\n".data(using: .utf8) ?? Data())
                }
            }
        }

        // 执行连接
        do {
            if session.authMethod == .privateKey, let keyPath = session.privateKeyPath {
                try bridge.connectWithKey(
                    host: session.host,
                    port: session.port,
                    username: session.username,
                    privateKeyPath: keyPath,
                    passphrase: nil
                )
            } else {
                try bridge.connect(
                    host: session.host,
                    port: session.port,
                    username: session.username,
                    password: nil  // 密码通过 PTY 输入
                )
            }

            // 连接已启动，等待 SSH 提示或连接成功
            // connectionState 会在检测到 shell 提示符时更新
            password = "" // 清除密码

        } catch {
            connectionState = .error
            terminalViewRef?.feed("连接失败: \(error.localizedDescription)\r\n".data(using: .utf8) ?? Data())
            password = ""
            waitingForPassword = false
        }
    }

    private func disconnect() {
        terminalDelegate.sshWriter = nil
        terminalDelegate.onSizeChanged = nil

        if useLibSSH2 {
            ssh2Connection?.disconnect()
            ssh2Connection = nil
        } else {
            sshBridge?.disconnect()
            sshBridge = nil
        }
        connectionState = .offline
    }


    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "terminal")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text("选择一个会话开始")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("从左侧边栏选择一个会话，或双击会话以连接")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignTokens.Spacing.xxxl)
    }
}

// MARK: - SSH 终端委托

/// 将 ShellMateTerminalView 的键盘输入转发给 SSH 连接
final class SSHTerminalDelegate: ShellMateTerminalViewDelegate {

    /// SSH 写入闭包
    var sshWriter: ((String) throws -> Void)?

    /// PTY 尺寸变化闭包
    var onSizeChanged: ((TerminalSize) -> Void)?

    func terminalView(_ view: ShellMateTerminalView, send data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        try? sshWriter?(text)
    }

    func terminalView(_ view: ShellMateTerminalView, send string: String) {
        try? sshWriter?(string)
    }

    func terminalView(_ view: ShellMateTerminalView, sizeChanged newSize: TerminalSize) {
        onSizeChanged?(newSize)
    }

    func terminalView(_ view: ShellMateTerminalView, titleChanged newTitle: String) {}
    func terminalViewBell(_ view: ShellMateTerminalView) {}
    func terminalView(_ view: ShellMateTerminalView, selectionChanged selection: String?) {}
}

// MARK: - 预览

#Preview("终端占位 - 无选中") {
    TerminalPlaceholderView()
        .frame(width: 800, height: 600)
}

#Preview("终端占位 - 有选中") {
    TerminalPlaceholderView(
        session: Session.preview,
        onConnect: { print("连接") }
    )
    .frame(width: 800, height: 600)
}

#Preview("终端占位 - 已连接") {
    var session = Session.preview
    session.connectionState = .connected

    return TerminalPlaceholderView(
        session: session,
        onConnect: { print("连接") }
    )
    .frame(width: 800, height: 600)
}
