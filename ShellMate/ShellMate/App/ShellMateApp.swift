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

    }

    // MARK: - 菜单命令

    @CommandsBuilder
    private var appCommands: some Commands {

        // ── 设置（⌘,）：替换系统默认 Settings 菜单，改为打开自定义浮动面板 ──
        CommandGroup(replacing: .appSettings) {
            Button("设置...") {
                NotificationCenter.default.post(name: .settingsRequested, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        // ── File 菜单 ──────────────────────────────────────────────────────────
        // 移除"新建窗口"（低频操作），改放至 Window 菜单
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
        }

        // ── 会话 菜单 ──────────────────────────────────────────────────────────
        CommandMenu("会话") {
            Button("连接选中会话") {
                NotificationCenter.default.post(name: .connectSessionRequested, object: nil)
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button("断开当前连接") {
                NotificationCenter.default.post(name: .disconnectSessionRequested, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Divider()

            // 危险操作与常用操作通过 Divider 隔离，防止误触
            Button("断开所有连接") {
                NotificationCenter.default.post(name: .disconnectAllRequested, object: nil)
            }

            Divider()

            Button("导入会话...") {
                NotificationCenter.default.post(name: .importSessionsRequested, object: nil)
            }

            Button("导出会话...") {
                NotificationCenter.default.post(name: .exportSessionsRequested, object: nil)
            }
        }

        // ── View 菜单：仅保留外观 + 视图显隐操作 ────────────────────────────
        CommandGroup(after: .toolbar) {
            Divider()

            // 外观模式：用 Toggle 实现选中态，Accessibility 正确识别，无硬编码 ✓ 字符
            Menu("外观模式") {
                Toggle(isOn: Binding(
                    get: { windowMode == "auto" },
                    set: { _ in windowMode = "auto" }
                )) {
                    Label("跟随系统", systemImage: "circle.lefthalf.filled")
                }
                Toggle(isOn: Binding(
                    get: { windowMode == "light" },
                    set: { _ in windowMode = "light" }
                )) {
                    Label("浅色模式", systemImage: "sun.max")
                }
                Toggle(isOn: Binding(
                    get: { windowMode == "dark" },
                    set: { _ in windowMode = "dark" }
                )) {
                    Label("深色模式", systemImage: "moon")
                }
            }

            Divider()

            Button("切换侧边栏") {
                NotificationCenter.default.post(name: .toggleSidebarRequested, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            // ⌘⌥L 替代原 ⌘L，避免与 Safari/Finder 等应用的"定位"快捷键语义冲突
            Button("聚焦搜索") {
                NotificationCenter.default.post(name: .focusSidebarSearchRequested, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .option])

            Divider()

            Button("呼出 / 隐藏 Hotkey 终端") {
                NotificationCenter.default.post(name: .hotkeyWindowToggleRequested, object: nil)
            }
        }

        // ── 终端 菜单（终端操作 + 字体 + 标签页切换）────────────────────────
        CommandMenu("终端") {
            Button("清屏") {
                NotificationCenter.default.post(name: .clearTerminalRequested, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)

            // ⌘⌥F 替代原 ⌘F，避免与系统 Edit > Find（⌘F）静默冲突
            Button("搜索") {
                NotificationCenter.default.post(name: .searchTerminalRequested, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

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

            Button("下一个标签页") {
                NotificationCenter.default.post(name: .nextTabRequested, object: nil)
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])

            Button("上一个标签页") {
                NotificationCenter.default.post(name: .previousTabRequested, object: nil)
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])

            Divider()

            ForEach(1...9, id: \.self) { index in
                Button(String.localizedStringWithFormat(
                    NSLocalizedString("标签页 %d", comment: "Tab selection menu item"), index
                )) {
                    AppEvent.postSelectTab(index: index - 1)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: .command)
            }
        }

        // ── 工具 菜单（面板入口统一归类）────────────────────────────────────
        CommandMenu("工具") {
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

        // ── Window 菜单：新建窗口（低频，从 File 下移至此）──────────────────
        CommandGroup(after: .windowArrangement) {
            Divider()
            Button("新建窗口") {
                NotificationCenter.default.post(name: .newWindowRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
        }

        // ── Help 菜单 ──────────────────────────────────────────────────────────
        CommandGroup(replacing: .help) {
            Button("ShellMate 帮助") {
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

            Button("检查更新...") { }
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

