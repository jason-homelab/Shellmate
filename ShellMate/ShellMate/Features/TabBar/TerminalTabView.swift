import SwiftUI

/// 终端标签视图
/// 显示单个终端标签页
struct TerminalTabView: View {

    // MARK: - 属性

    /// 标签页
    let tab: TerminalTab

    /// 是否选中
    let isSelected: Bool

    /// 关闭动作
    let onClose: () -> Void

    /// 选择动作
    let onSelect: () -> Void

    // MARK: - 私有状态

    @State private var isHovering: Bool = false
    /// W12.6：观察同步输入状态
    @ObservedObject private var syncStore = SyncInputStore.shared

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // 状态指示器
            statusIndicator

            // 标题
            HStack(spacing: 3) {
                Text(tab.title)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(isSelected ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                // W12.6：同步输入激活时显示 ⚡ 图标
                if syncStore.isSynced(tab.sessionId) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                }
            }

            Spacer(minLength: 0)

            // 关闭按钮
            if isHovering || isSelected {
                closeButton
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .frame(height: DesignTokens.Sizes.tabBarHeight)
        .frame(minWidth: DesignTokens.Sizes.tabMinWidth, maxWidth: DesignTokens.Sizes.tabMaxWidth)
        .background(tabBackground)
        .overlay(tabBorder)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            tabContextMenu
        }
    }

    // MARK: - 子视图

    /// 状态指示器
    @ViewBuilder
    private var statusIndicator: some View {
        if tab.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.5)
                .frame(width: 12, height: 12)
        } else {
            GlowingStatusDot(color: tab.connectionState.dotColor, size: 5)
        }
    }

    /// 关闭按钮
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(width: DesignTokens.Sizes.tabCloseButtonSize, height: DesignTokens.Sizes.tabCloseButtonSize)
                .background(
                    Circle()
                        .fill(DesignTokens.Colors.glassHoverColor)
                        .opacity(isHovering ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
        .help("关闭标签页")
    }

    /// 标签背景
    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            Rectangle()
                .fill(DesignTokens.Colors.glassSelected)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignTokens.Colors.glassBorderAccent)
                        .frame(height: 0.5)
                }
        } else if isHovering {
            Rectangle()
                .fill(DesignTokens.Colors.glassHoverColor)
        } else {
            Color.clear
        }
    }

    /// 标签底部强调线（选中时）
    @ViewBuilder
    private var tabBorder: some View {
        if isSelected {
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(DesignTokens.Colors.accentPrimary)
                    .frame(height: 2)
            }
        }
    }

    /// 右键菜单
    @ViewBuilder
    private var tabContextMenu: some View {
        Button("关闭标签页") {
            onClose()
        }

        Divider()

        Button("关闭其他标签页") {
            // 通过环境对象处理
        }

        Button("关闭右侧标签页") {
            // 通过环境对象处理
        }

        Button("关闭左侧标签页") {
            // 通过环境对象处理
        }

        Divider()

        Button("复制终端会话") {
            // 通过环境对象处理
        }
    }
}

// MARK: - 预览

#Preview("终端标签 - 选中") {
    HStack(spacing: 0) {
        TerminalTabView(
            tab: TerminalTab(sessionId: UUID(), title: "开发服务器", connectionState: .connected),
            isSelected: true,
            onClose: {},
            onSelect: {}
        )
    }
    .frame(height: DesignTokens.Sizes.tabBarHeight)
    .background(DesignTokens.Colors.surfaceWindow)
}

#Preview("终端标签 - 未选中") {
    HStack(spacing: 0) {
        TerminalTabView(
            tab: TerminalTab(sessionId: UUID(), title: "生产服务器", connectionState: .connecting),
            isSelected: false,
            onClose: {},
            onSelect: {}
        )
    }
    .frame(height: DesignTokens.Sizes.tabBarHeight)
    .background(DesignTokens.Colors.surfaceWindow)
}

#Preview("终端标签 - 所有状态") {
    HStack(spacing: 1) {
        ForEach(TerminalTab.previewTabs) { tab in
            TerminalTabView(
                tab: tab,
                isSelected: tab.title == "开发服务器",
                onClose: {},
                onSelect: {}
            )
        }
    }
    .frame(height: DesignTokens.Sizes.tabBarHeight)
    .background(DesignTokens.Colors.surfaceWindow)
}
