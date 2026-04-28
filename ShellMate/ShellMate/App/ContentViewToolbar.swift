import SwiftUI

// MARK: - ContentView 工具栏
//
// 全部使用原生 Button + PillButtonStyle，已废弃 DragGesture 模拟点击。
// 颜色/字号/间距/动画统一走 DesignTokens（不再有 Color.black.opacity 字面量）。
//
// macOS NSToolbar 注意：
//   - 所有 label 必须 Text(verbatim:)，防止 Localizable.strings 把"断开"自动译为 Disconnect
//   - 单个 ToolbarItem 包裹 HStack，避免多 item ButtonStyle 丢失
//   - principal placement 仅在有活跃会话时发射，右侧由 flexibleSpace 保证贴右

extension ContentView {

    // MARK: - 工具栏内容

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {

        ToolbarItem(placement: .navigation) {
            leftToolbarView
        }

        // 仅当有活跃会话时才发射 principal item；
        // 右侧贴右由 WindowAppKitHelpers 注入的 NSToolbar `.flexibleSpace` 保证。
        if let session = activeSession {
            ToolbarItem(placement: .principal) {
                Text(verbatim: "· \(session.name) ·")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(Capsule(style: .continuous).fill(DesignTokens.Colors.surfaceHover))
            }
        }

        ToolbarItem(placement: .primaryAction) {
            rightToolbarView
        }
    }

    // MARK: - 左侧按钮区
    // 布局对齐 Figma Toolbar.tsx:
    //   连接(text) 断开(text) | AI Script File | Split Log Commands Tunnel Tmux

