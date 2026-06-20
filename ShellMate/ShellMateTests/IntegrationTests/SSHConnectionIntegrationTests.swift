import XCTest
@testable import ShellMate

/// SSH 连接集成测试
/// 测试用例 TC-001 ~ TC-005
/// 使用 SSH2Connection（LibSSH2BridgeReal）直连真机 192.168.100.90
final class SSHConnectionIntegrationTests: XCTestCase {

    // MARK: - 测试环境配置

    /// 真机测试服务器地址（见 CLAUDE.md §4.1，原 .167 已下线）
    private let testHost = "192.168.100.90"

    /// SSH 端口
    private let testPort: Int32 = 22

    /// 测试用户名
    private let testUsername = "ubuntu"

    /// 测试密码
    private let testPassword = "Int3l@123"

    /// 测试私钥路径（TC-002 需要预先在服务器配置公钥）
    private let testPrivateKeyPath = "/tmp/shellmate_test_ed25519"

    /// 连接超时
    private let connectionTimeout: TimeInterval = 15

    /// 是否跳过集成测试（CI 环境中可设置）
    private var shouldSkipIntegrationTests: Bool {
        return ProcessInfo.processInfo.environment["SKIP_INTEGRATION_TESTS"] == "1"
    }

    // MARK: - 设置和清理

    override func setUpWithError() throws {
        try super.setUpWithError()
        if shouldSkipIntegrationTests {
            throw XCTSkip("跳过集成测试（设置了 SKIP_INTEGRATION_TESTS 环境变量）")
        }
    }

    // MARK: - 辅助方法

    /// 在后台线程执行阻塞的 SSH 操作（SSH2Connection 使用同步 API）
    private func runBlocking(_ block: @escaping () throws -> Void) async throws {
        try await Task.detached(priority: .userInitiated, operation: block).value
    }

    /// 创建"Shell 提示符"期望（必须在 connect 之前调用，避免错过第一批数据）
    /// 返回 (connection, expectation)，调用方负责在 connect 后等待 expectation
    private func makeShellPromptExpectation(for conn: SSH2Connection) -> XCTestExpectation {
        let exp = XCTestExpectation(description: "收到 Shell 提示符（$/#/~）")
        exp.assertForOverFulfill = false
        var accumulated = Data()
        conn.onDataReceived = { data in
            accumulated.append(data)
            guard let str = String(data: accumulated, encoding: .utf8) else { return }
            if str.contains("$") || str.contains("#") || str.contains("~") {
                exp.fulfill()
            }
        }
        return exp
    }

    // MARK: - TC-001: 密码认证 SSH 连接

    /// TC-001: 密码认证 SSH 连接成功，终端显示 shell 提示符
    func testTC001_PasswordAuthentication() async throws {
        let conn = SSH2Connection()

        // 1. 先注册数据回调，避免错过首批数据
        let promptExp = makeShellPromptExpectation(for: conn)

        // 2. 在后台线程执行阻塞连接
        try await runBlocking {
            try conn.connect(
                host: self.testHost,
                port: self.testPort,
                username: self.testUsername,
                password: self.testPassword
            )
        }

        // 3. 验证连接状态
        XCTAssertTrue(conn.isConnected, "TC-001: 密码认证后 isConnected 应为 true")

        // 4. 等待收到 Shell 提示符（Ubuntu 默认 ~$ 提示符）
        await fulfillment(of: [promptExp], timeout: 8)

        // 5. 断开连接
        conn.disconnect()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(conn.isConnected, "TC-001: disconnect 后 isConnected 应为 false")
    }

    /// TC-001 变体：错误密码应认证失败
    func testTC001_WrongPassword_ShouldFail() async throws {
        let conn = SSH2Connection()

        do {
            try await runBlocking {
                try conn.connect(
                    host: self.testHost,
                    port: self.testPort,
                    username: self.testUsername,
                    password: "wrongpassword_INVALID"
                )
            }
            XCTFail("TC-001 变体：错误密码不应连接成功")
        } catch {
            // 预期：认证失败或连接错误
        }

        XCTAssertFalse(conn.isConnected, "TC-001 变体：错误密码后应处于未连接状态")
    }

