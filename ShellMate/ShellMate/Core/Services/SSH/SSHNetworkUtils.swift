import Foundation
import Network
import Darwin

/// DNS 解析结果
struct DNSResolutionResult {
    /// 解析的 IP 地址列表
    let addresses: [String]

    /// 首选 IP 地址
    var preferredAddress: String? {
        // 优先 IPv4
        return addresses.first { $0.contains(".") } ?? addresses.first
    }

    /// 解析耗时（毫秒）
    let resolutionTime: TimeInterval

    /// 是否为 IPv6
    var hasIPv6: Bool {
        return addresses.contains { $0.contains(":") }
    }

    /// 是否为 IPv4
    var hasIPv4: Bool {
        return addresses.contains { $0.contains(".") }
    }
}

/// DNS 解析器
/// 提供异步 DNS 解析功能
final class DNSResolver {

    // MARK: - 单例

    static let shared = DNSResolver()

    // MARK: - 属性

    /// 解析超时时间（秒）
    var timeout: TimeInterval = 10

    /// DNS 缓存
    private var cache: [String: (result: DNSResolutionResult, expiry: Date)] = [:]

    /// 缓存锁
    private let cacheLock = NSLock()

    /// 缓存有效期（秒）
    private let cacheTTL: TimeInterval = 300 // 5 分钟

    // MARK: - 初始化

    private init() {}

    // MARK: - 解析方法

    /// 解析主机名
    /// - Parameter host: 主机名或 IP 地址
    /// - Returns: 解析结果
    func resolve(_ host: String) async throws -> DNSResolutionResult {
        // 检查是否为 IP 地址
        if isIPAddress(host) {
            return DNSResolutionResult(
                addresses: [host],
                resolutionTime: 0
            )
        }

        // 检查缓存
        if let cached = getCachedResult(for: host) {
            return cached
        }

        // 执行解析
        let startTime = CFAbsoluteTimeGetCurrent()

        return try await withCheckedThrowingContinuation { continuation in
            resolveAsync(host: host) { result in
                switch result {
                case .success(let addresses):
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let resolutionTime = (endTime - startTime) * 1000 // 毫秒

                    let dnsResult = DNSResolutionResult(
                        addresses: addresses,
                        resolutionTime: resolutionTime
                    )

                    // 缓存结果
                    self.cacheResult(dnsResult, for: host)

                    continuation.resume(returning: dnsResult)

                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 异步解析（内部实现）
    private func resolveAsync(host: String, completion: @escaping (Result<[String], SSHError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC // IPv4 和 IPv6
            hints.ai_socktype = SOCK_STREAM
            hints.ai_protocol = IPPROTO_TCP

            var result: UnsafeMutablePointer<addrinfo>?

            let resolveResult = getaddrinfo(host, nil, &hints, &result)

            if resolveResult != 0 {
                let errorMessage = String(cString: gai_strerror(resolveResult))
                completion(.failure(SSHError.dnsResolutionFailed(host: "\(host) - \(errorMessage)")))
                return
            }

            guard let firstResult = result else {
                completion(.failure(SSHError.dnsResolutionFailed(host: host)))
                return
            }

            defer { freeaddrinfo(result) }

            var addresses: [String] = []
            var current: UnsafeMutablePointer<addrinfo>? = firstResult

            while let info = current {
                if let addressString = self.addressToString(info.pointee) {
                    if !addresses.contains(addressString) {
                        addresses.append(addressString)
                    }
                }
                current = info.pointee.ai_next
            }

            if addresses.isEmpty {
                completion(.failure(SSHError.dnsResolutionFailed(host: host)))
            } else {
                completion(.success(addresses))
            }
        }
    }

    /// 将地址结构转换为字符串
    private func addressToString(_ info: addrinfo) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

        let result = getnameinfo(
            info.ai_addr,
            info.ai_addrlen,
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            NI_NUMERICHOST
        )

        if result == 0 {
            return String(cString: hostname)
        }
        return nil
    }

    /// 检查是否为 IP 地址
    private func isIPAddress(_ string: String) -> Bool {
        // IPv4 检查
        var addr4 = in_addr()
        if inet_pton(AF_INET, string, &addr4) == 1 {
            return true
        }

        // IPv6 检查
        var addr6 = in6_addr()
        if inet_pton(AF_INET6, string, &addr6) == 1 {
            return true
        }

        return false
    }

    // MARK: - 缓存

    /// 获取缓存结果
    private func getCachedResult(for host: String) -> DNSResolutionResult? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let cached = cache[host.lowercased()] else {
            return nil
        }

        // 检查是否过期
        if cached.expiry > Date() {
            return cached.result
        }

        // 过期，删除
        cache.removeValue(forKey: host.lowercased())
        return nil
    }

    /// 缓存结果
    private func cacheResult(_ result: DNSResolutionResult, for host: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        cache[host.lowercased()] = (result, Date().addingTimeInterval(cacheTTL))
    }

    /// 清除缓存
    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeAll()
    }

    /// 清除指定主机的缓存
    func clearCache(for host: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cache.removeValue(forKey: host.lowercased())
    }
}

// MARK: - TCP 连接工具

/// TCP 连接选项
struct TCPConnectionOptions {
    /// 连接超时（秒）
    var timeout: TimeInterval = 30

