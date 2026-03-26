import Foundation

/// 服务器性能监控器
/// 通过独立的 libssh2 连接轮询远端 /proc 指标，支持全部认证方式
/// 每 5 秒采集一次，首次轮询建立基准值，第二次起开始发布增量指标
@MainActor
final class ServerMetricsMonitor {

    // MARK: - 内部快照（用于计算增量）

    private struct CPUSnapshot {
        let user, nice, system, idle, iowait, irq, softirq: Int64
        var total: Int64 { user + nice + system + idle + iowait + irq + softirq }
        var active: Int64 { total - idle - iowait }
    }

    private struct NetSnapshot {
        let rx: Int64
        let tx: Int64
    }

    // MARK: - 属性

    private(set) var metrics: ServerMetrics?

    /// 指标更新回调（在主线程调用）
    var onUpdate: ((ServerMetrics?) -> Void)?

    private let host: String
    private let port: Int32
    private let username: String
    private let authMethod: AuthMethod
    private let privateKeyPath: String
    private let password: String?
    private let passphrase: String?

    private var timer: Timer?
    private var isPollRunning = false
    private var isFirstPoll = true
    private var prevCPU: CPUSnapshot?
    private var prevNet: NetSnapshot?
    private var prevPollTime: Date?

    // MARK: - 指标采集命令

    /// 首次采集命令：内置 sleep 1，采集两次快照后直接算增量
    /// 输出 6 行：CPU1 / NET1 / CPU2 / NET2 / MEM / DISK
    private static let firstPollCmd = [
        // 快照 1
        "awk 'NR==1{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat",
        "awk 'NR>2{rx+=$2;tx+=$10} END{printf \"%d %d\\n\",rx,tx}' /proc/net/dev",
        "sleep 1",
        // 快照 2 + 内存 + 磁盘
        "awk 'NR==1{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat",
        "awk 'NR>2{rx+=$2;tx+=$10} END{printf \"%d %d\\n\",rx,tx}' /proc/net/dev",
        "awk '/MemTotal/{mt=$2} /MemAvailable/{ma=$2} END{printf \"%d %d\\n\",mt-ma,mt}' /proc/meminfo",
        "df / | awk 'NR==2{printf \"%d %d\\n\",$3,$2}'"
    ].joined(separator: "; ")

    /// 常规采集命令（单次快照，与上次轮询算增量）
    /// 输出 4 行：CPU / MEM / DISK / NET
    private static let regularCmd = [
        "awk 'NR==1{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat",
        "awk '/MemTotal/{mt=$2} /MemAvailable/{ma=$2} END{printf \"%d %d\\n\",mt-ma,mt}' /proc/meminfo",
        "df / | awk 'NR==2{printf \"%d %d\\n\",$3,$2}'",
        "awk 'NR>2{rx+=$2;tx+=$10} END{printf \"%d %d\\n\",rx,tx}' /proc/net/dev"
    ].joined(separator: "; ")

    // MARK: - 初始化

    init(session: Session, password: String? = nil, passphrase: String? = nil) {
        self.host = session.host
        self.port = session.port
        self.username = session.username
        self.authMethod = session.authMethod
        self.privateKeyPath = session.privateKeyPath ?? ""
        self.password = password
        self.passphrase = passphrase
    }

    // MARK: - 生命周期

    func start() {
        // 立即采集一次基准值
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        prevCPU = nil
        prevNet = nil
        prevPollTime = nil
        metrics = nil
        onUpdate?(nil)
    }

    // MARK: - 采集