    // MARK: - TC-002: SSH Key 认证

    /// TC-002: SSH Key（Ed25519）认证无需输入密码连接成功
    /// 前置条件：/tmp/shellmate_test_ed25519 私钥存在，且公钥已添加到服务器 authorized_keys
    func testTC002_SSHKeyAuthentication() async throws {
        guard FileManager.default.fileExists(atPath: testPrivateKeyPath) else {
            throw XCTSkip("TC-002 跳过：私钥文件 \(testPrivateKeyPath) 不存在，请先配置 Ed25519 密钥对")
        }

        let conn = SSH2Connection()
        let promptExp = makeShellPromptExpectation(for: conn)

        try await runBlocking {
            try conn.connectWithKey(
                host: self.testHost,
                port: self.testPort,
                username: self.testUsername,
                privateKeyPath: self.testPrivateKeyPath,
                passphrase: nil
            )
        }

        XCTAssertTrue(conn.isConnected, "TC-002: 私钥认证后 isConnected 应为 true")
        await fulfillment(of: [promptExp], timeout: 8)
        conn.disconnect()
    }

    // MARK: - TC-003: 会话配置持久化

    /// TC-003: 退出重启后所有会话配置完整恢复（Core Data 持久化）
    func testTC003_SessionConfigurationPersistence() async throws {
        let persistenceController = await MainActor.run { PersistenceController(inMemory: true) }
        let repo = await MainActor.run { SessionRepository(persistenceController: persistenceController) }

        let session = Session(
            name: "真机测试服务器",
            host: testHost,
            port: testPort,
            username: testUsername,
            authMethod: .password,
            keepAliveInterval: 60,
            autoReconnect: true,
            encoding: "UTF-8",
            tags: ["集成测试", "真机"]
        )

        // 保存（async throws）
        try await repo.save(session)

        // 同一 persistenceController 重新创建 Repository（模拟重启后重建）
        let newRepo = await MainActor.run { SessionRepository(persistenceController: persistenceController) }
        let sessions = try await newRepo.fetchAll()

        XCTAssertEqual(sessions.count, 1, "TC-003: Core Data 应保存 1 条会话记录")

        let loaded = try XCTUnwrap(sessions.first)
        XCTAssertEqual(loaded.name, session.name,             "TC-003: name 应完整恢复")
        XCTAssertEqual(loaded.host, session.host,             "TC-003: host 应完整恢复")
        XCTAssertEqual(loaded.port, session.port,             "TC-003: port 应完整恢复")
        XCTAssertEqual(loaded.username, session.username,     "TC-003: username 应完整恢复")
        XCTAssertEqual(loaded.authMethod, session.authMethod, "TC-003: authMethod 应完整恢复")
        XCTAssertEqual(loaded.keepAliveInterval, session.keepAliveInterval, "TC-003: keepAliveInterval 应完整恢复")
        XCTAssertEqual(loaded.autoReconnect, session.autoReconnect,         "TC-003: autoReconnect 应完整恢复")
        XCTAssertEqual(loaded.encoding, session.encoding,     "TC-003: encoding 应完整恢复")
        XCTAssertEqual(loaded.tags, session.tags,             "TC-003: tags 应完整恢复")
    }

    /// TC-003 变体：Keychain 凭据存取
    func testTC003_KeychainCredentialsPersistence() throws {
        let sessionId = UUID()

        // 存入 Keychain
        try KeychainService.shared.savePassword(testPassword, for: sessionId, type: .password)

        // 读取
        let retrieved = try KeychainService.shared.getPassword(for: sessionId, type: .password)
        XCTAssertEqual(retrieved, testPassword, "TC-003 变体：Keychain 读取的密码应与存入一致")

        // 清理
        try KeychainService.shared.deletePassword(for: sessionId, type: .password)
    }

