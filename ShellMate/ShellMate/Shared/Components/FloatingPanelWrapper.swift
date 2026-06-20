import SwiftUI

// MARK: - FloatingPanelWrapper
//
// 全项目统一的悬浮面板视觉容器（Sprint 02 新增）。
// 包含：顶部拖拽手柄 → 面板标题栏 → 内容区（由调用方提供）。
//
// 使用方式：
//   FloatingPanelWrapper(icon: "doc.text", title: "日志面板", onClose: { ... }) {
//       LogPanelContentView()
//   }
//
// 覆盖范围：LogPanelView / TunnelManagerView / QuickCommandManagerView / TmuxManagerView 等

struct FloatingPanelWrapper<Content: View>: View {

    let icon: AppIcon
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖拽手柄（居中）
            HStack { Spacer(); PanelDragHandle(); Spacer() }

            // 统一面板标题栏
            PanelHeader(icon: icon, title: title, onClose: onClose)

            // 内容区（调用方自定义）
            content()
        }
        .glassCard(radius: DesignTokens.Sizes.cornerRadiusLarge)
        .panelShadow()
    }
}

// MARK: - 预览

#Preview("日志面板包裹示例") {
    FloatingPanelWrapper(icon: .docTextMagnifyingglass, title: "日志面板", onClose: {}) {
        Text("面板内容区")
            .font(DesignTokens.Typography.bodyMedium)
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.xxl)
    }
    .frame(width: 500)
    .padding(DesignTokens.Spacing.xxl)
}
