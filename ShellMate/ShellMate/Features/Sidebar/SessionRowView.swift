import SwiftUI

/// 会话行视图 — 亮色 macOS 风格
/// 激活状态：全宽 Apple Blue 胶囊背景 + 白色文字（对齐 Figma Make bg-[#007aff]）
/// 图标：server.rack SF Symbol
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

            // ── 1. 服务器图标容器
            sessionAvatar

            // ── 2. 会话信息
            sessionInfo

            Spacer(minLength: 0)
        }
        // Figma: px-3 py-2 = 12pt horizontal, 8pt vertical
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(rowBackground)
        // 已连接（非选中）：左侧 2px 蓝色指示条，让连接中的会话在列表里视觉浮出
        .overlay(alignment: .leading) {
            if isConnected && !isSelected {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary)
                    .frame(width: 2, height: 22)
            }
        }
        .contentShape(Rectangle())
        .opacity(isDragging ? 0.45 : 1.0)
        .scaleEffect(isDragging ? 0.97 : 1.0)
        .animation(DesignTokens.Animation.hover, value: isDragging)
        .animation(DesignTokens.Animation.hover, value: isHovering)
        .animation(DesignTokens.Animation.hover, value: isSelected)
        .onDrag {
            withAnimation(DesignTokens.Animation.hover) { isDragging = true }
            return NSItemProvider(object: session.id.uuidString as NSString)
        }
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.hover) {
                isHovering = hovering
                if !hovering { isDragging = false }
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

    // MARK: - 背景

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            // Figma: bg-[#007aff] shadow-md shadow-[#007aff]/30
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.accentPrimary)
                .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.30), radius: 6, x: 0, y: 4)
        } else if isHovering {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.surfaceHover)
        } else {
            Color.clear
        }
    }

    // MARK: - 服务器图标容器

    private var sessionAvatar: some View {
        ZStack {
            // 已连接：蓝色容器（突出）；离线：灰色容器（退后）；选中：白色透明
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                .fill(isSelected
                    ? Color.white.opacity(0.20)
                    : (isConnected
                       ? DesignTokens.Colors.accentPrimary.opacity(0.10)
                       : Color.black.opacity(0.06)))

            Image(systemName: "server.rack")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(isSelected
                    ? Color.white
                    : (isConnected
                       ? DesignTokens.Colors.accentPrimary
                       : DesignTokens.Colors.textSecondary))
        }
        .frame(width: 26, height: 26)
    }

    // MARK: - 会话信息

    private var sessionInfo: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
            // 已连接：semibold 加重，颜色饱和；离线：medium 常规，颜色退后
            Text(session.name)
                .font(isConnected
                    ? DesignTokens.Typography.bodyMediumStrong   // 13px semibold
                    : DesignTokens.Typography.bodyLargeMedium)   // 14px medium
                .foregroundColor(isSelected
                    ? Color.white
                    : (isConnected
                       ? DesignTokens.Colors.textPrimary
                       : DesignTokens.Colors.textSecondary))
                .lineLimit(1)
                .truncationMode(.tail)

            Text("\(session.username)@\(session.host)")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(isSelected
                    ? Color.white.opacity(0.80)
                    : DesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - 辅助

    private var isConnected: Bool {
        session.connectionState == .connected
    }

}


// MARK: - 预览

#Preview("会话行状态") {
    VStack(spacing: DesignTokens.Spacing.px) {
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .connected; return s
        }(), isSelected: true)
        SessionRowView(session: {
            var s = Session.preview; s.connectionState = .connected; return s
        }())
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
    .padding(.horizontal, DesignTokens.Spacing.xs)
    .padding(.vertical, DesignTokens.Spacing.xs)
    .background(DesignTokens.Colors.surfacePanel)
    .frame(width: 240)
}
