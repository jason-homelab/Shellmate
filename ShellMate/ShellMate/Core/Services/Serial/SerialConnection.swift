import Foundation
import Darwin

/// 串口连接（actor 隔离，消除 DispatchSource 回调与调用方之间的数据竞争）
/// 基于 POSIX termios API 管理串口设备（RS-232 / USB 转串口）。
/// 适用于网络设备控制台访问（Cisco console、交换机 console 等）。
actor SerialConnection {

    // MARK: - 属性

    var onDataReceived: (@Sendable (Data) -> Void)?
    var onDisconnected: (@Sendable () -> Void)?

    var isConnected: Bool { fd != -1 }

    private var fd: Int32 = -1
    private var readSource: DispatchSourceRead?

    // MARK: - 初始化

    deinit {
        readSource?.cancel()
        if fd != -1 { close(fd) }
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

    func connect(
        portPath:    String,
        baudRate:    Int32,
        dataBits:    Int32 = 8,
        parity:      String = "none",
        stopBits:    Int32 = 1,
        flowControl: String = "none"
    ) throws {
        // 打开串口（O_NONBLOCK 避免在 DCD 未 assert 时阻塞）
        let descriptor = open(portPath, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard descriptor != -1 else {
            throw SerialError.portOpenFailed(path: portPath, code: errno)
        }

        // 配置为阻塞模式（避免 EAGAIN 循环）
        let flags = fcntl(descriptor, F_GETFL)
        _ = fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK)

        // 配置 termios
        var options = termios()
        guard tcgetattr(descriptor, &options) == 0 else {
            close(descriptor)
            throw SerialError.configFailed("tcgetattr 失败，errno=\(errno)")
        }

        // 波特率
        let speed = baudConstant(baudRate)
        cfsetispeed(&options, speed)
        cfsetospeed(&options, speed)

        // 本地模式 + 启用接收
        options.c_cflag |= tcflag_t(CLOCAL | CREAD)

        // 数据位
        options.c_cflag &= ~tcflag_t(CSIZE)
        switch dataBits {
        case 5: options.c_cflag |= tcflag_t(CS5)
        case 6: options.c_cflag |= tcflag_t(CS6)
        case 7: options.c_cflag |= tcflag_t(CS7)
        default: options.c_cflag |= tcflag_t(CS8)
        }

        // 奇偶校验
        switch parity {
        case "odd":
            options.c_cflag |= tcflag_t(PARENB | PARODD)
        case "even":
            options.c_cflag |= tcflag_t(PARENB)
            options.c_cflag &= ~tcflag_t(PARODD)
        default:
            options.c_cflag &= ~tcflag_t(PARENB)
        }

        // 停止位
        if stopBits == 2 {
            options.c_cflag |= tcflag_t(CSTOPB)
        } else {
            options.c_cflag &= ~tcflag_t(CSTOPB)
        }

        // 流控
        switch flowControl {
        case "hardware":
            options.c_cflag |= tcflag_t(CRTSCTS)
            options.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)
        case "software":
            options.c_cflag &= ~tcflag_t(CRTSCTS)
            options.c_iflag |= tcflag_t(IXON | IXOFF)
        default:
            options.c_cflag &= ~tcflag_t(CRTSCTS)
            options.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)
        }

        // 原始模式（禁用 canonical、echo、信号）
        options.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG)
        // 禁用输出处理
        options.c_oflag &= ~tcflag_t(OPOST)
        // 读取最小字节/超时（VMIN=1, VTIME=0）
        withUnsafeMutableBytes(of: &options.c_cc) { ptr in
            ptr[Int(VMIN)]  = 1
            ptr[Int(VTIME)] = 0
        }

        guard tcsetattr(descriptor, TCSANOW, &options) == 0 else {
            close(descriptor)
            throw SerialError.configFailed("tcsetattr 失败，errno=\(errno)")
        }

        self.fd = descriptor
        startReading()
    }

    // MARK: - 写入

    func write(_ data: Data) throws {
        guard fd != -1 else { throw SerialError.notConnected }
        let result = data.withUnsafeBytes { ptr -> Int in
            Darwin.write(fd, ptr.baseAddress!, data.count)
        }
        if result < 0 { throw SerialError.writeFailed(errno: errno) }
    }

    // MARK: - 断开

    func disconnect() {
        guard fd != -1 else { return }
        readSource?.cancel()
        readSource = nil
        close(fd)
        fd = -1
        onDisconnected?()
    }

    // MARK: - 读取循环

    private func startReading() {
        let descriptor = fd
        let queue = DispatchQueue(label: "app.shellmate.serial.io", qos: .userInitiated)
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.doRead() }
        }
        source.resume()
        self.readSource = source
    }

    private func doRead() {
        guard fd != -1 else { return }
        var buffer = [UInt8](repeating: 0, count: 4096)
        let descriptor = fd
        let n = Darwin.read(descriptor, &buffer, 4096)
        if n > 0 {
            onDataReceived?(Data(buffer.prefix(n)))
        } else if n == 0 || (n < 0 && errno != EAGAIN && errno != EINTR) {
            disconnect()
        }
    }

    // MARK: - 辅助

    private func baudConstant(_ rate: Int32) -> speed_t {
        switch rate {
        case 1200:   return speed_t(B1200)
        case 2400:   return speed_t(B2400)
        case 4800:   return speed_t(B4800)
        case 9600:   return speed_t(B9600)
        case 19200:  return speed_t(B19200)
        case 38400:  return speed_t(B38400)
        case 57600:  return speed_t(B57600)
        case 115200: return speed_t(B115200)
        case 230400: return speed_t(B230400)
        default:     return speed_t(B9600)
        }
    }
}

// MARK: - SerialError

enum SerialError: LocalizedError {
    case portOpenFailed(path: String, code: Int32)
    case configFailed(String)
    case notConnected
    case writeFailed(errno: Int32)

    var errorDescription: String? {
        switch self {
        case .portOpenFailed(let path, let code):
            return "无法打开串口 \(path)（错误码: \(code)）"
        case .configFailed(let reason):
            return "串口配置失败: \(reason)"
        case .notConnected:
            return "串口未连接"
        case .writeFailed(let code):
            return "串口写入失败（错误码: \(code)）"
        }
    }
}
