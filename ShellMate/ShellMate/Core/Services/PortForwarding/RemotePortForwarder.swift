import Foundation
import Darwin

// MARK: - 远程端口转发（ssh -R）

/// 远程端口转发服务
/// 请求 SSH 服务器在远端监听端口，将入站连接通过 SSH 通道转发到本地目标地址
///
/// 工作流程：
/// 1. 建立独立 SSH 连接（阻塞模式）
/// 2. 调用 libssh2_channel_forward_listen_ex 请求服务器在远端绑定端口
/// 3. 在循环中调用 libssh2_channel_forward_accept 接受入站通道
/// 4. 对每条通道，连接到本地目标并双向桥接数据
final class RemotePortForwarder {

    private let rule: TunnelRule
    private let sessionConfig: SSHSessionConfig

    private var isRunning = false
    private var bridge: LibSSH2BridgeReal?
    private var listener: OpaquePointer?

    private let queue = DispatchQueue(label: "app.shellmate.tunnel.remote", qos: .userInitiated)
    private let channelQueue = DispatchQueue(label: "app.shellmate.tunnel.remote.ch", qos: .userInitiated, attributes: .concurrent)

    init(rule: TunnelRule, sessionConfig: SSHSessionConfig) {
        self.rule = rule
        self.sessionConfig = sessionConfig
    }

    deinit {
        stop()
    }

    // MARK: - 启动

    func start() {
        guard !isRunning else { return }
        isRunning = true

        DispatchQueue.main.async { self.rule.status = .starting }

        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                try self.runRemoteForward()
            } catch {
                print("[RemoteForward] 运行失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.rule.status = .failed(error.localizedDescription)
                }
            }
            self.isRunning = false
        }
    }

    // MARK: - 停止

    func stop() {
        isRunning = false
        if let l = listener {
            bridge?.closeForwardListener(l)
            listener = nil
        }
        bridge?.disconnect()
        bridge = nil
        DispatchQueue.main.async { self.rule.status = .stopped }
    }

    // MARK: - 内部实现

    private func runRemoteForward() throws {
        let b = LibSSH2BridgeReal()
        bridge = b

        try b.sessionInit()
        b.setTimeout(30000)
        try b.tcpConnect(host: sessionConfig.host, port: sessionConfig.port)
        try b.handshake()
        try authenticateBridge(b)
        b.setBlocking(true)

        // 请求服务器在远端监听
        var boundPort: Int32 = Int32(rule.localPort)
        guard let lst = b.forwardListen(
            host: "0.0.0.0",
            port: Int32(rule.localPort),
            boundPort: &boundPort,
            queueMaxsize: 5
        ) else {
            throw SSHError.tunnelListenFailed(
                port: rule.localPort,
                reason: "服务器拒绝 tcpip-forward 请求（检查 sshd GatewayPorts 设置）"
            )
        }
        listener = lst

        print("[RemoteForward] 服务器已在端口 \(boundPort) 开始监听")
        DispatchQueue.main.async { self.rule.status = .active }

        // 接受远端入站连接
        while isRunning {
            guard let channel = b.forwardAccept(listener: lst) else {
                usleep(100_000)
                continue
            }

            let localHost = rule.remoteHost.isEmpty ? "127.0.0.1" : rule.remoteHost
            let localPort = rule.remotePort

            channelQueue.async { [weak self] in
                self?.handleChannel(channel: channel, bridge: b, localHost: localHost, localPort: localPort)
            }
        }

        b.closeForwardListener(lst)
        listener = nil
    }

    /// 将远端入站通道流量转发到本地目标地址
    private func handleChannel(channel: OpaquePointer, bridge: LibSSH2BridgeReal, localHost: String, localPort: Int) {
        let localFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard localFD >= 0 else { return }
        defer {
            Darwin.close(localFD)
            bridge.closeChannel(channel: channel)
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(localPort).bigEndian
        inet_pton(AF_INET, localHost, &addr.sin_addr)

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(localFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectResult == 0 else {
            print("[RemoteForward] 连接本地 \(localHost):\(localPort) 失败")
            return
        }

        let bufferSize = 16384
        var channelBuf = [UInt8](repeating: 0, count: bufferSize)

        // SSH channel → 本地 socket
        let readerThread = Thread {
            while true {
                let n = bridge.readChannel(channel: channel, buffer: &channelBuf, bufferSize: bufferSize)
                if n <= 0 { break }
                var offset = 0
                while offset < n {
                    let sent = send(localFD, channelBuf.withUnsafeBufferPointer { $0.baseAddress!.advanced(by: offset) }, n - offset, 0)
                    if sent <= 0 { return }
                    offset += sent
                }
            }
        }
        readerThread.name = "RemoteForward.reader"
        readerThread.start()

        // 本地 socket → SSH channel
        var localBuf = [UInt8](repeating: 0, count: bufferSize)
        while true {
            let n = recv(localFD, &localBuf, bufferSize, 0)
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

    private func authenticateBridge(_ bridge: LibSSH2BridgeReal) throws {
        switch sessionConfig.authMethod {
        case .password:
            try bridge.authenticateWithPassword(username: sessionConfig.username, password: sessionConfig.password ?? "")
        case .privateKey:
            try bridge.authenticateWithPublicKey(
                username: sessionConfig.username,
                publicKeyPath: nil,
                privateKeyPath: sessionConfig.privateKeyPath ?? "",
                passphrase: sessionConfig.passphrase
            )
        case .sshAgent:
            try bridge.authenticateWithAgent(username: sessionConfig.username)
        case .keyboardInteractive:
            throw SSHError.authMethodNotSupported(method: "keyboard-interactive")
        }
    }
}
