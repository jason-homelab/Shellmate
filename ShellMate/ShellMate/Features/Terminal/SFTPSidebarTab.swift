import SwiftUI

// MARK: - SFTP 右侧 Sidebar Tab 条

/// SFTP 右侧边栏 Tab 条（始终可见，20pt 宽）。
/// 参考 Figma Screen 03：SFTPPanel 在 TerminalArea 右侧；左边框作为面板分隔线。
/// 从 TerminalView 抽出（Phase 17）：观察 TerminalController 的开合/连接状态，切换动作经闭包回传。
struct SFTPSidebarTab: View {

    /// 终端控制器（响应式读取 isSFTPPanelOpen / state）
    @ObservedObject var controller: TerminalController
    /// 切换 SFTP 面板开合（由 TerminalView 注入 toggleSFTPPanel）
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Button {
                withAnimation(DesignTokens.Animation.standard) {
                    onToggle()
                }
            } label: {
                VStack(spacing: DesignTokens.Spacing.micro) {
                    // 箭头方向指示（展开 ← / 收起 →）
                    (controller.isSFTPPanelOpen ? AppIcon.chevronRight : .chevronLeft).image
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    // SFTP 图标（Figma: folder.fill）
                    AppIcon.folderFill.image
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(
                            controller.isSFTPPanelOpen
                                ? DesignTokens.Colors.accentPrimary
                                : DesignTokens.Colors.textTertiary
                        )

                    // "SFTP" 纵向标签（面板收起时显示）
                    if !controller.isSFTPPanelOpen {
                        Text("SFTP")
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                            .rotationEffect(.degrees(-90))
                            .fixedSize()
                    }
                }
                .frame(width: 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .disabled(controller.state != .connected && !controller.isSFTPPanelOpen)
            .help(controller.isSFTPPanelOpen ? "隐藏 SFTP 面板" : "SFTP 文件管理器")

            Spacer()
        }
        .frame(width: 20)
        .background(DesignTokens.Colors.surfacePanel)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(DesignTokens.Colors.borderFaint),
            alignment: .leading
        )
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(DesignTokens.Colors.borderFaint),
            alignment: .trailing
        )
    }
}
