import SwiftUI

// W1 新增：Toast 渲染宿主
// 在主窗口 ZStack 顶层注入一次即可，订阅 FeedbackCenter.activeToasts

struct ToastHost: View {

    @ObservedObject private var center = FeedbackCenter.shared

    init() {}

    var body: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
            ForEach(center.activeToasts) { event in
                ToastCard(event: event)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, DesignTokens.Spacing.sm)
        .padding(.trailing, DesignTokens.Spacing.md)
        .allowsHitTesting(!center.activeToasts.isEmpty)
        .animation(DesignTokens.Animation.spring, value: center.activeToasts.map(\.id))
    }
}

private struct ToastCard: View {

    let event: FeedbackEvent

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                // P1#8 修正：按 level 渲染 icon（不能固定 feedbackInfo）
                Image(systemName: event.level.sfSymbol)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(event.level.fg)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    if let message = event.message {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.xs)

                Button {
                    FeedbackCenter.shared.dismiss(id: event.id)
                } label: {
                    AppIcon.close.image
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AccessibilityCatalog.Feedback.close)
            }

            // 自评 P1#8：渲染 actions（原 ToastCard 静默丢弃 actions）
            // 紧凑布局，仅渲染 .primary 与 .destructive 作为 Toast 友好的少操作
            if !event.actions.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Spacer(minLength: 0)
                    ForEach(event.actions) { action in
                        toastActionButton(action)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(minWidth: 240, maxWidth: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(event.level.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(event.level.border, lineWidth: 1)
                )
        )
        .elevation(DesignTokens.Elevation.e3)
        .a11yFeedback(level: event.level, title: localizedTitle)
    }

    @ViewBuilder
    private func toastActionButton(_ action: FeedbackAction) -> some View {
        Button {
            FeedbackCenter.shared.performAction(action, dismissingEventId: event.id)
        } label: {
            Text(action.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(actionColor(action.style))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(actionColor(action.style).opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private func actionColor(_ style: FeedbackAction.Style) -> Color {
        switch style {
        case .primary:     return event.level.fg
        case .destructive: return DesignTokens.Semantic.feedbackErrorFg
        case .secondary, .dismiss: return DesignTokens.Colors.textSecondary
        }
    }

    private var localizedTitle: String { "" }
}
