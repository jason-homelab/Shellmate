import SwiftUI

/// 新建 tmux 会话弹窗
/// 从 TmuxManagerView 的「+ 新建」按钮触发
struct TmuxNewSessionSheet: View {

    // MARK: - 属性

    var onCreate: (String, String) -> Void
    var onCancel: () -> Void

    // MARK: - 状态

    @State private var sessionName: String = ""
    @State private var windowName:  String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case sessionName, windowName }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "rectangle.3.group")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                Text("新建 tmux 会话")
                    .font(DesignTokens.Typography.titleSmall)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.lg)

            Divider()

            // 表单
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                fieldRow(label: "名称", placeholder: "留空则使用默认编号", text: $sessionName, field: .sessionName)
                fieldRow(label: "窗口名", placeholder: "可选", text: $windowName, field: .windowName)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            // 按钮组
            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .keyboardShortcut(.escape, modifiers: [])

                Button("创建") {
                    onCreate(sessionName, windowName)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 340)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                .fill(Color.white.opacity(0.95))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusPanel, style: .continuous)
                .strokeBorder(Color(hex: "#d2d2d7").opacity(0.50), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 6)
        .onAppear { focusedField = .sessionName }
    }

    // MARK: - 辅助

    @ViewBuilder
    private func fieldRow(label: String, placeholder: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(label)
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            CustomTextField(placeholder: placeholder, text: text)
                .font(DesignTokens.Typography.codeSmall)
                .focused($focusedField, equals: field)
                .onSubmit {
                    if field == .sessionName {
                        focusedField = .windowName
                    } else {
                        onCreate(sessionName, windowName)
                    }
                }
        }
    }
}

// MARK: - 预览

#Preview("新建 tmux 会话") {
    TmuxNewSessionSheet(
        onCreate: { _, _ in },
        onCancel: {}
    )
    .padding()
    .background(Color.black.opacity(0.8))
}
