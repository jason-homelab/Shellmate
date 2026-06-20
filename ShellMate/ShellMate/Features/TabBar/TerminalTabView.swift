import SwiftUI

/// 终端标签视图 — 1:1 对齐 main-window.html .tab
/// 结构：tab-dot → 标题 → close 按钮
/// 激活态：primary-dim bg + bottom 2px Apple Blue line + glow
struct TerminalTabView: View {

    // MARK: - 属性

    let tab: TerminalTab
    let isSelected: Bool
    let onClose: () -> Void
    let onSelect: () -> Void

    // MARK: - 私有状态

    @State private var isHovering: Bool = false
    @EnvironmentObject private var syncStore: SyncInputStore

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 8) {                       // Figma: gap-2 = 8pt

            // ── 连接状态点（保留为 SSH 客户端功能性指示，Figma 通用 mock 未含）──
            tabDot

            // ── 标题 ──
            // Figma: text-xs font-medium (12pt medium，非等宽)
            // Figma 9:8：选中 text-[#1d1d1f]，非选中/悬停 text-[#8e8e93] = textSubtle
            Text(tab.title)
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(isSelected
                    ? DesignTokens.Colors.textPrimary
                    : (isHovering ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textSubtle))
                .lineLimit(1)
                .truncationMode(.tail)

            // 同步输入激活时显示 ⚡
            if syncStore.isSynced(tab.sessionId) {
                AppIcon.quickCommand.image
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(.orange)
            }

            Spacer(minLength: 0)

            // 关闭按钮：仅 hover 时淡入（平滑过渡）
            closeButton
                .opacity(isHovering ? 1 : 0)
                .animation(DesignTokens.Animation.fast, value: isHovering)
        }
        // Figma 9:5：px-leading 14px，tab h-[32px]，maxW 140px
        .padding(.leading, 14)
        .padding(.trailing, DesignTokens.Spacing.sm)
        .frame(height: 32)
        .frame(minWidth: DesignTokens.Sizes.tabMinWidth, maxWidth: 140)
        .background(tabBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        // Figma 9:6: 底部蓝色指示线，纯色 #077aff，60×2，selected 时淡入缩放
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(DesignTokens.Colors.accentPrimary)
                .frame(width: 60, height: 2)
                .opacity(isSelected ? 1 : 0)
                .scaleEffect(x: isSelected ? 1 : 0.3, anchor: .center)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
        .animation(DesignTokens.Animation.medium, value: tab.connectionState)
        .help(tab.title)
        .accessibilityLabel(tab.title)
        .accessibilityHint(isSelected ? "当前标签页" : "切换到此标签页")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction { onSelect() }
        .contextMenu { tabContextMenu }
    }

    // MARK: - 连接状态点

    @ViewBuilder
    private var tabDot: some View {
        if tab.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.45)
                .frame(width: DesignTokens.Sizes.statusDotSize, height: DesignTokens.Sizes.statusDotSize)
        } else {
            let dotColor = tab.connectionState.dotColor
            let isIdle = (tab.connectionState == .offline || tab.connectionState == .disconnecting)
            Circle()
                // HTML: .tab-dot { background: var(--success) }
                // HTML: .tab-dot.idle { background: rgba(255,255,255,0.15) }
                .fill(isIdle ? DesignTokens.Colors.textDisabled : dotColor)
                // HTML: box-shadow: 0 0 5px rgba(52,211,153,0.6)（idle 无 glow）
                .shadow(color: isIdle ? .clear : dotColor.opacity(0.60), radius: 3, x: 0, y: 0)
                .frame(width: DesignTokens.Sizes.statusDotSize, height: DesignTokens.Sizes.statusDotSize)
        }
    }

    // MARK: - 关闭按钮

    @State private var isCloseHovering = false

    /// Figma: ml-2 h-5 w-5 rounded-md hover:bg-black/10 + X icon h-3 w-3 (12pt)
    private var closeButton: some View {
        Button(action: onClose) {
            Label("关闭标签页", systemImage: "xmark")
                .labelStyle(.iconOnly)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                        .fill(isCloseHovering ? DesignTokens.Colors.glassPressStrong : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isCloseHovering = $0 }
        .help("关闭标签页")
    }

    // MARK: - 背景

    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            // Figma 9:5: bg-[rgba(255,255,255,0.92)] = surfaceActive，纯色无渐变无描边
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.surfaceActive)
        } else if isHovering {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.glassUltraLight)
        } else {
            Color.clear
        }
    }

    // MARK: - 右键菜单

    @ViewBuilder
    private var tabContextMenu: some View {
        Button("关闭标签页") { onClose() }
        Divider()
        Button("关闭其他标签页") {}
        Button("关闭右侧标签页") {}
        Button("关闭左侧标签页") {}
        Divider()
        Button("复制终端会话") {}
    }
}

// MARK: - 预览

#Preview("终端标签 - 选中") {
    HStack(spacing: 0) {
        TerminalTabView(
            tab: TerminalTab(sessionId: UUID(), title: "Production Server", connectionState: .connected),
            isSelected: true,
            onClose: {},
            onSelect: {}
        )
        TerminalTabView(
            tab: TerminalTab(sessionId: UUID(), title: "Dev Server", connectionState: .offline),
            isSelected: false,
            onClose: {},
            onSelect: {}
        )
        TerminalTabView(
            tab: TerminalTab(sessionId: UUID(), title: "Staging", connectionState: .offline),
            isSelected: false,
            onClose: {},
            onSelect: {}
        )
    }
    .frame(height: DesignTokens.Sizes.tabBarHeight)
    .background(DesignTokens.Colors.surfaceCard)
}
