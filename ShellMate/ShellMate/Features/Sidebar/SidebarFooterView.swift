import SwiftUI

/// 侧边栏底部统计条 — 1:1 对齐 main-window.html .sidebar-footer
/// HTML: border-top + padding:8px 12px + flex justify-between
/// 显示"N connected"和"N total"两个等宽字体极暗色统计标签
struct SidebarFooterView: View {

    // MARK: - 属性

    /// 当前连接数
    var connectedCount: Int = 0

    /// 会话总数
    var totalCount: Int = 0

    // MARK: - 视图

    var body: some View {
        HStack {
            // Figma 8:34：10px regular，#8e8e93 = textSubtle，left=14
            Text(String(format: NSLocalizedString("%d 已连接", comment: ""), connectedCount))
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSubtle)

            Spacer()

            // Figma 8:35：10px regular，#8e8e93 = textSubtle，right-aligned
            Text(String(format: NSLocalizedString("共 %d 个", comment: ""), totalCount))
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSubtle)
        }
        .padding(.horizontal, 14)
        // Figma 8:32：h=31（与终端状态栏 32pt 刻意错开，保留层次感）
        .frame(height: DesignTokens.Sizes.sidebarFooterHeight)
        .background(DesignTokens.Colors.surfaceWindow)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 0.5)
        }
    }
}

// MARK: - 预览

#Preview("侧边栏底部统计") {
    VStack {
        Spacer()
        SidebarFooterView(connectedCount: 2, totalCount: 5)
    }
    .frame(width: 240, height: 400)
    .background(DesignTokens.Colors.surfacePanel)
}
