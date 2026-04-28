// UI 重构 by Frontend Designer Style
import SwiftUI

/// 分组头部视图 — Void 设计语言
/// 对齐 main-window.html .folder-row 规范，新增 hover 反馈 + 精致图标徽章
struct GroupHeaderView: View {

    // MARK: - 属性

    let group: SessionGroup
    var sessionCount: Int = 0
    var onToggle: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    // MARK: - 状态

    @State private var isHovering = false

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {

            // ── 展开/折叠箭头 ──
            // Figma: ChevronRight h-4 w-4 (16pt regular)，rotate-90 时展开。
            // 16pt regular 在 DesignTokens 中无精确匹配（labelXLarge 是 medium），
            // 此处保留 .system 字面量。
            Image(systemName: "chevron.right")
                .font(DesignTokens.Typography.iconLarge)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(group.isExpanded ? 90 : 0))
                .animation(DesignTokens.Animation.fast, value: group.isExpanded)

            // ── 文件夹图标徽章 ──
            // Figma: p-1.5 rounded-md bg-[#007aff]/10, Folder h-3.5 w-3.5 text-[#007aff]
            // 容器 = 6+14+6 = 26pt（与会话行图标一致）
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                    .fill(DesignTokens.Colors.accentPrimary.opacity(0.10))
                    .frame(width: 26, height: 26)
                Image(systemName: group.isExpanded ? "folder.fill" : "folder")
                    .font(DesignTokens.Typography.bodyLarge)
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            }

            // ── 分组名称 ──
            // Figma: text-sm font-medium = 14pt medium
            Text(group.name)
                .font(DesignTokens.Typography.bodyLargeMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // ── 会话数徽章 ──
            // Figma: text-xs text-[#86868b] ml-auto bg-black/5 px-2 py-0.5 rounded-full
            Text("\(sessionCount)")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(DesignTokens.Colors.surfaceHover)
                )
        }
        // Figma: px-3 py-2 rounded-lg = 12pt h-padding, 8pt v-padding, cornerRadiusSmall
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(isHovering ? DesignTokens.Colors.surfaceHover : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.hover) { isHovering = hovering }
        }
        .onTapGesture(count: 2) { onDoubleClick?() }
        .onTapGesture(count: 1) {
            withAnimation(DesignTokens.Animation.fast) { onToggle?() }
        }
    }
}

// MARK: - 预览

#Preview("分组头部") {
    VStack(spacing: DesignTokens.Spacing.px) {
        GroupHeaderView(
            group: SessionGroup(name: "开发服务器", colorHex: "#4A90D9", isExpanded: true),
            sessionCount: 5
        )
        GroupHeaderView(
            group: SessionGroup(name: "生产服务器", colorHex: "#F04060", isExpanded: false),
            sessionCount: 3
        )
        GroupHeaderView(
            group: SessionGroup(name: "测试环境", colorHex: "#F0A500", isExpanded: true),
            sessionCount: 8
        )
    }
    .padding(.horizontal, DesignTokens.Spacing.xs)
    .padding(.vertical, DesignTokens.Spacing.xs)
    .frame(width: 240)
    .background(DesignTokens.Colors.surfacePanel)
}
