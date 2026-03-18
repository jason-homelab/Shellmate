import SwiftUI

/// 会话高级设置 Tab
/// 包含超时、重连、编码等高级选项
struct SessionAdvancedTab: View {

    // MARK: - 属性

    @Binding var keepAliveInterval: Int32
    @Binding var autoReconnect: Bool
    @Binding var encoding: String

    // MARK: - 常量

    private let encodingOptions = [
        "UTF-8",
        "GBK",
        "GB2312",
        "GB18030",
        "BIG5",
        "ISO-8859-1",
        "EUC-JP",
        "Shift_JIS",
        "EUC-KR"
    ]

    private let keepAliveOptions: [(String, Int32)] = [
        ("关闭", 0),
        ("30 秒", 30),
        ("60 秒", 60),
        ("120 秒", 120),
        ("300 秒", 300)
    ]

    // MARK: - 视图

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            // 连接设置
            settingsSection(title: "连接设置") {
                // Keep-Alive 间隔
                FormField(label: "Keep-Alive 间隔") {
                    Picker("", selection: $keepAliveInterval) {
                        ForEach(keepAliveOptions, id: \.1) { option in
                            Text(option.0).tag(option.1)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                }

                Text("定期发送 Keep-Alive 包以保持连接活跃")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Divider()

            // 重连设置
            settingsSection(title: "重连设置") {
                Toggle(isOn: $autoReconnect) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text("自动重连")
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("连接断开时自动尝试重新连接")
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                }
                .toggleStyle(.switch)
            }

            Divider()

            // 编码设置
            settingsSection(title: "终端编码") {
                FormField(label: "字符编码") {
                    Picker("", selection: $encoding) {
                        ForEach(encodingOptions, id: \.self) { encoding in
                            Text(encoding).tag(encoding)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                }

                Text("用于终端显示和输入的字符编码")
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - 设置分组

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.titleSmall)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            content()
        }
    }
}

// MARK: - 预览

#Preview("高级设置 Tab") {
    SessionAdvancedTab(
        keepAliveInterval: .constant(60),
        autoReconnect: .constant(true),
        encoding: .constant("UTF-8")
    )
    .frame(width: 480, height: 400)
    .background(DesignTokens.Colors.surfacePanel)
}
