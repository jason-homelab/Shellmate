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
            // HTML: .sidebar-stat-val { color: rgba(52,211,153,0.75); font-weight:600 }
            // HTML: "N connected" — N 用绿色加粗，" connected" 用极暗色
            HStack(spacing: DesignTokens.Spacing.nano) {
                Text("\(connectedCount)")
                    .font(DesignTokens.Typography.codeTiny)
                    .monospacedDigit()
                    .foregroundColor(DesignTokens.Colors.statusConnected.opacity(0.75))
                Text("connected")
                    .font(DesignTokens.Typography.codeTiny)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            Text("\(totalCount) total")
                .font(DesignTokens.Typography.codeTiny)
                .monospacedDigit()
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, DesignTokens.Spacing.sm)
        // Figma §02: 跟随侧边栏 surfaceWindow (#f5f5f7)
        .background(DesignTokens.Colors.surfaceWindow)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.Colors.borderPrimary)
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
