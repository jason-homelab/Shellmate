import SwiftUI

/// ShellMate 主应用入口
/// macOS SSH 会话管理工具
@main
struct ShellMateApp: App {

    // MARK: - 属性

    /// 应用程序代理
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Core Data 持久化控制器
    let persistenceController = PersistenceController.shared

    // MARK: - 应用场景

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    configureAppearance()
                }
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            // 自定义菜单命令
            appCommands
        }

        // 设置窗口
        Settings {
            SettingsView()
        }
    }

    // MARK: - 菜单命令

    @CommandsBuilder
    private var appCommands: some Commands {
        // 文件菜单
        CommandGroup(replacing: .newItem) {
            Button("新建会话") {
                NotificationCenter.default.post(name: .newSessionRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("新建分组") {
                NotificationCenter.default.post(name: .newGroupRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("新建标签页") {
                NotificationCenter.default.post(name: .newTabRequested, object: nil)
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("关闭标签页") {
                NotificationCenter.default.post(name: .closeTabRequested, object: nil)
            }
            .keyboardShortcut("w", modifiers: .command)

            Divider()

            Button("新建窗口") {
                NotificationCenter.default.post(name: .newWindowRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
        }

        // 连接菜单
        CommandMenu("连接") {
            Button("连接选中会话") {
                NotificationCenter.default.post(name: .connectSessionRequested, object: nil)
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button("断开当前连接") {
                NotificationCenter.default.post(name: .disconnectSessionRequested, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Divider()

            Button("断开所有连接") {
                NotificationCenter.default.post(name: .disconnectAllRequested, object: nil)
            }
        }

        // 视图菜单
        CommandMenu("视图") {
            Button("切换侧边栏") {
                NotificationCenter.default.post(name: .toggleSidebarRequested, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Button("聚焦搜索") {
                NotificationCenter.default.post(name: .focusSidebarSearchRequested, object: nil)
            }
            .keyboardShortcut("l", modifiers: .command)

            Divider()

            Button("下一个标签页") {
                NotificationCenter.default.post(name: .nextTabRequested, object: nil)
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])

            Button("上一个标签页") {
                NotificationCenter.default.post(name: .previousTabRequested, object: nil)
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])

            Divider()

            // 直接选择标签页 (Cmd+1 到 Cmd+9)
            ForEach(1...9, id: \.self) { index in
                Button("标签页 \(index)") {
                    NotificationCenter.default.post(
                        name: .selectTabRequested,
                        object: nil,
                        userInfo: ["index": index - 1]
                    )
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
            }
        }

        // 终端菜单
        CommandMenu("终端") {
            Button("清屏") {
                NotificationCenter.default.post(name: .clearTerminalRequested, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("搜索") {
                NotificationCenter.default.post(name: .searchTerminalRequested, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)

            Divider()

            Button("增大字体") {
                NotificationCenter.default.post(name: .increaseFontRequested, object: nil)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("减小字体") {
                NotificationCenter.default.post(name: .decreaseFontRequested, object: nil)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("重置字体大小") {
                NotificationCenter.default.post(name: .resetFontRequested, object: nil)
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            Button("SFTP 文件管理器") {
                NotificationCenter.default.post(name: .sftpPanelRequested, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("隧道管理器") {
                NotificationCenter.default.post(name: .tunnelManagerRequested, object: nil)
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])

            Button("快捷命令") {
                NotificationCenter.default.post(name: .quickCommandsRequested, object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Button("命令编辑区") {
                NotificationCenter.default.post(name: .composePaneRequested, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        // 帮助菜单扩展
        CommandGroup(replacing: .help) {
            Button("ShellMate 帮助") {
                // 打开帮助文档
                if let url = URL(string: "https://shellmate.app/docs") {
                    NSWorkspace.shared.open(url)
                }
            }
            .keyboardShortcut("?", modifiers: .command)

            Divider()

            Button("访问官网") {
                if let url = URL(string: "https://shellmate.app") {
                    NSWorkspace.shared.open(url)
                }
            }

            Button("反馈问题") {
                if let url = URL(string: "https://github.com/shellmate/shellmate/issues") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Button("检查更新...") {
                // 检查更新逻辑
            }
        }
    }

    // MARK: - 外观配置

    private func configureAppearance() {
        // 配置窗口外观
        // 在这里可以设置全局外观偏好

        // W15.1 冷启动优化：在 UI 就绪后立即在后台预热 HighlightEngine
        // 避免首次 SSH 连接时正则编译阻塞主线程（HighlightEngine 是 @MainActor 单例）
        Task { @MainActor in
            _ = HighlightEngine.shared
        }
    }
}

// MARK: - 设置窗口

/// 设置页导航项
private enum SettingsTab: String, CaseIterable, Identifiable {
    case general    = "通用"
    case highlight  = "关键词高亮"
    case appearance = "外观"
    case terminal   = "终端"
    case security   = "安全"
    case sync       = "同步"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:    return "gear"
        case .highlight:  return "highlighter"
        case .appearance: return "paintbrush"
        case .terminal:   return "terminal"
        case .security:   return "lock.shield"
        case .sync:       return "icloud"
        }
    }
}

/// 设置主视图（640×520，不可调整大小）
/// 左侧 160pt 导航 + 右侧 480pt 内容区
struct SettingsView: View {

    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // 左侧导航
            settingsNav
                .frame(width: 160)

            Divider()

            // 右侧内容
            settingsContent
                .frame(width: 480)
        }
        .frame(width: 640, height: 520)
    }

    // MARK: - 导航列

    private var settingsNav: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                settingsNavItem(tab)
            }
            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 8)
        .background(DesignTokens.Colors.surfacePanel)
    }

    private func settingsNavItem(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        return Button(action: { selectedTab = tab }) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected
                        ? DesignTokens.Colors.accentPrimary
                        : DesignTokens.Colors.textSecondary)
                    .frame(width: 18)

                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected
                        ? DesignTokens.Colors.textPrimary
                        : DesignTokens.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? DesignTokens.Colors.accentPrimary.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 内容区

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView()
        case .highlight:
            HighlightSettingsView()
        case .appearance:
            AppearanceSettingsView()
        case .terminal:
            TerminalSettingsView()
        case .security:
            SecuritySettingsView()
        case .sync:
            SyncSettingsView()
        }
    }
}

// MARK: - 通用设置视图

/// 通用设置面板（W14 完善）
struct GeneralSettingsView: View {

    @AppStorage("general.startupBehavior")  private var startupBehavior: String = "last"
    @AppStorage("general.confirmOnClose")   private var confirmOnClose: Bool = true
    @AppStorage("general.checkUpdates")     private var checkUpdates: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 启动行为
                VStack(alignment: .leading, spacing: 8) {
                    Text("启动行为")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Picker("启动时", selection: $startupBehavior) {
                        Text("恢复上次会话").tag("last")
                        Text("显示欢迎界面").tag("welcome")
                        Text("空白界面").tag("blank")
                    }
                    .pickerStyle(.radioGroup)
                    .font(.system(size: 12))
                }

                Divider()

                // 关闭行为
                VStack(alignment: .leading, spacing: 8) {
                    Text("关闭确认")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Toggle(isOn: $confirmOnClose) {
                        Text("关闭活跃连接时弹窗确认")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    .toggleStyle(.checkbox)
                }

                Divider()

                // 更新
                VStack(alignment: .leading, spacing: 8) {
                    Text("更新")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Toggle(isOn: $checkUpdates) {
                        Text("自动检查更新")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    .toggleStyle(.checkbox)

                    Button("立即检查更新…") {}
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 终端设置视图

/// S05 — 终端行为设置面板
struct TerminalSettingsView: View {

    @AppStorage("terminal.scrollbackLines")  private var scrollbackLines: Int = 10000
    @AppStorage("terminal.bellEnabled")      private var bellEnabled: Bool = true
    @AppStorage("terminal.closeOnExit")      private var closeOnExit: Bool = false
    @AppStorage("terminal.copyOnSelect")     private var copyOnSelect: Bool = true

    /// 候选滚动缓冲行数（方便 Picker 使用）
    private let scrollbackOptions: [(label: String, value: Int)] = [
        ("1,000 行",   1_000),
        ("5,000 行",   5_000),
        ("10,000 行",  10_000),
        ("50,000 行",  50_000),
        ("100,000 行", 100_000),
        ("无限制",     0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // 回滚缓冲区
                VStack(alignment: .leading, spacing: 8) {
                    Text("回滚缓冲区")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    HStack(spacing: 12) {
                        Text("最大行数")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .frame(width: 100, alignment: .leading)

                        Picker("", selection: $scrollbackLines) {
                            ForEach(scrollbackOptions, id: \.value) { opt in
                                Text(opt.label).tag(opt.value)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }

                    Text("PRD §3.3.3：默认 10,000 行，0 表示无限制（谨慎使用，内存消耗较大）")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }

                Divider()

                // 行为设置
                VStack(alignment: .leading, spacing: 8) {
                    Text("行为")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Toggle(isOn: $bellEnabled) {
                        Text("启用响铃（Terminal Bell）")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    .toggleStyle(.checkbox)

                    Toggle(isOn: $copyOnSelect) {
                        Text("选中时自动复制到剪贴板")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    .toggleStyle(.checkbox)

                    Toggle(isOn: $closeOnExit) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("进程退出后自动关闭标签页")
                                .font(.system(size: 12))
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Text("远端 shell 退出后自动关闭对应标签页")
                                .font(.system(size: 10))
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 同步设置视图

/// iCloud 同步设置面板（W14 完善）
struct SyncSettingsView: View {

    @AppStorage("sync.enabled")      private var syncEnabled: Bool = true
    @AppStorage("sync.syncKeychain") private var syncKeychain: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // iCloud 同步开关
                VStack(alignment: .leading, spacing: 8) {
                    Text("iCloud 同步")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Toggle(isOn: $syncEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("启用 iCloud 同步")
                                .font(.system(size: 12))
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Text("在所有 Mac 设备间同步会话配置")
                                .font(.system(size: 10))
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }

                Divider()

                // 凭据同步说明
                VStack(alignment: .leading, spacing: 8) {
                    Text("凭据与安全")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                        Text("SSH 密码和私钥存储在本地 Keychain 中，不会通过 iCloud 同步。在新设备上首次连接时需要重新输入凭据。")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(DesignTokens.Colors.surfaceCard)
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }
}
