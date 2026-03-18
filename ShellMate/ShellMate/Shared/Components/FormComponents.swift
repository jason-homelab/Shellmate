import SwiftUI

// MARK: - 表单字段组件

/// 表单字段容器
/// 包含标签和内容的表单字段包装器
struct FormField<Content: View>: View {

    // MARK: - 属性

    /// 字段标签
    let label: String

    /// 是否必填
    var isRequired: Bool = false

    /// 字段内容
    @ViewBuilder let content: () -> Content

    // MARK: - 视图

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Text(label)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                if isRequired {
                    Text("*")
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(DesignTokens.Colors.statusError)
                }
            }

            content()
        }
    }
}

// MARK: - 按钮样式

/// 主按钮样式
struct PrimaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(isEnabled ? .white : DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium)
                    .fill(isEnabled ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.surfaceCard)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignTokens.Animation.fast, value: configuration.isPressed)
    }
}

/// 次要按钮样式
struct SecondaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(isEnabled ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium)
                    .stroke(
                        isEnabled ? DesignTokens.Colors.borderPrimary : DesignTokens.Colors.borderSecondary,
                        lineWidth: 1
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignTokens.Animation.fast, value: configuration.isPressed)
    }
}

/// 危险按钮样式
struct DestructiveButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(isEnabled ? .white : DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium)
                    .fill(isEnabled ? DesignTokens.Colors.statusError : DesignTokens.Colors.surfaceCard)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignTokens.Animation.fast, value: configuration.isPressed)
    }
}

/// 文本按钮样式
struct TextButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(isEnabled ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - 输入框组件

/// 自定义文本输入框
/// 支持四种状态：默认、聚焦、错误、禁用
struct CustomTextField: View {

    // MARK: - 属性

    /// 占位符文本
    let placeholder: String

    /// 文本绑定
    @Binding var text: String

    /// 是否为错误状态
    var isError: Bool = false

    /// 错误信息
    var errorMessage: String?

    /// 是否为密码输入
    var isSecure: Bool = false

    // MARK: - 状态

    @FocusState private var isFocused: Bool

    // MARK: - 视图

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .focused($isFocused)
                }
            }
            .font(DesignTokens.Typography.bodyMedium)
            .foregroundColor(DesignTokens.Colors.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.surfaceCard)
            .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium)
                    .stroke(borderColor, lineWidth: 1)
            )

            if let error = errorMessage, isError {
                Text(error)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.statusError)
            }
        }
    }

    // MARK: - 计算属性

    private var borderColor: Color {
        if isError {
            return DesignTokens.Colors.statusError
        } else if isFocused {
            return DesignTokens.Colors.borderFocus
        } else {
            return DesignTokens.Colors.borderPrimary
        }
    }
}

// MARK: - 切换开关组件

/// 自定义切换开关
struct CustomToggle: View {

    // MARK: - 属性

    /// 标签文本
    let label: String

    /// 是否开启
    @Binding var isOn: Bool

    /// 说明文本
    var subtitle: String?

    // MARK: - 视图

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(label)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(DesignTokens.Colors.accentPrimary)
    }
}

// MARK: - 分段选择器组件

/// 自定义分段选择器
struct CustomSegmentedPicker<T: Hashable>: View {

    // MARK: - 属性

    /// 选项列表
    let options: [T]

    /// 当前选中项
    @Binding var selection: T

    /// 选项标签生成器
    let labelProvider: (T) -> String

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(DesignTokens.Animation.fast) {
                        selection = option
                    }
                }) {
                    Text(labelProvider(option))
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(
                            selection == option
                                ? DesignTokens.Colors.textPrimary
                                : DesignTokens.Colors.textSecondary
                        )
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall)
                                .fill(
                                    selection == option
                                        ? DesignTokens.Colors.surfaceCard
                                        : Color.clear
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.xxs)
        .background(DesignTokens.Colors.surfacePanel)
        .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
    }
}

// MARK: - 预览

#Preview("按钮样式") {
    VStack(spacing: 16) {
        Button("主要按钮") {}
            .buttonStyle(PrimaryButtonStyle())

        Button("次要按钮") {}
            .buttonStyle(SecondaryButtonStyle())

        Button("危险按钮") {}
            .buttonStyle(DestructiveButtonStyle())

        Button("文本按钮") {}
            .buttonStyle(TextButtonStyle())

        Button("禁用按钮") {}
            .buttonStyle(PrimaryButtonStyle())
            .disabled(true)
    }
    .padding()
    .background(DesignTokens.Colors.surfaceWindow)
}

#Preview("输入框状态") {
    VStack(spacing: 16) {
        CustomTextField(placeholder: "默认状态", text: .constant(""))

        CustomTextField(placeholder: "有内容", text: .constant("hello@example.com"))

        CustomTextField(
            placeholder: "错误状态",
            text: .constant("invalid"),
            isError: true,
            errorMessage: "请输入有效的邮箱地址"
        )

        CustomTextField(
            placeholder: "密码输入",
            text: .constant("password"),
            isSecure: true
        )
    }
    .padding()
    .background(DesignTokens.Colors.surfaceWindow)
}

#Preview("切换开关") {
    VStack(spacing: 16) {
        CustomToggle(label: "自动重连", isOn: .constant(true))

        CustomToggle(
            label: "启用 iCloud 同步",
            isOn: .constant(false),
            subtitle: "在多台 Mac 之间同步会话配置"
        )
    }
    .padding()
    .background(DesignTokens.Colors.surfaceWindow)
}

#Preview("分段选择器") {
    CustomSegmentedPicker(
        options: ["基本", "认证", "高级", "外观"],
        selection: .constant("基本"),
        labelProvider: { $0 }
    )
    .padding()
    .background(DesignTokens.Colors.surfaceWindow)
}
