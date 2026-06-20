import SwiftUI

// MARK: - AI-06 安全审计弹窗（§21.2）

/// 在用户通过 Compose Pane / AI 插入 高风险命令时弹出。
/// 提供风险说明、AI 流式分析，以及"取消"/"继续执行"两个操作。
struct CommandSafetyAlertView: View {

    let risk: CommandRisk
    /// 用户确认继续执行时回调
    var onConfirm: () -> Void
    /// 用户取消时回调
    var onCancel: () -> Void

    @EnvironmentObject private var aiSettings: AISettingsStore

    @State private var aiAnalysis: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var analyzeError: String? = nil
    @State private var analysisTask: Task<Void, Never>? = nil
    @State private var showConfirmPrompt: Bool = false

    // MARK: - 颜色

    private var riskColor: Color { risk.level.color }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
            if !aiAnalysis.isEmpty || isAnalyzing || analyzeError != nil {
                Divider()
                aiAnalysisView
            }
            Divider()
            footerView
        }
        .frame(width: 460)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusLarge, style: .continuous)
                .strokeBorder(riskColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 28, x: 0, y: 10)
        .onDisappear { analysisTask?.cancel() }
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(riskColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: risk.level.icon)
                    .font(DesignTokens.Typography.displayXSmall)
                    .foregroundColor(riskColor)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.nano) {
                Text(risk.level.title)
                    .font(DesignTokens.Typography.labelLargeAlt)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("匹配规则：\(risk.matchedPattern)")
                    .font(DesignTokens.Typography.captionLarge)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, 14)
    }

    // MARK: - 内容

    private var contentView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 命令原文
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text("即将执行的命令")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Text(risk.command)
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(riskColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.sm)
                    .background(riskColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .textSelection(.enabled)
            }

            // 风险说明
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                AppIcon.feedbackInfo.image
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(riskColor)
                Text(risk.reason)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - AI 分析区

    private var aiAnalysisView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                AppIcon.ai.image
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                Text("AI 风险说明")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Spacer()
                if isAnalyzing {
                    ProgressView().scaleEffect(0.6)
                }
            }

            if let err = analyzeError {
                Text(err)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(aiAnalysis)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: 140)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.accentPrimary.opacity(0.04))
    }

    // MARK: - 底部

    private var footerView: some View {
        HStack {
            // AI 分析按钮（仅 AI 启用时显示）
            if aiSettings.isEnabled && aiAnalysis.isEmpty && !isAnalyzing {
                Button {
                    startAIAnalysis()
                } label: {
                    Label("AI 分析风险", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("取消", action: onCancel)
                .buttonStyle(.bordered)

            // 继续执行：高危命令需要二次确认
            if risk.level == .danger && !showConfirmPrompt {
                Button {
                    showConfirmPrompt = true
                } label: {
                    Text("继续执行…")
                        .foregroundColor(riskColor)
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: onConfirm) {
                    Label(risk.level == .danger ? "确认，我知道风险" : "继续执行",
                          systemImage: "checkmark")
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(riskColor)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - AI 分析

    private func startAIAnalysis() {
        analysisTask?.cancel()
        isAnalyzing = true
        analyzeError = nil
        aiAnalysis = ""

        let systemPrompt = """
        你是一名 Linux 安全专家。用户即将执行一条被标记为高风险的命令。
        请用中文简洁地分析：
        ① 该命令的实际危害（最坏情况）
        ② 是否有更安全的替代方案
        ③ 如果确实需要执行，应该注意什么

        直接输出分析，不超过 150 字。不要重复命令本身。
        """
        let userMsg = AIMessage.user("命令：`\(risk.command)`\n已识别风险：\(risk.reason)")

        analysisTask = Task { @MainActor in
            do {
                let service = try aiSettings.makeService()
                let stream = service.stream(
                    messages: [userMsg],
                    systemPrompt: systemPrompt,
                    model: aiSettings.currentModel.id,
                    apiKey: aiSettings.apiKey,
                    baseURL: aiSettings.baseURL
                )
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    aiAnalysis += chunk
                }
                isAnalyzing = false
            } catch let err as AIServiceError {
                isAnalyzing = false
                analyzeError = err.errorDescription ?? "分析失败"
            } catch {
                isAnalyzing = false
                if !Task.isCancelled { analyzeError = error.localizedDescription }
            }
        }
    }
}

// MARK: - 预览

#Preview("高危命令 - rm -rf") {
    CommandSafetyAlertView(
        risk: CommandRisk(
            command: "rm -rf /var/log/*",
            level: .danger,
            matchedPattern: "rm -rf",
            reason: "将递归强制删除目录及其所有内容，操作不可恢复"
        ),
        onConfirm: {},
        onCancel: {}
    )
    .padding()
}

#Preview("警告命令 - chmod 777") {
    CommandSafetyAlertView(
        risk: CommandRisk(
            command: "chmod -R 777 /var/www",
            level: .warning,
            matchedPattern: "chmod 777 / 递归赋权",
            reason: "将文件或目录设置为任意用户可读写执行，可能造成安全漏洞"
        ),
        onConfirm: {},
        onCancel: {}
    )
    .padding()
}
