import SwiftUI

// MARK: - ViewModel

@MainActor
final class AIAssistantViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var isStreaming: Bool = false
    @Published var streamingContent: String = ""
    @Published var errorMessage: String?
    @Published var inputText: String = ""

    private var streamingTask: Task<Void, Never>?
    let session: Session

    init(session: Session) { self.session = session }

    // MARK: - 系统提示词

    private var systemPrompt: String {
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

    // MARK: - 发送消息

    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        messages.append(.user(trimmed))
        inputText = ""
        errorMessage = nil

        let settings = AISettingsStore.shared
        let service: AIServiceProtocol
        do {
            service = try settings.makeService()
        } catch let e as AIServiceError {
            errorMessage = e.localizedDescription
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        isStreaming = true
        streamingContent = ""

        let msgs = messages
        let prompt = systemPrompt
        let model = settings.modelId
        let key = settings.apiKey
        let url = settings.baseURL

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
                if case .cancelled = e {} else { self.errorMessage = e.localizedDescription }
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.streamingContent = ""
            self.isStreaming = false
        }
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
        messages = []; streamingContent = ""; isStreaming = false; errorMessage = nil
    }

    /// 预填充错误上下文（面板首次打开时调用）
    func prefillError(_ errorText: String) {
        guard messages.isEmpty && !isStreaming else { return }
        let prompt = "请帮我分析以下终端错误并给出修复建议：\n\n```\n\(errorText)\n```"
        send(text: prompt)
    }

    deinit { streamingTask?.cancel() }
}

// MARK: - AI 助手面板

struct AIAssistantPanelView: View {

    @StateObject private var vm: AIAssistantViewModel
    @ObservedObject private var aiSettings = AISettingsStore.shared
    var onClose: () -> Void
    var initialError: String?

