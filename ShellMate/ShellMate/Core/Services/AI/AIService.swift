import Foundation
import Security
import SwiftUI

// MARK: - AI 提供商

enum AIProvider: String, CaseIterable, Codable {
    case claude = "claude"
    case openAI  = "openai"
    case ollama  = "ollama"

    var displayName: String {
        switch self {
        case .claude:  return "Claude (Anthropic)"
        case .openAI:  return "OpenAI"
        case .ollama:  return "Ollama（本地）"
        }
    }

    var models: [AIModel] {
        switch self {
        case .claude:
            return [
                AIModel(id: "claude-sonnet-4-6",          name: "Claude Sonnet 4.6", isDefault: true),
                AIModel(id: "claude-haiku-4-5-20251001",   name: "Claude Haiku 4.5"),
                AIModel(id: "claude-opus-4-6",             name: "Claude Opus 4.6"),
            ]
        case .openAI:
            return [
                AIModel(id: "gpt-4o",       name: "GPT-4o",        isDefault: true),
                AIModel(id: "gpt-4o-mini",  name: "GPT-4o Mini"),
                AIModel(id: "gpt-4-turbo",  name: "GPT-4 Turbo"),
            ]
        case .ollama:
            return [
                AIModel(id: "llama3.2",    name: "Llama 3.2",   isDefault: true),
                AIModel(id: "mistral",     name: "Mistral"),
                AIModel(id: "qwen2.5",     name: "Qwen 2.5"),
                AIModel(id: "deepseek-r1", name: "DeepSeek R1"),
            ]
        }
    }

    var defaultModel: AIModel { models.first(where: { $0.isDefault }) ?? models[0] }
    var needsAPIKey: Bool { self != .ollama }
}

struct AIModel: Identifiable, Hashable, Equatable {
    let id: String
    let name: String
    var isDefault: Bool = false
}

// MARK: - AI 消息

struct AIMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    let createdAt: Date

    enum Role: String {
        case user      = "user"
        case assistant = "assistant"
        case system    = "system"
    }

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id; self.role = role; self.content = content; self.createdAt = createdAt
    }

    static func user(_ t: String)      -> AIMessage { AIMessage(role: .user,      content: t) }
    static func assistant(_ t: String) -> AIMessage { AIMessage(role: .assistant, content: t) }
}

// MARK: - 错误

enum AIServiceError: LocalizedError {
    case noAPIKey(AIProvider)
    case requestFailed(String)
    case networkOffline
    case timeout
    case rateLimited
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let p):  return "未配置 \(p.displayName) 的 API Key，请前往「设置 → AI 助手」进行配置"
        case .requestFailed(let m): return m
        case .networkOffline:   return "网络不可用，请检查网络连接后重试"
        case .timeout:          return "请求超时，服务器响应过慢，请稍后重试"
        case .rateLimited:      return "请求频率超限，请稍等片刻后重试"
        case .cancelled:        return "已停止"
        }
    }

    /// 是否允许用户重试（取消操作和 API Key 缺失不可重试）
    var isRetryable: Bool {
        switch self {
        case .cancelled, .noAPIKey: return false
        default: return true
        }
    }
}

// MARK: - URLError 映射（21.4 离线降级）

extension AIServiceError {
    /// 将 URLError / HTTP 状态码转换为用户友好的 AIServiceError
    static func from(_ error: Error, httpStatus: Int? = nil) -> AIServiceError {
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed:
                return .networkOffline
            case .timedOut:
                return .timeout
            default:
                return .requestFailed(urlErr.localizedDescription)
            }
        }
        if let status = httpStatus {
            switch status {
            case 429: return .rateLimited
            case 401, 403: return .requestFailed("API Key 无效或无权限（HTTP \(status)），请检查密钥配置")
            case 500...599: return .requestFailed("服务器内部错误（HTTP \(status)），请稍后重试")
            default: return .requestFailed("请求失败（HTTP \(status)），请检查 API Key 是否有效")
            }
        }
        return .requestFailed(error.localizedDescription)
    }
}

// MARK: - 服务协议

