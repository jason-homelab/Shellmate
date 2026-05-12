import AppKit

/// 应用程序代理
/// 处理应用级别的生命周期事件
class AppDelegate: NSObject, NSApplicationDelegate {

    private static let windowModeKey = "appearance.windowMode"

    // MARK: - 应用生命周期

    func applicationWillFinishLaunching(_ notification: Notification) {
        // ① 类级别：在 WindowGroup 创建任何 NSWindow 之前禁用自动标签合并
        NSWindow.allowsAutomaticWindowTabbing = false

        // ② 启动时读取用户保存的外观模式并应用（保留用户选择，默认 "light"）
        let savedMode = UserDefaults.standard.string(forKey: Self.windowModeKey) ?? "light"
        applyWindowMode(savedMode)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 对已创建窗口逐一禁用标签合并
        NSApp.windows.forEach { $0.tabbingMode = .disallowed }

        // 后续任何新窗口成为 Key 时立即禁用
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            (notification.object as? NSWindow)?.tabbingMode = .disallowed
        }

        // 监听外观模式变化（Commands/工具栏/设置均通过 UserDefaults 写入）
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            let mode = UserDefaults.standard.string(forKey: Self.windowModeKey) ?? "light"
            self?.applyWindowMode(mode)
        }

        // 启动 Hotkey Window 全局快捷键监听（⌥Space，任务 13.8）
        HotkeyWindowManager.shared.startMonitoring()

        // 监听工具栏/菜单发出的 Hotkey Window 切换通知
        NotificationCenter.default.addObserver(
            forName: .hotkeyWindowToggleRequested,
            object: nil,
            queue: .main
        ) { _ in
            HotkeyWindowManager.shared.toggle()
        }

        AppLogger.general.debug("ShellMate 启动完成")
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyWindowManager.shared.stopMonitoring()
        PersistenceController.shared.save()
        AppLogger.general.debug("ShellMate 即将终止")
    }

    // MARK: - 外观模式

    private func applyWindowMode(_ mode: String) {
        switch mode {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            // "auto" 或未知值：置 nil 表示跟随系统外观，不强制覆盖
            NSApp.appearance = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭最后一个窗口后是否退出应用
        // macOS 应用通常返回 false，保持在 Dock 中运行
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        // 支持安全的状态恢复
        return true
    }

    // MARK: - 文件打开处理

    func application(_ application: NSApplication, open urls: [URL]) {
        // 处理通过 URL Scheme 打开的链接
        // 例如: shellmate://connect?host=example.com&user=root
        for url in urls {
            handleOpenURL(url)
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "shellmate" else { return }

        // TODO: 解析 URL 并执行相应操作
        AppLogger.general.debug("打开 URL: \(url)")
    }

    // MARK: - Dock 菜单

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        // 新建会话（NSLocalizedString 使用 bundle locale，受 AppleLanguages 控制）
        let newSessionItem = NSMenuItem(
            title: NSLocalizedString("新建会话", comment: "Dock menu: create new session"),
            action: #selector(newSession),
            keyEquivalent: ""
        )
        menu.addItem(newSessionItem)

        // 新建窗口
        let newWindowItem = NSMenuItem(
            title: NSLocalizedString("新建窗口", comment: "Dock menu: open new window"),
            action: #selector(newWindow),
            keyEquivalent: ""
        )
        menu.addItem(newWindowItem)

        return menu
    }

    @objc private func newSession() {
        // 发送通知以打开新建会话弹窗
        NotificationCenter.default.post(name: .newSessionRequested, object: nil)
    }

    @objc private func newWindow() {
        // 发送通知以打开新窗口
        NotificationCenter.default.post(name: .newWindowRequested, object: nil)
    }
}

// MARK: - 通知名称

extension Notification.Name {
    // 会话操作
    static let newSessionRequested = Notification.Name("newSessionRequested")
    static let newGroupRequested = Notification.Name("newGroupRequested")
    static let newWindowRequested = Notification.Name("newWindowRequested")

    // 连接操作
    static let connectSessionRequested = Notification.Name("connectSessionRequested")
    static let disconnectSessionRequested = Notification.Name("disconnectSessionRequested")
    static let disconnectAllRequested = Notification.Name("disconnectAllRequested")

    // 标签页操作
    static let newTabRequested = Notification.Name("newTabRequested")
    static let closeTabRequested = Notification.Name("closeTabRequested")
    static let nextTabRequested = Notification.Name("nextTabRequested")
    static let previousTabRequested = Notification.Name("previousTabRequested")
    static let selectTabRequested = Notification.Name("selectTabRequested")

    // 终端操作
    static let clearTerminalRequested = Notification.Name("clearTerminalRequested")
    static let searchTerminalRequested = Notification.Name("searchTerminalRequested")
    static let increaseFontRequested = Notification.Name("increaseFontRequested")
    static let decreaseFontRequested = Notification.Name("decreaseFontRequested")
    static let resetFontRequested = Notification.Name("resetFontRequested")

    // 视图操作
    static let toggleSidebarRequested = Notification.Name("toggleSidebarRequested")
    static let toggleToolbarRequested = Notification.Name("toggleToolbarRequested")
    static let focusSidebarSearchRequested = Notification.Name("focusSidebarSearchRequested")

    // 断开连接操作（通知当前激活的 TerminalView）
    static let disconnectActiveTerminalRequested = Notification.Name("disconnectActiveTerminalRequested")

    // 功能面板操作
    static let sftpPanelRequested = Notification.Name("sftpPanelRequested")
    static let aiPanelRequested = Notification.Name("aiPanelRequested")
    static let tunnelManagerRequested = Notification.Name("tunnelManagerRequested")
    static let quickCommandsRequested = Notification.Name("quickCommandsRequested")
    static let composePaneRequested = Notification.Name("composePaneRequested")
    static let tmuxManagerRequested = Notification.Name("tmuxManagerRequested")

    // 全局 UI 操作
    static let settingsRequested = Notification.Name("settingsRequested")
    static let scriptPanelRequested = Notification.Name("scriptPanelRequested")

    // Hotkey Window（任务 13.8）
    static let hotkeyWindowToggleRequested = Notification.Name("hotkeyWindowToggleRequested")

    // 会话连接状态同步（TerminalController → SessionStore）
    static let sessionConnectionStateChanged = Notification.Name("app.shellmate.sessionConnectionStateChanged")

    // 侧边栏右键分屏（SessionListView → ContentView）
    static let splitSessionRequested = Notification.Name("app.shellmate.splitSessionRequested")

    // 导入 / 导出会话（Session 菜单）
    static let importSessionsRequested = Notification.Name("app.shellmate.importSessionsRequested")
    static let exportSessionsRequested = Notification.Name("app.shellmate.exportSessionsRequested")
}
