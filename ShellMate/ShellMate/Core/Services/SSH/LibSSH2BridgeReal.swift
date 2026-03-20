import Foundation
import Darwin
import CommonCrypto
import CryptoKit

// MARK: - libssh2 常量
// Swift 无法访问 C 头文件中的宏定义，需要手动定义

private let LIBSSH2_ERROR_EAGAIN: Int32 = -37
private let LIBSSH2_ERROR_AUTHENTICATION_FAILED: Int32 = -18
private let LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED: Int32 = -19
private let SSH_DISCONNECT_BY_APPLICATION: Int32 = 11
private let LIBSSH2_CHANNEL_WINDOW_DEFAULT: UInt32 = 2 * 1024 * 1024
private let LIBSSH2_CHANNEL_PACKET_DEFAULT: UInt32 = 32768

// MARK: - 真正的 libssh2 桥接实现

/// libssh2 真实桥接层
/// 封装 libssh2 的底层 C 接口，提供 Swift 友好的 API
/// @unchecked Sendable：SSH2Connection 的读取队列和 ProxyJump 桥接线程均会跨线程使用本类，
/// 调用方负责确保同一 session 不被多线程并发访问（每个 hop 独占一个 LibSSH2BridgeReal 实例）
final class LibSSH2BridgeReal: @unchecked Sendable {

    // MARK: - 静态属性

    /// 全局初始化状态
    private static var isGloballyInitialized = false

    /// 全局初始化锁
    private static let initializationLock = NSLock()

    // MARK: - 实例属性

    /// libssh2 会话指针
    private var session: OpaquePointer?

    /// Socket 文件描述符
    private var socketFD: Int32 = -1

    /// 是否处于非阻塞模式
    private(set) var isNonBlocking: Bool = false

    /// 会话是否已初始化
    var isSessionInitialized: Bool {
        session != nil
    }

    /// 是否已连接
    var isConnected: Bool {
        socketFD >= 0 && session != nil
    }

    /// 连接的主机地址
    private(set) var connectedHost: String?

    /// 连接的端口号
    private(set) var connectedPort: Int32?

    // MARK: - 初始化

    init() {
        Self.ensureGlobalInitialization()
    }

    deinit {
        disconnect()
    }

    // MARK: - 全局初始化

    /// 确保 libssh2 全局初始化（线程安全）
    private static func ensureGlobalInitialization() {
        initializationLock.lock()
        defer { initializationLock.unlock() }

        guard !isGloballyInitialized else { return }

        let result = libssh2_init(0)
        guard result == 0 else {
            fatalError("[LibSSH2] 初始化失败: \(result)")
        }

        isGloballyInitialized = true
        print("[LibSSH2] 全局初始化完成")
    }

    // MARK: - 会话初始化

    /// 初始化 SSH 会话
    func sessionInit() throws {
        guard session == nil else {
            print("[LibSSH2] 会话已存在，跳过初始化")
            return
        }

        // Swift 无法使用 C 宏，使用 _ex 版本
        session = libssh2_session_init_ex(nil, nil, nil, nil)
        guard session != nil else {
            throw SSHError.libssh2Error(code: -1, message: "无法创建 SSH 会话")
        }

        print("[LibSSH2] SSH 会话初始化完成")
    }

    /// 设置会话阻塞模式
    func setBlocking(_ blocking: Bool) {
        guard let session = session else { return }
        libssh2_session_set_blocking(session, blocking ? 1 : 0)
        isNonBlocking = !blocking
    }

    /// 设置会话超时时间
    func setTimeout(_ timeout: Int) {
        guard let session = session else { return }
        libssh2_session_set_timeout(session, CLong(timeout))
    }

    // MARK: - TCP 连接

