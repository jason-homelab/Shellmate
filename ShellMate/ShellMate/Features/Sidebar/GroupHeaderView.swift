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
        HStack(spacing: DesignTokens.Spacing.xs) {

            // ── 展开/折叠箭头 ──
            // HTML: .folder-chevron { font-size:9px; color:var(--text-4) }
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(
                    isHovering
                        ? DesignTokens.Colors.textSecondary
                        : DesignTokens.Colors.textDisabled
                )
                .frame(width: 12)
                .rotationEffect(.degrees(group.isExpanded ? 90 : 0))
                .animation(DesignTokens.Animation.fast, value: group.isExpanded)

            // ── 文件夹图标徽章 ──
            // HTML: .folder-icon { width:22px; height:22px; bg:rgba(0,212,170,0.06); border:rgba(0,212,170,0.10) }
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(group.color.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(group.color.opacity(0.18), lineWidth: 0.75)
                    )
                    .frame(width: 22, height: 22)
                Image(systemName: group.isExpanded ? "folder.fill" : "folder")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(group.color.opacity(0.75))
            }

            // ── 分组名称 ──
            Text(group.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(
                    isHovering
                        ? DesignTokens.Colors.textPrimary
                        : DesignTokens.Colors.textSecondary
                )
                .lineLimit(1)

            Spacer(minLength: 0)

            // ── 会话数徽章 ──
            // HTML: .folder-badge { font-size:9.5px; bg:rgba(255,255,255,0.04); border:rgba(255,255,255,0.04) }
            Text("\(sessionCount)")
                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textDisabled)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(DesignTokens.Colors.glassUltraLight)
                        .overlay(
                            Capsule()
                                .strokeBorder(DesignTokens.Colors.glassBorderBottom, lineWidth: 0.5)
                        )
                )
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .frame(height: DesignTokens.Sizes.groupRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
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
    VStack(spacing: 1) {
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
