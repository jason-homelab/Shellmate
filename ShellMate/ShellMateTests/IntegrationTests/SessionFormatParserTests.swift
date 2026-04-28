import XCTest
@testable import ShellMate

/// SessionFormatParser 单元测试
/// 覆盖 Xshell (.xsh) / SecureCRT (.ini) / PuTTY (.reg) 三种格式的解析逻辑
/// 以及错误边界：空文件、无效编码、无会话、不支持格式
final class SessionFormatParserTests: XCTestCase {

    // MARK: - 辅助

    private func data(_ string: String, encoding: String.Encoding = .utf8) -> Data {
        string.data(using: encoding) ?? Data()
    }

    // MARK: - ═══════════════ Xshell (.xsh) ═══════════════

    /// Xshell 标准格式：解析出会话的 host/port/username
    func testXshellHappyPath() throws {
        let xsh = """
        [SessionInfo]
        Version=7.0
        SessionName=prod-server

        [Connection]
        Host=192.168.1.100
        Port=2222
        UserName=deploy
        Protocol=SSH
        """

        let sessions = try SessionFormatParser.parse(data: data(xsh), fileExtension: "xsh")

        XCTAssertEqual(sessions.count, 1)
        let s = try XCTUnwrap(sessions.first)
        XCTAssertEqual(s.host, "192.168.1.100")
        XCTAssertEqual(s.port, 2222)
        XCTAssertEqual(s.username, "deploy")
    }

    /// Xshell：密码认证（authMethod=0）
    func testXshellPasswordAuth() throws {
        let xsh = """
        [Connection]
        Host=10.0.0.1
        Port=22
        UserName=admin

        [Connection\\Authentication]
        Method=0
        """

        let sessions = try SessionFormatParser.parse(data: data(xsh), fileExtension: "xsh")
        let s = try XCTUnwrap(sessions.first)

        XCTAssertEqual(s.authMethod, .password)
    }

    /// Xshell：PublicKey 认证（authMethod=1）
    func testXshellPublicKeyAuth() throws {
        let xsh = """
        [Connection]
        Host=10.0.0.2
        Port=22
        UserName=git

        [Connection\\Authentication]
        Method=1
        """

        let sessions = try SessionFormatParser.parse(data: data(xsh), fileExtension: "xsh")
        let s = try XCTUnwrap(sessions.first)

        XCTAssertEqual(s.authMethod, .privateKey)
    }

    /// Xshell：空文件 → emptyFile 错误
    func testXshellEmptyFileThrows() {
        XCTAssertThrowsError(
            try SessionFormatParser.parse(data: Data(), fileExtension: "xsh")
        ) { error in
            guard case SessionFormatParser.ParseError.emptyFile = error else {
                XCTFail("应抛出 emptyFile 错误，实际：\(error)")
                return
            }
        }
    }

    /// Xshell：无 Host 字段 → noSessionsFound 错误
    func testXshellNoHostThrows() {
        let xsh = "[Connection]\nPort=22\nUserName=user\n"

        XCTAssertThrowsError(
            try SessionFormatParser.parse(data: data(xsh), fileExtension: "xsh")
        ) { error in
            guard case SessionFormatParser.ParseError.noSessionsFound = error else {
                XCTFail("应抛出 noSessionsFound 错误，实际：\(error)")
                return
            }
        }
    }

    /// Xshell：默认端口为 22（Port 字段缺失时）
    func testXshellDefaultPort() throws {
        let xsh = "[Connection]\nHost=myhost.com\nUserName=user\n"

        let sessions = try SessionFormatParser.parse(data: data(xsh), fileExtension: "xsh")

        XCTAssertEqual(sessions.first?.port, 22)
    }

    /// Xshell：用户名为空时会话名为 host
    func testXshellSessionNameFallbackToHost() throws {
        let xsh = "[Connection]\nHost=myserver.com\nPort=22\n"

        let sessions = try SessionFormatParser.parse(data: data(xsh), fileExtension: "xsh")

        XCTAssertEqual(sessions.first?.name, "myserver.com")
    }

    // MARK: - ═══════════════ SecureCRT (.ini) ═══════════════

    /// SecureCRT S:/D: 格式：解析出 host/port/username
    func testSecureCRTHappyPath() throws {
        let ini = """
        [/SSH2]
        S:"Hostname"=db.example.com
        D:"Port Number"=00000016
        S:"Username"=dbadmin
        """
        // 0x16 = 22（十进制）

        let sessions = try SessionFormatParser.parse(data: data(ini), fileExtension: "ini")

        XCTAssertEqual(sessions.count, 1)
        let s = try XCTUnwrap(sessions.first)
        XCTAssertEqual(s.host, "db.example.com")
        XCTAssertEqual(s.port, 22)
        XCTAssertEqual(s.username, "dbadmin")
    }