    /// 建立 TCP 连接
    func tcpConnect(host: String, port: Int32) throws {
        guard socketFD < 0 else {
            print("[LibSSH2] TCP 已连接")
            return
        }

        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        var result: UnsafeMutablePointer<addrinfo>?
        let portString = String(port)

        let resolveResult = getaddrinfo(host, portString, &hints, &result)
        guard resolveResult == 0, let addrInfo = result else {
            throw SSHError.dnsResolutionFailed(host: host)
        }
        defer { freeaddrinfo(result) }

        let fd = socket(addrInfo.pointee.ai_family, addrInfo.pointee.ai_socktype, addrInfo.pointee.ai_protocol)
        guard fd >= 0 else {
            throw SSHError.connectionFailed(host: host, port: port, underlying: nil)
        }

        let connectResult = Darwin.connect(fd, addrInfo.pointee.ai_addr, addrInfo.pointee.ai_addrlen)
        guard connectResult == 0 else {
            Darwin.close(fd)
            if errno == ECONNREFUSED {
                throw SSHError.connectionRefused(host: host, port: port)
            } else if errno == ENETUNREACH || errno == EHOSTUNREACH {
                throw SSHError.networkUnreachable
            } else if errno == ETIMEDOUT {
                throw SSHError.connectionTimeout(host: host, port: port)
            }
            throw SSHError.connectionFailed(host: host, port: port, underlying: nil)
        }

        socketFD = fd
        connectedHost = host
        connectedPort = port

        print("[LibSSH2] TCP 连接成功: \(host):\(port)")
    }

    // MARK: - SSH 握手

    /// 执行 SSH 握手
    func handshake() throws {
        guard let session = session else {
            throw SSHError.sessionNotInitialized
        }

        guard socketFD >= 0 else {
            throw SSHError.connectionFailed(host: connectedHost ?? "unknown", port: connectedPort ?? 22, underlying: nil)
        }

        var rc: Int32
        repeat {
            rc = libssh2_session_handshake(session, socketFD)
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            throw SSHError.handshakeFailed(reason: getLastErrorMessage())
        }

        print("[LibSSH2] SSH 握手完成")
    }

    /// 在已有文件描述符上执行 SSH 握手（用于 ProxyJump 多跳：socketpair 桥接通道）
    /// 与 handshake() 的区别：跳过 tcpConnect，直接使用外部提供的 fd
    func handshakeOnFD(_ fd: Int32) throws {
        guard let session = session else {
            throw SSHError.sessionNotInitialized
        }

        socketFD = fd

        var rc: Int32
        repeat {
            rc = libssh2_session_handshake(session, fd)
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            throw SSHError.handshakeFailed(reason: getLastErrorMessage())
        }

        print("[LibSSH2] 通过 socketpair 完成 SSH 握手（ProxyJump 中间跳）")
    }

