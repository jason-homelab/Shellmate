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
        // Figma 8:32：h=36px，bg=#f5f5f7，border-top 0.5px rgba(0,0,0,0.08)
        HStack {
            // Figma 8:34：10px regular，#8e8e93，left=14
            Text("\(connectedCount) connected")
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Spacer()

            // Figma 8:35：10px regular，#8e8e93，right-aligned
            Text("\(totalCount) total")
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
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
