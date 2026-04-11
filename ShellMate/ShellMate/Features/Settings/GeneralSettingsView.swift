import SwiftUI

// MARK: - 通用设置（General）

/// 对应 Figma 设置面板 §二：通用设置
struct GeneralSettingsView: View {

    // MARK: - 持久化偏好

    @AppStorage("general.autoReconnect")       private var autoReconnect: Bool   = false
    @AppStorage("general.confirmCloseTab")     private var confirmCloseTab: Bool = true
    @AppStorage("general.saveSessionLog")      private var saveSessionLog: Bool  = false
    @AppStorage("general.defaultProtocol")     private var defaultProtocol: String = "SSH"
    @AppStorage("general.language")            private var language: String      = "system"

    /// 同步给 ContentView 使用（决定 .environment(\.locale)）
    @AppStorage("app.language")                private var appLanguage: String   = "zh"

    @State private var showLanguageRestartAlert: Bool = false

    private let protocols = ["SSH", "Telnet", "Serial"]
    private let languages: [(String, LocalizedStringKey)] = [("system", "跟随系统"), ("zh-Hans", "简体中文"), ("en", "English")]

    // MARK: - 视图

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {

                // 语言
                settingRow(
                    title: "语言",
                    subtitle: nil
                ) {
                    Picker("", selection: $language) {
                        ForEach(languages, id: \.0) { lang in
                            Text(lang.1).tag(lang.0)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .onChange(of: language) { newLang in
                        applyLanguageSetting(newLang)
                    }
                }

                Divider()

                // 启动时自动重连
                toggleRow(
                    title: "启动时自动重连",
                    subtitle: "应用重启后自动建立上次活动会话",
                    binding: $autoReconnect
                )

                Divider()

                // 关闭标签确认
                toggleRow(
                    title: "关闭标签时需确认",
                    subtitle: "防止误关闭正在运行的会话",
                    binding: $confirmCloseTab
                )

                Divider()

                // 保存会话日志
                toggleRow(
                    title: "保存会话日志",
                    subtitle: "将终端输出保存至本地文件",
                    binding: $saveSessionLog
                )

                Divider()

                // 默认协议
                settingRow(
                    title: "默认连接协议",
                    subtitle: nil
                ) {
                    Picker("", selection: $defaultProtocol) {
                        ForEach(protocols, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .alert("需重启以应用语言更改", isPresented: $showLanguageRestartAlert) {
            Button("稍后重启", role: .cancel) { }
            Button("立即退出", role: .destructive) {
                NSApp.terminate(nil)
            }
        } message: {
            Text("语言更改将在重启应用后完全生效。菜单栏将立即更新。")
        }
    }

    // MARK: - 语言应用

    private func applyLanguageSetting(_ lang: String) {
        switch lang {
        case "en":
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
            appLanguage = "en"
        case "zh-Hans":
            UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
            appLanguage = "zh"
        default: // "system"
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            let systemLang = Locale.preferredLanguages.first ?? "zh-Hans"
            appLanguage = systemLang.hasPrefix("en") ? "en" : "zh"
        }
        UserDefaults.standard.synchronize()
        showLanguageRestartAlert = true
    }

    // MARK: - 辅助构建器

    private func toggleRow(title: LocalizedStringKey, subtitle: LocalizedStringKey?, binding: Binding<Bool>) -> some View {
        HStack(alignment: subtitle != nil ? .top : .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private func settingRow<Content: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey?,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            Spacer()
            control()
        }
    }
}

#Preview {
    GeneralSettingsView()
        .frame(width: 480)
        .padding()
}
