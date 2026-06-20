import SwiftUI

// MARK: - AI 助手面板

/// Trailing Drawer 400px，对齐 Figma-Spec-v2 §09
struct AIAssistantPanelView: View {

    @StateObject private var vm: AIPanelViewModel
    @EnvironmentObject private var aiSettings: AISettingsStore
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    var onClose: () -> Void
    var initialError: String?
    /// 一键插入终端回调（AI-03）
    var onInsertCommand: ((String) -> Void)?

    @State private var showPrivacyConsent: Bool = false

    init(
        session: Session,
        onClose: @escaping () -> Void,
        initialError: String? = nil,
        onInsertCommand: ((String) -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: AIPanelViewModel(session: session))
        self.onClose = onClose
        self.initialError = initialError
        self.onInsertCommand = onInsertCommand
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            messageListView
            inputView
        }
        // Figma: bg-white/90 backdrop-blur-xl
        .background {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(DesignTokens.Colors.surfacePanel)
        }
        .overlay(alignment: .leading) {
            // Figma: border-[#d2d2d7]/50
            Rectangle()
                .fill(DesignTokens.Colors.borderPrimary)
                .frame(width: 0.5)
        }
        .onAppear {
            if !aiSettings.hasShownPrivacyConsent {
                showPrivacyConsent = true
            } else if let err = initialError {
                vm.prefillError(err)
            }
        }
        .sheet(isPresented: $showPrivacyConsent) {
            AIPrivacyConsentView {
                aiSettings.hasShownPrivacyConsent = true
                showPrivacyConsent = false
                if let err = initialError { vm.prefillError(err) }
            } onDecline: {
                onClose()
            }
        }
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                    .fill(DesignTokens.Gradients.aiGradient)
                    .frame(width: 36, height: 36)
                    .shadow(color: DesignTokens.Colors.accentAI.opacity(0.35), radius: 8, x: 0, y: 3)
                AppIcon.ai.image
                    .font(DesignTokens.Typography.labelLargeMid)
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.px) {
                // Figma 12:4: "✦ AI 助手" 15px semibold
                (Text(verbatim: "✦ ") + Text("AI 助手"))
                    .font(DesignTokens.Typography.labelLargeAlt)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("基于 \(aiSettings.currentModel.name) · \(vm.session.name)")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            modelPickerView
            Button { withAnimation(.easeInOut(duration: 0.15)) { vm.clear() } } label: {
                AppIcon.squareAndPencil.image
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("新对话")
            Button(action: onClose) {
                AppIcon.close.image
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("关闭 AI 助手")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // Figma: bg-white/60 backdrop-blur-xl border-b border-[#d2d2d7]/50
        .background {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(DesignTokens.Colors.glassBorderTop)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.Colors.borderPrimary)
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
                            } else { Text(model.name) }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Text(aiSettings.currentModel.name)
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                AppIcon.chevronExpand.image
                    .font(DesignTokens.Typography.captionSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(DesignTokens.Colors.surfaceInput.opacity(0.80))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.lg) {
                    offlineBannerView
                    ForEach(vm.messages) { msg in
                        AIMessageBubbleView(message: msg, onInsertCommand: onInsertCommand)
                            .id(msg.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    if vm.isStreaming {
                        AIMessageBubbleView(
                            message: .assistant(vm.streamingContent),
                            isStreaming: true, onInsertCommand: onInsertCommand
                        )
                        .id("streaming")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if vm.messages.count <= 1 && !vm.isStreaming { quickSuggestionsView }
                    if let err = vm.errorMessage { errorBanner(err).padding(.horizontal, 14).padding(.top, DesignTokens.Spacing.xs) }
                    Color.clear.frame(height: 8)
                }
                .padding(DesignTokens.Spacing.md)
            }
            .onChange(of: vm.streamingContent) { _ in
                withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo("streaming", anchor: .bottom) }
            }
            .onChange(of: vm.messages.count) { _ in
                if let last = vm.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    // MARK: - 快速建议

    private let quickSuggestions = [
        "如何查找占用磁盘空间最大的文件？",
        "检查当前磁盘使用情况",
        "实时监控 CPU 占用率",
        "帮我写一个数据备份脚本"
    ]

    private var quickSuggestionsView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                AppIcon.lightbulb.image.font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.statusConnecting)
                Text("快速建议").font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            let columns = [GridItem(.flexible(), spacing: DesignTokens.Spacing.sm), GridItem(.flexible(), spacing: DesignTokens.Spacing.sm)]
            LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.sm) {
                ForEach(quickSuggestions, id: \.self) { s in
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.send(text: s) } } label: {
                        Text(s).font(DesignTokens.Typography.labelSmall)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center).lineLimit(2)
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            // Figma 12:18: bg-[rgba(0,0,0,0.05)] border-[rgba(0,0,0,0.08)] rounded-[14px] h-[28px]
                            .background(Color.black.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xxs).padding(.top, DesignTokens.Spacing.sm)
    }

    private func errorBanner(_ msg: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                AppIcon.warning.image.font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.statusError)
                Text(msg).font(DesignTokens.Typography.captionLarge).foregroundColor(DesignTokens.Colors.statusError)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button { vm.errorMessage = nil; vm.canRetry = false } label: {
                    AppIcon.close.image.font(DesignTokens.Typography.captionMedium).foregroundColor(DesignTokens.Colors.textTertiary)
                }.buttonStyle(.plain)
            }
            if vm.canRetry {
                HStack {
                    Spacer()
                    Button { vm.retry() } label: {
                        Label("重试", systemImage: "arrow.clockwise")
                            .font(DesignTokens.Typography.labelSmall)
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md).padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.statusError.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
            .strokeBorder(DesignTokens.Colors.statusError.opacity(0.25), lineWidth: 0.5))
    }

    @ViewBuilder
    private var offlineBannerView: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: DesignTokens.Spacing.sm) {
                AppIcon.wifiSlash.image.font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.statusConnecting)
                Text("网络不可用，AI 请求将在网络恢复后才能发送")
                    .font(DesignTokens.Typography.captionLarge).foregroundColor(DesignTokens.Colors.statusConnecting).lineLimit(2)
            }
            .padding(.horizontal, DesignTokens.Spacing.md).padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.statusConnecting.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .strokeBorder(DesignTokens.Colors.statusConnecting.opacity(0.25), lineWidth: 0.5))
            .padding(.horizontal, 14).padding(.top, DesignTokens.Spacing.xs)
        }
    }

    // MARK: - 输入区

    private var inputView: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            modeSwitchBar
            HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                ZStack(alignment: .leading) {
                    if vm.inputText.isEmpty {
                        Text(vm.inputMode == .nlCommand
                             ? "用自然语言描述你想执行的操作..."
                             : "Ask me anything about terminal commands...")
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $vm.inputText)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .onSubmit { guard !vm.isStreaming else { return }; withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.send(text: vm.inputText) } }
                }
                .frame(height: 36)
                // Figma 12:26: bg-[#efeff1] h-[36px] rounded-[18px]
                .background(DesignTokens.Colors.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    if vm.inputMode == .nlCommand {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.accentSecondary.opacity(0.50), lineWidth: 1.0)
                    }
                }
                sendOrStopButton
            }
            Text(vm.inputMode == .nlCommand
                 ? "AI 将生成一条 shell 命令，可一键插入终端执行"
                 : "Press Enter to send, Shift+Enter for new line")
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, DesignTokens.Spacing.md)
        // Figma: bg-white/60 backdrop-blur-xl border-t border-[#d2d2d7]/50
        .background {
            Rectangle().fill(.thinMaterial)
            Rectangle().fill(DesignTokens.Colors.glassBorderTop)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(DesignTokens.Colors.borderPrimary).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var sendOrStopButton: some View {
        if vm.isStreaming {
            Button { vm.cancel() } label: {
                AppIcon.stopFill.image.font(DesignTokens.Typography.bodySmallStrong)
                    .foregroundColor(DesignTokens.Colors.statusError)
                    .frame(width: 32, height: 32)
                    .background(DesignTokens.Colors.statusError.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }.buttonStyle(.plain).help("停止生成")
        } else {
            let canSend = !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let sendColor: Color = vm.inputMode == .nlCommand ? DesignTokens.Colors.accentSecondary : DesignTokens.Colors.accentPrimary
            // Figma 12:28: bg-[#077aff] size-[32px] rounded-[16px]
            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { vm.send(text: vm.inputText) } } label: {
                (vm.inputMode == .nlCommand ? AppIcon.terminal : .arrowUp).image
                    .font(DesignTokens.Typography.bodyLargeStrong).foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(sendColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: sendColor.opacity(0.3), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain).disabled(!canSend).opacity(canSend ? 1.0 : 0.4)
            .help(vm.inputMode == .nlCommand ? "生成命令（Return）" : "发送（Return）")
        }
    }

    private var modeSwitchBar: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            ForEach(AIInputMode.allCases, id: \.rawValue) { mode in
                let isSelected = vm.inputMode == mode
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { vm.inputMode = mode; vm.inputText = "" }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        (mode == .chat ? AppIcon.bubbleLeft : .terminal).image
                            .font(DesignTokens.Typography.captionMedium)
                        Text(mode.rawValue)
                            .font(DesignTokens.Typography.captionLarge)
                            .fontWeight(isSelected ? .semibold : .regular)
                    }
                    .foregroundColor(isSelected
                        ? (mode == .nlCommand ? DesignTokens.Colors.accentSecondary : DesignTokens.Colors.accentPrimary)
                        : DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, 10).padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(isSelected
                        ? (mode == .nlCommand
                           ? DesignTokens.Colors.accentSecondary.opacity(0.10)
                           : DesignTokens.Colors.accentPrimary.opacity(0.10))
                        : Color.clear)
                    .clipShape(Capsule())
                }.buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - 消息气泡

struct AIMessageBubbleView: View {
    let message: AIMessage
    var isStreaming: Bool = false
    var onInsertCommand: ((String) -> Void)?
    private var isUser: Bool { message.role == .user }
    @State private var bounce: Bool = false

    var body: some View {
        Group {
            if isUser {
                HStack(alignment: .bottom, spacing: DesignTokens.Spacing.sm) {
                    Spacer(minLength: 32)
                    Text(message.content)
                        .font(DesignTokens.Typography.bodySmall).foregroundColor(.white)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DesignTokens.Spacing.lg).padding(.vertical, DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.accentPrimary)
                        // Figma 12:8: bg-[#077aff] rounded-[12px]
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
                        .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.3), radius: 8, x: 0, y: 3)
                    ZStack {
                        Circle().fill(DesignTokens.Colors.textSecondary).frame(width: 32, height: 32)
                        Text("U").font(DesignTokens.Typography.labelSmall).foregroundColor(.white)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                }
            } else {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    ZStack {
                        Circle().fill(DesignTokens.Gradients.aiGradient)
                            .frame(width: 32, height: 32)
                            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                        AppIcon.ai.image.font(DesignTokens.Typography.labelLarge).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        if isStreaming && message.content.isEmpty {
                            typingIndicator.padding(.horizontal, DesignTokens.Spacing.lg).padding(.vertical, DesignTokens.Spacing.md)
                        } else {
                            aiBubbleContent.padding(.horizontal, DesignTokens.Spacing.lg).padding(.vertical, DesignTokens.Spacing.md)
                        }
                    }
                    // Figma 12:6/10/15: bg-[#efeff1] rounded-[12px]
                    .background(DesignTokens.Colors.surfaceOverlay)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
                    Spacer(minLength: 32)
                }
            }
        }
    }

    @ViewBuilder
    private var aiBubbleContent: some View {
        let segments = AIMarkdownParser.parse(message.content)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .text(let t):
                    if !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(t).font(DesignTokens.Typography.bodySmall).foregroundColor(DesignTokens.Colors.textPrimary)
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                case .code(let code, let lang):
                    AICodeBlockView(code: code, language: lang, onInsert: onInsertCommand)
                case .inlineCode(let c):
                    Text(c).font(DesignTokens.Typography.codeTiny)
                        .foregroundColor(DesignTokens.Colors.accentPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.micro).padding(.vertical, DesignTokens.Spacing.xxxs)
                        .background(DesignTokens.Colors.accentPrimary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous))
                }
            }
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(DesignTokens.Colors.textSecondary).frame(width: 8, height: 8)
                    .offset(y: bounce ? -4 : 0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.16), value: bounce)
            }
        }
        .onAppear { bounce = true }
        .onDisappear { bounce = false }
    }
}

