import AppKit
import SwiftUI

// MARK: - Hotkey Window 管理器（任务 13.8）

/// 全局快捷键浮动终端面板管理器
/// 默认快捷键 ⌥Space，覆盖在任意 App 之上，失焦自动隐藏
/// 对标 iTerm2 Hotkey Window
///
/// - Note: `NSEvent.addGlobalMonitorForEvents` 在 App Store Sandbox 版需要
///   Input Monitoring 权限（Privacy → Input Monitoring）；Direct 版无此限制。
final class HotkeyWindowManager {

    // MARK: - 单例

    static let shared = HotkeyWindowManager()

    // MARK: - 私有状态

    private var panel: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// 默认 key：⌥Space（keyCode=49，modifier=.option）
    private let hotkeyCode: UInt16 = 49
    private let hotkeyModifiers: NSEvent.ModifierFlags = .option

    // MARK: - 初始化

    private init() {
        // 注册默认偏好
        UserDefaults.standard.register(defaults: [
            UserDefaultsKeys.autoHideOnBlur: true
        ])
    }

    // MARK: - 公开 API

    /// 启动全局 & 本地快捷键监听（在 applicationDidFinishLaunching 调用）
    func startMonitoring() {
        // 全局监听：任意 App 激活时响应（需 Input Monitoring 权限，Sandbox 版降级处理）
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isHotkey(event) else { return }
            DispatchQueue.main.async { self.toggle() }
        }

        // 本地监听：ShellMate 自身为 frontmost 时响应（Sandbox 无需额外权限）
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isHotkey(event) else { return event }
            DispatchQueue.main.async { self.toggle() }
            return nil   // 消费事件，不传递给当前 firstResponder
        }
    }

    /// 停止监听（在 applicationWillTerminate 调用）
    func stopMonitoring() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    /// 切换 Hotkey Window 显示/隐藏
    func toggle() {
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - 私有：显示/隐藏

    private func show() {
        if panel == nil { panel = buildPanel() }
        guard let panel else { return }
        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    // MARK: - 私有：面板构建

    private func buildPanel() -> NSPanel {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame  = panelFrame(for: screen)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .fullSizeContentView,
                .nonactivatingPanel       // 呼出时不强制激活 ShellMate 主窗口
            ],
            backing: .buffered,
            defer: false
        )

        // 外观
        panel.title                      = "ShellMate — Hotkey Terminal"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel            = true
        panel.level                      = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)
        panel.collectionBehavior         = [.canJoinAllSpaces, .auxiliary, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed       = false
        panel.animationBehavior          = .utilityWindow
        panel.backgroundColor            = .clear

        // 内容：SwiftUI 本地终端视图
        let content = HotkeyTerminalContentView {
            panel.orderOut(nil)
        }
        panel.contentView = NSHostingView(rootView: content)

        // 失焦自动隐藏
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self, weak panel] _ in
            guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.autoHideOnBlur) else { return }
            panel?.orderOut(nil)
            _ = self  // 保持引用存活
        }

        return panel
    }

    // MARK: - 私有：定位

    private func positionPanel(_ panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        panel.setFrame(panelFrame(for: screen), display: true)
    }

    /// 面板尺寸：80% 屏宽 × 40% 屏高，定位于屏幕上方 10% 处
    private func panelFrame(for screen: NSScreen) -> NSRect {
        let sf     = screen.visibleFrame
        let width  = sf.width  * 0.80
        let height = sf.height * 0.40
        let x      = sf.minX + (sf.width - width) / 2
        let y      = sf.maxY - height - sf.height * 0.10
        return NSRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - 私有：快捷键判断

    private func isHotkey(_ event: NSEvent) -> Bool {
        // 仅响应 ⌥Space，不与含其他修饰键的组合冲突
        event.keyCode == hotkeyCode &&
        event.modifierFlags.intersection([.command, .option, .control, .shift]) == hotkeyModifiers
    }

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let autoHideOnBlur = "hotkey.autoHideOnBlur"
        static let customShortcut = "hotkey.customShortcut"   // 预留，暂未实现自定义
    }
}

// MARK: - Hotkey 终端内容视图

/// Hotkey Window 内部的终端视图
/// 上方紧凑标题条 + 下方占位区域（本地Shell功能已移除）
struct HotkeyTerminalContentView: View {

    var onClose: () -> Void

    // MARK: - 视图

    var body: some View {
        let base = VStack(spacing: 0) {
            titleBar
            TerminalPlaceholderView()
        }
        .background(Color.black)

        // ⎋ 关闭面板（onKeyPress 需 macOS 14+，低版本忽略，ESC 通过 NSPanel responder chain 处理）
        if #available(macOS 14.0, *) {
            base.onKeyPress(.escape) {
                onClose()
                return .handled
            }
        } else {
            base
        }
    }

    // MARK: - 标题条

    private var titleBar: some View {
        HStack(spacing: 8) {
            // 图标 + 标题
            Image(systemName: "terminal.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))

            Text("Hotkey Terminal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.75))

            Text("⌥Space")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Spacer()

            // 自动隐藏状态提示
            AutoHideToggleButton()

            // 关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("关闭（⌥Space 再次呼出）")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        // 与终端视图背景融合：深色磨砂
        .background(
            Color(NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }
}

// MARK: - 自动隐藏切换按钮

private struct AutoHideToggleButton: View {

    @AppStorage(HotkeyWindowManager.UserDefaultsKeys.autoHideOnBlur)
    private var autoHide: Bool = true

    var body: some View {
        Button {
            autoHide.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: autoHide ? "pin.slash" : "pin.fill")
                    .font(.system(size: 9, weight: .medium))
                Text(autoHide ? "失焦隐藏" : "保持显示")
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(autoHide ? 0.40 : 0.70))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(autoHide ? 0.06 : 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(autoHide ? "当前：失焦自动隐藏。点击保持显示" : "当前：保持显示。点击启用失焦隐藏")
    }
}

// MARK: - 预览

#Preview("Hotkey 终端面板") {
    HotkeyTerminalContentView(onClose: {})
        .frame(width: 960, height: 400)
}