    private func poll() {
        guard !isPollRunning else { return }
        isPollRunning = true

        let host = self.host
        let port = self.port
        let username = self.username
        let authMethod = self.authMethod
        let privateKeyPath = self.privateKeyPath
        let password = self.password
        let passphrase = self.passphrase
        let isFirst = self.isFirstPoll
        let cmd = isFirst ? Self.firstPollCmd : Self.regularCmd

        Task.detached(priority: .utility) { [weak self] in
            let output = Self.runSSH(
                cmd: cmd,
                host: host, port: port, username: username,
                authMethod: authMethod,
                privateKeyPath: privateKeyPath,
                password: password,
                passphrase: passphrase
            )
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isPollRunning = false
                guard let output, !output.isEmpty else { return }
                if isFirst {
                    self.isFirstPoll = false
                    self.parseFirstPoll(output)
                } else {
                    self.parseRegular(output)
                }
            }
        }
    }

    // MARK: - SSH 执行（nonisolated 静态方法，在后台线程运行）

    private nonisolated static func runSSH(
        cmd: String,
        host: String,
        port: Int32,
        username: String,
        authMethod: AuthMethod,
        privateKeyPath: String,
        password: String?,
        passphrase: String?
    ) -> String? {
        let bridge = LibSSH2BridgeReal()

        do {
            // 建立 TCP 连接与握手
            try bridge.sessionInit()
            bridge.setTimeout(5000)
            try bridge.tcpConnect(host: host, port: port)
            try bridge.handshake()

            // 认证
            switch authMethod {
            case .password, .keyboardInteractive:
                guard let pass = password, !pass.isEmpty else { return nil }
                try bridge.authenticateWithPassword(username: username, password: pass)
            case .privateKey:
                guard !privateKeyPath.isEmpty else { return nil }
                try bridge.authenticateWithPublicKey(
                    username: username,
                    publicKeyPath: nil,
                    privateKeyPath: privateKeyPath,
                    passphrase: passphrase
                )
            case .sshAgent:
                try bridge.authenticateWithAgent(username: username)
            }

            // 执行指标采集命令
            let output = try bridge.execCommand(cmd)
            bridge.disconnect()
            return output

        } catch {
            bridge.disconnect()
            return nil
        }
    }

    // MARK: - 解析

    /// 首次采集解析（6 行：CPU1 / NET1 / CPU2 / NET2 / MEM / DISK）
    /// 利用两次快照直接计算增量，立即发布指标（约 1 秒后得到结果）
    private func parseFirstPoll(_ output: String) {
        let lines = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
        guard lines.count >= 6 else { return }

        guard let cpu1 = parseCPU(lines[0]),
              let net1 = parseNet(lines[1]),
              let cpu2 = parseCPU(lines[2]),
              let net2 = parseNet(lines[3]),
              let (memUsed, memTotal) = parsePair(lines[4], scale: 1024),
              let (diskUsed, diskTotal) = parsePair(lines[5], scale: 1024)
        else { return }

        // CPU 增量（1 秒间隔）
        let dTotal = cpu2.total - cpu1.total
        let dActive = cpu2.active - cpu1.active
        let cpuUsage = dTotal > 0 ? Double(dActive) / Double(dTotal) * 100.0 : 0

        // 网络速率（1 秒间隔）
        let rxRate = Double(max(0, net2.rx - net1.rx))
        let txRate = Double(max(0, net2.tx - net1.tx))

        // 用第二次快照作为下次轮询的基准
        let now = Date()
        prevCPU = cpu2
        prevNet = net2
        prevPollTime = now

        publish(cpuUsage: cpuUsage, memUsed: memUsed, memTotal: memTotal,
                diskUsed: diskUsed, diskTotal: diskTotal,
                rxRate: rxRate, txRate: txRate, at: now)
    }

    /// 常规采集解析（4 行：CPU / MEM / DISK / NET，与上次轮询算增量）
    private func parseRegular(_ output: String) {
        let lines = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
        guard lines.count >= 4 else { return }

        guard let cpu = parseCPU(lines[0]),
              let (memUsed, memTotal) = parsePair(lines[1], scale: 1024),
              let (diskUsed, diskTotal) = parsePair(lines[2], scale: 1024),
              let net = parseNet(lines[3])
        else { return }

        let now = Date()

        var cpuUsage: Double = 0
        if let prev = prevCPU {
            let dTotal = cpu.total - prev.total
            let dActive = cpu.active - prev.active
            if dTotal > 0 { cpuUsage = Double(dActive) / Double(dTotal) * 100.0 }
        }

        var rxRate: Double = 0
        var txRate: Double = 0
        if let prevN = prevNet, let prevT = prevPollTime {
            let elapsed = now.timeIntervalSince(prevT)
            if elapsed > 0 {
                rxRate = Double(max(0, net.rx - prevN.rx)) / elapsed
                txRate = Double(max(0, net.tx - prevN.tx)) / elapsed
            }
        }

        prevCPU = cpu
        prevNet = net
        prevPollTime = now

        publish(cpuUsage: cpuUsage, memUsed: memUsed, memTotal: memTotal,
                diskUsed: diskUsed, diskTotal: diskTotal,
                rxRate: rxRate, txRate: txRate, at: now)
    }

    // MARK: - 解析辅助

    private func parseCPU(_ line: String) -> CPUSnapshot? {
        let parts = line.split(separator: " ").compactMap { Int64($0) }
        guard parts.count >= 7 else { return nil }
        return CPUSnapshot(user: parts[0], nice: parts[1], system: parts[2],
                           idle: parts[3], iowait: parts[4], irq: parts[5], softirq: parts[6])
    }

    private func parseNet(_ line: String) -> NetSnapshot? {
        let parts = line.split(separator: " ").compactMap { Int64($0) }
        guard parts.count >= 2 else { return nil }
        return NetSnapshot(rx: parts[0], tx: parts[1])
    }

    private func parsePair(_ line: String, scale: Int64) -> (Int64, Int64)? {
        let parts = line.split(separator: " ").compactMap { Int64($0) }
        guard parts.count >= 2 else { return nil }
        return (parts[0] * scale, parts[1] * scale)
    }

    private func publish(cpuUsage: Double, memUsed: Int64, memTotal: Int64,
                         diskUsed: Int64, diskTotal: Int64,
                         rxRate: Double, txRate: Double, at date: Date) {
        let result = ServerMetrics(
            cpuUsage: max(0, min(100, cpuUsage)),
            memoryUsed: memUsed, memoryTotal: memTotal,
            diskUsed: diskUsed, diskTotal: diskTotal,
            networkRxRate: max(0, rxRate), networkTxRate: max(0, txRate),
            updatedAt: date
        )
        metrics = result
        onUpdate?(result)
    }
}
