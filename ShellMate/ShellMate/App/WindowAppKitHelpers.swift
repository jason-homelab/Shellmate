import SwiftUI

private let windowModeKey = "appearance.windowMode"

// MARK: - 窗口标签禁用器

final class _WindowTabbingDisablerView: NSView {
    private var toolbarObserver: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.tabbingMode = .disallowed
        window?.toolbarStyle = .expanded   // 工具栏独立一行
        applyAppearance(to: window)

        // 关闭 NSToolbarItem 的系统胶囊背景（macOS 14+ 默认 isBordered=true）
        // SwiftUI 异步填充工具栏 items，需多次延迟尝试 + KVO 兜底
        scheduleToolbarBorderDisable()
        observeToolbarChanges()
    }

    deinit {
        if let observer = toolbarObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func scheduleToolbarBorderDisable() {
        // 多次延迟覆盖 SwiftUI 的异步 toolbar 填充
        Task { @MainActor [weak self] in
            let delaysNs: [UInt64] = [0, 50_000_000, 200_000_000, 500_000_000, 1_000_000_000]
            for ns in delaysNs {
                if ns > 0 { try? await Task.sleep(nanoseconds: ns) }
                self?.disableToolbarItemBorders()
            }
        }
    }

    private func observeToolbarChanges() {
        // 监听窗口工具栏变更，每次变更后再次清除 isBordered
        toolbarObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.disableToolbarItemBorders()
        }
    }

    private func disableToolbarItemBorders() {
        guard let toolbar = window?.toolbar else { return }
        for item in toolbar.items {
            item.isBordered = false
            // SwiftUI 可能把 HStack 包在 NSToolbarItemGroup 里，需要递归关闭
            if let group = item as? NSToolbarItemGroup {
                for subitem in group.subitems {
                    subitem.isBordered = false
                }
            }
        }
        toolbar.allowsExtensionItems = false

        // 在 principal 与 primaryAction 之间注入 flexibleSpace，强制右侧贴右
        injectFlexibleSpace(into: toolbar)
    }

    /// 在最后一项（primaryAction）之前注入 .flexibleSpace，强制其贴右。
    /// 不依赖 principal 是否存在，无 session 时也能正确右对齐。
    private func injectFlexibleSpace(into toolbar: NSToolbar) {
        let items = toolbar.items
        if items.contains(where: { $0.itemIdentifier == .flexibleSpace }) { return }
        guard items.count >= 2 else { return }
        toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: items.count - 1)
    }

    private func applyAppearance(to window: NSWindow?) {
        guard let window else { return }
        let mode = UserDefaults.standard.string(forKey: windowModeKey) ?? "dark"
        switch mode {
        case "light": window.appearance = NSAppearance(named: .aqua)
        case "dark":  window.appearance = NSAppearance(named: .darkAqua)
        default:      window.appearance = nil  // auto — 跟随 NSApp.appearance
        }
    }
}

struct WindowTabbingDisabler: NSViewRepresentable {
    func makeNSView(context: Context) -> _WindowTabbingDisablerView {
        _WindowTabbingDisablerView()
    }
    func updateNSView(_ nsView: _WindowTabbingDisablerView, context: Context) {}
}

// MARK: - 主窗口透明度 / Vibrancy 配置器

final class _WindowTransparencyView: NSView {

    var opacity: Double = 0 { didSet { applyToWindow() } }
    var windowMode: String = "dark" { didSet { applyToWindow() } }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyToWindow()
    }

    func applyToWindow() {
        guard let window else { return }
        // "light" = 浅色；其余（dark / auto）= 深色优先
        if windowMode == "light" {
            window.appearance = NSAppearance(named: .aqua)
        } else {
            window.appearance = NSAppearance(named: .darkAqua)
        }
        window.titlebarAppearsTransparent = true
        if opacity > 0 {
            window.isOpaque = false
            let alpha = max(0.0, 1.0 - opacity / 100.0)
            window.backgroundColor = NSColor(
                srgbRed: 0.027, green: 0.039, blue: 0.067, alpha: alpha
            )
        } else {
            window.isOpaque = true
            // 不透明时用 Void #070a11，使透明标题栏呈现与 HTML titlebar 一致的深空色
            window.backgroundColor = NSColor(
                srgbRed: 0.027, green: 0.039, blue: 0.067, alpha: 1.0
            )
        }
    }
}

struct WindowTransparencyConfigurator: NSViewRepresentable {
    let opacity: Double
    let windowMode: String

    func makeNSView(context: Context) -> _WindowTransparencyView {
        let view = _WindowTransparencyView()
        view.opacity = opacity
        view.windowMode = windowMode
        return view
    }

    func updateNSView(_ nsView: _WindowTransparencyView, context: Context) {
        nsView.opacity = opacity
        nsView.windowMode = windowMode
    }
}