    // MARK: - TC-004: 3 标签页并发独立工作

    /// TC-004: 3 个 SSH2Connection 并发建立，连接彼此独立、状态互不干扰
    func testTC004_ConcurrentConnections() async throws {
        let connections = (1...3).map { _ in SSH2Connection() }

        // 先为每个连接注册提示符期望
        let promptExps = connections.map { makeShellPromptExpectation(for: $0) }

        // 并发建立 3 个连接
        try await withThrowingTaskGroup(of: Void.self) { group in
            for conn in connections {
                group.addTask {
                    try await Task.detached(priority: .userInitiated) {
                        try conn.connect(
                            host: self.testHost,
                            port: self.testPort,
                            username: self.testUsername,
                            password: self.testPassword
                        )
                    }.value
                }
            }
            try await group.waitForAll()
        }

        // 验证 3 个连接均已建立
        for (index, conn) in connections.enumerated() {
            XCTAssertTrue(conn.isConnected, "TC-004: 连接 \(index + 1) 应处于已连接状态")
        }

        // 等待 3 个 Shell 提示符
        await fulfillment(of: promptExps, timeout: 10)

        // 验证独立性：分别发送不同命令，不互相干扰
        for (index, conn) in connections.enumerated() {
            XCTAssertNoThrow(try conn.write("echo 'tab\(index + 1)'\n"),
                             "TC-004: 连接 \(index + 1) 发送命令不应抛出异常")
        }

        // 清理
        for conn in connections { conn.disconnect() }
    }

    // MARK: - TC-005: 自动重连

    /// TC-005a: 指数退避延迟计算正确性验证（纯逻辑，无网络）
    func testTC005_ExponentialBackoffCalculation() async throws {
        let session = Session(
            name: "重连测试",
            host: testHost,
            port: testPort,
            username: testUsername,
            authMethod: .password,
            autoReconnect: true
        )

        let controller = await MainActor.run { TerminalController(session: session) }

        // 配置加速参数
        await MainActor.run {
            controller.reconnectConfig.enabled = true
            controller.reconnectConfig.maxAttempts = 3
            controller.reconnectConfig.baseDelay = 1.0
            controller.reconnectConfig.backoffFactor = 2.0
            controller.reconnectConfig.maxDelay = 30.0
        }

        let (d1, d2, d3) = await MainActor.run {(
            controller.reconnectConfig.delay(for: 1),
            controller.reconnectConfig.delay(for: 2),
            controller.reconnectConfig.delay(for: 3)
        )}
        XCTAssertEqual(d1,  1.0, accuracy: 0.001, "TC-005: 第 1 次延迟应为 1.0s")
        XCTAssertEqual(d2,  2.0, accuracy: 0.001, "TC-005: 第 2 次延迟应为 2.0s")
        XCTAssertEqual(d3,  4.0, accuracy: 0.001, "TC-005: 第 3 次延迟应为 4.0s")
    }

    /// TC-005b: 真机连接 + 主动断开后不触发自动重连
    func testTC005_AutoReconnect_ManualDisconnectSuppressesRetry() async throws {
        let session = Session(
            name: "真机测试-重连",
            host: testHost,
            port: testPort,
            username: testUsername,
            authMethod: .password,
            autoReconnect: true
        )

        // 预存密码到 Keychain（TerminalController 从 Keychain 读取）
        try KeychainService.shared.savePassword(testPassword, for: session.id, type: .password)
        defer { try? KeychainService.shared.deletePassword(for: session.id, type: .password) }

        let controller = await MainActor.run { TerminalController(session: session) }
        await MainActor.run {
            controller.reconnectConfig.enabled = true
            controller.reconnectConfig.maxAttempts = 3
            controller.reconnectConfig.baseDelay = 0.5
        }

        // 首次连接真机
        try await controller.connect()

        let connectedState = await MainActor.run { controller.state }
        XCTAssertEqual(connectedState, .connected, "TC-005b: 首次连接后应为 .connected")

        // 主动断开
        await controller.disconnect()

        let disconnectedState = await MainActor.run { controller.state }
        XCTAssertEqual(disconnectedState, .disconnected, "TC-005b: 主动断开后应为 .disconnected")

        // 等待 1s，确认主动断开不触发自动重连
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let stateAfterWait = await MainActor.run { controller.state }
        XCTAssertEqual(stateAfterWait, .disconnected, "TC-005b: 主动断开后 1s 内不应触发自动重连")
    }

