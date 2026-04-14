import SwiftUI

// MARK: - ContentView 工具栏

extension ContentView {

    // MARK: - 工具栏内容

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {

        // ── 左侧：连接控制 + 功能按钮 ─────────────────────────

        ToolbarItemGroup(placement: .navigation) {
            // 连接
            Button {
                if let session = sessionStore.selectedSession { connectToSession(session) }
            } label: {
                Text("连接")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(sessionStore.selectedSession != nil
                        ? DesignTokens.Colors.accentPrimary
                        : DesignTokens.Colors.textSecondary)
            }
            .disabled(sessionStore.selectedSession == nil)
            .help("连接选中会话 (⌘↩)")
            .keyboardShortcut(.return, modifiers: .command)

            // 断开
            Button {
                if let sessionId = tabBarStore.selectedTab?.sessionId {
                    NotificationCenter.default.post(
                        name: .disconnectActiveTerminalRequested,
                        object: nil,
                        userInfo: ["sessionId": sessionId]
                    )
                }
            } label: {
                Text("断开")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(tabBarStore.selectedTab != nil
                        ? DesignTokens.Colors.statusError
                        : DesignTokens.Colors.textSecondary)
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("断开当前会话")

            Divider()

            // AI 助手（Sparkles，对齐 Figma-Spec-v2 §03 按钮3）
            Button {
                NotificationCenter.default.post(name: .aiPanelRequested, object: nil)
            } label: {
                Image(systemName: "sparkles")
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("AI 助手 (⌘⇧A)")
            .keyboardShortcut("a", modifiers: [.command, .shift])

            // 脚本自动化
            Button { showScriptPanel = true } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            .help("脚本自动化 (⌘⇧S)")
            .keyboardShortcut("s", modifiers: [.command, .shift])

            // 终端录制
            Button { showRecordingDialog = true } label: {
                Image(systemName: "record.circle")
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("终端录制")

            // SFTP
            Button {
                NotificationCenter.default.post(name: .sftpPanelRequested, object: nil)
            } label: {
                Image(systemName: "folder.badge.gearshape")
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("文件传输 (SFTP)")

            Divider()

            // 分屏（支持左右/上下/四格，对齐 Figma-Spec-v2 §03）
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
                        // 四格：若无已选会话则唤起多选选择器（任务 13.15）
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
                Image(systemName: splitLayout != .none
                    ? "rectangle.split.2x1.fill"
                    : "rectangle.split.2x1")
                .foregroundColor(splitLayout != .none ? DesignTokens.Colors.accentPrimary : nil)
            }
            .help(splitLayout != .none ? "分屏管理" : "开启分屏")

            // 终端内搜索
            Button {
                NotificationCenter.default.post(name: .searchTerminalRequested, object: nil)
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("终端内搜索 (⌘F)")

            // 日志面板
            Button {
                showLogPanel = true
            } label: {
                Image(systemName: "doc.text.below.ecg")
            }
            .help("会话日志")

            // 快捷命令（Zap，对齐 Figma-Spec-v2 §03 按钮8）
            Button {
                NotificationCenter.default.post(name: .quickCommandsRequested, object: nil)
            } label: {
                Image(systemName: "bolt.fill")
            }
            .help("快捷命令")

            // 隧道管理器（Network，对齐 Figma-Spec-v2 §03 按钮9）
            Button {
                NotificationCenter.default.post(name: .tunnelManagerRequested, object: nil)
            } label: {
                Image(systemName: "network")
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("隧道管理器")

            // tmux 管理器（Terminal，对齐 Figma-Spec-v2 §03 按钮10）
            Button {
                NotificationCenter.default.post(name: .tmuxManagerRequested, object: nil)
            } label: {
                Image(systemName: "square.split.2x1")
            }
            .disabled(tabBarStore.selectedTab == nil)
            .help("tmux 管理器")

        }

        // ── 中间：当前会话名 pill ─────────────────────────────

        ToolbarItem(placement: .principal) {
            Group {
                if let session = activeSession {
                    Text(session.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.06))
                        .clipShape(Capsule())
                } else {
                    Text("ShellMate")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
        }

        // ── 右侧：全局操作 ────────────────────────────────────

        ToolbarItemGroup(placement: .primaryAction) {
            Button { showSharePopover.toggle() } label: {
                Image(systemName: "square.and.arrow.up.on.square")
            }
            .popover(isPresented: $showSharePopover, arrowEdge: .bottom) {
                sessionShareMenu
            }
            .help("导入 / 导出会话")

            Button {
                showAppearancePicker.toggle()
            } label: {
                Image(systemName: windowModeIcon)
            }
            .popover(isPresented: $showAppearancePicker, arrowEdge: .bottom) {
                AppearanceModePickerView(windowMode: $windowMode)
            }
            .help("外观模式")

            Button { showLanguagePicker.toggle() } label: {
                Text(appLanguage == "en" ? "EN" : "中")
                    .font(.system(size: 12, weight: .medium))
                    .frame(minWidth: 20)
            }
            .popover(isPresented: $showLanguagePicker, arrowEdge: .bottom) {
                languagePickerMenu
            }
            .help("切换语言 / Switch Language")

            Divider()

            // 设置（对齐 Figma-Spec-v2 §03 右侧第4按钮）
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
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
        switch windowMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var appLocale: Locale {
        appLanguage == "en" ? Locale(identifier: "en_US") : Locale(identifier: "zh_Hans")
    }
}