    /// 获取主机密钥指纹
    func getHostKeyFingerprint() throws -> HostKeyFingerprint {
        guard let session = session else {
            throw SSHError.sessionNotInitialized
        }

        var keyLen: Int = 0
        var keyType: Int32 = 0
        guard let key = libssh2_session_hostkey(session, &keyLen, &keyType) else {
            throw SSHError.hostKeyVerificationFailed(fingerprint: "无法获取主机密钥")
        }

        let keyData = Data(bytes: key, count: keyLen)

        // 计算 SHA256
        var sha256Hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(keyData.count), &sha256Hash)
        }
        let sha256 = Data(sha256Hash).base64EncodedString()

        // 计算 MD5（用 Insecure.MD5 替代已弃用的 CC_MD5，此处仅用于展示指纹非安全场景）
        let md5Digest = Insecure.MD5.hash(data: keyData)
        let md5 = md5Digest.map { String(format: "%02x", $0) }.joined()

        let keyTypeEnum = SSH2HostKeyType(rawValue: keyType) ?? .unknown

        return HostKeyFingerprint(
            keyType: keyTypeEnum,
            sha256: sha256,
            md5: md5,
            rawKey: keyData
        )
    }

    // MARK: - 认证

    /// 获取支持的认证方法列表
    func getUserAuthList(username: String) throws -> String {
        guard let session = session else {
            throw SSHError.sessionNotInitialized
        }

        guard let authList = libssh2_userauth_list(session, username, UInt32(username.count)) else {
            return ""
        }
        return String(cString: authList)
    }

    /// 使用密码认证
    func authenticateWithPassword(username: String, password: String) throws {
        guard let session = session else {
            throw SSHError.sessionNotInitialized
        }

        var rc: Int32
        repeat {
            rc = libssh2_userauth_password_ex(
                session,
                username,
                UInt32(username.count),
                password,
                UInt32(password.count),
                nil
            )
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            if rc == LIBSSH2_ERROR_AUTHENTICATION_FAILED {
                throw SSHError.invalidPassword
            }
            throw SSHError.authenticationFailed(method: "password", reason: getLastErrorMessage())
        }

        print("[LibSSH2] 密码认证成功")
    }

    /// 使用公钥认证
    func authenticateWithPublicKey(
        username: String,
        publicKeyPath: String?,
        privateKeyPath: String,
        passphrase: String?
    ) throws {
        guard let session = session else {
            throw SSHError.sessionNotInitialized
        }

        guard FileManager.default.fileExists(atPath: privateKeyPath) else {
            throw SSHError.invalidPrivateKey(reason: "私钥文件不存在")
        }

        var rc: Int32
        repeat {
            rc = libssh2_userauth_publickey_fromfile_ex(
                session,
                username,
                UInt32(username.count),
                publicKeyPath,
                privateKeyPath,
                passphrase
            )
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            if rc == LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED {
                throw SSHError.invalidPassphrase
            }
            throw SSHError.authenticationFailed(method: "publickey", reason: getLastErrorMessage())
        }

        print("[LibSSH2] 公钥认证成功")
    }

    /// 使用 SSH Agent 认证
    func authenticateWithAgent(username: String) throws {
        guard let session = session else {
            throw SSHError.sessionNotInitialized
        }

        guard ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] != nil else {
            throw SSHError.agentNotAvailable
        }

        guard let agent = libssh2_agent_init(session) else {
            throw SSHError.agentNotAvailable
        }
        defer { libssh2_agent_free(agent) }

        guard libssh2_agent_connect(agent) == 0 else {
            throw SSHError.agentNotAvailable
        }
        defer { libssh2_agent_disconnect(agent) }

        guard libssh2_agent_list_identities(agent) == 0 else {
            throw SSHError.agentAuthFailed(reason: "无法列出 Agent 身份")
        }

        var identity: UnsafeMutablePointer<libssh2_agent_publickey>?
        var prevIdentity: UnsafeMutablePointer<libssh2_agent_publickey>?

        while libssh2_agent_get_identity(agent, &identity, prevIdentity) == 0 {
            if let identity = identity {
                if libssh2_agent_userauth(agent, username, identity) == 0 {
                    print("[LibSSH2] SSH Agent 认证成功")
                    return
                }
            }
            prevIdentity = identity
        }

        throw SSHError.agentAuthFailed(reason: "没有可用的身份")
    }

    // MARK: - 通道操作

    /// 打开 Shell 通道
    func openShellChannel() throws -> OpaquePointer {
        guard let session = session else {
            throw SSHError.sessionNotInitialized
        }

        let channelType = "session"
        var channel: OpaquePointer?

        repeat {
            channel = libssh2_channel_open_ex(
                session,
                channelType,
                UInt32(channelType.count),
                LIBSSH2_CHANNEL_WINDOW_DEFAULT,
                LIBSSH2_CHANNEL_PACKET_DEFAULT,
                nil,
                0
            )
            if channel == nil {
                let rc = libssh2_session_last_errno(session)
                if rc != LIBSSH2_ERROR_EAGAIN {
                    throw SSHError.channelOpenFailed(reason: getLastErrorMessage())
                }
            }
        } while channel == nil

        print("[LibSSH2] Shell 通道已打开")
        return channel!
    }

    /// 请求 PTY
    func requestPTY(channel: OpaquePointer, term: String = "xterm-256color", cols: Int = 80, rows: Int = 24) throws {
        var rc: Int32
        repeat {
            rc = libssh2_channel_request_pty_ex(
                channel,
                term,
                UInt32(term.count),
                nil,
                0,
                Int32(cols),
                Int32(rows),
                0,
                0
            )
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            throw SSHError.ptyRequestFailed(reason: getLastErrorMessage())
        }

        print("[LibSSH2] PTY 请求成功: \(cols)x\(rows)")
    }

    /// 启动 Shell
    func startShell(channel: OpaquePointer) throws {
        var rc: Int32
        let request = "shell"
        repeat {
            rc = libssh2_channel_process_startup(
                channel,
                request,
                UInt32(request.count),
                nil,
                0
            )
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            throw SSHError.shellStartFailed(reason: getLastErrorMessage())
        }

        print("[LibSSH2] Shell 已启动")
    }

    /// 读取通道数据
    func readChannel(channel: OpaquePointer, buffer: UnsafeMutablePointer<UInt8>, bufferSize: Int) -> Int {
        return libssh2_channel_read_ex(channel, 0, UnsafeMutablePointer<CChar>(OpaquePointer(buffer)), bufferSize)
    }

    /// 写入通道数据
    func writeChannel(channel: OpaquePointer, data: UnsafePointer<UInt8>, length: Int) -> Int {
        return libssh2_channel_write_ex(channel, 0, UnsafePointer<CChar>(OpaquePointer(data)), length)
    }

    /// 调整 PTY 尺寸
    func resizePTY(channel: OpaquePointer, cols: Int, rows: Int) {
        libssh2_channel_request_pty_size_ex(channel, Int32(cols), Int32(rows), 0, 0)
    }

    /// 关闭通道
    func closeChannel(channel: OpaquePointer) {
        libssh2_channel_close(channel)
        libssh2_channel_free(channel)
        print("[LibSSH2] 通道已关闭")
    }

    // MARK: - 断开连接

    /// 断开 SSH 连接
    func disconnect(reason: String = "正常断开") {
        if let session = session {
            libssh2_session_disconnect_ex(session, SSH_DISCONNECT_BY_APPLICATION, reason, "")
            libssh2_session_free(session)
            self.session = nil
            print("[LibSSH2] SSH 会话已关闭")
        }

        if socketFD >= 0 {
            Darwin.close(socketFD)
            socketFD = -1
            print("[LibSSH2] TCP 连接已关闭")
        }

        connectedHost = nil
        connectedPort = nil
    }

    // MARK: - 辅助方法

    /// 获取最后一次错误信息
    func getLastErrorMessage() -> String {
        guard let session = session else {
            return "会话未初始化"
        }

        var errorMsg: UnsafeMutablePointer<CChar>?
        var errorMsgLen: Int32 = 0
        libssh2_session_last_error(session, &errorMsg, &errorMsgLen, 0)
        if let errorMsg = errorMsg {
            return String(cString: errorMsg)
        }
        return "未知错误"
    }

    /// 获取阻塞方向
    func getBlockDirections() -> Int32 {
        guard let session = session else {
            return 0
        }
        return libssh2_session_block_directions(session)
    }

    /// 获取 Socket 文件描述符
    func getSocketFD() -> Int32 {
        return socketFD
    }
}

