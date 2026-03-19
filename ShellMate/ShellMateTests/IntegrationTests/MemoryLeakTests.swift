import XCTest
@testable import ShellMate

/// 内存泄漏测试
/// W9.4: 内存泄漏检查（Instruments Leaks，3 会话并发）
final class MemoryLeakTests: XCTestCase {

    // MARK: - 属性

    /// 内存基准线
    private var baselineMemory: UInt64 = 0

    /// 允许的内存增长阈值（字节）
    private let memoryThreshold: UInt64 = 50 * 1024 * 1024 // 50MB

    // MARK: - 设置

    override func setUpWithError() throws {
        try super.setUpWithError()

        // 强制垃圾回收
        autoreleasepool { }

        // 记录基准内存
        baselineMemory = currentMemoryUsage()
    }

    override func tearDownWithError() throws {
        // 检查内存增长
        let currentMemory = currentMemoryUsage()
        let memoryGrowth = currentMemory > baselineMemory ? currentMemory - baselineMemory : 0

        print("内存增长: \(formatBytes(memoryGrowth))")

        if memoryGrowth > memoryThreshold {
            print("警告: 内存增长超过阈值 (\(formatBytes(memoryThreshold)))")
        }

        try super.tearDownWithError()
    }

    // MARK: - 测试用例

    /// 测试单个 SSH 连接的内存使用
    func testSingleConnectionMemory() async throws {
        let initialMemory = currentMemoryUsage()

        // 创建并使用连接
        autoreleasepool {
            let config = SSHSessionConfig(
                host: "localhost",
                port: 22,
                username: "test",
                authMethod: .password,
                password: "test"
            )

            let connection = SSHConnection(config: config)

            Task {
                // 模拟使用
                let _ = await connection.state
            }
        }

        // 等待清理
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let finalMemory = currentMemoryUsage()
        let growth = finalMemory > initialMemory ? finalMemory - initialMemory : 0

        print("单连接内存增长: \(formatBytes(growth))")

        // 单个连接内存增长应该很小
        XCTAssertLessThan(growth, 5 * 1024 * 1024, "单连接内存增长不应超过 5MB")
    }

    /// 测试 3 个并发连接的内存使用
    func testConcurrentConnectionsMemory() async throws {
        let initialMemory = currentMemoryUsage()

        // 创建 3 个并发连接
        var connections: [SSHConnection] = []

        autoreleasepool {
            for i in 0..<3 {
                let config = SSHSessionConfig(
                    host: "localhost",
                    port: 22,
                    username: "test\(i)",
                    authMethod: .password,
                    password: "test"
                )
                connections.append(SSHConnection(config: config))
            }
        }

        // 模拟并发使用
        await withTaskGroup(of: Void.self) { group in
            for connection in connections {
                group.addTask {
                    // 模拟数据传输
                    let _ = await connection.state
                }
            }
        }

        let afterUsageMemory = currentMemoryUsage()
        let usageGrowth = afterUsageMemory > initialMemory ? afterUsageMemory - initialMemory : 0

        print("3 连接使用中内存增长: \(formatBytes(usageGrowth))")

        // 3 个并发连接内存应该控制在 150MB 以内
        XCTAssertLessThan(usageGrowth, 150 * 1024 * 1024, "3 并发连接内存不应超过 150MB RSS")

        // 断开所有连接
        for connection in connections {
            await connection.disconnect()
        }
        connections.removeAll()

        // 等待清理
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let finalMemory = currentMemoryUsage()
        let residualGrowth = finalMemory > initialMemory ? finalMemory - initialMemory : 0

        print("清理后残留内存增长: \(formatBytes(residualGrowth))")

        // 清理后内存应该回落
        XCTAssertLessThan(residualGrowth, 20 * 1024 * 1024, "清理后残留内存不应超过 20MB")
    }

