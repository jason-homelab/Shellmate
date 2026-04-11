import SwiftUI

// MARK: - 窗口标签禁用器

/// 原生 Window Tab Bar 禁用器
///
/// 使用 NSView 子类覆写 viewDidMoveToWindow()，该方法在 view 被加入窗口层级时
/// 由 AppKit 回调，此时 window 属性保证非 nil——比 DispatchQueue.main.async 更可靠。
///
/// 三重防御层级（配合 AppDelegate 的 ① ② ③ 共同生效）：
/// - AppDelegate.applicationWillFinishLaunching：类级别，拦截窗口创建前
/// - AppDelegate.applicationDidFinishLaunching：实例级别，覆盖已有窗口
/// - 此处：视图级别，兜底处理 NavigationSplitView 内部列窗口
final class _WindowTabbingDisablerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.tabbingMode = .disallowed
    }
}

struct WindowTabbingDisabler: NSViewRepresentable {
    func makeNSView(context: Context) -> _WindowTabbingDisablerView {
        _WindowTabbingDisablerView()
    }
    func updateNSView(_ nsView: _WindowTabbingDisablerView, context: Context) {}
}

// MARK: - 主窗口透明度 / Vibrancy 配置器

/// 背景透明度配置视图（零尺寸 NSView，挂载到主窗口以精确控制窗口背景透明度）
/// 仅附加在 ContentView，不影响设置面板等辅助窗口
final class _WindowTransparencyView: NSView {

    var opacity: Double = 0 { didSet { applyToWindow() } }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyToWindow()
    }

    func applyToWindow() {
        guard let window else { return }
        if opacity > 0 {
            window.isOpaque = false
            // opacity 0→0% 透明；100→100% 透明
            let alpha = max(0.0, 1.0 - opacity / 100.0)
            window.backgroundColor = NSColor(white: 0.07, alpha: alpha)
        } else {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
        }
    }
}

struct WindowTransparencyConfigurator: NSViewRepresentable {
    let opacity: Double

    func makeNSView(context: Context) -> _WindowTransparencyView {
        let view = _WindowTransparencyView()
        view.opacity = opacity
        return view
    }

    func updateNSView(_ nsView: _WindowTransparencyView, context: Context) {
        nsView.opacity = opacity
    }
}
