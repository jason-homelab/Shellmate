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

            // 服务器图标（含连接状态角标）
            serverIcon

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
                // 选中：蓝色玻璃光晕（内缩居中 + 较大圆角）
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                    .fill(DesignTokens.Colors.glassSelected)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                            .strokeBorder(
                                DesignTokens.Gradients.glassAccentBorder,
                                lineWidth: 0.75
                            )
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, 2)
                    .shadow(color: DesignTokens.Colors.accentGlow, radius: 8, x: 0, y: 0)
            } else if isHovering {
                // 悬停：轻玻璃（同样内缩居中）
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                    .fill(DesignTokens.Colors.glassHoverColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.glassBorderSide, lineWidth: 0.5)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, 2)
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

    // MARK: - 服务器图标

    private var serverIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            // 图标背景圆角框
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DesignTokens.Colors.accentPrimary.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.18), lineWidth: 0.75)
                }
                .frame(width: 32, height: 32)

            // 服务器图标
            Image(systemName: "server.rack")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignTokens.Colors.accentPrimary.opacity(0.75))
                .frame(width: 32, height: 32)

            // 连接状态角标（仅非离线时显示）
            if session.connectionState != .offline {
                Circle()
                    .fill(dotColorForState(session.connectionState))
                    .frame(width: 7, height: 7)
                    .overlay {
                        Circle().strokeBorder(DesignTokens.Colors.surfaceWindow, lineWidth: 1.5)
                    }
                    .offset(x: 2, y: 2)
            }
        }
    }

    private func dotColorForState(_ state: ConnectionState) -> Color {
        switch state {
        case .connected:                  return DesignTokens.Colors.statusConnected
        case .connecting, .disconnecting: return DesignTokens.Colors.statusConnecting
        case .error:                      return DesignTokens.Colors.statusError
        default:                          return DesignTokens.Colors.statusOffline
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