// MARK: - 简易 Markdown 解析器

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
                result.append(.text(remaining)); break
            }
            let before = String(remaining[..<fenceRange.lowerBound])
            if !before.isEmpty { result.append(.text(before)) }
            let afterFence = String(remaining[fenceRange.upperBound...])
            let lang: String; let codeStart: String
            if let nl = afterFence.firstIndex(of: "\n") {
                lang = String(afterFence[..<nl]).trimmingCharacters(in: .whitespaces)
                codeStart = String(afterFence[afterFence.index(after: nl)...])
            } else { lang = ""; codeStart = afterFence }
            if let closeRange = codeStart.range(of: "```") {
                let code = String(codeStart[..<closeRange.lowerBound])
                result.append(.code(code, language: lang.isEmpty ? nil : lang))
                remaining = String(codeStart[closeRange.upperBound...])
            } else {
                result.append(.text("```" + afterFence)); break
            }
        }
        return result
    }
}

// MARK: - 19.5 AI 隐私数据说明弹窗

struct AIPrivacyConsentView: View {
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: DesignTokens.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentSecondary],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                    AppIcon.ai.image.font(DesignTokens.Typography.displayMedium).foregroundColor(.white)
                }
                Text("AI 助手数据说明")
                    .font(DesignTokens.Typography.labelXLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("在开启 AI 功能前，请了解以下数据处理方式")
                    .font(DesignTokens.Typography.bodySmall).foregroundColor(DesignTokens.Colors.textSecondary).multilineTextAlignment(.center)
            }
            .padding(.top, 28).padding(.horizontal, DesignTokens.Spacing.xxl).padding(.bottom, DesignTokens.Spacing.xl)
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                privacyItem(icon: "text.alignleft", color: DesignTokens.Colors.accentPrimary, title: "会发送的数据",
                            body: "• 您在 AI 输入框中填写的消息内容\n• 您主动点击\"发送给 AI\"时的终端输出片段（最近 50 行）")
                privacyItem(icon: "lock.slash", color: DesignTokens.Colors.statusConnected, title: "不会发送的数据",
                            body: "• SSH 密码、私钥、Passphrase\n• 完整终端历史（仅发送您选择的片段）\n• 会话配置、iCloud 同步数据")
                privacyItem(icon: "building.2", color: DesignTokens.Colors.statusConnecting, title: "数据去向",
                            body: "数据发送至您配置的 AI 服务商（Claude / OpenAI / 本地 Ollama），ShellMate 本身不存储或上传任何数据。")
            }
            .padding(.horizontal, DesignTokens.Spacing.xxl).padding(.vertical, 18)
            Divider()
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("不使用 AI 功能", action: onDecline).buttonStyle(.bordered).controlSize(.regular)
                Button("我已了解，继续使用", action: onAccept).buttonStyle(.borderedProminent).controlSize(.regular)
            }
            .padding(.horizontal, DesignTokens.Spacing.xxl).padding(.vertical, DesignTokens.Spacing.lg)
        }
        .frame(width: 420)
        .background(DesignTokens.Colors.surfacePanel)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
    }

    private func privacyItem(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon).font(DesignTokens.Typography.labelLarge).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.nano) {
                Text(title).font(DesignTokens.Typography.bodySmallStrong).foregroundColor(DesignTokens.Colors.textPrimary)
                Text(body).font(DesignTokens.Typography.captionLarge).foregroundColor(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

#Preview("AI 隐私说明") {
    AIPrivacyConsentView(onAccept: {}, onDecline: {})
        .padding()
}
