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
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: event.level.sfSymbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(event.level.fg)

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
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AccessibilityCatalog.Feedback.close)
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

    private var localizedTitle: String {
        // SwiftUI LocalizedStringKey → 当前 locale string 的简化映射
        // 业务侧 a11y 朗读由系统 Text 提供，此处仅作 modifier 占位
        ""
    }
}
