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
    }
}

/// 设置视图占位
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            TerminalSettingsView()
                .tabItem {
                    Label("终端", systemImage: "terminal")
                }

            SecuritySettingsView()
                .tabItem {
                    Label("安全", systemImage: "lock.shield")
                }

            SyncSettingsView()
                .tabItem {
                    Label("同步", systemImage: "icloud")
                }
        }
        .frame(width: 500, height: 400)
    }
}

/// 通用设置视图
struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("通用设置")
                .font(.headline)

            Text("W6-W7 将实现完整的设置面板")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

/// 终端设置视图
struct TerminalSettingsView: View {
    var body: some View {
        Form {
            Text("终端设置")
                .font(.headline)

            Text("W6-W7 将实现完整的终端设置")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

/// 安全设置视图
struct SecuritySettingsView: View {
    var body: some View {
        Form {
            Text("安全设置")
                .font(.headline)

            Text("W6-W7 将实现完整的安全设置")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

/// 同步设置视图
struct SyncSettingsView: View {
    var body: some View {
        Form {
            Text("iCloud 同步设置")
                .font(.headline)

            Text("W6-W7 将实现完整的同步设置")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
