import Foundation
import Darwin

// MARK: - SFTP 会话

/// SFTP 会话
/// 维护独立的 SSH 连接专用于 SFTP 文件操作，与终端 Shell 连接互不干扰。
/// 内部使用阻塞模式，所有操作均在专用后台队列执行。
final class SFTPSession: @unchecked Sendable {

    // MARK: - 属性

    /// 独立的 libssh2 桥接（不共享终端连接）
    private let bridge = LibSSH2BridgeReal()

    /// SFTP 子系统指针
    private var sftp: OpaquePointer?

    /// 专用后台队列（所有 libssh2 调用均在此队列执行）
    private let queue = DispatchQueue(label: "app.shellmate.sftp", qos: .userInitiated)

    /// 连接参数（用于重连）
    private var connectConfig: SFTPConnectConfig?

    /// 是否已连接
    private(set) var isConnected: Bool = false

    /// 并发传输计数（用于限流）
    private var activeTransferCount: Int = 0
    private let transferLock = NSLock()

    // MARK: - 内部配置结构

    struct SFTPConnectConfig {
        let host: String
        let port: Int32
        let username: String
        let authMethod: AuthMethod
        let password: String?
        let privateKeyPath: String?
        let passphrase: String?
    }

    // MARK: - 初始化

    init() {}

    deinit {
        if let sftp = sftp {
            bridge.closeSFTPSubsystem(sftp)
        }
        bridge.disconnect()
    }

    // MARK: - 连接

    /// 建立 SFTP 连接
    func connect(
        host: String,
        port: Int32,
        username: String,
        authMethod: AuthMethod,
        password: String? = nil,
        privateKeyPath: String? = nil,
        passphrase: String? = nil
    ) async throws {
        let config = SFTPConnectConfig(
            host: host,
            port: port,
            username: username,
            authMethod: authMethod,
            password: password,
            privateKeyPath: privateKeyPath,
            passphrase: passphrase
        )
        self.connectConfig = config

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.performConnect(config: config)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        isConnected = true
    }

