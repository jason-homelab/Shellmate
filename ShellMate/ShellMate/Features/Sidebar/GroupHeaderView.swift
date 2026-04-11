import SwiftUI

/// 分组头部视图
/// 在侧边栏中显示分组名称，支持展开/折叠
struct GroupHeaderView: View {

    // MARK: - 属性

    /// 分组数据
    let group: SessionGroup

    /// 分组下的会话数量
    var sessionCount: Int = 0

    /// 展开/折叠回调
    var onToggle: (() -> Void)?

    /// 双击回调（编辑分组）
    var onDoubleClick: (() -> Void)?

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // 展开/折叠箭头
            Button(action: {
                withAnimation(DesignTokens.Animation.fast) {
                    onToggle?()
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .rotationEffect(.degrees(group.isExpanded ? 90 : 0))
            }
            .buttonStyle(.plain)
            .frame(width: 16, height: 16)

            // 文件夹图标（颜色取自分组 colorHex）
            Image(systemName: "folder.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(group.color)

            // 分组名称
            Text(group.name)
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(1)

            Spacer()

            // 会话数量角标
            Text("\(sessionCount)")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(minWidth: 18)
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .background(Color.black.opacity(0.05))
                .clipShape(Capsule())
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .frame(height: DesignTokens.Sizes.groupRowHeight)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleClick?()
        }
        .onTapGesture(count: 1) {
            withAnimation(DesignTokens.Animation.fast) {
                onToggle?()
            }
        }
    }
}

// MARK: - 预览

#Preview("分组头部") {
    VStack(spacing: 0) {
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
    .padding()
    .background(DesignTokens.Colors.surfaceWindow)
}