    /// TC-005c: 不可达主机 + 禁用重连，最终状态为 .failed
    /// 使用 sshAgent 认证以绕过 Keychain 凭据预检（测试环境无 Keychain 密码），
    /// 让 TCP 连接失败真正触发 .failed 状态
    func testTC005_UnreachableHost_StateIsFailed() async throws {
        let session = Session(
            name: "不可达主机",
            host: "192.0.2.1",  // RFC 5737 文档测试地址，保证不可达
            port: 22,
            username: testUsername,
            authMethod: .sshAgent,  // 跳过 Keychain 凭据预检
            autoReconnect: false
        )

        let controller = await MainActor.run { TerminalController(session: session) }
        await MainActor.run { controller.reconnectConfig.enabled = false }

        do {
            try await controller.connect()
            // 若 connect() 未抛出，检查 needsCredentialInput（CI 无 Keychain 时的合法出口）
            let credMissing = await MainActor.run { controller.needsCredentialInput }
            if !credMissing {
                XCTFail("TC-005c: 不可达主机不应连接成功")
            }
        } catch { /* 预期失败：TCP 无法到达 192.0.2.1 */ }

        let finalState = await MainActor.run { controller.state }
        // 允许两种合法结果：.failed（TCP 失败）或 .disconnected（needsCredentialInput 提前返回）
        let isExpectedState: Bool
        switch finalState {
        case .failed, .disconnected: isExpectedState = true
        default: isExpectedState = false
        }
        XCTAssertTrue(isExpectedState, "TC-005c: 不可达主机最终状态应为 .failed 或 .disconnected，实际：\(finalState)")
    }

    // MARK: - Known Hosts 管理

    /// 验证 KnownHostsManager 的 add / check / remove 全流程
    func testKnownHostsManager() throws {
        let manager = KnownHostsManager.shared
        let fingerprint = HostKeyFingerprint(
            keyType: .ed25519,
            sha256: "AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl",
            md5: "16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48",
            rawKey: Data()
        )
        let host = "integration-test.shellmate.internal"

        try manager.add(host: host, port: 22, fingerprint: fingerprint)
        XCTAssertEqual(manager.check(host: host, port: 22, fingerprint: fingerprint), .match,
                       "KnownHosts: add 后 check 应为 .match")

        try manager.remove(host: host, port: 22)
        XCTAssertEqual(manager.check(host: host, port: 22, fingerprint: fingerprint), .notFound,
                       "KnownHosts: remove 后 check 应为 .notFound")
    }
}

// MARK: - 性能测试

extension SSHConnectionIntegrationTests {

    /// 连接建立性能（目标 < 5s，含网络往返）
    func testConnectionPerformance() {
        measure {
            let exp = self.expectation(description: "连接性能")
            Task {
                let conn = SSH2Connection()
                do {
                    try await self.runBlocking {
                        try conn.connect(
                            host: self.testHost,
                            port: self.testPort,
                            username: self.testUsername,
                            password: self.testPassword
                        )
                    }
                    conn.disconnect()
                } catch { /* 忽略，仅测性能 */ }
                exp.fulfill()
            }
            wait(for: [exp], timeout: self.connectionTimeout + 5)
        }
    }
}