    /// SecureCRT：PublicKey 认证
    func testSecureCRTPublicKeyAuth() throws {
        let ini = """
        [/SSH2]
        S:"Hostname"=git.example.com
        D:"Port Number"=00000016
        S:"Username"=git

        [/SSH2/Auth]
        S:"Auth0"=PublicKey
        """

        let sessions = try SessionFormatParser.parse(data: data(ini), fileExtension: "ini")
        let s = try XCTUnwrap(sessions.first)

        XCTAssertEqual(s.authMethod, .privateKey)
    }

    /// SecureCRT：空文件 → emptyFile 错误
    func testSecureCRTEmptyFileThrows() {
        XCTAssertThrowsError(
            try SessionFormatParser.parse(data: Data(), fileExtension: "ini")
        ) { error in
            guard case SessionFormatParser.ParseError.emptyFile = error else {
                XCTFail("应抛出 emptyFile 错误，实际：\(error)")
                return
            }
        }
    }

    /// SecureCRT：无 Hostname → noSessionsFound 错误
    func testSecureCRTNoHostThrows() {
        let ini = "[/SSH2]\nD:\"Port Number\"=00000016\nS:\"Username\"=user\n"

        XCTAssertThrowsError(
            try SessionFormatParser.parse(data: data(ini), fileExtension: "ini")
        ) { error in
            guard case SessionFormatParser.ParseError.noSessionsFound = error else {
                XCTFail("应抛出 noSessionsFound，实际：\(error)")
                return
            }
        }
    }

    /// SecureCRT：普通 INI 格式也能解析
    func testSecureCRTPlainINIFormat() throws {
        let ini = """
        [Connection]
        hostname=plain.example.com
        port=8022
        username=plainuser
        """

        let sessions = try SessionFormatParser.parse(data: data(ini), fileExtension: "ini")

        XCTAssertEqual(sessions.first?.host, "plain.example.com")
        XCTAssertEqual(sessions.first?.port, 8022)
    }

    // MARK: - ═══════════════ PuTTY (.reg) ═══════════════

    /// PuTTY .reg：单会话解析
    func testPuTTYSingleSession() throws {
        let reg = """
        Windows Registry Editor Version 5.00

        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\My%20Server]
        "HostName"="192.168.10.5"
        "PortNumber"=dword:00000016
        "UserName"="ubuntu"
        "Protocol"="ssh"
        """

        let sessions = try SessionFormatParser.parse(data: data(reg), fileExtension: "reg")

        XCTAssertEqual(sessions.count, 1)
        let s = try XCTUnwrap(sessions.first)
        XCTAssertEqual(s.host, "192.168.10.5")
        XCTAssertEqual(s.port, 22)
        XCTAssertEqual(s.username, "ubuntu")
        // 会话名应为 URL decode 后的 "My Server"
        XCTAssertEqual(s.name, "My Server")
    }

    /// PuTTY .reg：多会话一次导入
    func testPuTTYMultipleSessions() throws {
        let reg = """
        Windows Registry Editor Version 5.00

        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\Server1]
        "HostName"="10.0.0.1"
        "PortNumber"=dword:00000016
        "Protocol"="ssh"

        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\Server2]
        "HostName"="10.0.0.2"
        "PortNumber"=dword:00000016
        "Protocol"="ssh"
        """

        let sessions = try SessionFormatParser.parse(data: data(reg), fileExtension: "reg")

        XCTAssertEqual(sessions.count, 2)
        let hosts = sessions.map(\.host)
        XCTAssertTrue(hosts.contains("10.0.0.1"))
        XCTAssertTrue(hosts.contains("10.0.0.2"))
    }