// MARK: - SFTP 扩展

// libssh2 SFTP 宏无法在 Swift 中直接使用，手动定义
private let SFTP_FXF_READ: UInt = 0x00000001
private let SFTP_FXF_WRITE: UInt = 0x00000002
private let SFTP_FXF_APPEND: UInt = 0x00000004
private let SFTP_FXF_CREAT: UInt = 0x00000008
private let SFTP_FXF_TRUNC: UInt = 0x00000010

private let SFTP_OPENFILE: Int32 = 0
private let SFTP_OPENDIR: Int32 = 1

private let SFTP_ATTR_PERMISSIONS: UInt = 0x00000004
private let SFTP_ATTR_ACMODTIME: UInt = 0x00000008
private let SFTP_ATTR_SIZE: UInt = 0x00000001

private let SFTP_S_IFMT: UInt = 0o170000
private let SFTP_S_IFDIR: UInt = 0o040000
private let SFTP_S_IFLNK: UInt = 0o120000

private let SFTP_STAT: Int32 = 0
private let SFTP_SETSTAT: Int32 = 2

private let SFTP_RENAME_OVERWRITE: Int = 0x00000001
private let SFTP_RENAME_ATOMIC: Int = 0x00000002
private let SFTP_RENAME_NATIVE: Int = 0x00000004

