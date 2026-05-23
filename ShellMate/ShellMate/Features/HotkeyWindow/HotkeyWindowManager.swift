import AppKit
import SwiftUI

// MARK: - Hotkey Window 管理器

/// 全局快捷键浮动终端面板管理器
/// 默认快捷键 ⌥Space，覆盖在任意 App 之上，失焦自动隐藏
/// 面板功能：快速会话切换 / 启动器（连接后在主窗口渲染）
@MainActor
final class HotkeyWindowManager {

    // MARK: - 单例

    static let shared = HotkeyWindowManager()

    // MARK: - 私有状态

    private var panel: NSPanel?
    /// NSHostingView 引用，用于在 setSessionStore 后更新 rootView
    private var hostingView: NSHostingView<AnyView>?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// 注入的 SessionStore（由 ContentView.onAppear 设置）
    private weak var sessionStore: SessionStore?
    /// 当 sessionStore 尚未注入时使用的空占位 store
    private let emptyStore = SessionStore()

    /// 默认 key：⌥Space（keyCode=49，modifier=.option）
    private let hotkeyCode: UInt16 = 49
    private let hotkeyModifiers: NSEvent.ModifierFlags = .option

    // MARK: - 初始化

    private init() {
        UserDefaults.standard.register(defaults: [
            UserDefaultsKeys.autoHideOnBlur: true
        ])
    }

    // MARK: - 公开 API

    /// 从 ContentView 注入 SessionStore，保持响应式更新
    func setSessionStore(_ store: SessionStore) {
        sessionStore = store
        // 若面板已构建，实时更新 rootView 使会话列表响应最新数据
        hostingView?.rootView = makeRootView()
    }

    /// 启动全局 & 本地快捷键监听（在 applicationDidFinishLaunching 调用）
    func startMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isHotkey(event) else { return }
            Task { @MainActor [weak self] in self?.toggle() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isHotkey(event) else { return event }
            Task { @MainActor [weak self] in self?.toggle() }
            return nil
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
                // 移除 .titled 以隐藏原生标题栏及红黄绿按钮，改用 SwiftUI 自定义标题条
                .closable,
                .resizable,
                .fullSizeContentView,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )

        // 强制深色外观，与主应用保持一致
        panel.appearance               = NSAppearance(named: .darkAqua)
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel            = true
        panel.level                      = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)
        panel.collectionBehavior         = [.canJoinAllSpaces, .auxiliary, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed       = false
        panel.animationBehavior          = .utilityWindow
        panel.backgroundColor            = .clear

        let hv = NSHostingView(rootView: makeRootView())
        self.hostingView = hv
        panel.contentView = hv

        // 失焦自动隐藏
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self, weak panel] _ in
            guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.autoHideOnBlur) else { return }
            panel?.orderOut(nil)
            _ = self
        }

        return panel
    }

    /// 构建注入了 SessionStore 的 SwiftUI 根视图
    private func makeRootView() -> AnyView {
        let store = sessionStore ?? emptyStore
        let onClose: () -> Void = { [weak self] in self?.hide() }
        return AnyView(
            HotkeyTerminalContentView(onClose: onClose)
                .environmentObject(store)
        )
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
        event.keyCode == hotkeyCode &&
        event.modifierFlags.intersection([.command, .option, .control, .shift]) == hotkeyModifiers
    }

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let autoHideOnBlur = "hotkey.autoHideOnBlur"
        static let customShortcut = "hotkey.customShortcut"
    }
}

// MARK: - Hotkey 终端内容视图

struct HotkeyTerminalContentView: View {

    @EnvironmentObject private var sessionStore: SessionStore
    var onClose: () -> Void

    var body: some View {
        let base = VStack(spacing: 0) {
            titleBar
            Divider().background(Color.white.opacity(0.08))
            sessionListBody
        }
        .background(DesignTokens.Colors.surfaceWindow)

        if #available(macOS 14.0, *) {
            base.onKeyPress(.escape) { onClose(); return .handled }
        } else {
            base
        }
    }

    // MARK: - 标题条

    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal.fill")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("快捷终端")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text("⌥Space")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(DesignTokens.Colors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
                )

            Spacer()

            AutoHideToggleButton()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(DesignTokens.Colors.surfaceCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("关闭（⌥Space 再次呼出）")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 8)
        .background(DesignTokens.Colors.surfaceWindow)
    }

    // MARK: - 会话列表主体

    @ViewBuilder
    private var sessionListBody: some View {
        if sessionStore.sessions.isEmpty {
            hotkeyEmptyState
        } else {
            HotkeySessionListView(onClose: onClose)
        }
    }

    // MARK: - 空状态（无会话）

    private var hotkeyEmptyState: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // 图标容器 — 与 EmptyStateView 统一用 64pt
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            DesignTokens.Colors.accentPrimary.opacity(0.10),
                            DesignTokens.Colors.accentIndigo.opacity(0.10)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(0.18), lineWidth: 0.75)
                    )
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(LinearGradient(
                        colors: [DesignTokens.Colors.accentPrimary, DesignTokens.Colors.accentIndigo],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("还没有会话")
                    .font(DesignTokens.Typography.labelLargeAlt)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text("新建一个 SSH 连接，即可在此快速呼出")
                    .font(.system(size: 12.5))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                AppEvent.postOpenNewSession()
                onClose()
            } label: {
                Label("新建会话", systemImage: "plus")
                    .font(.system(size: 12.5, weight: .medium))
            }
            .buttonStyle(HotkeyPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xxl)
    }
}

