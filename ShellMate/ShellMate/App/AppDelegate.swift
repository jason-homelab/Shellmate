import AppKit

/// 应用程序代理
/// 处理应用级别的生命周期事件
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 应用生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 应用启动完成
        print("ShellMate 启动完成")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 应用即将终止
        // 保存 Core Data 上下文
        PersistenceController.shared.save()
        print("ShellMate 即将终止")
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
        print("打开 URL: \(url)")
    }

    // MARK: - Dock 菜单

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        // 新建会话
        let newSessionItem = NSMenuItem(
            title: "新建会话",
            action: #selector(newSession),
            keyEquivalent: ""
        )
        menu.addItem(newSessionItem)

        // 新建窗口
        let newWindowItem = NSMenuItem(
            title: "新建窗口",
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
}
