import Foundation

// MARK: - AppEnvironment
//
// 轻量级 DI 容器，集中持有所有核心服务实例。
//
// 使用方式：
//   - 正式运行：AppEnvironment.shared（真实服务）
//   - 单元测试：AppEnvironment(sftp: MockSFTPService(), llm: MockLLMService(), ...)
//
// ViewModel 初始化时接收 AppEnvironment 参数，从不自行实例化服务。

final class AppEnvironment {

    // MARK: - 单例（正式运行入口）

    static let shared = AppEnvironment()

    // MARK: - 服务持有

    let sftp:  SFTPServiceProtocol
    let llm:   LLMServiceProtocol

    // MARK: - 初始化（正式运行）

    private init() {
        sftp  = SFTPSession()
        llm   = ClaudeAIService()
    }

    // MARK: - 初始化（测试 / 预览 注入）

    init(
        sftp:  SFTPServiceProtocol,
        llm:   LLMServiceProtocol
    ) {
        self.sftp  = sftp
        self.llm   = llm
    }
}

// MARK: - MARK: SFTPSession 遵循 SFTPServiceProtocol

// SFTPSession 已实现协议要求的全部方法，此处通过 extension 声明遵循，
// 避免修改原始实现文件（符合开闭原则）。
extension SFTPSession: SFTPServiceProtocol {}

// MARK: - ClaudeAIService 遵循 LLMServiceProtocol

// ClaudeAIService 已实现 stream(messages:systemPrompt:model:apiKey:baseURL:)
// AIServiceProtocol 与 LLMServiceProtocol 接口完全一致，直接声明遵循。
extension ClaudeAIService: LLMServiceProtocol {}