    @ViewBuilder
    private var leftToolbarView: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {

            // 连接（蓝色主操作，text + icon）
            Button {
                if let session = sessionStore.selectedSession { connectToSession(session) }
            } label: {
                pillLabel(icon: "power", text: "连接")
            }
            .buttonStyle(PillButtonStyle(tone: .primary))
            .disabled(sessionStore.selectedSession == nil)
            .help("连接选中会话 (⌘↩)")
            .keyboardShortcut(.return, modifiers: .command)

            // 断开（text only）
            Button {
                if let sessionId = tabBarStore.selectedTab?.sessionId {
                    NotificationCenter.default.post(
                        name: .disconnectActiveTerminalRequested,
                        object: nil,
                        userInfo: ["sessionId": sessionId]
                    )
                }
            } label: {
                pillLabel(text: "断开")
            }
            .buttonStyle(PillButtonStyle(tone: .normal))
            .disabled(tabBarStore.selectedTab == nil)
            .help("断开当前会话")

            // ── 分隔线 1（Figma: Separator after Disconnect）──
            toolbarDivider

            // AI（icon-only — Sparkles）
            Button {
                NotificationCenter.default.post(name: .aiPanelRequested, object: nil)
            } label: {
                Label("AI 助手", systemImage: "sparkles").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .disabled(tabBarStore.selectedTab == nil)
            .help("AI 助手 (⌘⇧A)")
            .keyboardShortcut("a", modifiers: [.command, .shift])

            // 脚本（icon-only — Code2）
            Button {
                showScriptPanel = true
            } label: {
                Label("脚本自动化", systemImage: "chevron.left.forwardslash.chevron.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .help("脚本自动化 (⌘⇧S)")
            .keyboardShortcut("s", modifiers: [.command, .shift])

            // 文件（icon-only — FolderSync）
            Button {
                NotificationCenter.default.post(name: .sftpPanelRequested, object: nil)
            } label: {
                Label("文件传输", systemImage: "arrow.up.arrow.down").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .disabled(tabBarStore.selectedTab == nil)
            .help("文件传输 (SFTP)")

            // ── 分隔线 2（Figma: Separator before SplitControls）──
            toolbarDivider

            // 分屏（Menu — icon-only label，Menu 无法套 ButtonStyle，手写样式）
            splitMenu

            // 日志（icon-only — FileText）
            Button {
                showLogPanel = true
            } label: {
                Label("会话日志", systemImage: "doc.text").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .help("会话日志")

            // 命令（icon-only — Zap）
            Button {
                NotificationCenter.default.post(name: .quickCommandsRequested, object: nil)
            } label: {
                Label("快捷命令", systemImage: "bolt").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .help("快捷命令")

            // 隧道（icon-only — Network）
            Button {
                NotificationCenter.default.post(name: .tunnelManagerRequested, object: nil)
            } label: {
                Label("隧道管理", systemImage: "network").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .help("隧道管理器")

            // Tmux（icon-only — Terminal）
            Button {
                NotificationCenter.default.post(name: .tmuxManagerRequested, object: nil)
            } label: {
                Label("Tmux 管理", systemImage: "terminal").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .disabled(tabBarStore.selectedTab == nil)
            .help("Tmux 管理器")
        }
    }

    // MARK: - 分屏 Menu
    // Menu 不能直接套 ButtonStyle，icon-only 样式内联实现。

    @ViewBuilder
    private var splitMenu: some View {
        let isActive = splitLayout != .none
        Menu {
            if splitLayout == .none {
                Button { splitLayout = .horizontal; showSplitSessionPicker = true } label: {
                    Label("左右分屏", systemImage: "rectangle.split.2x1")
                }
                Button { splitLayout = .vertical; showSplitSessionPicker = true } label: {
                    Label("上下分屏", systemImage: "rectangle.split.1x2")
                }
                Button { splitLayout = .grid; showSplitSessionPicker = true } label: {
                    Label("四格分屏 (2×2)", systemImage: "rectangle.split.2x2")
                }
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
                    splitLayout = .none; splitSessionId = nil; gridSessionIds = []
                } label: { Label("关闭分屏", systemImage: "rectangle") }
            }
        } label: {
            Image(systemName: "rectangle.split.2x1")
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(isActive
                    ? DesignTokens.Colors.accentPrimary
                    : DesignTokens.Colors.textSecondary)
                .frame(
                    width: DesignTokens.Sizes.iconButtonSize,
                    height: DesignTokens.Sizes.iconButtonSize
                )
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous)
                        .fill(isActive
                            ? DesignTokens.Colors.accentPrimary.opacity(0.10)
                            : DesignTokens.Colors.surfaceHover)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(isActive ? "分屏管理" : "开启分屏")
    }

    // MARK: - 右侧图标按钮区
    // 对齐 Figma: ImportExport Search Info | separator | Settings

    @ViewBuilder
    private var rightToolbarView: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {

            Button { showImportExportDialog = true } label: {
                Label("导入导出", systemImage: "shippingbox").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .help("导入 / 导出会话")

            Button {
                NotificationCenter.default.post(name: .searchTerminalRequested, object: nil)
            } label: {
                Label("终端搜索", systemImage: "magnifyingglass").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .help("终端内搜索 (⌘F)")

            // Info（Figma: Info icon — macOS 标准 About 面板）
            Button {
                NSApp.orderFrontStandardAboutPanel(nil)
            } label: {
                Label("关于 ShellMate", systemImage: "info.circle").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .help("关于 ShellMate")

            // ── 分隔线（Figma: Separator before Settings）──
            toolbarDivider

            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label("设置", systemImage: "gearshape").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .help("设置 (⌘,)")
        }
    }

    // MARK: - 工具栏竖向分隔线
    // 对齐 Figma: h-5 mx-1 bg-[#d2d2d7]/50

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color(hex: "#d2d2d7").opacity(0.50))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
    }

    // MARK: - 文字 + 可选图标 label 辅助构造器

    @ViewBuilder
    private func pillLabel(icon: String? = nil, text: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(DesignTokens.Typography.labelMedium)
            }
            Text(verbatim: text)
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
        windowMode == "light" ? .light : .dark
    }

    var appLocale: Locale {
        appLanguage == "en" ? Locale(identifier: "en_US") : Locale(identifier: "zh_Hans")
    }
}
