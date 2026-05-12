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
    @ObservedObject private var syncStore = SyncInputStore.shared

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 8) {                       // Figma: gap-2 = 8pt

            // ── 连接状态点（保留为 SSH 客户端功能性指示，Figma 通用 mock 未含）──
            tabDot

            // ── 标题 ──
            // Figma: text-xs font-medium (12pt medium，非等宽)
            Text(tab.title)
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(isSelected
                    ? DesignTokens.Colors.textPrimary
                    : (isHovering ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary))
                .lineLimit(1)
                .truncationMode(.tail)

            // 同步输入激活时显示 ⚡
            if syncStore.isSynced(tab.sessionId) {
                Image(systemName: "bolt.fill")
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(.orange)
            }

            Spacer(minLength: 0)

            // ── 关闭按钮：Figma opacity-0 group-hover:opacity-100
            closeButton
                .opacity(isHovering || isSelected ? 1 : 0)
        }
        // Figma 9:5：px-leading 14px，tab h-[32px]，maxW 140px
        .padding(.leading, 14)
        .padding(.trailing, DesignTokens.Spacing.sm)
        .frame(height: 32)
        .frame(minWidth: DesignTokens.Sizes.tabMinWidth, maxWidth: 140)
        .background(tabBackground)
        .overlay(tabBorderRight)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        // Figma 9:6：激活标签底部 2px × 60px 蓝色指示线（居中）
        // 注：必须在 clipShape 之后叠加，否则底部圆角会将指示线裁断
        .overlay(alignment: .bottom) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary)
                    .frame(width: 60, height: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
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
            // Figma 9:5：bg=rgba(255,255,255,0.92)，rounded-8px，shadow-sm
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        } else if isHovering {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.glassUltraLight)
        } else {
            Color.clear
        }
    }

    // MARK: - 右侧边框

    /// Figma: border-r border-[#d2d2d7]/50（右侧 1pt 分隔线）
    private var tabBorderRight: some View {
        HStack(spacing: 0) {
            Spacer()
            Rectangle()
                .fill(Color(hex: "#d2d2d7").opacity(0.50))
                .frame(width: 1)
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
