import SwiftUI

// MARK: - 输入模式

enum AIInputMode: String, CaseIterable {
    case chat = "对话"
    case nlCommand = "生成命令"
}

// MARK: - ViewModel

@MainActor
final class AIAssistantViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var isStreaming: Bool = false
    @Published var streamingContent: String = ""
    @Published var errorMessage: String?
    @Published var inputText: String = ""
    @Published var inputMode: AIInputMode = .chat

    private var streamingTask: Task<Void, Never>?
    let session: Session

    init(session: Session) {
        self.session = session
        // 面板打开时预填充欢迎消息（对齐 Figma §09 初始状态）
        self._messages = .init(initialValue: [
            .assistant("""
            Hello! I'm your AI terminal assistant. I can help you with:

            • Command suggestions and explanations
            • Script generation
            • Troubleshooting errors
            • Best practices and security tips

            What would you like help with?
            """)
        ])
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

    /// 自然语言→命令模式：只返回一条可执行的 shell 命令代码块，不加任何解释
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

        let displayText = inputMode == .nlCommand ? "[\(AIInputMode.nlCommand.rawValue)] \(trimmed)" : trimmed
        messages.append(.user(displayText))
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

        let msgs = inputMode == .nlCommand
            ? [AIMessage.user(trimmed)]           // NL 模式只发原始输入，避免历史消息干扰
            : messages
        let prompt = inputMode == .nlCommand ? nlCommandSystemPrompt : chatSystemPrompt
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
        guard !isStreaming else { return }
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
    /// 一键插入终端回调（AI-03）：将生成的命令发送到当前活跃 SSH 会话
    var onInsertCommand: ((String) -> Void)?

    init(
        session: Session,
        onClose: @escaping () -> Void,
        initialError: String? = nil,
        onInsertCommand: ((String) -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: AIAssistantViewModel(session: session))
        self.onClose = onClose
        self.initialError = initialError
        self.onInsertCommand = onInsertCommand
    }

    var body: some View {
        // 对齐规范：h-full flex flex-col bg-white/90 backdrop-blur-xl
        VStack(spacing: 0) {
            headerView
            messageListView
            inputView
        }
        .background(Color.white.opacity(0.90))
        .background(.ultraThinMaterial)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(hex: "#d2d2d7").opacity(0.5))
                .frame(width: 0.5)
        }
        .onAppear {
            if let err = initialError { vm.prefillError(err) }
        }
    }

    // MARK: - 头部
    // 对齐规范：p-4 border-b border-[#d2d2d7]/50 bg-white/60 backdrop-blur-xl

    private var headerView: some View {
        HStack(spacing: 10) {
            // Figma: w-10 h-10 rounded-xl bg-gradient from-[#007aff] to-[#5856d6] shadow-lg
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#007aff"), Color(hex: "#5856d6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: Color(hex: "#007aff").opacity(0.40), radius: 8, x: 0, y: 3)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }

            // 标题文字组
            VStack(alignment: .leading, spacing: 1) {
                Text("AI 助手")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#1d1d1f"))
                Text("Helping with \(vm.session.name)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#86868b"))
                    .lineLimit(1)
            }

            Spacer()

            // 模型选择器
            modelPickerView

            // 清空按钮
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { vm.clear() }
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("新对话")

            // 关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("关闭 AI 助手")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.6))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: "#d2d2d7").opacity(0.5))
                .frame(height: 0.5)
        }
    }

    // MARK: - 模型选择器

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
            HStack(spacing: 4) {
                Text(aiSettings.currentModel.name)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DesignTokens.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - 消息列表
    // 对齐规范：flex-1 p-4，space-y-4

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(vm.messages) { msg in
                        AIMessageBubbleView(message: msg, onInsertCommand: onInsertCommand)
                            .id(msg.id)
                    }
                    if vm.isStreaming {
                        AIMessageBubbleView(
                            message: .assistant(vm.streamingContent),
                            isStreaming: true,
                            onInsertCommand: onInsertCommand
                        )
                        .id("streaming")
                    }
                    // Figma §7: 仅初始欢迎消息时显示快速建议（messages.count <= 1）
                    if vm.messages.count <= 1 && !vm.isStreaming {
                        quickSuggestionsView
                    }
                    if let err = vm.errorMessage {
                        errorBanner(err)
                            .padding(.horizontal, 14)
                            .padding(.top, 6)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding(14)
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
        // Figma: 透明背景，继承容器 bg-white/90
    }

    // MARK: - 快速建议（Figma §7：胶囊按钮 2 列网格）

    private let quickSuggestions = [
        "如何查找占用磁盘空间最大的文件？",
        "检查当前磁盘使用情况",
        "实时监控 CPU 占用率",
        "帮我写一个数据备份脚本"
    ]

    private var quickSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行：💡 快速建议
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#ff9500"))
                Text("快速建议")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#86868b"))
            }

            // 2×2 胶囊按钮网格
            let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(quickSuggestions, id: \.self) { suggestion in
                    Button { vm.send(text: suggestion) } label: {
                        Text(suggestion)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#1d1d1f"))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.80))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.statusError)
            Text(msg)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.statusError)
                .lineLimit(3)
            Spacer()
            Button { vm.errorMessage = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignTokens.Colors.statusError.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(DesignTokens.Colors.statusError.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - 输入区
    // 对齐规范：p-4 border-t border-[#d2d2d7]/50 bg-white/60 backdrop-blur-xl

    private var inputView: some View {
        VStack(spacing: 6) {
            // 模式切换条（AI-03：对话 / 生成命令）
            modeSwitchBar

            // 输入框行（flex gap-2）
            HStack(alignment: .center, spacing: 8) {
                // 输入框（bg-white/80 border-[#d2d2d7]/50 rounded-xl shadow-sm）
                ZStack(alignment: .leading) {
                    if vm.inputText.isEmpty {
                        Text(vm.inputMode == .nlCommand
                             ? "用自然语言描述你想执行的操作..."
                             : "Ask me anything about terminal commands...")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#86868b"))
                            .padding(.horizontal, 12)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $vm.inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#1d1d1f"))
                        .padding(.horizontal, 12)
                        .onSubmit {
                            guard !vm.isStreaming else { return }
                            vm.send(text: vm.inputText)
                        }
                }
                .frame(minHeight: 44)   // min-h-[44px]（Figma-Spec-v2 §09）
                .background(Color.white.opacity(0.80))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            vm.inputMode == .nlCommand
                                ? Color(hex: "#5856d6").opacity(0.50)
                                : Color(hex: "#d2d2d7").opacity(0.5),
                            lineWidth: vm.inputMode == .nlCommand ? 1.0 : 0.75
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)

                // 发送/停止按钮
                if vm.isStreaming {
                    // 停止按钮
                    Button { vm.cancel() } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignTokens.Colors.statusError)
                            .frame(width: 44, height: 44)
                            .background(DesignTokens.Colors.statusError.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("停止生成")
                } else {
                    let canSend = !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let sendColor = vm.inputMode == .nlCommand
                        ? Color(hex: "#5856d6")
                        : Color(hex: "#007aff")
                    Button { vm.send(text: vm.inputText) } label: {
                        Image(systemName: vm.inputMode == .nlCommand ? "terminal" : "paperplane.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(sendColor)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
                            .shadow(color: sendColor.opacity(0.3), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .opacity(canSend ? 1.0 : 0.4)
                    .help(vm.inputMode == .nlCommand ? "生成命令（Return）" : "发送（Return）")
                }
            }

            // 提示文字
            Text(vm.inputMode == .nlCommand
                 ? "AI 将生成一条 shell 命令，可一键插入终端执行"
                 : "Press Enter to send, Shift+Enter for new line")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#86868b"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.60))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "#d2d2d7").opacity(0.5))
                .frame(height: 0.5)
        }
    }

    // MARK: - 模式切换条（AI-03）

    private var modeSwitchBar: some View {
        HStack(spacing: 4) {
            ForEach(AIInputMode.allCases, id: \.rawValue) { mode in
                let isSelected = vm.inputMode == mode
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        vm.inputMode = mode
                        vm.inputText = ""
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode == .chat ? "bubble.left" : "terminal")
                            .font(.system(size: 10, weight: .medium))
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundColor(isSelected
                        ? (mode == .nlCommand ? Color(hex: "#5856d6") : Color(hex: "#007aff"))
                        : Color(hex: "#86868b"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        isSelected
                            ? (mode == .nlCommand
                               ? Color(hex: "#5856d6").opacity(0.10)
                               : Color(hex: "#007aff").opacity(0.10))
                            : Color.clear
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - 消息气泡
// 对齐 Figma-Spec-v2 §09：AI左/用户右，圆角气泡，头像

struct AIMessageBubbleView: View {
    let message: AIMessage
    var isStreaming: Bool = false
    /// 一键插入终端（AI-03），nil 表示不显示插入按钮
    var onInsertCommand: ((String) -> Void)?

    private var isUser: Bool { message.role == .user }

    var body: some View {
        Group {
            if isUser {
                // 用户消息：右对齐（flex gap-3 justify-end）
                HStack(alignment: .bottom, spacing: 8) {
                    Spacer(minLength: 32)
                    // 气泡（bg-[#007aff] text-white shadow-lg shadow-[#007aff]/30）
                    Text(message.content)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#007aff"))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color(hex: "#007aff").opacity(0.3), radius: 8, x: 0, y: 3)
                    // 头像（bg-[#86868b] text-white "U"）
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#86868b"))
                            .frame(width: 28, height: 28)
                        Text("U")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                }
            } else {
                // AI 消息：左对齐（flex gap-3 justify-start）
                HStack(alignment: .top, spacing: 8) {
                    // 头像（渐变圆形 from-[#007aff] to-[#5856d6]）
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#007aff"), Color(hex: "#5856d6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    // 气泡（bg-white/80 border border-[#d2d2d7]/50 shadow-sm）
                    VStack(alignment: .leading, spacing: 0) {
                        if isStreaming && message.content.isEmpty {
                            typingIndicator
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                        } else {
                            aiBubbleContent
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                        }
                    }
                    .background(Color.white.opacity(0.80))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color(hex: "#d2d2d7").opacity(0.5), lineWidth: 0.75)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    Spacer(minLength: 32)
                }
            }
        }
    }

    // AI 消息内容（支持 Markdown 代码块）
    @ViewBuilder
    private var aiBubbleContent: some View {
        let segments = AIMarkdownParser.parse(message.content)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .text(let t):
                    if !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(t)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#1d1d1f"))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .code(let code, let lang):
                    AICodeBlockView(code: code, language: lang, onInsert: onInsertCommand)
                case .inlineCode(let c):
                    Text(c)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(DesignTokens.Colors.accentPrimary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous))
                }
            }
        }
    }

    // Typing 指示器（三点弹跳，对齐规范 §09 §06）
    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#86868b"))
                    .frame(width: 6, height: 6)
                    // 错开弹跳延迟
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: isStreaming
                    )
            }
        }
    }
}

// MARK: - 代码块视图

struct AICodeBlockView: View {
    let code: String
    let language: String?
    /// 一键插入终端（AI-03），nil 表示不显示该按钮
    var onInsert: ((String) -> Void)?
    @State private var isCopied: Bool = false
    @State private var isInserted: Bool = false

    /// 提取纯命令文本（去除 ⚠️ 警告行和首尾空白）
    private var cleanCommand: String {
        code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("⚠️") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack(spacing: 6) {
                if let lang = language, !lang.isEmpty {
                    Text(lang.lowercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                Spacer()

                // 复制按钮
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
                            .font(.system(size: 10))
                    }
                    .foregroundColor(isCopied
                        ? DesignTokens.Colors.statusConnected
                        : DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)

                // 插入终端按钮（AI-03，仅注入回调时显示）
                if let onInsert {
                    Button {
                        onInsert(cleanCommand)
                        withAnimation { isInserted = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { isInserted = false }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isInserted ? "checkmark.circle.fill" : "terminal")
                                .font(.system(size: 10))
                            Text(isInserted ? "已插入" : "插入终端")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(isInserted
                            ? DesignTokens.Colors.statusConnected
                            : Color(hex: "#5856d6"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            isInserted
                                ? DesignTokens.Colors.statusConnected.opacity(0.10)
                                : Color(hex: "#5856d6").opacity(0.10)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("将命令插入当前终端并执行")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(DesignTokens.Colors.borderSecondary.opacity(0.5))

            // 代码内容
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.trimmingCharacters(in: .newlines))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.accentPrimary.opacity(0.9))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        }
        .background(DesignTokens.Colors.surfaceWindow)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderSecondary, lineWidth: 0.5)
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
