import Foundation
import Darwin

// MARK: - 本地端口转发（ssh -L）

/// 本地端口转发服务
/// 在本地监听 TCP 端口，每当新连接到来时通过 SSH direct-tcpip 通道转发流量
///
/// 架构说明：
/// - 每个入站连接建立独立的 SSH 会话并打开 direct-tcpip 通道
/// - 本地监听在 listenerQueue 上运行（accept 循环）
/// - 每条连接的数据桥接在独立线程上运行
final class LocalPortForwarder {

    private let rule: TunnelRule
    private let sessionConfig: SSHSessionConfig

    private var listenerFD: Int32 = -1
    private var isRunning = false

    private let listenerQueue = DispatchQueue(label: "app.shellmate.tunnel.local.accept", qos: .userInitiated)
    private let connectionQueue = DispatchQueue(label: "app.shellmate.tunnel.local.conn", qos: .userInitiated, attributes: .concurrent)

    private var onStatusChange: ((TunnelStatus) -> Void)?

    init(rule: TunnelRule, sessionConfig: SSHSessionConfig, onStatusChange: ((TunnelStatus) -> Void)? = nil) {
        self.rule = rule
        self.sessionConfig = sessionConfig
        self.onStatusChange = onStatusChange
    }

    deinit {
        stop()
    }

    // MARK: - 启动

    func start() throws {
        guard !isRunning else { return }

        listenerFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard listenerFD >= 0 else {
            throw SSHError.tunnelBindFailed(port: rule.localPort, reason: "无法创建 socket（errno: \(errno)）")
        }

        // SO_REUSEADDR：允许端口复用，防止 TIME_WAIT 导致的绑定失败
        var reuse: Int32 = 1
        setsockopt(listenerFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(rule.localPort).bigEndian
        inet_pton(AF_INET, rule.localBindAddress, &addr.sin_addr)

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenerFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(listenerFD)
            listenerFD = -1
            throw SSHError.tunnelBindFailed(port: rule.localPort, reason: "端口 \(rule.localPort) 绑定失败（errno: \(errno)）")
        }

        guard listen(listenerFD, 5) == 0 else {
            Darwin.close(listenerFD)
            listenerFD = -1
            throw SSHError.tunnelBindFailed(port: rule.localPort, reason: "listen() 失败")
        }

        isRunning = true
        notifyStatus(.active)

        let fd = listenerFD
        listenerQueue.async { [weak self] in
            self?.acceptLoop(listenerFD: fd)
        }

        AppLogger.tunnel.debug("[LocalForward] 已在 \(self.rule.localBindAddress):\(self.rule.localPort) 开始监听")
    }

    // MARK: - 停止

    func stop() {
        isRunning = false
        if listenerFD >= 0 {
            Darwin.close(listenerFD)
            listenerFD = -1
        }
        notifyStatus(.stopped)
        AppLogger.tunnel.debug("[LocalForward] 已停止监听端口 \(self.rule.localPort)")
    }

    // MARK: - 内部实现

    private func acceptLoop(listenerFD: Int32) {
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(listenerFD, $0, &clientAddrLen)
                }
            }

            guard clientFD >= 0 else {
                if isRunning {
                    AppLogger.tunnel.debug("[LocalForward] accept() 失败，errno: \(errno)")
                }
                break
            }

            let remoteHost = rule.remoteHost
            let remotePort = rule.remotePort
            let config = sessionConfig

            connectionQueue.async { [weak self] in
                self?.handleConnection(clientFD: clientFD, remoteHost: remoteHost, remotePort: remotePort, config: config)
            }
        }
    }

    /// 为每条入站连接建立独立的 SSH direct-tcpip 通道并双向桥接
    private func handleConnection(clientFD: Int32, remoteHost: String, remotePort: Int, config: SSHSessionConfig) {
        defer { Darwin.close(clientFD) }

        let bridge = LibSSH2BridgeReal()
        do {
            try bridge.sessionInit()
            bridge.setTimeout(30000)
            try bridge.tcpConnect(host: config.host, port: config.port)
            try bridge.handshake()
            try authenticateBridge(bridge, config: config)

            guard let channel = bridge.openDirectTCPIPChannel(
                host: remoteHost,
                port: Int32(remotePort),
                sourceHost: "127.0.0.1",
                sourcePort: 0
            ) else {
                AppLogger.tunnel.debug("[LocalForward] 无法打开 direct-tcpip 通道到 \(remoteHost):\(remotePort)")
                return
            }

            bridge.setBlocking(true)
            bridgeData(clientFD: clientFD, bridge: bridge, channel: channel)
            bridge.closeChannel(channel: channel)

        } catch {
            AppLogger.tunnel.debug("[LocalForward] 连接处理失败: \(error.localizedDescription)")
        }
    }

    /// 在本地 socket 与 SSH channel 之间双向桥接数据
    private func bridgeData(clientFD: Int32, bridge: LibSSH2BridgeReal, channel: OpaquePointer) {
        let bufferSize = 16384
        var channelBuf = [UInt8](repeating: 0, count: bufferSize)

        // SSH channel → 本地 socket（后台线程）
        let readerThread = Thread {
            while true {
                let n = bridge.readChannel(channel: channel, buffer: &channelBuf, bufferSize: bufferSize)
                if n > 0 {
                    var offset = 0
                    while offset < n {
                        let sent = send(clientFD, channelBuf.withUnsafeBufferPointer { $0.baseAddress!.advanced(by: offset) }, n - offset, 0)
                        if sent <= 0 { return }
                        offset += sent
                    }
                } else if n == 0 {
                    break
                }
            }
        }
        readerThread.name = "LocalForward.reader"
        readerThread.start()

        // 本地 socket → SSH channel（当前线程）
        var localBuf = [UInt8](repeating: 0, count: bufferSize)
        while true {
            let n = recv(clientFD, &localBuf, bufferSize, 0)
            if n <= 0 { break }
            let data = Data(bytes: localBuf, count: n)
            _ = data.withUnsafeBytes { rawBuf in
                bridge.writeChannel(
                    channel: channel,
                    data: rawBuf.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    length: n
                )
            }
        }
    }

    // MARK: - 辅助

    private func authenticateBridge(_ bridge: LibSSH2BridgeReal, config: SSHSessionConfig) throws {
        switch config.authMethod {
        case .password:
            try bridge.authenticateWithPassword(username: config.username, password: config.password ?? "")
        case .privateKey:
            try bridge.authenticateWithPublicKey(
                username: config.username,
                publicKeyPath: nil,
                privateKeyPath: config.privateKeyPath ?? "",
                passphrase: config.passphrase
            )
        case .sshAgent:
            try bridge.authenticateWithAgent(username: config.username)
        case .keyboardInteractive:
            throw SSHError.authMethodNotSupported(method: "keyboard-interactive")
        }
    }

    private func notifyStatus(_ status: TunnelStatus) {
        Task { @MainActor [weak self] in
            self?.rule.status = status
            self?.onStatusChange?(status)
        }
    }
}
