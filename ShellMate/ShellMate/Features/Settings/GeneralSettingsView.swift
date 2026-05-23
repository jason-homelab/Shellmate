import SwiftUI
import UserNotifications

// MARK: - 通用设置（General）

/// 对应 Figma 设置面板 §二：通用设置
struct GeneralSettingsView: View {

    // MARK: - 持久化偏好（Figma 14:2 通用 Tab 六项设置）

    // 连接
    @AppStorage("general.keepAlive")             private var keepAlive: Bool             = true
    @AppStorage("general.autoReconnect")         private var autoReconnect: Bool         = true
    @AppStorage("general.compression")           private var compression: Bool           = false
    // 通知
    @AppStorage("general.connectionNotification") private var connectionNotification: Bool = true
    @AppStorage("general.commandNotification")   private var commandNotification: Bool   = false
    // 安全
    @AppStorage("general.verifyKnownHosts")      private var verifyKnownHosts: Bool      = true

    // MARK: - 视图

    var body: some View {
        ScrollView { settingsContent }
    }

    /// 可供父视图直接嵌入的内容（不含 ScrollView 包装）
    var settingsContent: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Figma 14:12 — 连接
            sectionHeader("连接")
            toggleRow(title: "保持连接活跃",   subtitle: "防止 SSH 超时断开",    binding: $keepAlive)
            toggleRow(title: "自动重连",       subtitle: "连接断开后自动重试",    binding: $autoReconnect)
            toggleRow(title: "压缩传输",       subtitle: "启用数据压缩以提升速度", binding: $compression)

            // Figma 14:31 — 通知（开启时在此处请求系统权限，而非在触发器执行时）
            sectionHeader("通知")
            toggleRow(title: "连接通知",       subtitle: "连接状态改变时通知",    binding: $connectionNotification)
                .onChange(of: connectionNotification) { enabled in
                    if enabled { requestNotificationPermission() }
                }
            toggleRow(title: "命令完成通知",   subtitle: "长时命令完成时通知",    binding: $commandNotification)
                .onChange(of: commandNotification) { enabled in
                    if enabled { requestNotificationPermission() }
                }

            // Figma 14:44 — 安全
            sectionHeader("安全")
            toggleRow(title: "已知主机验证",   subtitle: "验证 SSH 服务器指纹",   binding: $verifyKnownHosts)
        }
    }

    // MARK: - 通知权限

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - 辅助构建器

    // Figma: text-[11px] font-semibold text-[#8e8e93] left-[28px] pt-[16px]
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DesignTokens.Typography.labelSmall)
            .foregroundColor(DesignTokens.Colors.textSubtle)
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Figma: h-[52px] px-[28px]，title text-[13px] medium #1d1d1f，subtitle text-[12px] #8e8e93，bottom border rgba(0,0,0,0.06)
    private func toggleRow(title: String, subtitle: String, binding: Binding<Bool>) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignTokens.Typography.labelLarge)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(subtitle)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSubtle)
            }
            Spacer()
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 28)
        .frame(height: 52)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

#Preview {
    GeneralSettingsView()
        .frame(width: 480)
        .padding()
}
