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
    @Binding var connectionProtocol: String

    /// 可选分组列表
    var groups: [SessionGroup] = []

    private let protocols = ["SSH", "Telnet", "Serial"]

    /// 各协议的默认端口
    private func defaultPort(for proto: String) -> String {
        switch proto {
        case "Telnet": return "23"
        case "Serial": return ""
        default: return "22"
        }
    }

    // MARK: - 私有辅助

    /// 将 UUID? binding 转为 String binding，规避 macOS Picker 对 Optional tag 的已知 bug
    private var groupPickerBinding: Binding<String> {
        Binding(
            get: { selectedGroupId?.uuidString ?? "" },
            set: { selectedGroupId = $0.isEmpty ? nil : UUID(uuidString: $0) }
        )
    }

    @State private var showingGroupPicker = false

    // MARK: - 视图

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // 连接协议
            FormField(label: "连接协议", isRequired: true) {
                Picker("", selection: $connectionProtocol) {
                    ForEach(protocols, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: connectionProtocol) { newProto in
                    // 自动填充对应协议的默认端口（仅在当前端口是已知默认值时才更新）
                    let knownDefaults = ["22", "23", ""]
                    if knownDefaults.contains(port) {
                        port = defaultPort(for: newProto)
                    }
                }
            }

            Divider()

            // 会话名称
            FormField(label: "会话名称", isRequired: true) {
                CustomTextField(placeholder: "输入会话名称", text: $name)
            }

            // 主机地址
            FormField(label: "主机地址", isRequired: true) {
                CustomTextField(placeholder: "例如: 192.168.1.100 或 example.com", text: $host)
            }

            // 端口和用户名（并排）
            HStack(spacing: DesignTokens.Spacing.lg) {
                FormField(label: "端口", isRequired: true) {
                    CustomTextField(placeholder: "22", text: $port)
                        .frame(width: 80)
                }

                FormField(label: "用户名", isRequired: true) {
                    CustomTextField(placeholder: "root", text: $username)
                }
            }

            // 分组选择
            // 注：macOS 上 Picker 对 UUID? (Optional) binding 存在已知问题，
            // 改用 String binding（空字符串 = 未分组）规避 tag 匹配失效的 bug
            FormField(label: "分组") {
                Picker("选择分组", selection: groupPickerBinding) {
                    Text("未分组").tag("")

                    ForEach(groups) { group in
                        HStack {
                            Circle()
                                .fill(group.color)
                                .frame(width: 8, height: 8)
                            Text(group.name)
                        }
                        .tag(group.id.uuidString)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(DesignTokens.Spacing.lg)
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
        connectionProtocol: .constant("SSH"),
        groups: SessionGroup.previewList
    )
    .frame(width: 480)
    .background(DesignTokens.Colors.surfacePanel)
}