    init(session: Session, onClose: @escaping () -> Void, initialError: String? = nil) {
        _vm = StateObject(wrappedValue: AIAssistantViewModel(session: session))
        self.onClose = onClose
        self.initialError = initialError
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider().opacity(0.5)

            messageListView

            Divider().opacity(0.5)

            inputView
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DesignTokens.Colors.glassBorderSide)
                .frame(width: 0.5)
        }
        .onAppear {
            if let err = initialError { vm.prefillError(err) }
        }
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#60A5FA"), Color(hex: "#A78BFA")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Text("AI 助手")
                .font(DesignTokens.Typography.labelLarge)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // 模型选择器
            modelPickerView

            // 清空
            Button { withAnimation { vm.clear() } } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("清空对话")

            // 关闭
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("关闭 AI 助手")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 40)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Rectangle().fill(DesignTokens.Colors.glassUltraLight))
        )
    }

    private var modelPickerView: some View {
        Menu {
            ForEach(AIProvider.allCases, id: \.rawValue) { prov in
                Section(prov.displayName) {
                    ForEach(prov.models) { model in
                        Button {
                            aiSettings.provider = prov
                            aiSettings.modelId  = model.id
                        } label: {
                            if aiSettings.provider == prov && aiSettings.modelId == model.id {
                                Label(model.name, systemImage: "checkmark")
                            } else {
                                Text(model.name)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(aiSettings.currentModel.name)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(DesignTokens.Colors.glassMedium)
            .cornerRadius(5)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.md) {
                    if vm.messages.isEmpty && !vm.isStreaming {
                        emptyStateView
                    } else {
                        ForEach(vm.messages) { msg in
                            AIMessageBubbleView(message: msg)
                                .id(msg.id)
                        }
                        if vm.isStreaming {
                            AIMessageBubbleView(
                                message: .assistant(vm.streamingContent),
                                isStreaming: true
                            )
                            .id("streaming")
                        }
                    }
                    if let err = vm.errorMessage {
                        errorBanner(err)
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .onChange(of: vm.streamingContent) { _ in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            .onChange(of: vm.messages.count) { _ in
                if let last = vm.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer().frame(height: 8)

            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#60A5FA").opacity(0.8), Color(hex: "#A78BFA").opacity(0.8)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                VStack(spacing: 4) {
                    Text("AI 助手")
                        .font(DesignTokens.Typography.titleSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Text("\(vm.session.username)@\(vm.session.host)")
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }

            // 快速建议
            VStack(spacing: DesignTokens.Spacing.xs) {
                suggestionChip(icon: "magnifyingglass",   text: "查找大于 100MB 的文件")
                suggestionChip(icon: "gauge.with.dots.needle.33percent", text: "分析 CPU 与内存占用")
                suggestionChip(icon: "doc.text",          text: "生成日志自动归档脚本")
                suggestionChip(icon: "network",           text: "检查端口占用情况")
                suggestionChip(icon: "lock.open",         text: "修复常见 Permission denied 错误")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func suggestionChip(icon: String, text: String) -> some View {
        Button { vm.send(text: text) } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                    .frame(width: 16)
                Text(text)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.glassMedium)
            .cornerRadius(DesignTokens.Sizes.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                    .strokeBorder(DesignTokens.Colors.glassBorderSide, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.statusError)
            Text(msg)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.statusError)
                .lineLimit(3)
            Spacer()
            Button { vm.errorMessage = nil } label: {
                Image(systemName: "xmark").font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.statusError.opacity(0.10))
        .cornerRadius(DesignTokens.Sizes.cornerRadiusSmall)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                .strokeBorder(DesignTokens.Colors.statusError.opacity(0.30), lineWidth: 0.5)
        )
    }

    // MARK: - 输入区

    private var inputView: some View {
        HStack(alignment: .bottom, spacing: DesignTokens.Spacing.sm) {
            TextField("问我任何问题…", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1...5)
                .onSubmit {
                    guard !vm.isStreaming else { return }
                    vm.send(text: vm.inputText)
                }
                .submitLabel(.send)

            if vm.isStreaming {
                Button { vm.cancel() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(DesignTokens.Colors.statusError)
                }
                .buttonStyle(.plain)
                .help("停止生成")
            } else {
                let canSend = !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                Button { vm.send(text: vm.inputText) } label: {
                    if canSend {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#60A5FA"), Color(hex: "#A78BFA")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(DesignTokens.Colors.textTertiary.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("发送（Return）")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.glassLight)
    }
}

// MARK: - 消息气泡

struct AIMessageBubbleView: View {
    let message: AIMessage
    var isStreaming: Bool = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.xs) {
            if isUser { Spacer(minLength: 32) }

            if !isUser { avatarView(isUser: false) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubbleBody
                if isStreaming && message.content.isEmpty {
                    typingIndicator
                }
            }

            if !isUser { Spacer(minLength: 32) }

            if isUser { avatarView(isUser: true) }
        }
    }

    @ViewBuilder
    private var bubbleBody: some View {
        let segments = AIMarkdownParser.parse(message.content)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .text(let t):
                    if !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(t)
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(isUser ? .white : DesignTokens.Colors.textPrimary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .code(let code, let lang):
                    AICodeBlockView(code: code, language: lang)
                case .inlineCode(let c):
                    Text(c)
                        .font(DesignTokens.Typography.codeSmall)
                        .foregroundColor(Color(hex: "#93C5FD"))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.black.opacity(0.20))
                        .cornerRadius(3)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            Group {
                if isUser {
                    LinearGradient(
                        colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentTertiary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                } else {
                    DesignTokens.Colors.glassMedium
                }
            }
        )
        .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium)
                .strokeBorder(
                    isUser ? Color.white.opacity(0.15) : DesignTokens.Colors.glassBorderSide,
                    lineWidth: 0.5
                )
        )
    }

    @ViewBuilder
    private func avatarView(isUser: Bool) -> some View {
        Circle()
            .fill(
                isUser
                    ? AnyShapeStyle(DesignTokens.Colors.accentPrimary.opacity(0.15))
                    : AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: "#3B82F6").opacity(0.7), Color(hex: "#8B5CF6").opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .frame(width: 24, height: 24)
            .overlay(
                Image(systemName: isUser ? "person.fill" : "sparkles")
                    .font(.system(size: isUser ? 10 : 9, weight: .semibold))
                    .foregroundColor(isUser ? DesignTokens.Colors.accentPrimary : .white)
            )
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DesignTokens.Colors.textTertiary)
                    .frame(width: 5, height: 5)
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 6)
        .background(DesignTokens.Colors.glassMedium)
        .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
    }
}

// MARK: - 代码块视图

struct AICodeBlockView: View {
    let code: String
    let language: String?
    @State private var isCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                if let lang = language, !lang.isEmpty {
                    Text(lang.lowercased())
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    withAnimation { isCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { isCopied = false }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(isCopied ? "已复制" : "复制")
                            .font(DesignTokens.Typography.labelSmall)
                    }
                    .foregroundColor(isCopied
                        ? DesignTokens.Colors.statusConnected
                        : DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.20))

            // 代码内容
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.trimmingCharacters(in: .newlines))
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(Color(hex: "#93C5FD"))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.sm)
            }
        }
        .background(Color.black.opacity(0.28))
        .cornerRadius(DesignTokens.Sizes.cornerRadiusSmall)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - 简易 Markdown 解析器（仅处理围栏代码块）

enum MessageSegment {
    case text(String)
    case code(String, language: String?)
    case inlineCode(String)
}

enum AIMarkdownParser {

    static func parse(_ input: String) -> [MessageSegment] {
        var result: [MessageSegment] = []
        var remaining = input

        while !remaining.isEmpty {
            guard let fenceRange = remaining.range(of: "```") else {
                result.append(.text(remaining))
                break
            }
            // 追加代码块前的文本
            let before = String(remaining[..<fenceRange.lowerBound])
            if !before.isEmpty { result.append(.text(before)) }

            let afterFence = String(remaining[fenceRange.upperBound...])

            // 提取可选语言标记（第一行）
            let lang: String
            let codeStart: String
            if let nl = afterFence.firstIndex(of: "\n") {
                lang      = String(afterFence[..<nl]).trimmingCharacters(in: .whitespaces)
                codeStart = String(afterFence[afterFence.index(after: nl)...])
            } else {
                lang = ""; codeStart = afterFence
            }

            // 找闭合 ```
            if let closeRange = codeStart.range(of: "```") {
                let code = String(codeStart[..<closeRange.lowerBound])
                result.append(.code(code, language: lang.isEmpty ? nil : lang))
                remaining = String(codeStart[closeRange.upperBound...])
            } else {
                // 未闭合：当普通文本处理
                result.append(.text("```" + afterFence))
                break
            }
        }
        return result
    }
}

// MARK: - 预览

#Preview("AI 助手面板") {
    HStack(spacing: 0) {
        Color.black.frame(width: 400)
        AIAssistantPanelView(session: Session.preview, onClose: {})
            .frame(width: 340)
    }
    .frame(height: 600)
}
