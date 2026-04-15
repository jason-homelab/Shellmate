import Foundation

// MARK: - ServiceProtocols
//
// 所有核心服务的抽象协议层。
// 真实实现与 Mock 实现均遵循同一协议，通过 AppEnvironment DI 容器注入，
// 使 ViewModel 层可在单元测试中完全替换底层依赖。

// MARK: - SSH 连接协议

/// SSH 连接服务的最小可测接口
protocol SSHConnectionProtocol: AnyObject {

    /// 当前连接状态
    var state: SSHConnectionState { get async }

    /// 建立连接
    func connect(config: SSHSessionConfig) async throws

    /// 断开连接
    func disconnect() async

    /// 向 Shell 发送原始数据
    func send(data: Data) async throws

    /// 执行单次命令（非交互式），返回标准输出
    func execute(command: String) async throws -> String
}

/// 连接状态（与 SSHConnection.State 对应，独立定义避免 Actor 暴露）
enum SSHConnectionState: Equatable {
    case disconnected
    case connecting
    case authenticating
    case connected
    case disconnecting
    case failed(String)
}

// MARK: - SFTP 服务协议

/// SFTP 文件操作服务的抽象接口
protocol SFTPServiceProtocol: AnyObject {

    /// 是否已连接
    var isConnected: Bool { get }

    /// 建立 SFTP 连接
    func connect(
        host: String,
        port: Int32,
        username: String,
        authMethod: AuthMethod,
        password: String?,
        privateKeyPath: String?,
        passphrase: String?
    ) async throws

    /// 断开连接
    func disconnect() async

    /// 列出目录内容
    func listDirectory(path: String) async throws -> [SFTPFileItem]

    /// 创建目录
    func createDirectory(path: String) async throws

    /// 删除文件
    func deleteFile(path: String) async throws

    /// 重命名/移动文件
    func renameFile(from sourcePath: String, to destPath: String) async throws

    /// 上传文件（含进度回调）
    func uploadFile(
        localPath: String,
        remotePath: String,
        transferItem: SFTPTransferItem,
        resume: Bool
    ) async throws

    /// 下载文件（含进度回调）
    func downloadFile(
        remotePath: String,
        localPath: String,
        transferItem: SFTPTransferItem,
        resume: Bool
    ) async throws
}

// MARK: - LLM 服务协议

/// AI 大语言模型对话服务的抽象接口
protocol LLMServiceProtocol {

    /// 以流式方式发送对话请求，返回 AsyncThrowingStream<String>
    /// - Parameters:
    ///   - messages: 对话历史（含 system/user/assistant）
    ///   - systemPrompt: 系统提示词
    ///   - model: 模型 ID
    ///   - apiKey: API 密钥
    ///   - baseURL: 服务端地址
    func stream(
        messages: [AIMessage],
        systemPrompt: String,
        model: String,
        apiKey: String,
        baseURL: String
    ) -> AsyncThrowingStream<String, Error>
}
