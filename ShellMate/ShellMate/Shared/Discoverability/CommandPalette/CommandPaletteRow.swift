import SwiftUI

// W8：单行视图。AI 类目特殊渲染（icon 渐变 + 右侧 "AI" 标识）

struct CommandPaletteRow: View {

    let capability: Capability
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // 左侧 3pt 选中蓝条
                Rectangle()
                    .fill(isSelected ? DesignTokens.Colors.accentPrimary : Color.clear)
                    .frame(width: 3)

                // 图标
                icon
                    .frame(width: 22, height: 22)

                // 标题
                Text(capability.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: DesignTokens.Spacing.sm)

                // 右侧：AI 标识或快捷键
                trailing
            }
            .padding(.trailing, DesignTokens.Spacing.sm)
            .frame(height: 36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    // MARK: - 图标

    @ViewBuilder
    private var icon: some View {
        if capability.category == .ai {
            capability.icon.image
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DesignTokens.Gradients.aiIcon)
        } else {
            capability.icon.image
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
    }

    // MARK: - Trailing

    @ViewBuilder
    private var trailing: some View {
        HStack(spacing: 6) {
            if capability.category == .ai {
                Text("AI")
                    .font(DesignTokens.Typography.Mono.label)
                    .foregroundColor(DesignTokens.Colors.accentAI)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.Colors.accentAI.opacity(0.14))
                    )
            }
            if let shortcut = capability.shortcut {
                Text(shortcut.display)
                    .font(DesignTokens.Typography.Mono.dataXS)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.Colors.glassLight)
                    )
            }
        }
    }

    // MARK: - 行背景

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            DesignTokens.Colors.glassSelected
        } else if isHovered {
            DesignTokens.Colors.glassHoverColor
        } else {
            Color.clear
        }
    }
}
