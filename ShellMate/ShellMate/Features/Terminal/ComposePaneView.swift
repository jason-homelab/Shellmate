import SwiftUI
import AppKit

// MARK: - O02 Compose Pane（命令编辑区）

/// Compose Pane — 停靠于终端底部的多行命令编辑区
/// 规格：与 TerminalPane 同宽，默认高度 120pt（60–200pt 可拖拽调整）
/// 任务 14.8：集成 AI 命令补全，输入暂停后自动建议
struct ComposePaneView: View {

    /// 发送命令回调
    var onSend: (String) -> Void

    /// 关闭面板回调
    var onClose: () -> Void

    /// 获取最近终端输出（AI 补全上下文），由 TerminalController 注入（任务 14.8）
    var contextProvider: (() -> String)? = nil

    // MARK: - AI 补全状态（任务 14.8）

    @StateObject private var aiSettings = AISettingsStore.shared
    @State private var aiSuggestion: String? = nil
    @State private var isLoadingAI: Bool = false
    @State private var aiDebounceTask: Task<Void, Never>? = nil

    // MARK: - 状态

    @State private var content: String = ""
    @State private var sendLineByLine: Bool = false
    @State private var lineDelay: Int = 50
    @State private var language: ComposeLanguage = .bash
    @State private var paneHeight: CGFloat = 120
    @State private var isDragging: Bool = false

    private let minHeight: CGFloat = 60
    private let maxHeight: CGFloat = 200

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽调整线
            resizeHandle

            // 代码编辑区
            codeEditorArea

            // AI 建议条（任务 14.8，仅 AI 启用时显示）
            if aiSettings.isEnabled {
                aiSuggestionBar
            }

