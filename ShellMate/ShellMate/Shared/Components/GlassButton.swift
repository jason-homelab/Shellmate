import SwiftUI

// MARK: - GlassButton
//
// 超级按钮组件，内聚三种视觉变体与 Hover/Press 动画。
// 替代项目中所有散落的 Button + inline 样式写法。
//
// 用法示例：
//   GlassButton("连接", icon: "bolt.fill", variant: .primary) { connect() }
//   GlassButton("取消", variant: .ghost) { cancel() }
//   GlassButton("删除", icon: "trash", variant: .danger) { delete() }

struct GlassButton: View {

    let title: String
    var icon: String?
    var variant: GlassButtonVariant = .ghost
    let action: () -> Void

    init(_ title: String = "", icon: String? = nil, variant: GlassButtonVariant = .ghost, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.action = action
    }

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.micro) {   // HTML: .tb-btn { gap: 5px }
                if let icon {
                    Image(systemName: icon)
                        .font(DesignTokens.Typography.labelMedium)
                }
                Text(title)
                    .font(DesignTokens.Typography.labelMedium)
            }
        }
        .buttonStyle(GlassButtonStyle(variant: variant))
    }
}

// MARK: - 便捷扩展

extension GlassButton {
    /// 图标专用（无文字）
    init(icon: String, variant: GlassButtonVariant = .ghost, action: @escaping () -> Void) {
        self.init("", icon: icon, variant: variant, action: action)
    }
}

// MARK: - 预览

#Preview("GlassButton 三变体") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        HStack(spacing: DesignTokens.Spacing.md) {
            GlassButton("连接", icon: "bolt.fill", variant: .primary) {}
            GlassButton("取消", variant: .ghost) {}
            GlassButton("删除", icon: "trash", variant: .danger) {}
        }

        HStack(spacing: DesignTokens.Spacing.md) {
            GlassButton(icon: "gear", variant: .ghost) {}
            GlassButton(icon: "plus", variant: .primary) {}
            GlassButton(icon: "xmark", variant: .danger) {}
        }
    }
    .padding(DesignTokens.Spacing.xxl)
    .background(DesignTokens.Colors.surfaceWindow)
}
