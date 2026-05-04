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

    /// 窗口外观模式："auto"（跟随系统）/ "light"（浅色）/ "dark"（深色）
    @AppStorage("appearance.windowMode") private var windowMode: String = "dark"

    // MARK: - 应用场景

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    configureAppearance()
                }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
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
                // 与侧边栏双击/Tab栏+按钮保持一致：连接选中会话或打开新建会话表单
                NotificationCenter.default.post(name: .newTabRequested, object: nil)
            }
            .keyboardShortcut("t", modifiers: .command)
            // 说明：⌘T 触发与 Tab 栏 + 按钮相同的逻辑，工具栏不再重复展示该按钮

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
            // 外观模式子菜单
            Menu("外观模式") {
                Button(action: { windowMode = "auto" }) {
                    Label(
                        windowMode == "auto" ? "✓ 跟随系统" : "跟随系统",
                        systemImage: "circle.lefthalf.filled"
                    )
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button(action: { windowMode = "light" }) {
                    Label(
                        windowMode == "light" ? "✓ 浅色模式" : "浅色模式",
                        systemImage: "sun.max"
                    )
                }
                .keyboardShortcut("2", modifiers: [.command, .option])

                Button(action: { windowMode = "dark" }) {
                    Label(
                        windowMode == "dark" ? "✓ 深色模式" : "深色模式",
                        systemImage: "moon"
                    )
                }
                .keyboardShortcut("3", modifiers: [.command, .option])
            }

            Divider()

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
                // 使用 NSLocalizedString + String.localizedStringWithFormat 以支持菜单栏多语言
                Button(String.localizedStringWithFormat(
                    NSLocalizedString("标签页 %d", comment: "Tab selection menu item"), index
                )) {
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

        // 工具菜单（Hotkey Window 等快捷工具）
        CommandMenu("工具") {
            Button("呼出 / 隐藏 Hotkey 终端") {
                NotificationCenter.default.post(name: .hotkeyWindowToggleRequested, object: nil)
            }
            // 注意：⌥Space 由全局 NSEvent monitor 直接捕获，菜单此处仅作发现性入口
            // （.option + .space 在 SwiftUI Commands 中无法可靠绑定）
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
        // W15.1 冷启动优化：在 UI 就绪后立即在后台预热 HighlightEngine
        Task { @MainActor in
            _ = HighlightEngine.shared
        }
        // 注：NSApp.appearance 由 AppDelegate.windowModeObserver (KVO) 统一管理
    }
}

