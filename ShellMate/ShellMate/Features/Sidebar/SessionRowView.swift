import SwiftUI

/// 会话行视图
/// 在侧边栏中显示单个会话的信息
struct SessionRowView: View {

    // MARK: - 属性

    /// 会话数据
    let session: Session

    /// 是否选中
    var isSelected: Bool = false

    /// 双击回调（连接会话）
    var onDoubleClick: (() -> Void)?

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 状态点
            StatusDotView(state: session.connectionState)

            // 会话信息
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                // 会话名称
                Text(session.name)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                // 主机地址
                Text("\(session.username)@\(session.host)")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // 标签（如果有）
            if !session.tags.isEmpty {
                TagListView(tags: session.tags, maxDisplayCount: 1)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(height: DesignTokens.Sizes.sessionRowHeight)
        .background(isSelected ? DesignTokens.Colors.backgroundSelected : Color.clear)
        .cornerRadius(DesignTokens.Sizes.cornerRadiusSmall)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleClick?()
        }
    }
}

// MARK: - 预览

#Preview("会话行 - 离线") {
    VStack(spacing: 0) {
        SessionRowView(session: .preview)
        SessionRowView(session: .preview, isSelected: true)
    }
    .padding()
    .background(DesignTokens.Colors.surfaceWindow)
}

#Preview("会话行 - 不同状态") {
    VStack(spacing: 0) {
        SessionRowView(session: {
            var s = Session.preview
            s.connectionState = .offline
            return s
        }())

        SessionRowView(session: {
            var s = Session.preview
            s.connectionState = .connecting
            return s
        }())

        SessionRowView(session: {
            var s = Session.preview
            s.connectionState = .connected
            return s
        }())

        SessionRowView(session: {
            var s = Session.preview
            s.connectionState = .error
            return s
        }())
    }
    .padding()
    .background(DesignTokens.Colors.surfaceWindow)
}