private let SFTP_STATUS_NO_SUCH_FILE: UInt32 = 2
private let SFTP_STATUS_PERMISSION_DENIED: UInt32 = 3

extension LibSSH2BridgeReal {

    // MARK: - SFTP 子系统

    /// 打开 SFTP 子系统（需要已建立 SSH 连接）
    func openSFTPSubsystem() throws -> OpaquePointer {
        guard let session = session else {
            throw SSHError.sessionNotInitialized
        }

        var sftp: OpaquePointer?
        repeat {
            sftp = libssh2_sftp_init(session)
            if sftp == nil {
                let rc = libssh2_session_last_errno(session)
                guard rc == LIBSSH2_ERROR_EAGAIN else {
                    throw SSHError.libssh2Error(code: rc, message: "SFTP 子系统初始化失败: \(getLastErrorMessage())")
                }
            }
        } while sftp == nil

        print("[LibSSH2] SFTP 子系统已打开")
        return sftp!
    }

    /// 关闭 SFTP 子系统
    func closeSFTPSubsystem(_ sftp: OpaquePointer) {
        libssh2_sftp_shutdown(sftp)
        print("[LibSSH2] SFTP 子系统已关闭")
    }

    // MARK: - 目录操作

    /// 列出目录内容
    /// - Returns: [(文件名, 长格式条目, 属性)]
    func sftpListDirectory(sftp: OpaquePointer, path: String) throws -> [(name: String, attrs: LIBSSH2_SFTP_ATTRIBUTES)] {
        let handle = try sftpOpenDir(sftp: sftp, path: path)
        defer { libssh2_sftp_close_handle(handle) }

        var entries: [(name: String, attrs: LIBSSH2_SFTP_ATTRIBUTES)] = []
        var nameBuffer = [CChar](repeating: 0, count: 512)
        var attrs = LIBSSH2_SFTP_ATTRIBUTES()

        while true {
            let rc = libssh2_sftp_readdir_ex(
                handle,
                &nameBuffer,
                nameBuffer.count,
                nil,
                0,
                &attrs
            )

            if rc > 0 {
                let name = String(cString: nameBuffer)
                // 跳过 . 和 ..
                if name != "." && name != ".." {
                    entries.append((name: name, attrs: attrs))
                }
                // 清空缓冲区
                nameBuffer = [CChar](repeating: 0, count: 512)
                attrs = LIBSSH2_SFTP_ATTRIBUTES()
            } else if rc == Int32(LIBSSH2_ERROR_EAGAIN) {
                continue
            } else {
                break // EOF 或错误
            }
        }

        return entries
    }