    /// 测试重复连接/断开的内存泄漏
    func testRepeatedConnectionMemoryLeak() async throws {
        let initialMemory = currentMemoryUsage()
        let iterations = 10

        for i in 0..<iterations {
            autoreleasepool {
                let config = SSHSessionConfig(
                    host: "localhost",
                    port: 22,
                    username: "test",
                    authMethod: .password,
                    password: "test"
                )

                let connection = SSHConnection(config: config)

                Task {
                    let _ = await connection.state
                    await connection.disconnect()
                }
            }

            // 短暂等待
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        // 等待所有任务完成
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let finalMemory = currentMemoryUsage()
        let growth = finalMemory > initialMemory ? finalMemory - initialMemory : 0
        let growthPerIteration = growth / UInt64(iterations)

        print("重复连接总内存增长: \(formatBytes(growth))")
        print("每次迭代平均增长: \(formatBytes(growthPerIteration))")

        // 重复连接不应该导致持续内存增长
        XCTAssertLessThan(growthPerIteration, 1 * 1024 * 1024, "每次连接/断开循环内存增长不应超过 1MB")
    }

    /// 测试终端控制器的内存使用
    func testTerminalControllerMemory() async throws {
        let initialMemory = currentMemoryUsage()

        var controllers: [TerminalController] = []

        // 创建 3 个终端控制器
        for _ in 0..<3 {
            let session = Session(
                name: "测试",
                host: "localhost",
                username: "test"
            )

            let controller = await TerminalController(session: session)
            controllers.append(controller)
        }

        let afterCreateMemory = currentMemoryUsage()
        let createGrowth = afterCreateMemory > initialMemory ? afterCreateMemory - initialMemory : 0

        print("创建 3 个控制器内存增长: \(formatBytes(createGrowth))")

        // 清理
        for controller in controllers {
            await controller.disconnect()
        }
        controllers.removeAll()

        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        let finalMemory = currentMemoryUsage()
        let residualGrowth = finalMemory > initialMemory ? finalMemory - initialMemory : 0

        print("清理后残留内存: \(formatBytes(residualGrowth))")
    }

    /// 测试数据缓冲区的内存管理
    func testDataBufferMemory() async throws {
        let initialMemory = currentMemoryUsage()

        // 模拟大量数据处理
        autoreleasepool {
            var buffers: [Data] = []

            for _ in 0..<100 {
                // 创建 1MB 数据块
                let data = Data(repeating: 0x00, count: 1024 * 1024)
                buffers.append(data)
            }

            // 处理数据
            for buffer in buffers {
                _ = buffer.count
            }

            // 清理
            buffers.removeAll()
        }

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let finalMemory = currentMemoryUsage()
        let growth = finalMemory > initialMemory ? finalMemory - initialMemory : 0

        print("数据处理后内存增长: \(formatBytes(growth))")

        // 大量数据处理后不应有显著内存残留
        XCTAssertLessThan(growth, 10 * 1024 * 1024, "数据处理后残留内存不应超过 10MB")
    }

    /// 测试 AsyncStream 的内存管理
    func testAsyncStreamMemory() async throws {
        let initialMemory = currentMemoryUsage()

        // 创建多个 AsyncStream
        var streams: [AsyncStream<Data>] = []
        var continuations: [AsyncStream<Data>.Continuation] = []

        for _ in 0..<10 {
            let (stream, continuation) = AsyncStream<Data>.makeStream(
                bufferingPolicy: .bufferingNewest(100)
            )
            streams.append(stream)
            continuations.append(continuation)
        }

        // 发送数据
        for continuation in continuations {
            for _ in 0..<100 {
                continuation.yield(Data(repeating: 0x00, count: 1024)) // 1KB
            }
            continuation.finish()
        }

        // 清理
        streams.removeAll()
        continuations.removeAll()

        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        let finalMemory = currentMemoryUsage()
        let growth = finalMemory > initialMemory ? finalMemory - initialMemory : 0

        print("AsyncStream 清理后内存增长: \(formatBytes(growth))")
    }

    // MARK: - 辅助方法

    /// 获取当前内存使用量
    private func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }

    /// 格式化字节数
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - 内存监控器

/// 内存监控器
/// 用于运行时监控内存使用情况
final class MemoryMonitor {

    static let shared = MemoryMonitor()

    /// 内存警告阈值
    var warningThreshold: UInt64 = 500 * 1024 * 1024 // 500MB

    /// 内存错误阈值
    var errorThreshold: UInt64 = 1024 * 1024 * 1024 // 1GB

    /// 监控定时器
    private var timer: Timer?

    /// 内存历史记录
    private var memoryHistory: [UInt64] = []

    /// 最大历史记录数
    private let maxHistoryCount = 60

    private init() {}

    /// 开始监控
    func startMonitoring(interval: TimeInterval = 1.0) {
        stopMonitoring()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkMemory()
        }
    }

    /// 停止监控
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// 检查内存
    private func checkMemory() {
        let currentMemory = getCurrentMemory()

        // 记录历史
        memoryHistory.append(currentMemory)
        if memoryHistory.count > maxHistoryCount {
            memoryHistory.removeFirst()
        }

        // 检查阈值
        if currentMemory > errorThreshold {
            print("⛔️ 内存错误: \(formatBytes(currentMemory)) > \(formatBytes(errorThreshold))")
        } else if currentMemory > warningThreshold {
            print("⚠️ 内存警告: \(formatBytes(currentMemory)) > \(formatBytes(warningThreshold))")
        }
    }

    /// 获取当前内存
    private func getCurrentMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    /// 格式化字节数
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// 获取内存报告
    func getMemoryReport() -> String {
        let current = getCurrentMemory()
        let average = memoryHistory.isEmpty ? 0 : memoryHistory.reduce(0, +) / UInt64(memoryHistory.count)
        let peak = memoryHistory.max() ?? 0

        return """
        内存使用报告:
        - 当前: \(formatBytes(current))
        - 平均: \(formatBytes(average))
        - 峰值: \(formatBytes(peak))
        - 警告阈值: \(formatBytes(warningThreshold))
        - 错误阈值: \(formatBytes(errorThreshold))
        """
    }
}