            // 操作栏
            actionBar
        }
        .frame(height: paneHeight + (aiSettings.isEnabled && (aiSuggestion != nil || isLoadingAI) ? 32 : 0))
        .background(DesignTokens.Colors.terminalBackground)
        .onChange(of: content) { _ in
            scheduleAICompletion()
        }
    }

    // MARK: - 子视图

    private var resizeHandle: some View {
        ZStack {
            Rectangle()
                .fill(isDragging ? DesignTokens.Colors.accentPrimary.opacity(0.3) : DesignTokens.Colors.borderFaint)

            // 居中三点装饰
            HStack(spacing: DesignTokens.Spacing.nano) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(DesignTokens.Colors.borderSubtle)
                        .frame(width: 2, height: 2)
                }
            }
        }
        .frame(height: 4)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    let delta = -value.translation.height  // 向上拖 = 增大高度
                    let newHeight = (paneHeight + delta).clamped(to: minHeight...maxHeight)
                    paneHeight = newHeight
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .cursor(.resizeUpDown)
    }

    private var codeEditorArea: some View {
        HStack(spacing: 0) {
            // 行号列
            lineNumberColumn

            // 代码内容区
            TextEditor(text: $content)
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.terminalText)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.top, DesignTokens.Spacing.xs)
                .padding(.leading, 10)
                .padding(.trailing, DesignTokens.Spacing.xxs)
        }
        .background(DesignTokens.Colors.terminalBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignTokens.Colors.borderSubtle),
            alignment: .top
        )
        .frame(maxHeight: .infinity)
    }

    private var lineNumberColumn: some View {
        let lines = content.components(separatedBy: "\n")
        return ZStack(alignment: .topTrailing) {
            DesignTokens.Colors.surfaceOverlay
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(lines.indices), id: \.self) { i in
                    Text("\(i + 1)")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                        .frame(height: 20, alignment: .trailing)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.top, DesignTokens.Spacing.xs)
        }
        .frame(width: 28)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(DesignTokens.Colors.borderFaint),
            alignment: .trailing
        )
    }

    private var actionBar: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // 发送按钮
            Button(action: sendContent) {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "paperplane.fill")
                        .font(DesignTokens.Typography.captionMedium)
                    Text("发送")
                        .font(DesignTokens.Typography.captionLarge)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut(.return, modifiers: .control)

            Divider().frame(height: 16)

            // 逐行发送切换
            Toggle("逐行", isOn: $sendLineByLine)
                .toggleStyle(.button)
                .font(DesignTokens.Typography.captionLarge)
                .controlSize(.small)

            if sendLineByLine {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Text("延迟")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                    TextField("50", value: $lineDelay, format: .number)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.codeSmall)
                        .padding(DesignTokens.Spacing.xs)
                        .background(DesignTokens.Colors.surfaceInput)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
                        )
                        .frame(width: 44)
                    Text("ms")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                }
            }

            Spacer()

            // 语言选择
            Picker("", selection: $language) {
                ForEach(ComposeLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .frame(width: 80)
            .font(DesignTokens.Typography.codeSmall)
            .foregroundColor(DesignTokens.Colors.textSecondary)

            Divider().frame(height: 16)

            // 清空并关闭
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textDisabled)
            }
            .buttonStyle(.plain)
            .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(DesignTokens.Colors.surfaceToolbar)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignTokens.Colors.borderFaint),
            alignment: .top
        )
    }

    // MARK: - AI 建议条（任务 14.8）

    @ViewBuilder
    private var aiSuggestionBar: some View {
        if isLoadingAI {
            HStack(spacing: DesignTokens.Spacing.xs) {
                ProgressView().controlSize(.mini)
                Text("AI 补全中…")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(DesignTokens.Colors.accentPrimary.opacity(0.04))
            .overlay(Rectangle().frame(height: 1).foregroundColor(DesignTokens.Colors.borderFaint), alignment: .top)
        } else if let suggestion = aiSuggestion {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(DesignTokens.Typography.captionSmall)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)

                Text(suggestion)
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                // Tab 接受
                Button("Tab 接受") {
                    acceptSuggestion(suggestion)
                }
                .font(DesignTokens.Typography.captionMedium)
                .buttonStyle(.plain)
                .foregroundColor(DesignTokens.Colors.accentPrimary)
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .background(DesignTokens.Colors.accentPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXXSmall, style: .continuous))

                // 关闭
                Button {
                    aiSuggestion = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(DesignTokens.Colors.textDisabled)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(DesignTokens.Colors.accentPrimary.opacity(0.04))
            .overlay(Rectangle().frame(height: 1).foregroundColor(DesignTokens.Colors.borderFaint), alignment: .top)
        }
    }

    // MARK: - AI 补全逻辑

    /// 防抖调度：用户停止输入 600ms 后触发 AI 建议
    private func scheduleAICompletion() {
        aiDebounceTask?.cancel()
        aiSuggestion = nil
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, aiSettings.isEnabled else { return }

        aiDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // 600ms
            guard !Task.isCancelled else { return }
            await fetchAISuggestion(for: trimmed)
        }
    }

    @MainActor
    private func fetchAISuggestion(for input: String) async {
        guard aiSettings.isEnabled, !input.isEmpty else { return }
        isLoadingAI = true
        defer { isLoadingAI = false }

        let context = contextProvider?() ?? ""
        let contextSnippet = context.isEmpty ? "" : "\n\n最近终端输出（最后 50 行）：\n```\n\(context.suffix(2000))\n```"

        let systemPrompt = """
        你是一个 SSH 终端命令补全助手。根据用户当前输入和终端上下文，建议最可能的完整命令或下一步补全。
        规则：
        1. 只返回一行完整的 shell 命令，不加任何解释
        2. 若输入已完整，返回空字符串
        3. 不要返回 markdown，不要加代码块
        """
        let userMessage = "当前输入：\(input)\(contextSnippet)\n\n建议完整命令："

        let service = AIServiceFactory.make(for: aiSettings.provider)
        let model = aiSettings.currentModel.id
        let apiKey = aiSettings.loadAPIKey(for: aiSettings.provider)
        let baseURL = aiSettings.baseURL

        var result = ""
        do {
            let stream = service.stream(
                messages: [.user(userMessage)],
                systemPrompt: systemPrompt,
                model: model,
                apiKey: apiKey,
                baseURL: baseURL
            )
            for try await chunk in stream {
                result += chunk
                if Task.isCancelled { return }
            }
            let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty && cleaned != input {
                aiSuggestion = cleaned
            }
        } catch {
            // 静默失败：AI 建议是辅助功能，不影响主流程
        }
    }

    private func acceptSuggestion(_ suggestion: String) {
        content = suggestion
        aiSuggestion = nil
    }

    // MARK: - 操作

    private func sendContent() {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if sendLineByLine {
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            let delayMs = lineDelay
            Task { @MainActor in
                for (index, line) in lines.enumerated() {
                    if index > 0 { try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000) }
                    onSend(line + "\r")
                }
            }
        } else {
            onSend(content)
        }
    }
}

// MARK: - 语言类型

enum ComposeLanguage: String, CaseIterable {
    case bash, sh, python, ruby, zsh

    var displayName: String { rawValue }
}

// MARK: - 辅助扩展

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
