import XCTest
@testable import ShellMate

/// 功能集成测试
/// 覆盖 TC-006 ~ TC-009（SFTP 上传、端口转发、高亮引擎、主机密钥变更检测）
final class FeatureIntegrationTests: XCTestCase {

    // MARK: - 测试环境配置

    private let testHost     = "192.168.100.167"
    private let testPort: Int32 = 22
    private let testUsername = "ubuntu"
    private let testPassword = "Int3l@123"

    // MARK: - 服务器可达性检查

    /// 快速检查测试服务器 TCP 端口是否可达（非阻塞 connect + select，最多等待 3 秒）
    private func isServerReachable() -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard sock >= 0 else { return false }
        defer { Darwin.close(sock) }

        // 设为非阻塞
        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port   = in_port_t(testPort).bigEndian
        addr.sin_addr   = in_addr(s_addr: inet_addr(testHost))

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        // 非阻塞 connect 立即返回 EINPROGRESS
        if connectResult == 0 { return true }
        guard errno == EINPROGRESS else { return false }

        // 用 select() 等待最多 3 秒
        var fdset = fd_set()
        withUnsafeMutablePointer(to: &fdset) { ptr in
            __darwin_fd_set(sock, ptr)
        }
        var tv = timeval(tv_sec: 3, tv_usec: 0)
        let sel = select(sock + 1, nil, &fdset, nil, &tv)
        guard sel > 0 else { return false }

