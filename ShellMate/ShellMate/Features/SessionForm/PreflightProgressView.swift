import SwiftUI

// W4 新增：连接测试进度视图（解 UE-P0#2）
// 详见 docs/design-specs/W0_设计规格统一交付.md §8

struct PreflightProgressView: View {

    let result: PreflightResult?
    var isRunning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ForEach(PreflightStage.allCases) { stage in
                stageRow(stage)
            }

            if let failure = result?.firstFailure {
                FailureSuggestionsCard(error: failure.error)
                    .padding(.top, DesignTokens.Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.glassLight)
        )
        .animation(DesignTokens.Animation.spring, value: result?.summary)
    }

    // MARK: - 阶段行

    @ViewBuilder
    private func stageRow(_ stage: PreflightStage) -> some View {
        let status = result?.stages[stage] ?? (isRunning ? .pending : .pending)
        HStack(spacing: DesignTokens.Spacing.xs) {
            stageIcon(status)
                .frame(width: 18, height: 18)

            Text(stage.title)
                .font(.system(size: 12))
                .foregroundColor(stageTextColor(status))

            Spacer(minLength: 0)

            stageTrailing(status)
        }
        .frame(height: 22)
    }

    @ViewBuilder
    private func stageIcon(_ status: PreflightStageStatus) -> some View {
        switch status {
        case .pending:
            AppIcon.statusDisconnected
                .image
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(DesignTokens.Colors.textTertiary)
        case .inProgress:
            ProgressView()
                .controlSize(.small)
        case .success:
            AppIcon.feedbackSuccess
                .image
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(DesignTokens.Colors.statusConnected)
                .transition(.scale.combined(with: .opacity))
        case .failed:
            AppIcon.feedbackError
                .image
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(DesignTokens.Semantic.feedbackErrorFg)
        case .skipped:
            AppIcon.dismiss
                .image
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(DesignTokens.Colors.textDisabled)
        }
    }

    private func stageTextColor(_ status: PreflightStageStatus) -> Color {
        switch status {
        case .pending, .skipped: return DesignTokens.Colors.textTertiary
        case .inProgress:        return DesignTokens.Colors.textPrimary
        case .success:           return DesignTokens.Colors.textPrimary
        case .failed:            return DesignTokens.Semantic.feedbackErrorFg
        }
    }

    @ViewBuilder
    private func stageTrailing(_ status: PreflightStageStatus) -> some View {
        switch status {
        case .success(let ms):
            Text("\(ms)ms")
                .font(DesignTokens.Typography.Mono.dataXS)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        case .skipped:
            Text("已跳过")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.textDisabled)
        default:
            EmptyView()
        }
    }
}

// MARK: - 失败建议卡片

private struct FailureSuggestionsCard: View {

    let error: PreflightError

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("可能原因：")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignTokens.Semantic.feedbackErrorFg)

            ForEach(Array(error.suggestions.enumerated()), id: \.offset) { _, suggestion in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Text(suggestion)
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.Semantic.feedbackErrorBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(DesignTokens.Semantic.feedbackErrorBorder, lineWidth: 1)
                )
        )
    }
}