    /// 打开目录句柄
    private func sftpOpenDir(sftp: OpaquePointer, path: String) throws -> OpaquePointer {
        var handle: OpaquePointer?
        repeat {
            handle = libssh2_sftp_open_ex(
                sftp,
                path,
                UInt32(path.utf8.count),
                0,
                0,
                SFTP_OPENDIR
            )
            if handle == nil {
                let code = UInt32(libssh2_sftp_last_error(sftp))
                guard libssh2_session_last_errno(session) == LIBSSH2_ERROR_EAGAIN else {
                    if code == SFTP_STATUS_NO_SUCH_FILE {
                        throw SSHError.sftpFileNotFound(path: path)
                    } else if code == SFTP_STATUS_PERMISSION_DENIED {
                        throw SSHError.sftpPermissionDenied(path: path)
                    }
                    throw SSHError.sftpOpenFailed(path: path, code: code)
                }
            }
        } while handle == nil

        return handle!
    }

    /// 创建目录
    func sftpCreateDirectory(sftp: OpaquePointer, path: String, mode: Int = 0o755) throws {
        var rc: Int32
        repeat {
            rc = libssh2_sftp_mkdir_ex(sftp, path, UInt32(path.utf8.count), mode)
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            let code = UInt32(libssh2_sftp_last_error(sftp))
            if code == SFTP_STATUS_PERMISSION_DENIED {
                throw SSHError.sftpPermissionDenied(path: path)
            }
            throw SSHError.sftpOperationFailed(operation: "mkdir", code: code)
        }
    }

    /// 删除目录
    func sftpRemoveDirectory(sftp: OpaquePointer, path: String) throws {
        var rc: Int32
        repeat {
            rc = libssh2_sftp_rmdir_ex(sftp, path, UInt32(path.utf8.count))
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            let code = UInt32(libssh2_sftp_last_error(sftp))
            throw SSHError.sftpOperationFailed(operation: "rmdir", code: code)
        }
    }

    // MARK: - 文件操作

    /// 打开文件句柄（读取模式）
    func sftpOpenFileRead(sftp: OpaquePointer, path: String) throws -> OpaquePointer {
        var handle: OpaquePointer?
        repeat {
            handle = libssh2_sftp_open_ex(
                sftp,
                path,
                UInt32(path.utf8.count),
                SFTP_FXF_READ,
                0,
                SFTP_OPENFILE
            )
            if handle == nil {
                let code = UInt32(libssh2_sftp_last_error(sftp))
                guard libssh2_session_last_errno(session) == LIBSSH2_ERROR_EAGAIN else {
                    if code == SFTP_STATUS_NO_SUCH_FILE {
                        throw SSHError.sftpFileNotFound(path: path)
                    } else if code == SFTP_STATUS_PERMISSION_DENIED {
                        throw SSHError.sftpPermissionDenied(path: path)
                    }
                    throw SSHError.sftpOpenFailed(path: path, code: code)
                }
            }
        } while handle == nil

        return handle!
    }

    /// 打开文件句柄（写入模式，覆盖）
    func sftpOpenFileWrite(sftp: OpaquePointer, path: String, append: Bool = false) throws -> OpaquePointer {
        let flags: UInt = append
            ? (SFTP_FXF_WRITE | SFTP_FXF_CREAT | SFTP_FXF_APPEND)
            : (SFTP_FXF_WRITE | SFTP_FXF_CREAT | SFTP_FXF_TRUNC)

        var handle: OpaquePointer?
        repeat {
            handle = libssh2_sftp_open_ex(
                sftp,
                path,
                UInt32(path.utf8.count),
                flags,
                0o644,
                SFTP_OPENFILE
            )
            if handle == nil {
                let code = UInt32(libssh2_sftp_last_error(sftp))
                guard libssh2_session_last_errno(session) == LIBSSH2_ERROR_EAGAIN else {
                    if code == SFTP_STATUS_PERMISSION_DENIED {
                        throw SSHError.sftpPermissionDenied(path: path)
                    }
                    throw SSHError.sftpOpenFailed(path: path, code: code)
                }
            }
        } while handle == nil

        return handle!
    }