protocol AIServiceProtocol {
    func stream(
        messages: [AIMessage],
        systemPrompt: String,
        model: String,
        apiKey: String,
        baseURL: String
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Claude 实现（Anthropic Messages API，SSE）

struct ClaudeAIService: AIServiceProtocol {
    func stream(messages: [AIMessage], systemPrompt: String, model: String,
                apiKey: String, baseURL: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // defer 确保无论何种退出路径（正常/取消/异常）continuation 都会被 finish，
                // 防止消费方永久挂起在 for await 上
                defer { continuation.finish() }
                do {
                    try Task.checkCancellation()
                    guard let url = URL(string: "\(baseURL)/v1/messages") else {
                        throw AIServiceError.requestFailed("无效的 API URL")
                    }
                    var req = URLRequest(url: url, timeoutInterval: 90)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
                    req.setValue("2023-06-01",       forHTTPHeaderField: "anthropic-version")

                    let payload: [String: Any] = [
                        "model": model, "max_tokens": AppConstants.aiMaxTokens, "stream": true,
                        "system": systemPrompt,
                        "messages": messages.filter { $0.role != .system }
                            .map { ["role": $0.role.rawValue, "content": $0.content] }
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        throw AIServiceError.from(URLError(.badServerResponse), httpStatus: status)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { continuation.finish(throwing: AIServiceError.cancelled); return }
                        guard line.hasPrefix("data: ") else { continue }
                        let raw = String(line.dropFirst(6))
                        guard raw != "[DONE]",
                              let d = raw.data(using: .utf8),
                              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                              let delta = (j["delta"] as? [String: Any])?["text"] as? String
                        else { continue }
                        continuation.yield(delta)
                    }
                } catch is CancellationError {
                    continuation.finish(throwing: AIServiceError.cancelled)
                } catch let e as AIServiceError {
                    continuation.finish(throwing: e)
                } catch {
                    continuation.finish(throwing: AIServiceError.from(error))
                }
            }
        }
    }
}

// MARK: - OpenAI 实现（Chat Completions API，SSE）

struct OpenAIService: AIServiceProtocol {
    func stream(messages: [AIMessage], systemPrompt: String, model: String,
                apiKey: String, baseURL: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                defer { continuation.finish() }
                do {
                    try Task.checkCancellation()
                    guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
                        throw AIServiceError.requestFailed("无效的 API URL")
                    }
                    var req = URLRequest(url: url, timeoutInterval: 90)
                    req.httpMethod = "POST"
                    req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
                    req.setValue("Bearer \(apiKey)",  forHTTPHeaderField: "Authorization")

                    var msgs: [[String: String]] = []
                    if !systemPrompt.isEmpty { msgs.append(["role": "system", "content": systemPrompt]) }
                    msgs += messages.filter { $0.role != .system }
                        .map { ["role": $0.role.rawValue, "content": $0.content] }

                    req.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "stream": true, "messages": msgs])

                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        throw AIServiceError.from(URLError(.badServerResponse), httpStatus: status)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { continuation.finish(throwing: AIServiceError.cancelled); return }
                        guard line.hasPrefix("data: ") else { continue }
                        let raw = String(line.dropFirst(6))
                        guard raw != "[DONE]",
                              let d = raw.data(using: .utf8),
                              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                              let choices = j["choices"] as? [[String: Any]],
                              let delta = (choices.first?["delta"] as? [String: Any])?["content"] as? String
                        else { continue }
                        continuation.yield(delta)
                    }
                } catch is CancellationError {
                    continuation.finish(throwing: AIServiceError.cancelled)
                } catch let e as AIServiceError {
                    continuation.finish(throwing: e)
                } catch {
                    continuation.finish(throwing: AIServiceError.from(error))
                }
            }
        }
    }
}

// MARK: - Ollama 实现（本地部署，streaming JSON）