// MARK: - 会话列表视图

private struct HotkeySessionListView: View {

    @EnvironmentObject private var sessionStore: SessionStore
    var onClose: () -> Void

    private var connectedSessions: [Session] {
        sessionStore.sessions.filter { $0.connectionState == .connected }
    }
    private var otherSessions: [Session] {
        sessionStore.sessions.filter { $0.connectionState != .connected }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if !connectedSessions.isEmpty {
                        sectionHeader("已连接", count: connectedSessions.count)
                        ForEach(connectedSessions) { session in
                            HotkeySessionRowView(session: session, onClose: onClose)
                            if session.id != connectedSessions.last?.id {
                                rowDivider
                            }
                        }
                    }

                    if !otherSessions.isEmpty {
                        if !connectedSessions.isEmpty {
                            Divider()
                                .background(DesignTokens.Colors.borderPrimary)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                        }
                        sectionHeader("其他会话", count: otherSessions.count)
                        ForEach(otherSessions) { session in
                            HotkeySessionRowView(session: session, onClose: onClose)
                            if session.id != otherSessions.last?.id {
                                rowDivider
                            }
                        }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
            }

            // 底部工具栏
            Divider().background(DesignTokens.Colors.borderPrimary)
            HStack {
                Spacer()
                Button {
                    AppEvent.postOpenNewSession()
                    onClose()
                } label: {
                    Label("新建会话", systemImage: "plus")
                        .font(DesignTokens.Typography.labelMedium)
                }
                .buttonStyle(HotkeyPrimaryButtonStyle())
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.surfaceWindow)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Text("\(count)")
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(DesignTokens.Colors.surfaceCard)
                .clipShape(Capsule())
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var rowDivider: some View {
        Divider()
            .background(DesignTokens.Colors.borderPrimary.opacity(0.5))
            .padding(.leading, DesignTokens.Spacing.lg + 26 + DesignTokens.Spacing.sm)
    }
}

// MARK: - 会话行视图

private struct HotkeySessionRowView: View {

    let session: Session
    var onClose: () -> Void
    @State private var isHovering = false

    private var isConnected: Bool { session.connectionState == .connected }

    var body: some View {
        Button {
            AppEvent.postOpenSession(sessionId: session.id)
            NSApp.activate(ignoringOtherApps: true)
            onClose()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // 状态指示点
                Circle()
                    .fill(session.connectionState.dotColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: isConnected ? session.connectionState.dotColor.opacity(0.5) : .clear,
                            radius: 3, x: 0, y: 0)

                // 图标背景
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isConnected
                              ? DesignTokens.Colors.statusConnected.opacity(0.12)
                              : DesignTokens.Colors.surfaceCard)
                    Image(systemName: session.connectionType.iconName)
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(isConnected
                                         ? DesignTokens.Colors.statusConnected
                                         : DesignTokens.Colors.textSecondary)
                }
                .frame(width: 22, height: 22)

                // 名称 + 主机
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.name)
                        .font(DesignTokens.Typography.labelLarge)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                    Text("\(session.username)@\(session.host):\(session.port)")
                        .font(DesignTokens.Typography.codeTiny)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                // 操作标签
                Text(isConnected ? "打开" : "连接")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(isConnected
                                     ? DesignTokens.Colors.accentPrimary
                                     : DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (isConnected ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.surfaceCard)
                            .opacity(isHovering ? (isConnected ? 0.18 : 0.8) : (isConnected ? 0.10 : 0.5))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(
                                (isConnected ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.borderPrimary)
                                    .opacity(isConnected ? 0.3 : 0.8),
                                lineWidth: 0.5
                            )
                    )
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                isHovering
                    ? DesignTokens.Colors.surfaceHover
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - 自动隐藏切换按钮

private struct AutoHideToggleButton: View {

    @AppStorage(HotkeyWindowManager.UserDefaultsKeys.autoHideOnBlur)
    private var autoHide: Bool = true

    var body: some View {
        Button { autoHide.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: autoHide ? "pin.slash" : "pin.fill")
                    .font(.system(size: 9, weight: .medium))
                Text(autoHide ? "失焦隐藏" : "保持显示")
                    .font(.system(size: 10))
            }
            .foregroundColor(autoHide
                             ? DesignTokens.Colors.textTertiary
                             : DesignTokens.Colors.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(DesignTokens.Colors.surfaceCard.opacity(autoHide ? 0.6 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.borderPrimary, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(autoHide ? "当前：失焦自动隐藏。点击保持显示" : "当前：保持显示。点击启用失焦隐藏")
    }
}

// MARK: - Hotkey 主按钮样式

private struct HotkeyPrimaryButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovering ? .white : DesignTokens.Colors.accentPrimary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                    .fill(
                        isHovering
                            ? DesignTokens.Colors.accentPrimary.opacity(configuration.isPressed ? 0.9 : 1.0)
                            : DesignTokens.Colors.accentPrimary.opacity(0.12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(DesignTokens.Colors.accentPrimary.opacity(isHovering ? 0 : 0.28), lineWidth: 0.75)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.hover) { isHovering = hovering }
            }
    }
}

// MARK: - 预览

#Preview("Hotkey 快捷终端 — 有会话") {
    HotkeyTerminalContentView(onClose: {})
        .environmentObject(SessionStore())
        .frame(width: 960, height: 380)
}

#Preview("Hotkey 快捷终端 — 空状态") {
    HotkeyTerminalContentView(onClose: {})
        .environmentObject(SessionStore())
        .frame(width: 960, height: 300)
}
