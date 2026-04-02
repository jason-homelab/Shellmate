import SwiftUI

/// 会话行视图（Figma-Spec-v2 §02 扁平风格）
/// 选中蓝色填充 + 悬停浅灰 + 精致状态点
struct SessionRowView: View {

    // MARK: - 属性

    let session: Session
    var isSelected: Bool = false
    var onDoubleClick: (() -> Void)?

    // MARK: - 状态

    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {

            // 服务器图标（含连接状态角标）
            serverIcon

            // 会话信息
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(session.name)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(
                        isSelected ? .white : DesignTokens.Colors.textPrimary
                    )
                    .lineLimit(1)

                Text("\(session.username)@\(session.host)")
                    .font(DesignTokens.Typography.codeSmall)
                    .foregroundColor(
                        isSelected
                            ? Color.white.opacity(0.75)
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
                // 选中：实心蓝色背景 + 下方阴影（对齐 Figma 设计）
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, 2)
                    .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 4, x: 0, y: 2)
            } else if isHovering {
                // 悬停：轻灰填充，无边框（Figma-Spec-v2 扁平风格）
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                    .fill(DesignTokens.Colors.glassHoverColor)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, 2)
            }
        }
        .contentShape(Rectangle())
        // 拖拽视觉反馈：拖动时降低透明度 + 轻微缩放，提示行正在被移动
        .opacity(isDragging ? 0.45 : 1.0)
        .scaleEffect(isDragging ? 0.97 : 1.0)
        .animation(DesignTokens.Animation.hover, value: isDragging)
        .onDrag {
            withAnimation(DesignTokens.Animation.hover) { isDragging = true }
            return NSItemProvider(object: session.id.uuidString as NSString)
        }
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.hover) {
                isHovering = hovering
                if !hovering { isDragging = false }   // 拖拽结束时恢复
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
            // 图标背景圆角框（选中时使用白色半透明背景）
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(isSelected
                    ? Color.white.opacity(0.20)
                    : DesignTokens.Colors.accentPrimary.opacity(0.10))
                .overlay {
                    if !isSelected {
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.18), lineWidth: 0.75)
                    }
                }
                .frame(width: DesignTokens.Sizes.sessionIconSize, height: DesignTokens.Sizes.sessionIconSize)

            // 服务器图标
            Image(systemName: "server.rack")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : DesignTokens.Colors.accentPrimary.opacity(0.75))
                .frame(width: DesignTokens.Sizes.sessionIconSize, height: DesignTokens.Sizes.sessionIconSize)

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
