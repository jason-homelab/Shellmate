import SwiftUI
import Darwin


// MARK: - 终端占位视图

/// 终端占位视图
/// 在终端功能实现前显示的占位界面，支持基础 SSH 连接测试
struct TerminalPlaceholderView: View {

    // MARK: - 属性

    /// 当前选中的会话（可选）
    var session: Session?

    /// 连接回调
    var onConnect: (() -> Void)?

    /// 新建会话回调（空状态按钮触发）
    var onNewSession: (() -> Void)?

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
            .background(DesignTokens.Colors.surfaceWindow.opacity(0.90))
            .background(.ultraThinMaterial)

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

            CustomTextField(placeholder: "密码", text: $password, isSecure: true)
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

    // MARK: - 会话信息视图（高保真连接卡片）

    @ViewBuilder
    private func sessionInfoView(_ session: Session) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // 会话图标卡片（渐变圆角，与 Figma SessionRow icon 保持视觉延续）
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignTokens.Colors.accentPrimary.opacity(0.12),
                                    DesignTokens.Colors.accentIndigo.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.18), lineWidth: 1)
                        )

                    Image(systemName: "terminal.fill")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentIndigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // 会话信息文字组
                VStack(spacing: 6) {
                    Text(session.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Text("\(session.username)@\(session.host):\(session.port)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                // 连接状态 Pill
                HStack(spacing: 6) {
                    StatusDotView(state: session.connectionState)
                    Text(session.connectionState.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(session.connectionState.dotColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(session.connectionState.dotColor.opacity(0.08))
                .clipShape(Capsule())

                // 操作区
                if connectionState == .offline {
                    Button(action: { initiateConnect() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("连接")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignTokens.Spacing.xxl)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
                        .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                } else if connectionState == .connecting {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("正在连接...")
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
            .padding(DesignTokens.Spacing.xxxl)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                    .fill(Color.white.opacity(0.80))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.75)
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 6)
            .frame(maxWidth: 320)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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


    // MARK: - 空状态视图（Figma-Spec-v2 §01 §4）

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 渐变圆角图标容器：96×96px，from-[#007aff]/10 to-[#5856d6]/10
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.accentPrimary.opacity(0.10),
                                DesignTokens.Colors.accentIndigo.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentIndigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // 主标题：text-xl semibold #1d1d1f
            Text("No Active Sessions")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // 副文字：text-sm #86868b
            Text("Select a session from the sidebar to get started")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)

            // 新建会话按钮：bg-primary rounded-xl
            Button(action: { onNewSession?() }) {
                Text("Create New Session")
                    .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
                .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        onConnect: { AppLogger.general.debug("连接") }
    )
    .frame(width: 800, height: 600)
}

#Preview("终端占位 - 已连接") {
    var session = Session.preview
    session.connectionState = .connected

    return TerminalPlaceholderView(
        session: session,
        onConnect: { AppLogger.general.debug("连接") }
    )
    .frame(width: 800, height: 600)
}