    /// PuTTY .reg：Default Settings 条目被跳过
    func testPuTTYDefaultSettingsSkipped() throws {
        let reg = """
        Windows Registry Editor Version 5.00

        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\Default%20Settings]
        "HostName"=""
        "PortNumber"=dword:00000016
        "Protocol"="ssh"

        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\RealServer]
        "HostName"="real.host.com"
        "PortNumber"=dword:00000016
        "Protocol"="ssh"
        """

        let sessions = try SessionFormatParser.parse(data: data(reg), fileExtension: "reg")

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.host, "real.host.com")
    }

    /// PuTTY .reg：非 SSH 协议（telnet）会话被忽略
    func testPuTTYNonSSHSessionSkipped() throws {
        let reg = """
        Windows Registry Editor Version 5.00

        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\TelnetHost]
        "HostName"="telnet.host.com"
        "PortNumber"=dword:00000017
        "Protocol"="telnet"

        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\SSHHost]
        "HostName"="ssh.host.com"
        "PortNumber"=dword:00000016
        "Protocol"="ssh"
        """

        let sessions = try SessionFormatParser.parse(data: data(reg), fileExtension: "reg")

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.host, "ssh.host.com")
    }

    /// PuTTY .reg：空文件 → emptyFile 错误
    func testPuTTYEmptyFileThrows() {
        XCTAssertThrowsError(
            try SessionFormatParser.parse(data: Data(), fileExtension: "reg")
        ) { error in
            guard case SessionFormatParser.ParseError.emptyFile = error else {
                XCTFail("应抛出 emptyFile 错误，实际：\(error)")
                return
            }
        }
    }

    /// PuTTY .reg：无有效会话 → noSessionsFound 错误
    func testPuTTYNoValidSessionsThrows() {
        let reg = "Windows Registry Editor Version 5.00\n\n[HKEY_CURRENT_USER\\Software\\Other]\n\"Key\"=\"Value\"\n"

        XCTAssertThrowsError(
            try SessionFormatParser.parse(data: data(reg), fileExtension: "reg")
        ) { error in
            guard case SessionFormatParser.ParseError.noSessionsFound = error else {
                XCTFail("应抛出 noSessionsFound，实际：\(error)")
                return
            }
        }
    }

    /// PuTTY：无 hostname 的 Sessions 条目被跳过
    func testPuTTYSessionWithoutHostSkipped() throws {
        let reg = """
        Windows Registry Editor Version 5.00

        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\NoHost]
        "PortNumber"=dword:00000016
        "Protocol"="ssh"

        [HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\WithHost]
        "HostName"="valid.host.com"
        "PortNumber"=dword:00000016
        "Protocol"="ssh"
        """

        let sessions = try SessionFormatParser.parse(data: data(reg), fileExtension: "reg")

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.host, "valid.host.com")
    }

    // MARK: - ═══════════════ 格式分发测试 ═══════════════

    /// 不支持的文件扩展名 → unsupportedFormat 错误
    func testUnsupportedFormatThrows() {
        let content = data("some content")

        XCTAssertThrowsError(
            try SessionFormatParser.parse(data: content, fileExtension: "xml")
        ) { error in
            guard case SessionFormatParser.ParseError.unsupportedFormat(let ext) = error else {
                XCTFail("应抛出 unsupportedFormat 错误，实际：\(error)")
                return
            }
            XCTAssertEqual(ext, "xml")
        }
    }

    /// 扩展名大小写不敏感：".XSH" 等同于 ".xsh"
    func testExtensionCaseInsensitive() throws {
        let xsh = "[Connection]\nHost=myhost.com\nPort=22\nUserName=user\n"

        let sessions = try SessionFormatParser.parse(data: data(xsh), fileExtension: "XSH")

        XCTAssertEqual(sessions.count, 1)
    }

    // MARK: - ═══════════════ ParseError 本地化描述测试 ═══════════════

    /// ParseError.unsupportedFormat 错误描述包含文件格式
    func testUnsupportedFormatErrorDescription() {
        let error = SessionFormatParser.ParseError.unsupportedFormat("csv")
        XCTAssertTrue(error.errorDescription?.contains("csv") ?? false)
    }

    /// ParseError.emptyFile 有描述
    func testEmptyFileErrorDescription() {
        let error = SessionFormatParser.ParseError.emptyFile
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    /// ParseError.noSessionsFound 有描述
    func testNoSessionsFoundErrorDescription() {
        let error = SessionFormatParser.ParseError.noSessionsFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    // MARK: - ═══════════════ 端口范围边界测试 ═══════════════

    /// 端口号解析：非标准端口（如 8022）正确保留
    func testNonStandardPortParsed() throws {
        let xsh = "[Connection]\nHost=jump.example.com\nPort=8022\nUserName=ops\n"

        let sessions = try SessionFormatParser.parse(data: data(xsh), fileExtension: "xsh")

        XCTAssertEqual(sessions.first?.port, 8022)
    }

    /// 端口号解析：非法端口字段（非数字）降级为 22
    func testInvalidPortFallsBackToDefault() throws {
        let xsh = "[Connection]\nHost=myhost.com\nPort=notanumber\nUserName=user\n"

        let sessions = try SessionFormatParser.parse(data: data(xsh), fileExtension: "xsh")

        XCTAssertEqual(sessions.first?.port, 22)
    }
}
