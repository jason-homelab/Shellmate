import SwiftUI

/// 会话行视图 — 1:1 对齐 Figma Desktop 节点 8:2
/// 行高 44pt，状态点 6×6（left=14），空图标容器 26×26（left=29），文字起始 left=64
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
        HStack(spacing: 0) {

            // ── 1. 状态点（Figma 8:16/8:21：6×6 px，left=14，top=19 → 垂直居中于 44pt 行）
            Circle()
                .fill(isConnected
                    ? DesignTokens.Colors.statusConnected
                    : DesignTokens.Colors.textDisabled)
                .frame(width: DesignTokens.Sizes.statusDotSize, height: DesignTokens.Sizes.statusDotSize)
                .padding(.leading, 14)
                .padding(.trailing, 9)

            // ── 2. 空图标容器（Figma 8:17/8:22：26×26，rounded-6pt，无图标 SVG）
            // Direction C：已连接=淡蓝底（accentPrimary/10），离线=灰底（black/6），选中=白色透明
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                .fill(isSelected
                    ? Color.white.opacity(0.20)
                    : (isConnected
                       ? DesignTokens.Colors.accentPrimary.opacity(0.10)
                       : Color.black.opacity(0.06)))
                .frame(width: 26, height: 26)
                .padding(.trailing, 9)

            // ── 3. 会话信息（Figma：text left=64，name top=7，host top=25）
            sessionInfo

            Spacer(minLength: 0)
        }
        // Figma 8:15/8:20：h=44px，w=248px（行左边距 4px 由 SessionListView 控制）
        .frame(height: DesignTokens.Sizes.sessionRowHeight)
        .padding(.trailing, DesignTokens.Spacing.md)
        .background(rowBackground)
        // Direction C：已连接（非选中）左侧 2px 蓝色指示条，让连接中的会话在列表里视觉浮出
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
            // Figma 8:15：bg-[#077aff] rounded-[8px]（无 shadow）
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.accentPrimary)
        } else if isHovering {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.surfaceHover)
        } else {
            Color.clear
        }
    }

    // MARK: - 会话信息

    private var sessionInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Figma 8:18/8:23：13px，Direction C：已连接 semibold 加重，离线 medium 退后
            Text(session.name)
                .font(isConnected
                    ? DesignTokens.Typography.bodyMediumStrong  // 13px semibold（已连接）
                    : DesignTokens.Typography.labelLarge)       // 13px medium（离线）
                .foregroundColor(isSelected
                    ? Color.white
                    : (isConnected
                       ? DesignTokens.Colors.textPrimary
                       : DesignTokens.Colors.textSecondary))
                .lineLimit(1)
                .truncationMode(.tail)

            // Figma 8:19/8:24：11px regular，rgba(255,255,255,0.7) / #8e8e93
            Text("\(session.username)@\(session.host)")
                .font(DesignTokens.Typography.captionLarge)
                .foregroundColor(isSelected
                    ? Color.white.opacity(0.70)
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