    /// 读取文件数据
    func sftpReadFile(handle: OpaquePointer, buffer: UnsafeMutablePointer<CChar>, bufferSize: Int) -> Int {
        return libssh2_sftp_read(handle, buffer, bufferSize)
    }

    /// 写入文件数据
    func sftpWriteFile(handle: OpaquePointer, data: UnsafePointer<CChar>, length: Int) -> Int {
        return libssh2_sftp_write(handle, data, length)
    }

    /// 移动文件读写位置（断点续传）
    func sftpSeek64(handle: OpaquePointer, offset: UInt64) {
        libssh2_sftp_seek64(handle, offset)
    }

    /// 获取当前读写位置
    func sftpTell64(handle: OpaquePointer) -> UInt64 {
        return libssh2_sftp_tell64(handle)
    }

    /// 关闭文件句柄
    func sftpCloseHandle(handle: OpaquePointer) {
        libssh2_sftp_close_handle(handle)
    }

    /// 删除文件
    func sftpDeleteFile(sftp: OpaquePointer, path: String) throws {
        var rc: Int32
        repeat {
            rc = libssh2_sftp_unlink_ex(sftp, path, UInt32(path.utf8.count))
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            let code = UInt32(libssh2_sftp_last_error(sftp))
            if code == SFTP_STATUS_NO_SUCH_FILE {
                throw SSHError.sftpFileNotFound(path: path)
            } else if code == SFTP_STATUS_PERMISSION_DENIED {
                throw SSHError.sftpPermissionDenied(path: path)
            }
            throw SSHError.sftpOperationFailed(operation: "unlink", code: code)
        }
    }

    /// 重命名/移动文件
    func sftpRenameFile(sftp: OpaquePointer, from sourcePath: String, to destPath: String) throws {
        let flags: Int = SFTP_RENAME_OVERWRITE | SFTP_RENAME_ATOMIC | SFTP_RENAME_NATIVE

        var rc: Int32
        repeat {
            rc = libssh2_sftp_rename_ex(
                sftp,
                sourcePath,
                UInt32(sourcePath.utf8.count),
                destPath,
                UInt32(destPath.utf8.count),
                flags
            )
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            let code = UInt32(libssh2_sftp_last_error(sftp))
            throw SSHError.sftpOperationFailed(operation: "rename", code: code)
        }
    }

    // MARK: - 文件属性

    /// 获取文件属性（lstat - 不跟随符号链接）
    func sftpStatFile(sftp: OpaquePointer, path: String) throws -> LIBSSH2_SFTP_ATTRIBUTES {
        var attrs = LIBSSH2_SFTP_ATTRIBUTES()
        var rc: Int32
        repeat {
            rc = libssh2_sftp_stat_ex(sftp, path, UInt32(path.utf8.count), SFTP_STAT, &attrs)
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            let code = UInt32(libssh2_sftp_last_error(sftp))
            if code == SFTP_STATUS_NO_SUCH_FILE {
                throw SSHError.sftpFileNotFound(path: path)
            }
            throw SSHError.sftpOperationFailed(operation: "stat", code: code)
        }
        return attrs
    }

    /// 设置文件权限（chmod）
    func sftpSetPermissions(sftp: OpaquePointer, path: String, mode: UInt32) throws {
        var attrs = LIBSSH2_SFTP_ATTRIBUTES()
        attrs.flags = SFTP_ATTR_PERMISSIONS
        attrs.permissions = UInt(mode)

        var rc: Int32
        repeat {
            rc = libssh2_sftp_stat_ex(sftp, path, UInt32(path.utf8.count), SFTP_SETSTAT, &attrs)
        } while rc == LIBSSH2_ERROR_EAGAIN

        guard rc == 0 else {
            let code = UInt32(libssh2_sftp_last_error(sftp))
            if code == SFTP_STATUS_PERMISSION_DENIED {
                throw SSHError.sftpPermissionDenied(path: path)
            }
            throw SSHError.sftpOperationFailed(operation: "chmod", code: code)
        }
    }

