import SwiftUI

/// 会话基本信息 Tab
/// 包含会话名称、主机、端口、用户名、分组选择
struct SessionBasicTab: View {

    // MARK: - 属性

    @Binding var name: String
    @Binding var host: String
    @Binding var port: String
    @Binding var username: String
    @Binding var selectedGroupId: UUID?

    /// 可选分组列表
    var groups: [SessionGroup] = []

    // MARK: - 私有状态

    @State private var showingGroupPicker = false

    // MARK: - 视图

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 会话名称
            FormField(label: "会话名称", isRequired: true) {
                TextField("输入会话名称", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // 主机地址
            FormField(label: "主机地址", isRequired: true) {
                TextField("例如: 192.168.1.100 或 example.com", text: $host)
                    .textFieldStyle(.roundedBorder)
            }

            // 端口和用户名（并排）
            HStack(spacing: DesignTokens.Spacing.lg) {
                FormField(label: "端口", isRequired: true) {
                    TextField("22", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                FormField(label: "用户名", isRequired: true) {
                    TextField("root", text: $username)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // 分组选择
            FormField(label: "分组") {
                Picker("选择分组", selection: $selectedGroupId) {
                    Text("未分组").tag(nil as UUID?)

                    ForEach(groups) { group in
                        HStack {
                            Circle()
                                .fill(group.color)
                                .frame(width: 8, height: 8)
                            Text(group.name)
                        }
                        .tag(group.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

/// 表单字段包装器
struct FormField<Content: View>: View {

    let label: String
    var isRequired: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Text(label)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                if isRequired {
                    Text("*")
                        .font(DesignTokens.Typography.labelSmall)
                        .foregroundColor(DesignTokens.Colors.statusError)
                }
            }

            content()
        }
    }
}

// MARK: - 预览

#Preview("基本信息 Tab") {
    SessionBasicTab(
        name: .constant("我的服务器"),
        host: .constant("192.168.1.100"),
        port: .constant("22"),
        username: .constant("root"),
        selectedGroupId: .constant(nil),
        groups: SessionGroup.previewList
    )
    .frame(width: 480)
    .background(DesignTokens.Colors.surfacePanel)
}
