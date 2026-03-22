import SwiftUI

/// 会话行视图（Liquid Glass 设计）
/// 玻璃拟态悬停 + 选中光晕 + 精致状态点
struct SessionRowView: View {

    // MARK: - 属性

    let session: Session
    var isSelected: Bool = false
    var onDoubleClick: (() -> Void)?

    // MARK: - 状态

    @State private var isHovering: Bool = false

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {

            // 发光状态点
            glowingDot

            // 会话信息
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(
                        isSelected
                            ? DesignTokens.Colors.textPrimary
                            : (isHovering ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textPrimary)
                    )
                    .lineLimit(1)

                Text("\(session.username)@\(session.host)")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(
                        isSelected
                            ? DesignTokens.Colors.accentSecondary.opacity(0.80)
                            : DesignTokens.Colors.textTertiary
                    )
                    .lineLimit(1)
            }

            Spacer()

            // 标签徽章
            if !session.tags.isEmpty {
                TagListView(tags: session.tags, maxDisplayCount: 1)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(height: DesignTokens.Sizes.sessionRowHeight)
        .background {
            if isSelected {
                // 选中：蓝色玻璃光晕
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .fill(DesignTokens.Colors.glassSelected)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(
                                DesignTokens.Gradients.glassAccentBorder,
                                lineWidth: 0.75
                            )
                    }
            } else if isHovering {
                // 悬停：轻玻璃
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .fill(DesignTokens.Colors.glassHoverColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.glassBorderSide, lineWidth: 0.5)
                    }
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.hover) {
                isHovering = hovering
            }
        }
        .onTapGesture(count: 2) {
            onDoubleClick?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.name)，\(session.username)@\(session.host)")
        .accessibilityHint(isSelected ? "已选中，双击连接" : "双击连接此会话")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityValue(session.connectionState.displayName)
    }

    // MARK: - 发光状态点

    @ViewBuilder
    private var glowingDot: some View {
        let dotColor = dotColorForState(session.connectionState)
        GlowingStatusDot(
            color: dotColor,
            size: DesignTokens.Sizes.statusDotSize
        )
    }

    private func dotColorForState(_ state: ConnectionState) -> Color {
        switch state {
        case .connected:              return DesignTokens.Colors.statusConnected
        case .connecting, .disconnecting: return DesignTokens.Colors.statusConnecting
        case .error:                  return DesignTokens.Colors.statusError
        default:                      return DesignTokens.Colors.statusOffline
        }
    }
}

// MARK: - 预览

#Preview("会话行状态") {
    VStack(spacing: 2) {
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .connected; return s
        }())
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .connected; return s
        }(), isSelected: true)
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .connecting; return s
        }())
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .error; return s
        }())
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .offline; return s
        }())
    }
    .padding(8)
    .background(DesignTokens.Colors.surfaceWindow)
    .frame(width: 224)
}