    /// 是否启用 TCP_NODELAY
    var noDelay: Bool = true

    /// 是否启用 SO_KEEPALIVE
    var keepAlive: Bool = true

    /// 接收缓冲区大小
    var receiveBufferSize: Int = 65536

    /// 发送缓冲区大小
    var sendBufferSize: Int = 65536

    /// 是否优先使用 IPv4
    var preferIPv4: Bool = true
}

/// TCP 连接器
/// 提供增强的 TCP 连接功能
final class TCPConnector: @unchecked Sendable {

    // MARK: - 属性

    /// 连接选项
    let options: TCPConnectionOptions

    /// DNS 解析器
    private let dnsResolver = DNSResolver.shared

    // MARK: - 初始化

    init(options: TCPConnectionOptions = TCPConnectionOptions()) {
        self.options = options
    }

    // MARK: - 连接方法

    /// 建立 TCP 连接
    /// - Parameters:
    ///   - host: 主机名或 IP 地址
    ///   - port: 端口号
    /// - Returns: Socket 文件描述符
    func connect(host: String, port: Int32) async throws -> Int32 {
        // DNS 解析
        let dnsResult = try await dnsResolver.resolve(host)
        print("[TCPConnector] DNS 解析完成: \(dnsResult.addresses) (\(dnsResult.resolutionTime)ms)")

        // 选择地址
        guard let address = selectAddress(from: dnsResult) else {
            throw SSHError.dnsResolutionFailed(host: host)
        }

        // 尝试连接
        return try await connectToAddress(address, port: port, originalHost: host)
    }

    /// 选择最佳地址
    private func selectAddress(from result: DNSResolutionResult) -> String? {
        if options.preferIPv4 {
            return result.addresses.first { $0.contains(".") } ?? result.addresses.first
        } else {
            return result.addresses.first { $0.contains(":") } ?? result.addresses.first
        }
    }

