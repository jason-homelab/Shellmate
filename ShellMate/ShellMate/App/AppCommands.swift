import SwiftUI

/// 全局菜单栏命令定义
///
/// 使用独立 Commands struct 以支持 @FocusedObject，
/// 从当前聚焦窗口动态读取 TabBarStore，实现：
/// - 仅展示已打开的标签页（不再硬编码 Tab 1-9）
/// - 显示真实会话名（tab.title = session.name）
struct AppCommands: Commands {

    // MARK: - 聚焦窗口数据

    @FocusedObject private var tabBarStore: TabBarStore?

    // MARK: - 持久化设置

    @AppStorage("appearance.windowMode") private var windowMode: String = "dark"

    // MARK: - 菜单体

    var body: some Commands {

        // ── ShellMate 菜单：设置 (⌘,) ──────────────────────────────────────
        CommandGroup(replacing: .appSettings) {
            Button("设置...") {
                NotificationCenter.default.post(name: .settingsRequested, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        // ── File 菜单 ──────────────────────────────────────────────────────
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

            // W7 横切层通电 #3：恢复最近关闭的标签页（解 UE-P0#3）
            Button("恢复最近关闭的标签页") {
                NotificationCenter.default.post(name: .reopenLastClosedTabRequested, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(tabBarStore?.recentlyClosedTabs.isEmpty ?? true)
        }

        // ── 会话 菜单 ───────────────────────────────────────────────────────
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

        // ── View 菜单：外观 + 视图显隐 ──────────────────────────────────────
        CommandGroup(after: .toolbar) {
            Divider()

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

            Button("聚焦搜索") {
                NotificationCenter.default.post(name: .focusSidebarSearchRequested, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .option])

            Divider()

            Button("呼出 / 隐藏 Hotkey 终端") {
                NotificationCenter.default.post(name: .hotkeyWindowToggleRequested, object: nil)
            }
        }

        // ── 终端 菜单 ───────────────────────────────────────────────────────
        CommandMenu("终端") {
            terminalMenuContent
        }

        // ── 工具 菜单 ───────────────────────────────────────────────────────
        CommandMenu("工具") {
            // W8：命令面板 ⌘K — 在 ShellMate 内搜索所有功能（解 UE-P0#5）
            Button("命令面板…") {
                NotificationCenter.default.post(name: .toggleCommandPaletteRequested, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)

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

        // ── Window 菜单 ─────────────────────────────────────────────────────
        CommandGroup(after: .windowArrangement) {
            Divider()
            Button("新建窗口") {
                NotificationCenter.default.post(name: .newWindowRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
        }

        // ── Help 菜单 ───────────────────────────────────────────────────────
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

    // MARK: - 终端菜单内容（抽离避免 body 链过长导致类型检查超时）

    @ViewBuilder
    private var terminalMenuContent: some View {
        Button("清屏") {
            NotificationCenter.default.post(name: .clearTerminalRequested, object: nil)
        }
        .keyboardShortcut("k", modifiers: .command)

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

        let tabCount = tabBarStore?.tabs.count ?? 0
        Button("下一个标签页") {
            NotificationCenter.default.post(name: .nextTabRequested, object: nil)
        }
        .keyboardShortcut("]", modifiers: [.command, .shift])
        .disabled(tabCount < 2)

        Button("上一个标签页") {
            NotificationCenter.default.post(name: .previousTabRequested, object: nil)
        }
        .keyboardShortcut("[", modifiers: [.command, .shift])
        .disabled(tabCount < 2)

        // ── 动态标签页列表：仅显示已开的 Tab，标题为真实会话名 ──
        if let tabs = tabBarStore?.tabs, !tabs.isEmpty {
            Divider()

            // ⌘1–⌘9：前 9 个标签页带快捷键
            ForEach(Array(tabs.prefix(9).enumerated()), id: \.element.id) { index, tab in
                Button("\(index + 1) – \(tab.title)") {
                    AppEvent.postSelectTab(index: index)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }

            // 第 10 个标签页起：无快捷键，直接显示
            if tabs.count > 9 {
                ForEach(Array(tabs.dropFirst(9).enumerated()), id: \.element.id) { offset, tab in
                    Button("\(offset + 10) – \(tab.title)") {
                        AppEvent.postSelectTab(index: offset + 9)
                    }
                }
            }
        }
    }
}