    /// 断开连接
    func disconnect() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                if let sftp = self.sftp {
                    self.bridge.closeSFTPSubsystem(sftp)
                    self.sftp = nil
                }
                self.bridge.disconnect()
                self.isConnected = false
                continuation.resume()
            }
        }
    }

    // MARK: - 目录操作

    /// 列出目录内容
    func listDirectory(path: String) async throws -> [SFTPFileItem] {
        return try await runOnQueue {
            guard let sftp = self.sftp else { throw SSHError.sftpNotConnected }

            let entries = try self.bridge.sftpListDirectory(sftp: sftp, path: path)
            return entries.map { (name, attrs) in
                let fileType = LibSSH2BridgeReal.sftpFileType(permissions: attrs.permissions)
                let modTime: Date? = (attrs.flags & 0x00000008 != 0)
                    ? Date(timeIntervalSince1970: TimeInterval(attrs.mtime))
                    : nil
                let size: UInt64 = (attrs.flags & 0x00000001 != 0) ? attrs.filesize : 0
                let perm: UInt32 = (attrs.flags & 0x00000004 != 0)
                    ? UInt32(attrs.permissions & 0o777)
                    : 0

                return SFTPFileItem(
                    name: name,
                    path: path.hasSuffix("/") ? "\(path)\(name)" : "\(path)/\(name)",
                    fileType: fileType,
                    size: size,
                    permissions: perm,
                    modifiedAt: modTime,
                    uid: UInt32(attrs.uid),
                    gid: UInt32(attrs.gid)
                )
            }.sorted { lhs, rhs in
                // 目录排在文件前面，同类型按名称排序
                if lhs.fileType.isDirectory != rhs.fileType.isDirectory {
                    return lhs.fileType.isDirectory
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    /// 创建目录
    func createDirectory(path: String) async throws {
        try await runOnQueueVoid {
            guard let sftp = self.sftp else { throw SSHError.sftpNotConnected }
            try self.bridge.sftpCreateDirectory(sftp: sftp, path: path)
        }
    }

    // MARK: - 文件操作（10.6）

    /// 删除文件
    func deleteFile(path: String) async throws {
        try await runOnQueueVoid {
            guard let sftp = self.sftp else { throw SSHError.sftpNotConnected }
            try self.bridge.sftpDeleteFile(sftp: sftp, path: path)
        }
    }

    /// 删除目录（递归）
    func deleteDirectory(path: String) async throws {
        try await runOnQueueVoid {
            guard let sftp = self.sftp else { throw SSHError.sftpNotConnected }
            // 先删除目录内容，再删除目录本身
            let entries = try self.bridge.sftpListDirectory(sftp: sftp, path: path)
            for (name, attrs) in entries {
                let childPath = "\(path)/\(name)"
                let fileType = LibSSH2BridgeReal.sftpFileType(permissions: attrs.permissions)
                if fileType.isDirectory {
                    try self.deleteDirectorySync(sftp: sftp, path: childPath)
                } else {
                    try self.bridge.sftpDeleteFile(sftp: sftp, path: childPath)
                }
            }
            try self.bridge.sftpRemoveDirectory(sftp: sftp, path: path)
        }
    }

    /// 重命名/移动文件
    func renameFile(from sourcePath: String, to destPath: String) async throws {
        try await runOnQueueVoid {
            guard let sftp = self.sftp else { throw SSHError.sftpNotConnected }
            try self.bridge.sftpRenameFile(sftp: sftp, from: sourcePath, to: destPath)
        }
    }

    /// 设置文件权限（chmod）
    func setPermissions(path: String, mode: UInt32) async throws {
        try await runOnQueueVoid {
            guard let sftp = self.sftp else { throw SSHError.sftpNotConnected }
            try self.bridge.sftpSetPermissions(sftp: sftp, path: path, mode: mode)
        }
    }

    // MARK: - 文件下载（10.4 / 10.5）

    /// 下载文件
    /// - Parameters:
    ///   - remotePath: 远程文件路径
    ///   - localPath: 本地保存路径
    ///   - transferItem: 用于更新进度的传输条目
    ///   - resume: 是否断点续传（true = 追加到已有文件末尾）
    func downloadFile(
        remotePath: String,
        localPath: String,
        transferItem: SFTPTransferItem,
        resume: Bool = false
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.performDownload(
                        remotePath: remotePath,
                        localPath: localPath,
                        transferItem: transferItem,
                        resume: resume
                    )
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 上传文件
    /// - Parameters:
    ///   - localPath: 本地文件路径
    ///   - remotePath: 远程目标路径
    ///   - transferItem: 用于更新进度的传输条目
    ///   - resume: 是否断点续传（true = 追加到远程文件末尾）
    func uploadFile(
        localPath: String,
        remotePath: String,
        transferItem: SFTPTransferItem,
        resume: Bool = false
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.performUpload(
                        localPath: localPath,
                        remotePath: remotePath,
                        transferItem: transferItem,
                        resume: resume
                    )
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - 私有：连接实现

    private func performConnect(config: SFTPConnectConfig) throws {
        try bridge.sessionInit()
        bridge.setTimeout(30000)
        bridge.setBlocking(true) // SFTP 使用阻塞模式

        try bridge.tcpConnect(host: config.host, port: config.port)
        try bridge.handshake()

        // 认证
        switch config.authMethod {
        case .password, .keyboardInteractive:
            guard let pass = config.password else {
                throw SSHError.authenticationFailed(method: "password", reason: "密码未提供")
            }
            try bridge.authenticateWithPassword(username: config.username, password: pass)

        case .privateKey:
            guard let keyPath = config.privateKeyPath, !keyPath.isEmpty else {
                throw SSHError.invalidPrivateKey(reason: "未提供私钥路径")
            }
            try bridge.authenticateWithPublicKey(
                username: config.username,
                publicKeyPath: nil,
                privateKeyPath: keyPath,
                passphrase: config.passphrase
            )

        case .sshAgent:
            try bridge.authenticateWithAgent(username: config.username)
        }

        // 打开 SFTP 子系统
        sftp = try bridge.openSFTPSubsystem()
        AppLogger.sftp.debug("[SFTPSession] 连接成功: \(config.username)@\(config.host):\(config.port)")
    }

    // MARK: - 私有：下载实现

    private func performDownload(
        remotePath: String,
        localPath: String,
        transferItem: SFTPTransferItem,
        resume: Bool
    ) throws {
        guard let sftp = sftp else { throw SSHError.sftpNotConnected }

        // 获取远程文件大小
        let attrs = try bridge.sftpStatFile(sftp: sftp, path: remotePath)
        let remoteSize = attrs.filesize

        DispatchQueue.main.async {
            transferItem.totalBytes = remoteSize
            transferItem.state = .inProgress
        }

        // 确定本地文件起始偏移（断点续传）
        let localOffset: UInt64
        if resume, let localSize = localFileSize(at: localPath), localSize > 0, localSize < remoteSize {
            localOffset = localSize
        } else {
            localOffset = 0
        }

        // 打开远程文件
        let remoteHandle = try bridge.sftpOpenFileRead(sftp: sftp, path: remotePath)
        defer { bridge.sftpCloseHandle(handle: remoteHandle) }

        // 断点续传：跳转到指定偏移
        if localOffset > 0 {
            bridge.sftpSeek64(handle: remoteHandle, offset: localOffset)
        }

        // 打开本地文件
        let writeMode = localOffset > 0 ? "ab" : "wb" // 追加或覆盖
        guard let localFile = fopen(localPath, writeMode) else {
            throw SSHError.sftpTransferFailed(reason: "无法打开本地文件: \(localPath)")
        }
        defer { fclose(localFile) }

        // 传输循环（W15.4 SFTP CPU 优化：128KB 缓冲区减少 libssh2 调用次数）
        let bufferSize = AppConstants.sftpTransferBufferSize
        var buffer = [CChar](repeating: 0, count: bufferSize)
        var transferred: UInt64 = localOffset
        var lastSpeedUpdate = Date()
        var speedBytes: UInt64 = 0

        while !transferItem.isCancelled {
            let bytesRead = bridge.sftpReadFile(handle: remoteHandle, buffer: &buffer, bufferSize: bufferSize)

            if bytesRead > 0 {
                let written = fwrite(buffer, 1, bytesRead, localFile)
                guard written == bytesRead else {
                    throw SSHError.sftpTransferFailed(reason: "本地写入失败")
                }
                transferred += UInt64(bytesRead)
                speedBytes += UInt64(bytesRead)

                // 更新进度（W15.4：节流到 1.0 秒，减少主线程 DispatchQueue 切换频率）
                let now = Date()
                let elapsed = now.timeIntervalSince(lastSpeedUpdate)
                if elapsed >= 1.0 {
                    let speed = Double(speedBytes) / elapsed
                    let t = transferred
                    DispatchQueue.main.async {
                        transferItem.transferredBytes = t
                        transferItem.bytesPerSecond = speed
                    }
                    speedBytes = 0
                    lastSpeedUpdate = now
                }
            } else if bytesRead == Int(LIBSSH2_ERROR_EAGAIN) {
                usleep(1000)
            } else if bytesRead == 0 {
                break // EOF
            } else {
                throw SSHError.sftpReadFailed(code: bridge.sftpLastError(sftp: sftp))
            }
        }

        let finalState: SFTPTransferState = transferItem.isCancelled ? .cancelled : .completed
        let finalTransferred = transferred
        DispatchQueue.main.async {
            transferItem.transferredBytes = finalTransferred
            transferItem.bytesPerSecond = 0
            transferItem.state = finalState
        }

        if transferItem.isCancelled {
            throw SSHError.cancelled
        }
    }

    // MARK: - 私有：上传实现

    private func performUpload(
        localPath: String,
        remotePath: String,
        transferItem: SFTPTransferItem,
        resume: Bool
    ) throws {
        guard let sftp = sftp else { throw SSHError.sftpNotConnected }

        // 获取本地文件大小
        guard let localSize = localFileSize(at: localPath), localSize > 0 else {
            throw SSHError.sftpTransferFailed(reason: "本地文件不存在或为空: \(localPath)")
        }

        DispatchQueue.main.async {
            transferItem.totalBytes = localSize
            transferItem.state = .inProgress
        }

        // 确定远程文件起始偏移（断点续传）
        let remoteOffset: UInt64
        if resume, let remoteAttrs = try? bridge.sftpStatFile(sftp: sftp, path: remotePath),
           remoteAttrs.filesize > 0, remoteAttrs.filesize < localSize {
            remoteOffset = remoteAttrs.filesize
        } else {
            remoteOffset = 0
        }

        // 打开远程文件（断点续传用 append，否则覆盖）
        let remoteHandle = try bridge.sftpOpenFileWrite(sftp: sftp, path: remotePath, append: remoteOffset > 0)
        defer { bridge.sftpCloseHandle(handle: remoteHandle) }

        // 打开本地文件
        guard let localFile = fopen(localPath, "rb") else {
            throw SSHError.sftpTransferFailed(reason: "无法打开本地文件: \(localPath)")
        }
        defer { fclose(localFile) }

        // 断点续传：跳过已上传的字节
        if remoteOffset > 0 {
            fseek(localFile, Int(remoteOffset), SEEK_SET)
        }

        // 传输循环（W15.4 SFTP CPU 优化：128KB 缓冲区减少 libssh2 调用次数）
        let bufferSize = AppConstants.sftpTransferBufferSize
        var buffer = [CChar](repeating: 0, count: bufferSize)
        var transferred: UInt64 = remoteOffset
        var lastSpeedUpdate = Date()
        var speedBytes: UInt64 = 0

        while !transferItem.isCancelled {
            let bytesRead = fread(&buffer, 1, bufferSize, localFile)
            guard bytesRead > 0 else { break }

            var sent = 0
            while sent < bytesRead && !transferItem.isCancelled {
                let toSend = bytesRead - sent
                let result = buffer.withUnsafeBytes { rawPtr in
                    let ptr = rawPtr.baseAddress!.advanced(by: sent)
                        .assumingMemoryBound(to: CChar.self)
                    return bridge.sftpWriteFile(handle: remoteHandle, data: ptr, length: toSend)
                }

                if result > 0 {
                    sent += result
                } else if result == Int(LIBSSH2_ERROR_EAGAIN) {
                    usleep(1000)
                } else {
                    throw SSHError.sftpWriteFailed(code: bridge.sftpLastError(sftp: sftp))
                }
            }

            transferred += UInt64(bytesRead)
            speedBytes += UInt64(bytesRead)

            let now = Date()
            let elapsed = now.timeIntervalSince(lastSpeedUpdate)
            if elapsed >= 1.0 {
                let speed = Double(speedBytes) / elapsed
                let t = transferred
                DispatchQueue.main.async {
                    transferItem.transferredBytes = t
                    transferItem.bytesPerSecond = speed
                }
                speedBytes = 0
                lastSpeedUpdate = now
            }
        }

        let finalState: SFTPTransferState = transferItem.isCancelled ? .cancelled : .completed
        let finalTransferred = transferred
        DispatchQueue.main.async {
            transferItem.transferredBytes = finalTransferred
            transferItem.bytesPerSecond = 0
            transferItem.state = finalState
        }

        if transferItem.isCancelled {
            throw SSHError.cancelled
        }
    }

    // MARK: - 私有：辅助方法

    private func runOnQueue<T>(_ block: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try block()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runOnQueueVoid(_ block: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try block()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func deleteDirectorySync(sftp: OpaquePointer, path: String) throws {
        let entries = try bridge.sftpListDirectory(sftp: sftp, path: path)
        for (name, attrs) in entries {
            let childPath = "\(path)/\(name)"
            let fileType = LibSSH2BridgeReal.sftpFileType(permissions: attrs.permissions)
            if fileType.isDirectory {
                try deleteDirectorySync(sftp: sftp, path: childPath)
            } else {
                try bridge.sftpDeleteFile(sftp: sftp, path: childPath)
            }
        }
        try bridge.sftpRemoveDirectory(sftp: sftp, path: path)
    }

    private func localFileSize(at path: String) -> UInt64? {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64 else { return nil }
        return size
    }
}

// MARK: - LibSSH2BridgeReal SFTP 辅助扩展

extension LibSSH2BridgeReal {
    /// 获取 SFTP 最后一次错误码
    func sftpLastError(sftp: OpaquePointer) -> UInt32 {
        return UInt32(libssh2_sftp_last_error(sftp))
    }
}