    /// 连接到指定地址
    private func connectToAddress(_ address: String, port: Int32, originalHost: String) async throws -> Int32 {
        // 确定地址族
        let isIPv6 = address.contains(":")
        let family: Int32 = isIPv6 ? AF_INET6 : AF_INET

        // 创建 socket
        let fd = socket(family, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else {
            throw SSHError.connectionFailed(host: originalHost, port: port, underlying: nil)
        }

        // 配置 socket 选项
        try configureSocket(fd)

        // 设置非阻塞模式（用于超时控制）
        var flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        // 构建地址结构
        let connectResult: Int32

        if isIPv6 {
            var addr = sockaddr_in6()
            addr.sin6_family = sa_family_t(AF_INET6)
            addr.sin6_port = in_port_t(port).bigEndian
            inet_pton(AF_INET6, address, &addr.sin6_addr)

            connectResult = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Darwin.connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in6>.size))
                }
            }
        } else {
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(UInt16(port)).bigEndian
            inet_pton(AF_INET, address, &addr.sin_addr)

            connectResult = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    Darwin.connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        // 检查连接结果
        if connectResult < 0 && errno != EINPROGRESS {
            close(fd)
            throw mapErrnoToError(originalHost: originalHost, port: port)
        }

        // 等待连接完成（带超时）
        try await waitForConnection(fd: fd, host: originalHost, port: port)

        // 恢复阻塞模式
        flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)

        print("[TCPConnector] TCP 连接成功: \(address):\(port)")
        return fd
    }

    /// 配置 socket 选项
    private func configureSocket(_ fd: Int32) throws {
        var value: Int32 = 1

        // TCP_NODELAY
        if options.noDelay {
            setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &value, socklen_t(MemoryLayout<Int32>.size))
        }

        // SO_KEEPALIVE
        if options.keepAlive {
            setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &value, socklen_t(MemoryLayout<Int32>.size))
        }

        // 接收缓冲区
        var recvBuf = Int32(options.receiveBufferSize)
        setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &recvBuf, socklen_t(MemoryLayout<Int32>.size))

        // 发送缓冲区
        var sendBuf = Int32(options.sendBufferSize)
        setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sendBuf, socklen_t(MemoryLayout<Int32>.size))
    }

    /// 等待连接完成
    private func waitForConnection(fd: Int32, host: String, port: Int32) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var writeSet = fd_set()
                var errorSet = fd_set()

                // 初始化 fd_set（__darwin_fd_zero/__darwin_fd_set 在 Swift 中不可用，直接赋值置零后手动设位）
                writeSet = fd_set()
                errorSet = fd_set()
                let byteIndex = Int(fd) / 32
                let bitIndex = Int(fd) % 32
                withUnsafeMutablePointer(to: &writeSet.fds_bits) { ptr in
                    ptr.withMemoryRebound(to: Int32.self, capacity: 32) { bits in
                        bits[byteIndex] |= Int32(bitPattern: UInt32(1) << bitIndex)
                    }
                }
                withUnsafeMutablePointer(to: &errorSet.fds_bits) { ptr in
                    ptr.withMemoryRebound(to: Int32.self, capacity: 32) { bits in
                        bits[byteIndex] |= Int32(bitPattern: UInt32(1) << bitIndex)
                    }
                }

                // 设置超时
                var timeout = timeval()
                timeout.tv_sec = Int(self.options.timeout)
                timeout.tv_usec = 0

                // 等待连接
                let selectResult = select(fd + 1, nil, &writeSet, &errorSet, &timeout)

                if selectResult < 0 {
                    continuation.resume(throwing: SSHError.connectionFailed(host: host, port: port, underlying: nil))
                } else if selectResult == 0 {
                    continuation.resume(throwing: SSHError.connectionTimeout(host: host, port: port))
                } else {
                    // 检查连接错误
                    var error: Int32 = 0
                    var errorLen = socklen_t(MemoryLayout<Int32>.size)
                    getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &errorLen)

                    if error != 0 {
                        continuation.resume(throwing: self.mapErrnoToError(error, host: host, port: port))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// 将 errno 映射为 SSHError
    private func mapErrnoToError(originalHost: String, port: Int32) -> SSHError {
        return mapErrnoToError(errno, host: originalHost, port: port)
    }

    private func mapErrnoToError(_ err: Int32, host: String, port: Int32) -> SSHError {
        switch err {
        case ECONNREFUSED:
            return SSHError.connectionRefused(host: host, port: port)
        case ENETUNREACH, EHOSTUNREACH:
            return SSHError.networkUnreachable
        case ETIMEDOUT:
            return SSHError.connectionTimeout(host: host, port: port)
        default:
            return SSHError.connectionFailed(host: host, port: port, underlying: nil)
        }
    }
}

// MARK: - 网络可达性检测

/// 网络可达性状态
enum NetworkReachabilityStatus {
    case reachable(ConnectionType)
    case unreachable

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case other
    }
}

/// 网络可达性监控器
final class NetworkReachabilityMonitor {

    // MARK: - 单例

    static let shared = NetworkReachabilityMonitor()

    // MARK: - 属性

    /// 网络路径监控器
    private var pathMonitor: NWPathMonitor?

    /// 监控队列
    private let monitorQueue = DispatchQueue(label: "app.shellmate.network.monitor")

    /// 当前状态
    private(set) var currentStatus: NetworkReachabilityStatus = .unreachable

    /// 状态变更回调
    var onStatusChange: ((NetworkReachabilityStatus) -> Void)?

    // MARK: - 初始化

    private init() {}

    // MARK: - 监控

    /// 开始监控
    func startMonitoring() {
        guard pathMonitor == nil else { return }

        let monitor = NWPathMonitor()

        monitor.pathUpdateHandler = { [weak self] path in
            let status = self?.mapPathToStatus(path) ?? .unreachable
            self?.currentStatus = status
            self?.onStatusChange?(status)
        }

        monitor.start(queue: monitorQueue)
        pathMonitor = monitor

        print("[NetworkMonitor] 开始监控网络状态")
    }

    /// 停止监控
    func stopMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
        print("[NetworkMonitor] 停止监控网络状态")
    }

    /// 检查主机是否可达
    func checkReachability(to host: String) async -> Bool {
        // 使用 DNS 解析来检查可达性
        do {
            _ = try await DNSResolver.shared.resolve(host)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 私有方法

    /// 将路径状态映射为可达性状态
    private func mapPathToStatus(_ path: NWPath) -> NetworkReachabilityStatus {
        guard path.status == .satisfied else {
            return .unreachable
        }

        if path.usesInterfaceType(.wifi) {
            return .reachable(.wifi)
        } else if path.usesInterfaceType(.cellular) {
            return .reachable(.cellular)
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .reachable(.wired)
        } else {
            return .reachable(.other)
        }
    }
}
