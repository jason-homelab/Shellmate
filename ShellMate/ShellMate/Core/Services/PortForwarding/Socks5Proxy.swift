import Foundation
import Darwin

// MARK: - SOCKS5 协议常量

private let SOCKS5_VERSION:     UInt8 = 5
private let SOCKS5_NO_AUTH:     UInt8 = 0
private let SOCKS5_CMD_CONNECT: UInt8 = 1
private let SOCKS5_ATYP_IPV4:   UInt8 = 1
private let SOCKS5_ATYP_DOMAIN: UInt8 = 3
private let SOCKS5_REPLY_OK:    UInt8 = 0
private let SOCKS5_REPLY_ERR:   UInt8 = 5  // Connection refused

// MARK: - SOCKS5 动态代理（ssh -D）

/// SOCKS5 本地代理服务
/// 在本地监听 SOCKS5 端口，对每条连接：
/// 1. 完成 SOCKS5 协议握手，获取目标 host:port
/// 2. 建立独立 SSH 连接并打开 direct-tcpip 通道到目标地址
/// 3. 双向桥接数据
final class Socks5Proxy {

    private let rule: TunnelRule
    private let sessionConfig: SSHSessionConfig

    private var listenerFD: Int32 = -1
    private var isRunning = false

    private let listenerQueue = DispatchQueue(label: "app.shellmate.tunnel.socks5.accept", qos: .userInitiated)
    private let connectionQueue = DispatchQueue(label: "app.shellmate.tunnel.socks5.conn", qos: .userInitiated, attributes: .concurrent)

    init(rule: TunnelRule, sessionConfig: SSHSessionConfig) {
        self.rule = rule
        self.sessionConfig = sessionConfig
    }

    deinit {
        stop()
    }

    // MARK: - 启动

    func start() throws {
        guard !isRunning else { return }

        listenerFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard listenerFD >= 0 else {
            throw SSHError.tunnelBindFailed(port: rule.localPort, reason: "SOCKS5: 无法创建 socket")
        }

        var reuse: Int32 = 1
        setsockopt(listenerFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(rule.localPort).bigEndian
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenerFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(listenerFD)
            listenerFD = -1
            throw SSHError.tunnelBindFailed(port: rule.localPort, reason: "SOCKS5 端口 \(rule.localPort) 绑定失败（errno: \(errno)）")
        }

        guard listen(listenerFD, 10) == 0 else {
            Darwin.close(listenerFD)
            listenerFD = -1
            throw SSHError.tunnelBindFailed(port: rule.localPort, reason: "SOCKS5 listen() 失败")
        }

        isRunning = true
        DispatchQueue.main.async { self.rule.status = .active }

        let fd = listenerFD
        listenerQueue.async { [weak self] in
            self?.acceptLoop(listenerFD: fd)
        }

        print("[SOCKS5] 已在 127.0.0.1:\(rule.localPort) 开始监听")
    }

    // MARK: - 停止

    func stop() {
        isRunning = false
        if listenerFD >= 0 {
            Darwin.close(listenerFD)
            listenerFD = -1
        }
        DispatchQueue.main.async { self.rule.status = .stopped }
        print("[SOCKS5] 已停止监听端口 \(rule.localPort)")
    }

    // MARK: - Accept 循环

