import SwiftUI
import Darwin


// MARK: - 终端占位视图

/// 终端占位视图
/// 在终端功能实现前显示的占位界面，支持基础 SSH 连接测试（libssh2）
struct TerminalPlaceholderView: View {

    // MARK: - 属性

    var session: Session?
    var onConnect: (() -> Void)?
    var onNewSession: (() -> Void)?

    // MARK: - 状态

    @State private var ssh2Connection: SSH2Connection?
    @State private var connectionState: ConnectionState = .offline
    @State private var terminalViewRef: ShellMateTerminalView?
    @State private var terminalDelegate: SSHTerminalDelegate = SSHTerminalDelegate()
    @State private var showPasswordPrompt: Bool = false
    @State private var password: String = ""

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            if let session = session {
                if connectionState != .offline {
                    terminalView(session)
                } else {
                    sessionInfoView(session)
                }
            } else {
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

    @FocusState private var isTerminalFocused: Bool

    @ViewBuilder
    private func terminalView(_ session: Session) -> some View {
        VStack(spacing: 0) {
            HStack {
                StatusDotView(state: connectionState)
                Text("\(session.username)@\(session.host)")
                    .font(DesignTokens.Typography.codeMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Spacer()

                Button { disconnect() } label: {
                    Label("断开", systemImage: "stop.fill")
                }
                .buttonStyle(PillButtonStyle(tone: .destructive))
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.surfacePanel)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DesignTokens.Colors.borderPrimary)
                    .frame(height: 0.5)
            }

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

    // MARK: - 会话信息视图

    @ViewBuilder
    private func sessionInfoView(_ session: Session) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: DesignTokens.Spacing.xxl) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXLarge, style: .continuous)
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
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXLarge, style: .continuous)
                                .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.18), lineWidth: 1)
                        )

                    Image(systemName: "terminal.fill")
                        .font(DesignTokens.Typography.displayXLarge)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentIndigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text(session.name)
                        .font(DesignTokens.Typography.titleLarge)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Text("\(session.username)@\(session.host):\(session.port)")
                        .font(DesignTokens.Typography.codeMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                HStack(spacing: DesignTokens.Spacing.xs) {
                    StatusDotView(state: session.connectionState)
                    Text(session.connectionState.displayName)
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(session.connectionState.dotColor)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.micro)
                .background(session.connectionState.dotColor.opacity(0.08))
                .clipShape(Capsule())

                if connectionState == .offline {
                    Button(action: { initiateConnect() }) {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "bolt.fill")
                                .font(DesignTokens.Typography.bodySmallStrong)
                            Text("连接")
                                .font(DesignTokens.Typography.bodyLargeStrong)
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
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                        Text("正在连接...")
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
            .padding(DesignTokens.Spacing.xxxl)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                    .fill(DesignTokens.Colors.surfaceCard)
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
        performConnectWithLibSSH2(session: session)
    }

    private func performConnectWithLibSSH2(session: Session) {
        let savedPassword = password
        password = ""

        DispatchQueue.global(qos: .userInitiated).async {
            let connection = SSH2Connection()

            connection.onDataReceived = { data in
                DispatchQueue.main.async {
                    terminalViewRef?.feed(data)

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

    private func disconnect() {
        terminalDelegate.sshWriter = nil
        terminalDelegate.onSizeChanged = nil
        ssh2Connection?.disconnect()
        ssh2Connection = nil
        connectionState = .offline
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.15), lineWidth: 0.75)
                    )
                Image(systemName: "desktopcomputer")
                    .font(DesignTokens.Typography.heroMedium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentIndigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("暂无活跃会话")
                    .font(DesignTokens.Typography.displayXSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("从侧边栏选择会话，或新建一个 SSH 连接")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { onNewSession?() }) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.labelSmall)
                    Text("新建会话")
                        .font(DesignTokens.Typography.labelLarge)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
                .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.Spacing.xxs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SSH 终端委托

final class SSHTerminalDelegate: ShellMateTerminalViewDelegate {

    var sshWriter: ((String) throws -> Void)?
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
