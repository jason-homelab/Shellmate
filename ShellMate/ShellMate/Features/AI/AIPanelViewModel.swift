import SwiftUI
import Combine

// MARK: - 输入模式

enum AIInputMode: String, CaseIterable {
    case chat = "对话"
    case nlCommand = "生成命令"
}

// MARK: - AI 面板 ViewModel

/// AI 助手面板业务逻辑：消息管理、流式 SSE、错误/重试、输入模式切换
@MainActor
final class AIPanelViewModel: BaseViewModel {

    // MARK: - 对话状态

    @Published var messages: [AIMessage] = []
    @Published var isStreaming: Bool = false
    @Published var streamingContent: String = ""
    @Published var canRetry: Bool = false
    @Published var inputText: String = ""
    @Published var inputMode: AIInputMode = .chat

    // MARK: - 依赖

    let session: Session

    // MARK: - 私有

    private var streamingTask: Task<Void, Never>?
    /// 上一次发送的原始文本（供重试使用）
    private var lastSentText: String = ""

    // MARK: - 初始化

    init(session: Session) {
        self.session = session
        super.init()
        messages = [
            .assistant("""
            Hello! I'm your AI terminal assistant. I can help you with:

            • Command suggestions and explanations
            • Script generation
            • Troubleshooting errors
            • Best practices and security tips

            What would you like help with?
            """)
        ]
    }

    // MARK: - 系统提示词

    private var chatSystemPrompt: String {
        """
        You are an expert DevOps engineer and SSH terminal assistant integrated into ShellMate, \
        a professional macOS SSH client.
        Current connection: \(session.username)@\(session.host) (port \(session.port))

        Guidelines:
        - Be concise and practical
        - Format all shell commands in fenced code blocks with the language tag (e.g. ```bash)
        - Add ⚠️ warning prefix for dangerous or destructive commands
        - Respond in Chinese by default unless the user writes in another language
        - Keep explanations brief; put the command first, then explain
        """
    }

    private var nlCommandSystemPrompt: String {
        """
        You are a shell command generator for ShellMate SSH client.
        Current connection: \(session.username)@\(session.host) (port \(session.port))

        Rules:
        1. Return ONLY a single fenced shell code block (```bash ... ```) with the command to execute.
        2. Do NOT include any explanation, preamble, or text outside the code block.
        3. If the request is dangerous (rm -rf, dd, chmod 777 etc.), prepend the block with exactly one line: ⚠️ 高风险命令，请确认后再执行
        4. If you cannot generate a safe command, return a comment inside the block explaining why.
        """
    }

    // MARK: - 发送消息

    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        // 离线预检：网络不可用时直接报错
        if !NetworkMonitor.shared.isConnected {
            errorMessage = AIServiceError.networkOffline.errorDescription
            canRetry = true
            lastSentText = trimmed
            return
        }

        let displayText = inputMode == .nlCommand ? "[\(AIInputMode.nlCommand.rawValue)] \(trimmed)" : trimmed
        messages.append(.user(displayText))
        inputText = ""
        errorMessage = nil
        canRetry = false
        lastSentText = trimmed

        let settings = AISettingsStore.shared
        let service: AIServiceProtocol
        do {
            service = try settings.makeService()
        } catch let e as AIServiceError {
            errorMessage = e.localizedDescription
            canRetry = e.isRetryable
            return
        } catch {
            errorMessage = error.localizedDescription
            canRetry = false
            return
        }

        isStreaming = true
        streamingContent = ""

        let msgs = inputMode == .nlCommand ? [AIMessage.user(trimmed)] : messages
        let prompt = inputMode == .nlCommand ? nlCommandSystemPrompt : chatSystemPrompt
        let model  = settings.modelId
        let key    = settings.apiKey
        let url    = settings.baseURL

        streamingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                for try await chunk in service.stream(
                    messages: msgs, systemPrompt: prompt,
                    model: model, apiKey: key, baseURL: url
                ) {
                    if Task.isCancelled { break }
                    self.streamingContent += chunk
                }
                if !self.streamingContent.isEmpty {
                    self.messages.append(.assistant(self.streamingContent))
                }
            } catch let e as AIServiceError {
                if case .cancelled = e { /* 用户主动取消，不显示错误 */ }
                else {
                    self.errorMessage = e.errorDescription
                    self.canRetry = e.isRetryable
                }
            } catch {
                self.errorMessage = error.localizedDescription
                self.canRetry = true
            }
            self.streamingContent = ""
            self.isStreaming = false
        }
    }

    // MARK: - 控制操作

    /// 重试上一次失败的请求
    func retry() {
        guard canRetry, !lastSentText.isEmpty else { return }
        if let last = messages.last, last.role == .user { messages.removeLast() }
        errorMessage = nil
        canRetry = false
        send(text: lastSentText)
    }

    func cancel() {
        streamingTask?.cancel()
        streamingTask = nil
        if !streamingContent.isEmpty {
            messages.append(.assistant(streamingContent))
        }
        streamingContent = ""
        isStreaming = false
    }

    func clear() {
        streamingTask?.cancel()
        messages = []
        streamingContent = ""
        isStreaming = false
        errorMessage = nil
    }

    /// 预填充错误上下文（面板首次打开时调用）
    func prefillError(_ errorText: String) {
        guard !isStreaming else { return }
        let prompt = "请帮我分析以下终端错误并给出修复建议：\n\n```\n\(errorText)\n```"
        send(text: prompt)
    }

    deinit { streamingTask?.cancel() }
}
