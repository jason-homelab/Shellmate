import SwiftUI

// MARK: - 外观设置 Tab（D01 Tab 4）

/// 会话外观设置 Tab
/// 主题/字号默认继承全局设置，Picker 选择「跟随全局」以外的值即为会话级覆盖，不修改全局设置
struct SessionAppearanceTab: View {

    // MARK: - 属性

    /// 会话覆盖主题 ID（空字符串 = 跟随全局）
    @Binding var overrideThemeId: String
    /// 会话覆盖字号（0 = 跟随全局）
    @Binding var overrideFontSizeValue: Int32
    @Binding var startupCommand: String

    // MARK: - 全局默认值（只读，用于 Picker 提示文本）

    @AppStorage("appearance.themeId") private var globalThemeId: String = "shellmate-dark"
    @AppStorage("appearance.fontSize") private var globalFontSize: Double = 13

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                themeSection
                    .padding(.bottom, 14)

                Divider().padding(.bottom, 14)

                fontSizeSection
                    .padding(.bottom, 14)

                Divider().padding(.bottom, 14)

                startupCommandSection
                    .padding(.bottom, 14)
            }
            .padding(18)
        }
    }

    // MARK: - 颜色主题

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("颜色主题")

            Picker("", selection: $overrideThemeId) {
                // 第一项 tag "" = 跟随全局，不覆盖
                Text("跟随全局（\(globalThemeName)）")
                    .tag("")
                Divider()
                ForEach(AppTheme.builtins) { theme in
                    Text(theme.name).tag(theme.id)
                }
            }
            .pickerStyle(.menu)

            if !overrideThemeId.isEmpty {
                Text("会话将使用「\(selectedThemeName)」，不影响全局设置")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            } else {
                Text("当前全局：\(globalThemeName)")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
    }

    private var globalThemeName: String {
        AppTheme.builtins.first(where: { $0.id == globalThemeId })?.name ?? globalThemeId
    }

    private var selectedThemeName: String {
        AppTheme.builtins.first(where: { $0.id == overrideThemeId })?.name ?? overrideThemeId
    }

    // MARK: - 字号

    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("终端字号")

            HStack(spacing: 8) {
                Picker("", selection: $overrideFontSizeValue) {
                    Text("跟随全局（\(Int(globalFontSize))pt）").tag(Int32(0))
                    Divider()
                    ForEach([9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24], id: \.self) { size in
                        Text("\(size)pt").tag(Int32(size))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }

            if overrideFontSizeValue > 0 {
                Text("会话将使用 \(overrideFontSizeValue)pt，不影响全局设置")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
            } else {
                Text("当前全局：\(Int(globalFontSize))pt")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
    }

    // MARK: - 启动命令

    private var startupCommandSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("启动命令（可选）")

            CustomTextField(placeholder: "如: screen -r main 或 tmux attach -t main",
                            text: $startupCommand)
                .font(.system(size: 11, design: .monospaced))

            Text("连接成功后自动发送此命令")
                .font(.system(size: 9.5))
                .foregroundColor(DesignTokens.Colors.textDisabled)
        }
    }

    // MARK: - 辅助

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .textCase(.uppercase)
            .kerning(0.4)
    }
}

// MARK: - 预览

#Preview("外观设置 Tab") {
    SessionAppearanceTab(
        overrideThemeId: .constant(""),
        overrideFontSizeValue: .constant(0),
        startupCommand: .constant("")
    )
    .frame(width: 504, height: 420)
    .background(DesignTokens.Colors.surfacePanel)
}