    private func acceptLoop(listenerFD: Int32) {
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(listenerFD, $0, &clientAddrLen)
                }
            }
            guard clientFD >= 0 else { break }

            let config = sessionConfig
            connectionQueue.async { [weak self] in
                self?.handleSocks5Connection(clientFD: clientFD, config: config)
            }
        }
    }

    // MARK: - 连接处理

    private func handleSocks5Connection(clientFD: Int32, config: SSHSessionConfig) {
        defer { Darwin.close(clientFD) }

        // SOCKS5 握手：解析目标地址
        guard let (targetHost, targetPort) = socks5Handshake(clientFD: clientFD) else {
            return
        }

        // 建立独立 SSH 连接并打开 direct-tcpip 通道
        let bridge = LibSSH2BridgeReal()
        do {
            try bridge.sessionInit()
            bridge.setTimeout(30000)
            try bridge.tcpConnect(host: config.host, port: config.port)
            try bridge.handshake()
            try authenticateBridge(bridge, config: config)

            guard let channel = bridge.openDirectTCPIPChannel(
                host: targetHost,
                port: Int32(targetPort),
                sourceHost: "127.0.0.1",
                sourcePort: 0
            ) else {
                sendSocks5Response(clientFD: clientFD, success: false)
                return
            }

            sendSocks5Response(clientFD: clientFD, success: true)
            bridge.setBlocking(true)
            bridgeData(clientFD: clientFD, bridge: bridge, channel: channel)
            bridge.closeChannel(channel: channel)

        } catch {
            print("[SOCKS5] 连接到目标 \(targetHost):\(targetPort) 失败: \(error.localizedDescription)")
            sendSocks5Response(clientFD: clientFD, success: false)
        }
    }

    // MARK: - SOCKS5 协议握手

    /// 执行 SOCKS5 握手，返回目标 (host, port)，失败返回 nil
    private func socks5Handshake(clientFD: Int32) -> (String, Int)? {
        var buf = [UInt8](repeating: 0, count: 512)

        // 阶段 1：客户端问候（VER + NMETHODS + METHODS[]）
        guard recv(clientFD, &buf, 2, MSG_WAITALL) == 2, buf[0] == SOCKS5_VERSION else {
            return nil
        }
        let nMethods = Int(buf[1])
        guard nMethods > 0, recv(clientFD, &buf, nMethods, MSG_WAITALL) == nMethods else {
            return nil
        }

        // 服务端选择 NO_AUTH（0x00）
        let greeting: [UInt8] = [SOCKS5_VERSION, SOCKS5_NO_AUTH]
        send(clientFD, greeting, 2, 0)

        // 阶段 2：客户端请求（VER + CMD + RSV + ATYP + 目标地址 + 目标端口）
        guard recv(clientFD, &buf, 4, MSG_WAITALL) == 4 else { return nil }
        guard buf[0] == SOCKS5_VERSION, buf[1] == SOCKS5_CMD_CONNECT else { return nil }
        let atyp = buf[3]

        var targetHost = ""
        switch atyp {
        case SOCKS5_ATYP_IPV4:
            var ipBuf = [UInt8](repeating: 0, count: 4)
            guard recv(clientFD, &ipBuf, 4, MSG_WAITALL) == 4 else { return nil }
            targetHost = ipBuf.map { String($0) }.joined(separator: ".")

        case SOCKS5_ATYP_DOMAIN:
            // 先读 1 字节长度，再读域名
            guard recv(clientFD, &buf, 1, MSG_WAITALL) == 1 else { return nil }
            let domainLen = Int(buf[0])
            guard domainLen > 0 else { return nil }
            var domainBuf = [UInt8](repeating: 0, count: domainLen)
            guard recv(clientFD, &domainBuf, domainLen, MSG_WAITALL) == domainLen else { return nil }
            targetHost = String(bytes: domainBuf, encoding: .utf8) ?? ""

        default:
            return nil
        }

        // 读取大端序 2 字节端口
        var portBuf = [UInt8](repeating: 0, count: 2)
        guard recv(clientFD, &portBuf, 2, MSG_WAITALL) == 2 else { return nil }
        let targetPort = (Int(portBuf[0]) << 8) | Int(portBuf[1])

        return (targetHost, targetPort)
    }

    /// 发送 SOCKS5 响应
    private func sendSocks5Response(clientFD: Int32, success: Bool) {
        // 固定回复：VER REP RSV ATYP BND.ADDR(4字节) BND.PORT(2字节)
        let reply: UInt8 = success ? SOCKS5_REPLY_OK : SOCKS5_REPLY_ERR
        let response: [UInt8] = [SOCKS5_VERSION, reply, 0x00, SOCKS5_ATYP_IPV4, 0, 0, 0, 0, 0, 0]
        send(clientFD, response, response.count, 0)
    }

    // MARK: - 数据桥接

    private func bridgeData(clientFD: Int32, bridge: LibSSH2BridgeReal, channel: OpaquePointer) {
        let bufferSize = 16384
        var channelBuf = [UInt8](repeating: 0, count: bufferSize)

        let readerThread = Thread {
            while true {
                let n = bridge.readChannel(channel: channel, buffer: &channelBuf, bufferSize: bufferSize)
                if n <= 0 { break }
                var offset = 0
                while offset < n {
                    let sent = send(clientFD, channelBuf.withUnsafeBufferPointer { $0.baseAddress!.advanced(by: offset) }, n - offset, 0)
                    if sent <= 0 { return }
                    offset += sent
                }
            }
        }
        readerThread.name = "Socks5.reader"
        readerThread.start()

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
}