    // MARK: - SFTP 辅助

    /// 获取 SFTP 文件类型
    static func sftpFileType(permissions: UInt) -> SFTPFileType {
        let typeBits = permissions & SFTP_S_IFMT
        switch typeBits {
        case SFTP_S_IFDIR:  return .directory
        case SFTP_S_IFLNK:  return .symlink
        case 0o100000:      return .regularFile // SFTP_S_IFREG
        default:            return .other
        }
    }
}

// MARK: - 端口转发扩展

extension LibSSH2BridgeReal {

    // MARK: - direct-tcpip 通道（本地转发 / SOCKS5）

    /// 打开 direct-tcpip 通道
    /// 用于本地端口转发（-L）和 SOCKS5 代理（-D），在 SSH 会话中建立到目标 host:port 的 TCP 连接
    /// - Parameters:
    ///   - host: 目标主机（远端服务器可达的地址）
    ///   - port: 目标端口
    ///   - sourceHost: 本地来源地址（用于日志记录，通常 127.0.0.1）
    ///   - sourcePort: 本地来源端口（用于日志记录，通常 0）
    /// - Returns: 成功返回通道指针，失败返回 nil
    func openDirectTCPIPChannel(
        host: String,
        port: Int32,
        sourceHost: String,
        sourcePort: Int32
    ) -> OpaquePointer? {
        guard let session = session else { return nil }
        var ch: OpaquePointer?
        repeat {
            ch = libssh2_channel_direct_tcpip_ex(session, host, port, sourceHost, sourcePort)
            if ch == nil {
                let rc = libssh2_session_last_errno(session)
                guard rc == LIBSSH2_ERROR_EAGAIN else { break }
                usleep(10_000)
            }
        } while ch == nil
        return ch
    }

    // MARK: - 远程端口转发（-R）

    /// 请求 SSH 服务器在远端监听指定端口（tcpip-forward 全局请求）
    /// - Parameters:
    ///   - host: 服务器绑定地址（"0.0.0.0" 监听所有接口）
    ///   - port: 服务器监听端口（0 = 由服务器自动分配）
    ///   - boundPort: 输出参数，服务器实际绑定的端口
    ///   - queueMaxsize: 最大等待连接队列大小
    /// - Returns: 成功返回监听器指针，失败返回 nil
    func forwardListen(
        host: String,
        port: Int32,
        boundPort: inout Int32,
        queueMaxsize: Int32
    ) -> OpaquePointer? {
        guard let session = session else { return nil }
        var listener: OpaquePointer?
        repeat {
            listener = libssh2_channel_forward_listen_ex(session, host, port, &boundPort, queueMaxsize)
            if listener == nil {
                let rc = libssh2_session_last_errno(session)
                guard rc == LIBSSH2_ERROR_EAGAIN else { break }
                usleep(50_000)
            }
        } while listener == nil
        return listener
    }

    /// 接受一个远端入站连接（阻塞，直到有连接到来或发生错误）
    /// - Parameter listener: 由 forwardListen 返回的监听器指针
    /// - Returns: 成功返回新建通道指针，失败返回 nil
    func forwardAccept(listener: OpaquePointer) -> OpaquePointer? {
        guard let session = session else { return nil }
        var ch: OpaquePointer?
        repeat {
            ch = libssh2_channel_forward_accept(listener)
            if ch == nil {
                let rc = libssh2_session_last_errno(session)
                guard rc == LIBSSH2_ERROR_EAGAIN else { break }
                usleep(50_000)
            }
        } while ch == nil
        return ch
    }

    /// 关闭远端监听器（停止接受新连接）
    func closeForwardListener(_ listener: OpaquePointer) {
        libssh2_channel_forward_cancel(listener)
    }
}
