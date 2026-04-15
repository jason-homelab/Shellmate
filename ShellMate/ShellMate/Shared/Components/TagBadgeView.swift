import SwiftUI

/// 标签徽章视图
/// 显示会话标签的小徽章
struct TagBadgeView: View {

    // MARK: - 属性

    /// 标签文本
    let text: String

    /// 背景颜色（可选，默认使用强调色）
    var backgroundColor: Color = DesignTokens.Colors.accentPrimary.opacity(0.2)

    /// 文字颜色（可选，默认使用强调色）
    var textColor: Color = DesignTokens.Colors.accentPrimary

    /// 是否可删除
    var isDeletable: Bool = false

    /// 删除回调
    var onDelete: (() -> Void)?

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Text(text)
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(textColor)
                .lineLimit(1)

            if isDeletable {
                Button(action: {
                    onDelete?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(textColor.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxxs)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
    }
}

/// 标签列表视图
/// 水平排列多个标签
struct TagListView: View {

    // MARK: - 属性

    /// 标签列表
    let tags: [String]

    /// 最大显示数量（超出显示 +N）
    var maxDisplayCount: Int = 3

    /// 是否可编辑
    var isEditable: Bool = false

    /// 删除回调
    var onDelete: ((String) -> Void)?

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            // 显示前几个标签
            ForEach(displayedTags, id: \.self) { tag in
                TagBadgeView(
                    text: tag,
                    isDeletable: isEditable,
                    onDelete: { onDelete?(tag) }
                )
            }

            // 显示剩余数量
            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
    }

    // MARK: - 计算属性

    private var displayedTags: [String] {
        Array(tags.prefix(maxDisplayCount))
    }

    private var remainingCount: Int {
        max(0, tags.count - maxDisplayCount)
    }
}

// MARK: - 颜色标签样式

extension TagBadgeView {
    /// 创建成功样式的标签
    static func success(_ text: String) -> TagBadgeView {
        TagBadgeView(
            text: text,
            backgroundColor: DesignTokens.Colors.statusConnected.opacity(0.2),
            textColor: DesignTokens.Colors.statusConnected
        )
    }

    /// 创建警告样式的标签
    static func warning(_ text: String) -> TagBadgeView {
        TagBadgeView(
            text: text,
            backgroundColor: DesignTokens.Colors.statusConnecting.opacity(0.2),
            textColor: DesignTokens.Colors.statusConnecting
        )
    }

    /// 创建错误样式的标签
    static func error(_ text: String) -> TagBadgeView {
        TagBadgeView(
            text: text,
            backgroundColor: DesignTokens.Colors.statusError.opacity(0.2),
            textColor: DesignTokens.Colors.statusError
        )
    }
}

// MARK: - 预览

#Preview("标签徽章") {
    VStack(spacing: 16) {
        // 基本样式
        HStack {
            TagBadgeView(text: "生产")
            TagBadgeView(text: "开发")
            TagBadgeView(text: "测试")
        }

        // 带删除按钮
        HStack {
            TagBadgeView(text: "可删除", isDeletable: true) {
                AppLogger.general.debug("删除标签")
            }
        }

        // 不同状态
        HStack {
            TagBadgeView.success("成功")
            TagBadgeView.warning("警告")
            TagBadgeView.error("错误")
        }

        // 标签列表
        TagListView(tags: ["Linux", "Ubuntu", "AWS", "生产", "重要"])
    }
    .padding(DesignTokens.Spacing.xxl)
    .background(DesignTokens.Colors.surfaceWindow)
}
