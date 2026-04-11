import SwiftUI

/// 侧边栏搜索视图
/// 提供搜索框用于过滤会话列表
struct SidebarSearchView: View {

    // MARK: - 属性

    /// 搜索文本绑定
    @Binding var searchText: String

    /// 外部焦点触发器：父视图将此值切换为 true 时，搜索框自动获得焦点
    @Binding var focusTrigger: Bool

    /// 是否显示搜索框
    @State private var isSearching: Bool = false

    /// 是否获得焦点
    @FocusState private var isFocused: Bool

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            // 搜索输入框
            TextField("搜索会话...", text: $searchText)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    // 搜索提交处理
                }

            // 清除按钮
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                .stroke(
                    isFocused ? DesignTokens.Colors.borderFocus : Color.clear,
                    lineWidth: 1
                )
        )
        .accessibilityLabel("搜索会话")
        .accessibilityHint("输入名称、主机地址或标签进行过滤")
        .onChange(of: focusTrigger) { triggered in
            if triggered {
                isFocused = true
                focusTrigger = false
            }
        }
    }
}

// MARK: - 预览

#Preview("搜索框") {
    VStack(spacing: 16) {
        SidebarSearchView(searchText: .constant(""), focusTrigger: .constant(false))
        SidebarSearchView(searchText: .constant("服务器"), focusTrigger: .constant(false))
    }
    .padding()
    .background(DesignTokens.Colors.surfaceWindow)
}
