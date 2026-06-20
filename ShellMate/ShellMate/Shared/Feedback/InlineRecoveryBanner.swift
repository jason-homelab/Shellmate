import SwiftUI

// W1 新增：可恢复操作的 inline Banner
// 用于错误诊断场景：banner 上的按钮就是恢复入口（解 UE-P1#8）

struct InlineRecoveryBanner: View {

    let event: FeedbackEvent
    var onDismiss: () -> Void = {}

    init(event: FeedbackEvent, onDismiss: @escaping () -> Void = {}) {
        self.event = event
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左侧 indicator 条
            Rectangle()
                .fill(event.level.fg)
                .frame(width: 4)

            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: event.level.sfSymbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(event.level.fg)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    if let message = event.message {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !event.actions.isEmpty {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            ForEach(event.actions) { action in
                                actionButton(action)
                            }
                        }
                        .padding(.top, DesignTokens.Spacing.xxs)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    onDismiss()
                    FeedbackCenter.shared.dismiss(id: event.id)
                } label: {
                    AppIcon.close.image
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AccessibilityCatalog.Feedback.close)
            }
            .padding(.vertical, DesignTokens.Spacing.sm + 2)
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                .fill(event.level.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                        .strokeBorder(event.level.border, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
        .elevation(DesignTokens.Elevation.e2)
    }

    @ViewBuilder
    private func actionButton(_ action: FeedbackAction) -> some View {
        Button {
            FeedbackCenter.shared.performAction(action, dismissingEventId: event.id)
        } label: {
            Text(action.title)
                .font(.system(size: 12, weight: .medium))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(actionBg(action.style))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(actionBorder(action.style), lineWidth: 1)
                )
        )
        .foregroundColor(actionFg(action.style))
    }

    private func actionBg(_ style: FeedbackAction.Style) -> Color {
        switch style {
        case .primary:     return event.level.fg.opacity(0.12)
        case .destructive: return DesignTokens.Semantic.feedbackErrorFg.opacity(0.12)
        case .secondary, .dismiss: return Color.clear
        }
    }

    private func actionBorder(_ style: FeedbackAction.Style) -> Color {
        switch style {
        case .primary:     return event.level.fg.opacity(0.30)
        case .destructive: return DesignTokens.Semantic.feedbackErrorFg.opacity(0.30)
        case .secondary:   return DesignTokens.Colors.glassBorderSide
        case .dismiss:     return Color.clear
        }
    }

    private func actionFg(_ style: FeedbackAction.Style) -> Color {
        switch style {
        case .primary:     return event.level.fg
        case .destructive: return DesignTokens.Semantic.feedbackErrorFg
        case .secondary, .dismiss: return DesignTokens.Colors.textPrimary
        }
    }
}
