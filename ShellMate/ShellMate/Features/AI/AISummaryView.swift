import SwiftUI

// MARK: - AI-05 会话摘要面板（§20.3/20.4）

/// 对当前终端会话最近输出进行 AI 摘要，使用流式响应展示结果。
/// 入口：工具栏「摘要」按钮（⌘⇧S），由 TerminalView 传入最近 200 行输出。
struct AISummaryView: View {

    let sessionName: String
    let terminalOutput: String
    var onClose: () -> Void

    @ObservedObject private var aiSettings = AISettingsStore.shared

    @State private var summaryText: String = ""
    @State private var isStreaming: Bool = false
    @State private var errorMessage: String? = nil
    @State private var streamTask: Task<Void, Never>? = nil
    @State private var isCopied: Bool = false

    // MARK: - 摘要 System Prompt

    private var systemPrompt: String {
        """
        你是一名 Linux 专家助手，擅长分析终端会话。
        用户会提供终端会话的最近输出内容，请用**中文**生成一份简洁的操作摘要，包含：
        ① 执行了哪些主要命令
        ② 命令的执行结果（成功 / 失败 / 警告）
        ③ 当前工作状态（如正在运行的服务、当前目录等）

        要求：
        - 输出使用 Markdown 格式（加粗关键词、使用列表）
        - 若终端输出内容不含有意义的操作，直接说明"暂无可摘要的操作记录"
        - 不要重复用户问题，直接输出摘要内容
        """
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
            Divider()
            footerView
        }
        .frame(width: 480)
        .background(DesignTokens.Colors.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.50), radius: 24, x: 0, y: 8)
        .onAppear { startSummary() }
        .onDisappear { streamTask?.cancel() }
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.accentPrimary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(DesignTokens.Typography.displayXSmall)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.nano) {
                Text("会话摘要")
                    .font(DesignTokens.Typography.labelLargeAlt)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(sessionName)
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isStreaming {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, DesignTokens.Spacing.xxs)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 14)
    }

    // MARK: - 内容

    private var contentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Group {
                if let err = errorMessage {
                    // 错误状态
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(DesignTokens.Typography.displayLarge)
                            .foregroundColor(DesignTokens.Colors.statusConnecting)
                        Text(err)
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.xl)
                } else if summaryText.isEmpty && isStreaming {
                    // 等待第一个 token
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在生成摘要…")
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.xl)
                } else if summaryText.isEmpty {
                    Text("暂无内容")
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.xl)
                } else {
                    // 摘要正文（纯文本，保留 Markdown 符号便于阅读）
                    Text(summaryText)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(maxHeight: 360)
    }

    // MARK: - 底部

    private var footerView: some View {
        HStack {
            // 重新生成
            Button {
                summaryText = ""
                errorMessage = nil
                startSummary()
            } label: {
                Label("重新生成", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isStreaming)

            Spacer()

            // 复制摘要
            if !summaryText.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(summaryText, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
                } label: {
                    Label(isCopied ? "已复制" : "复制摘要", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            Button("关闭", action: onClose)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - 摘要生成

    private func startSummary() {
        streamTask?.cancel()

        // 21.4 离线预检
        if !NetworkMonitor.shared.isConnected {
            errorMessage = "网络不可用，请检查网络连接后重试"
            isStreaming = false
            return
        }

        isStreaming = true
        errorMessage = nil

        let output = terminalOutput.isEmpty
            ? "（终端暂无输出记录）"
            : terminalOutput

        let userMessage = AIMessage.user("以下是终端会话的最近输出，请生成操作摘要：\n\n```\n\(output)\n```")

        streamTask = Task { @MainActor in
            do {
                let service = try aiSettings.makeService()
                let stream = service.stream(
                    messages: [userMessage],
                    systemPrompt: systemPrompt,
                    model: aiSettings.currentModel.id,
                    apiKey: aiSettings.apiKey,
                    baseURL: aiSettings.baseURL
                )
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    summaryText += chunk
                }
                isStreaming = false
            } catch let err as AIServiceError {
                isStreaming = false
                errorMessage = err.errorDescription ?? "请求失败"
            } catch {
                isStreaming = false
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - 预览

#Preview("AI 会话摘要") {
    AISummaryView(
        sessionName: "开发服务器 · ubuntu@192.168.1.100",
        terminalOutput: "$ ls -la\ntotal 32\n$ git status\nOn branch main\nnothing to commit\n$ docker ps\nCONTAINER ID   IMAGE   STATUS",
        onClose: {}
    )
    .padding()
}
