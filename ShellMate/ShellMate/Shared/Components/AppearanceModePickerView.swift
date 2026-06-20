import SwiftUI
import AppKit

// MARK: - 外观模式选项

private enum WindowMode: String, CaseIterable {
    case auto  = "auto"
    case light = "light"
    case dark  = "dark"

    var label: String {
        switch self {
        case .auto:  return "跟随系统"
        case .light: return "浅色"
        case .dark:  return "深色"
        }
    }

    var icon: String {
        switch self {
        case .auto:  return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark:  return "moon"
        }
    }
}

// MARK: - 外观模式 Picker 弹出视图

/// 类 macOS 系统偏好设置外观选择器
/// 工具栏按钮点击后以 Popover 形式弹出，三卡片横排布局
struct AppearanceModePickerView: View {

    @Binding var windowMode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("外观模式")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            HStack(spacing: 10) {
                ForEach(WindowMode.allCases, id: \.rawValue) { mode in
                    modeCard(mode)
                }
            }

            Text("⌘⌥1 / 2 / 3 快速切换")
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(width: 260)
    }

    @ViewBuilder
    private func modeCard(_ mode: WindowMode) -> some View {
        let isSelected = windowMode == mode.rawValue

        Button {
            windowMode = mode.rawValue
        } label: {
            VStack(spacing: DesignTokens.Spacing.sm) {
                // 预览图
                modePreview(mode)
                    .frame(width: 64, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                            .stroke(
                                isSelected
                                    ? DesignTokens.Colors.accentPrimary
                                    : DesignTokens.Colors.borderSubtle,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected
                            ? DesignTokens.Colors.accentPrimary.opacity(0.3)
                            : .clear,
                        radius: 4
                    )

                // 标签 + 选中圈
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    if isSelected {
                        AppIcon.feedbackSuccess.image
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                    }
                    Text(mode.label)
                        .font(DesignTokens.Typography.captionLarge)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(
                            isSelected
                                ? DesignTokens.Colors.accentPrimary
                                : DesignTokens.Colors.textSecondary
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 模式预览小图（模拟窗口浅/深色样式）
    @ViewBuilder
    private func modePreview(_ mode: WindowMode) -> some View {
        switch mode {
        case .light:
            ZStack {
                Color(hex: "#F5F5F5")
                VStack(spacing: DesignTokens.Spacing.nano) {
                    // 模拟标题栏
                    HStack(spacing: DesignTokens.Spacing.nano) {
                        Circle().fill(Color(hex: "#FF5F57")).frame(width: 5, height: 5)
                        Circle().fill(Color(hex: "#FEBC2E")).frame(width: 5, height: 5)
                        Circle().fill(Color(hex: "#28C840")).frame(width: 5, height: 5)
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.Spacing.micro)
                    .padding(.top, DesignTokens.Spacing.micro)
                    // 模拟内容
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusTiny)
                        .fill(Color(hex: "#E8E8E8"))
                        .frame(height: 6)
                        .padding(.horizontal, DesignTokens.Spacing.micro)
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusTiny)
                        .fill(Color(hex: "#DEDEDE"))
                        .frame(height: 6)
                        .padding(.horizontal, 10)
                    Spacer()
                }
            }

        case .dark:
            ZStack {
                Color(hex: "#1C1C1E")
                VStack(spacing: DesignTokens.Spacing.nano) {
                    HStack(spacing: DesignTokens.Spacing.nano) {
                        Circle().fill(Color(hex: "#FF5F57")).frame(width: 5, height: 5)
                        Circle().fill(Color(hex: "#FEBC2E")).frame(width: 5, height: 5)
                        Circle().fill(Color(hex: "#28C840")).frame(width: 5, height: 5)
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.Spacing.micro)
                    .padding(.top, DesignTokens.Spacing.micro)
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusTiny)
                        .fill(Color(hex: "#3A3A3C"))
                        .frame(height: 6)
                        .padding(.horizontal, DesignTokens.Spacing.micro)
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusTiny)
                        .fill(Color(hex: "#2C2C2E"))
                        .frame(height: 6)
                        .padding(.horizontal, 10)
                    Spacer()
                }
            }

        case .auto:
            // 左半浅色 / 右半深色，模拟"跟随系统"
            ZStack {
                HStack(spacing: 0) {
                    Color(hex: "#F5F5F5").frame(maxWidth: .infinity)
                    Color(hex: "#1C1C1E").frame(maxWidth: .infinity)
                }
                // 分割线
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1)
                // 标题栏点（横跨两色）
                VStack {
                    HStack(spacing: DesignTokens.Spacing.nano) {
                        Circle().fill(Color(hex: "#FF5F57")).frame(width: 5, height: 5)
                        Circle().fill(Color(hex: "#FEBC2E")).frame(width: 5, height: 5)
                        Circle().fill(Color(hex: "#28C840")).frame(width: 5, height: 5)
                        Spacer()
                    }
                    .padding(.horizontal, DesignTokens.Spacing.micro)
                    .padding(.top, DesignTokens.Spacing.micro)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - 预览

#Preview("外观模式选择器") {
    AppearanceModePickerView(windowMode: .constant("auto"))
        .background(DesignTokens.Colors.surfacePanel)
}
