import SwiftUI

/// 侧边栏底部视图
/// 包含新建会话按钮和其他快捷操作
struct SidebarFooterView: View {

    // MARK: - 属性

    /// 新建会话回调
    var onNewSession: (() -> Void)?

    /// 新建分组回调
    var onNewGroup: (() -> Void)?

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 新建会话按钮
            Button(action: {
                onNewSession?()
            }) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))

                    Text("新建会话")
                        .font(DesignTokens.Typography.labelMedium)
                }
                .foregroundColor(DesignTokens.Colors.accentPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.Sizes.buttonHeight)
                .background(DesignTokens.Colors.accentPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(.plain)

            // 新建分组按钮
            Button(action: {
                onNewGroup?()
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: DesignTokens.Sizes.buttonHeight, height: DesignTokens.Sizes.buttonHeight)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("新建分组")
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(Color(hex: "#f5f5f7").opacity(0.90))
        .background(.ultraThinMaterial)
    }
}

// MARK: - 预览

#Preview("侧边栏底部") {
    VStack {
        Spacer()
        SidebarFooterView(
            onNewSession: { AppLogger.general.debug("新建会话") },
            onNewGroup: { AppLogger.general.debug("新建分组") }
        )
    }
    .frame(width: 220, height: 400)
    .background(DesignTokens.Colors.surfaceWindow)
}