        // 验证连接成功
        var errCode: Int32 = 0
        var errLen = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(sock, SOL_SOCKET, SO_ERROR, &errCode, &errLen)
        return errCode == 0
    }

    // MARK: - TC-006：SFTP 文件上传进度达 100%

    /// TC-006：上传一个本地文件到远程服务器，验证进度最终达到 100%（state = .completed）
    func testTC006_SFTPUploadProgressReaches100Percent() async throws {
        guard isServerReachable() else {
            throw XCTSkip("TC-006 跳过：测试服务器 \(testHost):\(testPort) 不可达")
        }
        // 准备 1 MB 的本地测试文件
        let localPath = NSTemporaryDirectory() + "shellmate_tc006_upload.bin"
        let fileSize: UInt64 = 1 * 1024 * 1024 // 1 MB
        let data = Data(repeating: 0xAB, count: Int(fileSize))
        try data.write(to: URL(fileURLWithPath: localPath))
        defer { try? FileManager.default.removeItem(atPath: localPath) }

        let remotePath = "/tmp/shellmate_tc006_upload_\(Int(Date().timeIntervalSince1970)).bin"

        // 建立 SFTP 连接
        let sftp = SFTPSession()
        try await sftp.connect(
            host: testHost,
            port: testPort,
            username: testUsername,
            authMethod: .password,
            password: testPassword
        )
        defer { Task { await sftp.disconnect() } }

        XCTAssertTrue(sftp.isConnected, "TC-006：SFTP 连接后 isConnected 应为 true")

        // 创建传输条目
        let transferItem = await MainActor.run {
            SFTPTransferItem(
                localPath: localPath,
                remotePath: remotePath,
                direction: .upload,
                totalBytes: fileSize
            )
        }

        // 执行上传
        try await sftp.uploadFile(
            localPath: localPath,
            remotePath: remotePath,
            transferItem: transferItem
        )

        // 验证进度和状态（在主线程读取 @Published 属性）
        let (finalState, transferredBytes, totalBytes) = await MainActor.run {
            (transferItem.state, transferItem.transferredBytes, transferItem.totalBytes)
        }

        XCTAssertEqual(finalState, .completed, "TC-006：上传完成后 state 应为 .completed")
        XCTAssertEqual(transferredBytes, totalBytes, "TC-006：transferredBytes 应等于 totalBytes（进度 = 100%）")
        XCTAssertGreaterThan(totalBytes, 0, "TC-006：totalBytes 应 > 0")

        // 清理远程文件
        try? await sftp.deleteFile(path: remotePath)
    }

    // MARK: - TC-007：本地端口转发流量验证

    /// TC-007：启动 L 型端口转发，通过本地端口连接远程 SSH 端口，验证收到 SSH banner
    func testTC007_LocalPortForwardingTrafficVerification() async throws {
        guard isServerReachable() else {
            throw XCTSkip("TC-007 跳过：测试服务器 \(testHost):\(testPort) 不可达")
        }
        // 配置 SSH 会话（用于建立 direct-tcpip 通道）
        let config = SSHSessionConfig(
            host: testHost,
            port: testPort,
            username: testUsername,
            authMethod: .password,
            password: testPassword
        )

        // 将远程 SSH 端口（22）转发到本地随机端口
        let localPort = 54322
        let rule = TunnelRule(
            type: .localForward,
            localBindAddress: "127.0.0.1",
            localPort: localPort,
            remoteHost: testHost,
            remotePort: 22
        )

        // 启动端口转发
        let forwarder = LocalPortForwarder(rule: rule, sessionConfig: config)
        try forwarder.start()
        defer { forwarder.stop() }

        // 给 accept 循环一点时间就绪
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        // 通过 TCP 连接本地端口，期望收到 SSH banner
        let banner = try await receiveBannerFromLocalPort(localPort, timeout: 10)
        XCTAssertTrue(
            banner.hasPrefix("SSH-"),
            "TC-007：通过本地端口转发应收到 SSH banner（实际：\(banner)）"
        )
    }

    // MARK: - TC-008：ERROR 关键字高亮注入

    /// TC-008：HighlightEngine 处理含 ERROR 的数据时，应注入 ANSI 红色高亮序列
    @MainActor
    func testTC008_ErrorKeywordHighlighting() async throws {
        // 构造仅含默认规则的引擎（不依赖 UserDefaults 持久化）
        let engine = HighlightEngine.shared

        // 保存原始状态
        let originalEnabled = engine.isEnabled
        let originalRules   = engine.rules
        defer {
            engine.isEnabled = originalEnabled
            engine.rules     = originalRules
        }

        // 加载默认规则并启用
        engine.isEnabled = true
        engine.rules = HighlightRule.defaults

        // 构造包含关键字的测试数据
        let raw = "Some output: ERROR occurred in module\n"
        let input = raw.data(using: .utf8)!

        let output = engine.process(input)
        guard let outputStr = String(data: output, encoding: .utf8) else {
            XCTFail("TC-008：输出应可解码为 UTF-8 字符串")
            return
        }

        // 验证 ANSI 转义序列已注入
        XCTAssertTrue(
            outputStr.contains("\u{1B}["),
            "TC-008：处理含 ERROR 的数据后，输出应包含 ANSI 转义序列"
        )
        XCTAssertTrue(
            outputStr.contains("ERROR"),
            "TC-008：高亮后关键字 ERROR 仍应存在于输出中"
        )
        // 红色（31m）
        XCTAssertTrue(
            outputStr.contains("\u{1B}[31m"),
            "TC-008：ERROR 关键字应注入红色 ANSI 序列（\\e[31m）"
        )
    }

    /// TC-008 补充：不含关键字的数据不应被修改
    @MainActor
    func testTC008_NoKeyword_DataUnchanged() async throws {
        let engine = HighlightEngine.shared

        let originalEnabled = engine.isEnabled
        let originalRules   = engine.rules
        defer {
            engine.isEnabled = originalEnabled
            engine.rules     = originalRules
        }

        engine.isEnabled = true
        engine.rules = HighlightRule.defaults

        let raw = "Everything looks fine today.\n"
        let input = raw.data(using: .utf8)!
        let output = engine.process(input)
        let outputStr = String(data: output, encoding: .utf8)!

        XCTAssertFalse(
            outputStr.contains("\u{1B}["),
            "TC-008：不含关键字时输出不应含 ANSI 序列"
        )
        XCTAssertEqual(outputStr, raw, "TC-008：无关键字时数据应原样返回")
    }

    // MARK: - TC-009：主机密钥变更阻止自动连接

    /// TC-009：已存储主机密钥后，若新指纹不同，check() 应返回 .mismatch
    func testTC009_HostKeyChangedBlocksAutoConnect() throws {
        // 使用临时路径隔离测试，避免污染生产 known_hosts
        let tempDir = NSTemporaryDirectory() + "shellmate_tc009_\(Int(Date().timeIntervalSince1970))/"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let manager = KnownHostsManager(storageDirectory: tempDir)

        // 构造第一次连接的指纹
        let originalKey = Data("original_key_data_abc123".utf8)
        let originalFingerprint = HostKeyFingerprint(
            keyType: .ed25519,
            sha256: "AAAA1111OriginalFingerprint==",
            md5:    "aabbccdd00112233",
            rawKey: originalKey
        )

        // 添加到 known_hosts
        try manager.add(host: testHost, port: testPort, fingerprint: originalFingerprint, comment: "TC-009 测试")

        // 验证：相同指纹 → match
        let matchResult = manager.check(host: testHost, port: testPort, fingerprint: originalFingerprint)
        XCTAssertEqual(matchResult, .match, "TC-009：相同指纹应返回 .match")

        // 构造变更后的指纹（模拟密钥轮换或 MITM 攻击）
        let changedKey = Data("changed_key_data_xyz789".utf8)
        let changedFingerprint = HostKeyFingerprint(
            keyType: .ed25519,
            sha256: "BBBB2222ChangedFingerprint==",
            md5:    "11223344aabbccdd",
            rawKey: changedKey
        )

        // 验证：指纹变更 → mismatch（应阻止自动连接）
        let mismatchResult = manager.check(host: testHost, port: testPort, fingerprint: changedFingerprint)
        switch mismatchResult {
        case .mismatch(let entry):
            XCTAssertEqual(entry.fingerprint, originalFingerprint.sha256,
                           "TC-009：mismatch 中的 existing 指纹应与原存储一致")
        default:
            XCTFail("TC-009：主机密钥变更应返回 .mismatch，实际返回：\(mismatchResult)")
        }
    }

    /// TC-009 补充：未知主机应返回 .notFound（不阻止，但应提示用户确认）
    func testTC009_UnknownHost_ReturnsNotFound() throws {
        let tempDir = NSTemporaryDirectory() + "shellmate_tc009b_\(Int(Date().timeIntervalSince1970))/"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let manager = KnownHostsManager(storageDirectory: tempDir)

        let fingerprint = HostKeyFingerprint(
            keyType: .sshRSA,
            sha256: "CCCC3333UnknownHost==",
            md5:    "00aabbccddeeff11",
            rawKey: Data("unknown_host_key".utf8)
        )

        let result = manager.check(host: "10.99.99.99", port: 22, fingerprint: fingerprint)
        XCTAssertEqual(result, KnownHostCheckResult.notFound, "TC-009：未知主机应返回 .notFound")
    }

    // MARK: - 私有辅助

    /// 通过 TCP 连接本地端口，返回接收到的首行内容（去除 \r\n）
    private func receiveBannerFromLocalPort(_ port: Int, timeout: TimeInterval) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
                guard sock >= 0 else {
                    continuation.resume(throwing: NSError(domain: "TC007", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "socket() 失败"]))
                    return
                }
                defer { Darwin.close(sock) }

                // 设置超时
                var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
                setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port   = in_port_t(port).bigEndian
                addr.sin_addr   = in_addr(s_addr: inet_addr("127.0.0.1"))

                let connectResult = withUnsafePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                guard connectResult == 0 else {
                    continuation.resume(throwing: NSError(domain: "TC007", code: Int(errno),
                        userInfo: [NSLocalizedDescriptionKey: "connect() 失败，errno=\(errno)"]))
                    return
                }

                // 读取首行
                var buf = [UInt8](repeating: 0, count: 256)
                let n = recv(sock, &buf, buf.count - 1, 0)
                guard n > 0 else {
                    continuation.resume(throwing: NSError(domain: "TC007", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "recv() 超时或返回 0"]))
                    return
                }

                let line = String(bytes: buf.prefix(Int(n)), encoding: .utf8)?
                    .components(separatedBy: "\n").first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.resume(returning: line)
            }
        }
    }
}
