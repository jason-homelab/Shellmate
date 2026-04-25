import SwiftUI

// MARK: - ContentView 工具栏

extension ContentView {

    // MARK: - 工具栏内容

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {

        // ── 左侧：连接控制 + 功能按钮 ─────────────────────────
        // 对齐 main-window.html .toolbar 精确结构

        ToolbarItemGroup(placement: .navigation) {
            // ⏻ 连接 — Figma-Spec-v2 §03 §2 #1: power 图标
            GlassButton("连接", icon: "power", variant: .connect) {
                if let session = sessionStore.selectedSession { connectToSession(session) }
            }
            .disabled(sessionStore.selectedSession == nil)
            .help("连接选中会话 (⌘↩)")
            .keyboardShortcut(.return, modifiers: .command)

            // ⏹ 断开 — Figma-Spec-v2 §03 §2: power 状态变体
            GlassButton("断开", icon: "power", variant: .disconnect) {
                if let sessionId = tabBarStore.selectedTab?.sessionId {
                    NotificationCenter.default.post(
                        name: .disconnectActiveTerminalRequested,
                        object: nil,
                        userInfo: ["sessionId": sessionId]
                    )
                }
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("断开当前会话")

            Divider()

            // ✦ AI — .tb-btn.active { bg: primary-dim, color: primary }
            GlassButton("AI", icon: "sparkles", variant: .active) {
                NotificationCenter.default.post(name: .aiPanelRequested, object: nil)
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("AI 助手 (⌘⇧A)")
            .keyboardShortcut("a", modifiers: [.command, .shift])

            // </> 脚本
            GlassButton("脚本", icon: "chevron.left.forwardslash.chevron.right") {
                showScriptPanel = true
            }
            .help("脚本自动化 (⌘⇧S)")
            .keyboardShortcut("s", modifiers: [.command, .shift])

            // ⇅ 文件
            GlassButton("文件", icon: "arrow.up.arrow.down") {
                NotificationCenter.default.post(name: .sftpPanelRequested, object: nil)
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("文件传输 (SFTP)")

            Divider()

            // ⊡ 分屏（支持左右/上下/四格）
            Menu {
                if splitLayout == .none {
                    Button {
                        splitLayout = .horizontal; showSplitSessionPicker = true
                    } label: { Label("左右分屏", systemImage: "rectangle.split.2x1") }
                    Button {
                        splitLayout = .vertical; showSplitSessionPicker = true
                    } label: { Label("上下分屏", systemImage: "rectangle.split.1x2") }
                    Button {
                        splitLayout = .grid; showSplitSessionPicker = true
                    } label: { Label("四格分屏 (2×2)", systemImage: "rectangle.split.2x2") }
                } else {
                    Button {
                        splitLayout = .horizontal
                        if splitSessionId == nil { showSplitSessionPicker = true }
                    } label: { Label("切换为左右分屏", systemImage: "rectangle.split.2x1") }
                    Button {
                        splitLayout = .vertical
                        if splitSessionId == nil { showSplitSessionPicker = true }
                    } label: { Label("切换为上下分屏", systemImage: "rectangle.split.1x2") }
                    Button {
                        splitLayout = .grid
                        if gridSessionIds.isEmpty { showSplitSessionPicker = true }
                    } label: { Label("切换为四格分屏", systemImage: "rectangle.split.2x2") }
                    Divider()
                    Button(role: .destructive) {
                        splitLayout = .none
                        splitSessionId = nil
                        gridSessionIds = []
                    } label: { Label("关闭分屏", systemImage: "rectangle") }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: splitLayout != .none ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                        .font(.system(size: 12, weight: .medium))
                    Text("分屏")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(splitLayout != .none
                    ? DesignTokens.Colors.accentPrimary
                    : DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .help(splitLayout != .none ? "分屏管理" : "开启分屏")

            // 📋 日志 — Figma-Spec-v2 §03 §2 #10: doc.text
            GlassButton("日志", icon: "doc.text") {
                showLogPanel = true
            }
            .help("会话日志")

            // 快捷命令 — Figma-Spec-v2 §03 §2 #6: terminal
            GlassButton("命令", icon: "terminal") {
                NotificationCenter.default.post(name: .quickCommandsRequested, object: nil)
            }
            .help("快捷命令")

            // ⚒ 隧道
            GlassButton("隧道", icon: "network") {
                NotificationCenter.default.post(name: .tunnelManagerRequested, object: nil)
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("隧道管理器")

            // ■ tmux — opacity: 0.35（未来功能，对齐 HTML spec）
            GlassButton("tmux", icon: "square.split.2x1") {
                NotificationCenter.default.post(name: .tmuxManagerRequested, object: nil)
            }
            .disabled(tabBarStore.selectedTab == nil)
            .opacity(0.35)
            .help("tmux 管理器")
        }

        // ── 中间：当前会话名徽章（对齐 HTML .tb-session-name）─────
        // 胶囊徽章：bg rgba(255,255,255,0.035) + border rgba(255,255,255,0.07) + radius 14px

        ToolbarItem(placement: .principal) {
            if let session = activeSession {
                HStack(spacing: 8) {
                    // HTML: .tb-session-dot { color: rgba(226,228,240,0.20); font-size:14px }
                    Text("·")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.20))
                    Text(session.name)
                        // HTML: font-size:12px; font-weight:500; color:rgba(226,228,240,0.48)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.48))
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.20))
                }
                // HTML: .tb-session-name { padding:4px 14px; border-radius:14px; bg:rgba(255,255,255,0.035); border:1px solid rgba(255,255,255,0.07) }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.035))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.75)
                        )
                )
            } else {
                Text("ShellMate")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }

        // ── 右侧：全局操作 ────────────────────────────────────

        ToolbarItemGroup(placement: .primaryAction) {
            // ↑↓ 导出
            GlassButton("导出", icon: "shippingbox") { showSharePopover.toggle() }
                .popover(isPresented: $showSharePopover, arrowEdge: .bottom) { sessionShareMenu }
                .help("导入 / 导出会话")

            // ⌕ 搜索
            GlassButton("搜索", icon: "magnifyingglass") {
                NotificationCenter.default.post(name: .searchTerminalRequested, object: nil)
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("终端内搜索 (⌘F)")

            // ⏺ 录制 — Figma-Spec-v2 §03 §2 #8: record.circle
            GlassButton("录制", icon: "record.circle") {
                showRecordingDialog = true
            }
            .help("录制 / 历史")

            Divider()

            // ⚙ 设置
            GlassButton("设置", icon: "gearshape") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .help("设置 (⌘,)")
        }
    }

    // MARK: - 辅助计算属性

    var windowModeIcon: String {
        switch windowMode {
        case "light": return "sun.max"
        case "dark":  return "moon"
        default:      return "circle.lefthalf.filled"
        }
    }

    var preferredColorScheme: ColorScheme? {
        // "light" = 浅色；其余（dark / auto）= 深色优先（Void 设计语言以深色为基准）
        windowMode == "light" ? .light : .dark
    }

    var appLocale: Locale {
        appLanguage == "en" ? Locale(identifier: "en_US") : Locale(identifier: "zh_Hans")
    }
}
