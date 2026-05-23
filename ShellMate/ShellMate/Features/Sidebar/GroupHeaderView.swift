import SwiftUI

/// 分组头部视图 — 1:1 对齐 Figma 8:30
/// h-[36px] rounded-[6px] text-[12px] font-medium text-[#6e6e73]
/// 无数量角标、无彩色图标徽章，与会话行形成轻重对比
struct GroupHeaderView: View {

    // MARK: - 属性

    let group: SessionGroup
    var onToggle: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    // MARK: - 状态

    @State private var isHovering = false

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 4) {

            // ── 展开/折叠箭头 ── Figma: › 10pt medium secondary
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 12)
                .rotationEffect(.degrees(group.isExpanded ? 90 : 0))
                .animation(DesignTokens.Animation.fast, value: group.isExpanded)

            // ── 文件夹图标 ── Figma: 📁 12pt secondary，无彩色背景
            Image(systemName: group.isExpanded ? "folder.fill" : "folder")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 14)

            // ── 分组名称 ── Figma 8:31: text-[12px] font-medium text-[#6e6e73]
            Text(group.name)
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        // Figma 8:30: left-[8px] within row，h-[36px]，rounded-[6px]
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .frame(height: DesignTokens.Sizes.groupRowHeight)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(isHovering ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.hover) { isHovering = hovering }
        }
        .onTapGesture(count: 2) { onDoubleClick?() }
        .onTapGesture(count: 1) {
            withAnimation(DesignTokens.Animation.fast) { onToggle?() }
        }
        .help("\(group.name) — 双击编辑")
        .accessibilityLabel(group.name)
        .accessibilityHint(group.isExpanded ? "已展开，单击折叠，双击重命名" : "已折叠，单击展开，双击重命名")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { withAnimation(DesignTokens.Animation.fast) { onToggle?() } }
        .accessibilityAction(named: "重命名") { onDoubleClick?() }
    }
}

// MARK: - 预览

#Preview("分组头部") {
    VStack(spacing: DesignTokens.Spacing.px) {
        GroupHeaderView(
            group: SessionGroup(name: "开发服务器", colorHex: "#4A90D9", isExpanded: true)
        )
        GroupHeaderView(
            group: SessionGroup(name: "生产服务器", colorHex: "#F04060", isExpanded: false)
        )
        GroupHeaderView(
            group: SessionGroup(name: "测试环境", colorHex: "#F0A500", isExpanded: true)
        )
    }
    .padding(.horizontal, DesignTokens.Spacing.xs)
    .padding(.vertical, DesignTokens.Spacing.xs)
    .frame(width: 240)
    .background(DesignTokens.Colors.surfacePanel)
}
