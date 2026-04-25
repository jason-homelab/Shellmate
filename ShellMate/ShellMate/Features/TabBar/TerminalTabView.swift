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
        HStack(spacing: 7) {                       // HTML: gap:7px

            // ── 连接状态点（6×6）── main-window.html .tab-dot
            tabDot

            // ── 标题 ──
            Text(tab.title)
                // HTML: .tab { font-size:11.5px; }
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                // HTML: .tab { color: var(--text-3) = rgba(226,228,240,0.30) }
                // HTML: .tab:hover { color: var(--text-2) = rgba(226,228,240,0.52) }
                // HTML: .tab.active { color: rgba(226,228,240,0.90) }
                .foregroundColor(isSelected
                    ? DesignTokens.Colors.textPrimary
                    : (isHovering ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textTertiary))
                .lineLimit(1)
                .truncationMode(.tail)

            // 同步输入激活时显示 ⚡
            if syncStore.isSynced(tab.sessionId) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
            }

            Spacer(minLength: 0)

            // ── 关闭按钮 ── .tab-close
            closeButton
                .opacity(isHovering || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 14)                  // HTML: padding: 0 14px
        .frame(height: DesignTokens.Sizes.tabBarHeight)
        .frame(minWidth: DesignTokens.Sizes.tabMinWidth, maxWidth: DesignTokens.Sizes.tabMaxWidth)
        .background(tabBackground)
        .overlay(alignment: .bottom) { activeBottomLine }
        .overlay(tabBorderRight)
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
                .frame(width: 6, height: 6)
        } else {
            let dotColor = tab.connectionState.dotColor
            let isIdle = (tab.connectionState == .offline || tab.connectionState == .disconnecting)
            Circle()
                // HTML: .tab-dot { background: var(--success) }
                // HTML: .tab-dot.idle { background: rgba(255,255,255,0.15) }
                .fill(isIdle ? DesignTokens.Colors.textDisabled : dotColor)
                // HTML: box-shadow: 0 0 5px rgba(52,211,153,0.6)（idle 无 glow）
                .shadow(color: isIdle ? .clear : dotColor.opacity(0.60), radius: 3, x: 0, y: 0)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - 关闭按钮

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .medium))
                // HTML: .tab-close { color: rgba(226,228,240,0.30) }
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: 16, height: 16)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isHovering ? DesignTokens.Colors.surfaceHover : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help("关闭标签页")
    }

    // MARK: - 背景

    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            // HTML: .tab.active { background: linear-gradient(180deg, rgba(0,122,255,0.055) 0%, rgba(0,122,255,0.025) 60%, transparent 100%) }
            LinearGradient(
                stops: [
                    .init(color: DesignTokens.Colors.accentPrimary.opacity(0.055), location: 0),
                    .init(color: DesignTokens.Colors.accentPrimary.opacity(0.025), location: 0.60),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isHovering {
            DesignTokens.Colors.glassUltraLight
        } else {
            Color.clear
        }
    }

    // MARK: - 底部激活线

    @ViewBuilder
    private var activeBottomLine: some View {
        if isSelected {
            // HTML: linear-gradient(90deg, transparent, primary, transparent) + 双层光晕
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: DesignTokens.Colors.accentPrimary, location: 0.25),
                    .init(color: DesignTokens.Colors.accentPrimary, location: 0.75),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 2)
            .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.60), radius: 6, x: 0, y: 0)
            .shadow(color: DesignTokens.Colors.accentPrimary.opacity(0.28), radius: 14, x: 0, y: 0)
        }
    }

    // MARK: - 右侧边框

    private var tabBorderRight: some View {
        HStack(spacing: 0) {
            Spacer()
            Rectangle()
                .fill(DesignTokens.Colors.borderSecondary)
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
