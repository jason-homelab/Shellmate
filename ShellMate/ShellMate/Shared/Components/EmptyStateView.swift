import SwiftUI

/// 空状态视图
/// 用于显示列表为空或搜索无结果时的提示
struct EmptyStateView: View {

    // MARK: - 属性

    /// 图标名称（SF Symbols）
    let iconName: String

    /// 标题
    let title: String

    /// 描述文本
    var description: String?

    /// 按钮标题（可选）
    var buttonTitle: String?

    /// 按钮点击回调
    var onButtonTap: (() -> Void)?

    // MARK: - 视图

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // 图标
            Image(systemName: iconName)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            // 文字内容
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                if let description = description {
                    Text(description)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // 操作按钮
            if let buttonTitle = buttonTitle {
                Button(action: {
                    onButtonTap?()
                }) {
                    Text(buttonTitle)
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.accentPrimary)
                        .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 预设样式

extension EmptyStateView {
    /// 无会话状态
    static func noSessions(onAdd: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            iconName: "server.rack",
            title: "暂无会话",
            description: "点击下方按钮创建你的第一个 SSH 会话",
            buttonTitle: "新建会话",
            onButtonTap: onAdd
        )
    }

    /// 搜索无结果状态
    static func noSearchResults(query: String) -> EmptyStateView {
        EmptyStateView(
            iconName: "magnifyingglass",
            title: "未找到结果",
            description: "没有找到与「\(query)」匹配的会话"
        )
    }

    /// 无分组状态
    static func noGroups(onAdd: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            iconName: "folder",
            title: "暂无分组",
            description: "创建分组来整理你的会话",
            buttonTitle: "新建分组",
            onButtonTap: onAdd
        )
    }

    /// 加载中状态
    static var loading: EmptyStateView {
        EmptyStateView(
            iconName: "arrow.triangle.2.circlepath",
            title: "加载中...",
            description: nil
        )
    }

    /// 错误状态
    static func error(message: String, onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            iconName: "exclamationmark.triangle",
            title: "出错了",
            description: message,
            buttonTitle: "重试",
            onButtonTap: onRetry
        )
    }
}

// MARK: - 预览

#Preview("空状态 - 无会话") {
    EmptyStateView.noSessions {
        print("新建会话")
    }
    .background(DesignTokens.Colors.surfaceWindow)
}

#Preview("空状态 - 搜索无结果") {
    EmptyStateView.noSearchResults(query: "测试服务器")
        .background(DesignTokens.Colors.surfaceWindow)
}

#Preview("空状态 - 错误") {
    EmptyStateView.error(message: "网络连接失败，请检查网络设置") {
        print("重试")
    }
    .background(DesignTokens.Colors.surfaceWindow)
}
