import Foundation
import Network

/// Telnet 连接（actor 隔离，消除 NWConnection 回调与调用方之间的数据竞争）
/// 使用 Network.framework NWConnection 建立 TCP 连接，实现基础 IAC 协议协商。
/// 适用于网络设备（交换机/路由器）控制台访问（Cisco、Juniper、H3C 等）。
actor TelnetConnection {

    // MARK: - Telnet IAC 常量

    private enum IAC {
        static let iac:   UInt8 = 255
        static let dont:  UInt8 = 254
        static let doCmd: UInt8 = 253
        static let wont:  UInt8 = 252
        static let will:  UInt8 = 251
        static let sb:    UInt8 = 250
        static let se:    UInt8 = 240
        static let echo:  UInt8 = 1
        static let sga:   UInt8 = 3
        static let naws:  UInt8 = 31
        static let ttype: UInt8 = 24
    }

    // MARK: - 属性

    var onDataReceived: (@Sendable (Data) -> Void)?
    var onDisconnected: (@Sendable () -> Void)?

    var isConnected: Bool { _isConnected }

    private var _isConnected = false
    private var connection: NWConnection?
    private var cols: Int = 80
    private var rows: Int = 24

    // MARK: - 初始化

    deinit {
        connection?.cancel()
    }

    // MARK: - 回调配置

    func configure(
        onDataReceived: (@Sendable (Data) -> Void)?,
        onDisconnected: (@Sendable () -> Void)?
    ) {
        self.onDataReceived = onDataReceived
        self.onDisconnected = onDisconnected
    }

    // MARK: - 连接

    func connect(host: String, port: UInt16) async throws {
        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw TelnetError.invalidPort(port)
        }

        let params = NWParameters.tcp
        let conn = NWConnection(host: nwHost, port: nwPort, using: params)
        self.connection = conn

        // 将 async 挂起点桥接到 NWConnection 的回调队列
        // @unchecked Sendable 包装避免 CheckedContinuation 跨并发域告警
        final class ContinuationHolder: @unchecked Sendable {
            var continuation: CheckedContinuation<Void, Error>?
            private let lock = NSLock()

            func resume(with result: Result<Void, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard let cont = continuation else { return }
                continuation = nil
                switch result {
                case .success:           cont.resume()
                case .failure(let err):  cont.resume(throwing: err)
                }
            }
        }

        let holder = ContinuationHolder()

        conn.stateUpdateHandler = { [weak self, holder] state in
            switch state {
            case .ready:
                // 先恢复挂起的 connect()，再更新 actor 内部状态
                holder.resume(with: .success(()))
            case .failed(let error):
                holder.resume(with: .failure(TelnetError.connectionFailed(error.localizedDescription)))
                guard let self else { return }
                Task { await self.handleUnexpectedDisconnect() }
            case .cancelled:
                holder.resume(with: .failure(TelnetError.cancelled))
                guard let self else { return }
                Task { await self.handleUnexpectedDisconnect() }
            default:
                break
            }
        }
        conn.start(queue: DispatchQueue(label: "app.shellmate.telnet.nw", qos: .userInitiated))

        try await withCheckedThrowingContinuation { cont in
            holder.continuation = cont
        }

        // 到达此处说明连接已就绪（否则上方抛出异常）
        _isConnected = true
        startReceiving()
    }

    // MARK: - 写入

    func write(_ data: Data) {
        guard _isConnected, let conn = connection else { return }
        conn.send(content: data, completion: .idempotent)
    }

    // MARK: - 断开

    func disconnect() {
        _isConnected = false
        connection?.cancel()
        connection = nil
    }

    // MARK: - 终端尺寸（NAWS）

    func updateWindowSize(columns: Int, rows: Int) {
        self.cols = columns
        self.rows = rows
        guard _isConnected else { return }
        let naws: [UInt8] = [
            IAC.iac, IAC.sb, IAC.naws,
            UInt8(columns >> 8 & 0xFF), UInt8(columns & 0xFF),
            UInt8(rows    >> 8 & 0xFF), UInt8(rows    & 0xFF),
            IAC.iac, IAC.se
        ]
        write(Data(naws))
    }

    // MARK: - 接收循环

    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            let hasError = error != nil
            Task { await self.handleReceived(content: content, isComplete: isComplete, hasError: hasError) }
        }
    }

    private func handleReceived(content: Data?, isComplete: Bool, hasError: Bool) {
        guard _isConnected else { return }

        if let data = content, !data.isEmpty {
            let (clean, responses) = processIAC(data)
            for r in responses { write(r) }
            if !clean.isEmpty { onDataReceived?(clean) }
        }

        if hasError || isComplete {
            _isConnected = false
            onDisconnected?()
        } else {
            startReceiving()
        }
    }

    private func handleUnexpectedDisconnect() {
        guard _isConnected else { return }
        _isConnected = false
        onDisconnected?()
    }

    // MARK: - IAC 协议处理

    private func processIAC(_ data: Data) -> (clean: Data, responses: [Data]) {
        let bytes = [UInt8](data)
        var clean: [UInt8] = []
        var responses: [Data] = []
        var i = 0

        while i < bytes.count {
            guard bytes[i] == IAC.iac else {
                clean.append(bytes[i])
                i += 1
                continue
            }

            i += 1
            guard i < bytes.count else { break }
            let cmd = bytes[i]
            i += 1

            switch cmd {
            case IAC.sb:
                // 子协商：跳到 IAC SE
                while i < bytes.count - 1 {
                    if bytes[i] == IAC.iac && bytes[i + 1] == IAC.se { i += 2; break }
                    i += 1
                }
            case IAC.will, IAC.wont, IAC.doCmd, IAC.dont:
                guard i < bytes.count else { break }
                let opt = bytes[i]; i += 1
                if let resp = negotiationResponse(cmd: cmd, option: opt) {
                    responses.append(resp)
                }
            case IAC.iac:
                // 0xFF 0xFF → 字面量 0xFF
                clean.append(IAC.iac)
            default:
                break
            }
        }
        return (Data(clean), responses)
    }

    private func negotiationResponse(cmd: UInt8, option: UInt8) -> Data? {
        switch (cmd, option) {
        case (IAC.will, IAC.echo):  return Data([IAC.iac, IAC.doCmd, IAC.echo])
        case (IAC.will, IAC.sga):   return Data([IAC.iac, IAC.doCmd, IAC.sga])
        case (IAC.doCmd, IAC.echo): return Data([IAC.iac, IAC.will,  IAC.echo])
        case (IAC.doCmd, IAC.sga):  return Data([IAC.iac, IAC.will,  IAC.sga])
        case (IAC.doCmd, IAC.naws):
            var r = Data([IAC.iac, IAC.will, IAC.naws])
            r.append(contentsOf: [
                IAC.iac, IAC.sb, IAC.naws,
                UInt8(cols >> 8 & 0xFF), UInt8(cols & 0xFF),
                UInt8(rows >> 8 & 0xFF), UInt8(rows & 0xFF),
                IAC.iac, IAC.se
            ])
            return r
        case (IAC.doCmd, IAC.ttype): return Data([IAC.iac, IAC.wont, IAC.ttype])
        case (IAC.doCmd, let opt):   return Data([IAC.iac, IAC.wont, opt])
        case (IAC.will,  let opt):   return Data([IAC.iac, IAC.dont, opt])
        default: return nil
        }
    }
}

// MARK: - TelnetError

enum TelnetError: LocalizedError {
    case invalidPort(UInt16)
    case connectionFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidPort(let p):      return "无效端口号: \(p)"
        case .connectionFailed(let r): return "Telnet 连接失败: \(r)"
        case .cancelled:               return "连接已取消"
        }
    }
}
