import SwiftUI

// MARK: - 表单字段容器

struct FormField<Content: View>: View {
    let label: String
    var isRequired: Bool = false
    let content: () -> Content

    init(label: String, isRequired: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.isRequired = isRequired
        self.content = content
    }

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
                        .accessibilityLabel("必填")
                }
            }
            .accessibilityHidden(true)          // 标签文字由 content 的 accessibilityLabel 统一承担
            content()
                .accessibilityLabel(isRequired ? "\(label)，必填" : label)
        }
    }
}

// MARK: - 主按钮样式（玻璃渐变 + 光晕）

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(isEnabled ? .white : DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background {
                if isEnabled {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .fill(DesignTokens.Gradients.accentButton)
                        .overlay {
                            // 顶部高光层（拟物玻璃按钮感）
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.22), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                        }
                } else {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .fill(DesignTokens.Colors.surfaceCard)
                }
            }
            .shadow(
                color: isEnabled
                    ? DesignTokens.Colors.accentGlow
                    : .clear,
                radius: configuration.isPressed ? 6 : 12,
                x: 0, y: 0
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.40)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(DesignTokens.Animation.hover, value: configuration.isPressed)
    }
}

// MARK: - 次要按钮样式（玻璃面板 + 渐变边框）

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(isEnabled ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? DesignTokens.Colors.glassPress
                            : DesignTokens.Colors.glassLight
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(DesignTokens.Gradients.glassBorder(), lineWidth: 0.75)
                    }
            }
            .opacity(isEnabled ? 1.0 : 0.40)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(DesignTokens.Animation.hover, value: configuration.isPressed)
    }
}

// MARK: - 危险按钮样式

struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(isEnabled ? .white : DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background {
                if isEnabled {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#F87070"), Color(hex: "#D43060")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.18), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        }
                } else {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .fill(DesignTokens.Colors.surfaceCard)
                }
            }
            .shadow(
                color: isEnabled ? DesignTokens.Colors.statusError.opacity(0.30) : .clear,
                radius: configuration.isPressed ? 4 : 10,
                x: 0, y: 0
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.40)
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(DesignTokens.Animation.hover, value: configuration.isPressed)
    }
}

// MARK: - 文本按钮样式

struct TextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.labelMedium)
            .foregroundColor(isEnabled ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .opacity(configuration.isPressed ? 0.55 : 1.0)
            .animation(DesignTokens.Animation.hover, value: configuration.isPressed)
    }
}

// MARK: - 工具栏图标按钮样式

struct ToolbarIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                isActive
                    ? DesignTokens.Colors.accentPrimary
                    : (isEnabled ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textDisabled)
            )
            .frame(width: DesignTokens.Sizes.iconButtonSize, height: DesignTokens.Sizes.iconButtonSize)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? DesignTokens.Colors.glassPress
                            : (isActive
                                ? DesignTokens.Colors.accentGlow
                                : (configuration.isPressed ? DesignTokens.Colors.glassHoverColor : Color.clear))
                    )
            }
            .opacity(isEnabled ? 1.0 : 0.40)
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(DesignTokens.Animation.hover, value: configuration.isPressed)
    }
}

// MARK: - 玻璃输入框

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var isError: Bool = false
    var errorMessage: String?
    var isSecure: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            ZStack {
                // 玻璃背景
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .fill(DesignTokens.Colors.surfaceInput)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .fill(DesignTokens.Colors.glassUltraLight)
                    }

                // 边框（状态感知）
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(borderGradient, lineWidth: isFocused ? 1.0 : 0.75)

                // 聚焦光晕
                if isFocused && !isError {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.25), lineWidth: 3)
                        .blur(radius: 2)
                }

                // 输入内容
                HStack {
                    Group {
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

                    if isError {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(DesignTokens.Colors.statusError)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
            .frame(height: 30)
            .animation(DesignTokens.Animation.fast, value: isFocused)
            .animation(DesignTokens.Animation.fast, value: isError)

            if let error = errorMessage, isError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(error)
                        .font(DesignTokens.Typography.labelSmall)
                }
                .foregroundColor(DesignTokens.Colors.statusError)
                .padding(.horizontal, 2)
                .accessibilityLabel("错误：\(error)")
            }
        }
        .accessibilityValue(isError ? (errorMessage ?? "输入有误") : "")
    }

    private var borderGradient: LinearGradient {
        if isError {
            return LinearGradient(
                colors: [DesignTokens.Colors.statusError.opacity(0.70),
                         DesignTokens.Colors.statusError.opacity(0.40)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isFocused {
            return LinearGradient(
                colors: [DesignTokens.Colors.accentPrimary.opacity(0.75),
                         DesignTokens.Colors.accentSecondary.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return DesignTokens.Gradients.glassBorder()
        }
    }
}

// MARK: - 玻璃切换开关

struct CustomToggle: View {
    let label: String
    @Binding var isOn: Bool
    var subtitle: String?

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(label)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                if let subtitle {
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

// MARK: - 玻璃分段选择器

struct CustomSegmentedPicker<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let labelProvider: (T) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(DesignTokens.Animation.glass) {
                        selection = option
                    }
                } label: {
                    Text(labelProvider(option))
                        .font(DesignTokens.Typography.labelMedium)
                        .foregroundColor(
                            isSelected
                                ? .white
                                : DesignTokens.Colors.textSecondary
                        )
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm - 1)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                                    .fill(DesignTokens.Gradients.accentButton)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.18), Color.clear],
                                                    startPoint: .top,
                                                    endPoint: .center
                                                )
                                            )
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                                    }
                                    .shadow(
                                        color: DesignTokens.Colors.accentGlow,
                                        radius: 8, x: 0, y: 0
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                .fill(DesignTokens.Colors.surfaceInput)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(DesignTokens.Gradients.glassBorder(), lineWidth: 0.75)
                }
        }
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
        CustomTextField(placeholder: "主机地址", text: .constant(""))
        CustomTextField(placeholder: "主机地址", text: .constant("192.168.1.1"))
        CustomTextField(
            placeholder: "端口",
            text: .constant("invalid"),
            isError: true,
            errorMessage: "端口号必须在 1–65535 范围内"
        )
        CustomTextField(placeholder: "密码", text: .constant("secret"), isSecure: true)
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