struct OllamaAIService: AIServiceProtocol {
    func stream(messages: [AIMessage], systemPrompt: String, model: String,
                apiKey: String, baseURL: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                defer { continuation.finish() }
                do {
                    try Task.checkCancellation()
                    guard let url = URL(string: "\(baseURL)/api/chat") else {
                        throw AIServiceError.requestFailed("无效的 Ollama URL")
                    }
                    var req = URLRequest(url: url, timeoutInterval: 120)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    var msgs: [[String: String]] = []
                    if !systemPrompt.isEmpty { msgs.append(["role": "system", "content": systemPrompt]) }
                    msgs += messages.filter { $0.role != .system }
                        .map { ["role": $0.role.rawValue, "content": $0.content] }

                    req.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "stream": true, "messages": msgs])

                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)
                    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        let msg = status == 0
                            ? "Ollama 服务无响应，请确认已启动（\(baseURL)）"
                            : "Ollama 返回错误（HTTP \(status)）"
                        throw AIServiceError.requestFailed(msg)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { continuation.finish(throwing: AIServiceError.cancelled); return }
                        guard !line.isEmpty,
                              let d = line.data(using: .utf8),
                              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                              let msg = j["message"] as? [String: Any],
                              let content = msg["content"] as? String
                        else { continue }
                        continuation.yield(content)
                        if (j["done"] as? Bool) == true { break }
                    }
                } catch is CancellationError {
                    continuation.finish(throwing: AIServiceError.cancelled)
                } catch let e as AIServiceError {
                    continuation.finish(throwing: e)
                } catch {
                    continuation.finish(throwing: AIServiceError.from(error))
                }
            }
        }
    }
}

// MARK: - 工厂

enum AIServiceFactory {
    static func make(for provider: AIProvider) -> AIServiceProtocol {
        switch provider {
        case .claude:  return ClaudeAIService()
        case .openAI:  return OpenAIService()
        case .ollama:  return OllamaAIService()
        }
    }
}

// MARK: - 设置 Store（API Key 存入系统 Keychain）

@MainActor
final class AISettingsStore: ObservableObject {

    static let shared = AISettingsStore()

    // 功能开关
    @AppStorage("ai.enabled")               var isEnabled: Bool   = true
    @AppStorage("ai.errorDetective")        var errorDetectiveEnabled: Bool = true
    /// 首次使用 AI 功能时是否已展示隐私数据说明（App Store 合规要求）
    @AppStorage("ai.hasShownPrivacyConsent") var hasShownPrivacyConsent: Bool = false

    // 提供商 & 模型
    @AppStorage("ai.providerRaw")       var providerRaw: String = AIProvider.claude.rawValue
    @AppStorage("ai.modelId")           var modelId: String = "claude-sonnet-4-6"
    @AppStorage("ai.ollamaBaseURL")     var ollamaBaseURL: String = "http://localhost:11434"

    var provider: AIProvider {
        get { AIProvider(rawValue: providerRaw) ?? .claude }
        set {
            objectWillChange.send()
            providerRaw = newValue.rawValue
            modelId = newValue.defaultModel.id
        }
    }

    var currentModel: AIModel {
        provider.models.first { $0.id == modelId } ?? provider.defaultModel
    }

    var baseURL: String {
        switch provider {
        case .claude:  return "https://api.anthropic.com"
        case .openAI:  return "https://api.openai.com"
        case .ollama:  return ollamaBaseURL
        }
    }

    // MARK: Keychain（独立于 SSH 凭据 Keychain 域）

    private static let keychainService = "app.shellmate.ai"

    func saveAPIKey(_ key: String, for prov: AIProvider) {
        let account = "apikey.\(prov.rawValue)"
        let baseQuery: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  Self.keychainService,
            kSecAttrAccount:  account,
        ]
        SecItemDelete(baseQuery as CFDictionary)
        guard !key.isEmpty else { return }
        var attrs = baseQuery
        attrs[kSecValueData]      = key.data(using: .utf8)!
        attrs[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked
        SecItemAdd(attrs as CFDictionary, nil)
    }

    func loadAPIKey(for prov: AIProvider) -> String {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: "apikey.\(prov.rawValue)",
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8)
        else { return "" }
        return str
    }

    var apiKey: String { loadAPIKey(for: provider) }

    func makeService() throws -> AIServiceProtocol {
        if provider.needsAPIKey && apiKey.isEmpty {
            throw AIServiceError.noAPIKey(provider)
        }
        return AIServiceFactory.make(for: provider)
    }

    private init() {}
}
