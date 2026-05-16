import SwiftUI

// MARK: - ContentView 工具栏
//
// 1:1 对齐 Figma OBPyCWFtlCx5OEIXwrckZm / Toolbar（节点 7:2）：
//   按钮均使用 Unicode 字符内联文本（⏻ ✦ </> ⇅ ⊡），不使用 SF Symbol 独立图标
//   左侧 — ⏻ 连接(tinted) 断开 | ✦ AI </> 脚本 ⇅ 文件 ⊡ 分屏 日志 命令 隧道
//   中部 — 当前会话 Badge（胶囊）
//   右侧 — 导入导出 搜索 录制 设置

extension ContentView {

    // MARK: - 工具栏内容

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {

        // 左侧按钮区：.navigation = macOS 工具栏左侧区域
        ToolbarItem(placement: .navigation) {
            leftToolbarView
        }

        // .principal 插槽始终占位（macOS 据此在两侧插入 flexible space，使右侧按钮贴右端）
        // 有活跃会话 → 显示会话名胶囊徽章；无活跃会话 → 透明占位（不显示任何内容）
        ToolbarItem(placement: .principal) {
            if let session = activeSession {
                Text(verbatim: "· \(session.name) ·")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(Capsule(style: .continuous).fill(DesignTokens.Colors.surfaceHover))
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }

        // 右侧按钮区：.primaryAction = macOS 工具栏右侧区域（Figma 截图右对齐）
        ToolbarItem(placement: .primaryAction) {
            rightToolbarView
        }
    }

    // MARK: - 左侧按钮区
    // Figma 7:2 左侧：所有按钮均为单一 Text，Unicode 字符+空格+汉字 内联渲染

    @ViewBuilder
    private var leftToolbarView: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {

            // ── 分组 1：连接管理（主操作 + 析构操作）──
            connectionGroup

            toolbarDivider

            // ── 分组 2：功能工具（中性操作）──
            toolGroup
        }
    }

    // MARK: - 连接管理分组（连接 + 断开）

    @ViewBuilder
    private var connectionGroup: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Button {
                if let session = sessionStore.selectedSession { connectToSession(session) }
            } label: {
                Text("⏻ 连接")
            }
            .buttonStyle(PillButtonStyle(tone: .tinted))
            .disabled(sessionStore.selectedSession == nil)
            .help("连接选中会话 (⌘↩)")
            .keyboardShortcut(.return, modifiers: .command)

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
            }
            // Figma 7:6: 断开与功能按钮同级——rgba(0,0,0,0.04) 中性灰，无红色
            .buttonStyle(PillButtonStyle(tone: .normal))
            .disabled(tabBarStore.selectedTab == nil)
            .help("断开当前会话")
        }
    }

    // MARK: - 功能工具分组（AI / 脚本 / 文件 / 分屏）

    @ViewBuilder
    private var toolGroup: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Button {
                NotificationCenter.default.post(name: .aiPanelRequested, object: nil)
            } label: {
                Text(verbatim: "✦ AI")
            }
            .buttonStyle(PillButtonStyle(tone: .normal))
            .disabled(tabBarStore.selectedTab == nil)
            .help("AI 助手 (⌘⇧A)")
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button {
                panels.showScriptPanel = true
            } label: {
                Text("</> 脚本")
            }
            .buttonStyle(PillButtonStyle(tone: .normal))
            .help("脚本自动化 (⌘⇧S)")
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button {
                NotificationCenter.default.post(name: .sftpPanelRequested, object: nil)
            } label: {
                Text("⇅ 文件")
            }
            .buttonStyle(PillButtonStyle(tone: .normal))
            .disabled(tabBarStore.selectedTab == nil)
            .help("文件传输 (SFTP)")

            splitMenu

            Button { panels.showLogPanel = true } label: {
                Text("日志")
            }
            .buttonStyle(PillButtonStyle(tone: .normal))
            .help("会话日志")

            Button {
                NotificationCenter.default.post(name: .quickCommandsRequested, object: nil)
            } label: {
                Text("命令")
            }
            .buttonStyle(PillButtonStyle(tone: .normal))
            .help("快捷命令 (⌘⇧K)")
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Button {
                NotificationCenter.default.post(name: .tunnelManagerRequested, object: nil)
            } label: {
                Text("隧道")
            }
            .buttonStyle(PillButtonStyle(tone: .normal))
            .help("隧道管理器 (⌘⇧U)")
            .keyboardShortcut("u", modifiers: [.command, .shift])
        }
    }

    // MARK: - 分屏 Menu（Figma 7:15：⊡ 分屏，与其他按钮样式完全一致）

    @ViewBuilder
    private var splitMenu: some View {
        SplitScreenMenuButton(
            splitLayout: $panels.splitLayout,
            showSplitSessionPicker: $panels.showSplitSessionPicker,
            splitSessionId: $panels.splitSessionId,
            gridSessionIds: $panels.gridSessionIds
        )
    }

    // MARK: - 右侧图标按钮区（Figma Make Toolbar.tsx 右侧：导出 搜索 录制 | 设置）

    @ViewBuilder
    private var rightToolbarView: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {

            Button { panels.showImportExportDialog = true } label: {
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

            Button { panels.showRecordingDialog = true } label: {
                Label("录制", systemImage: "record.circle").labelStyle(.iconOnly)
            }
            .buttonStyle(PillButtonStyle(tone: .normal, variant: .iconOnly))
            .help("录制会话")

            // Figma Make: Separator before Settings (h-5 mx-1 bg-[#d2d2d7]/50)
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

    // MARK: - 工具栏分隔线（Figma 7:8：1px × 20px，borderPrimary 自适应）

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.12))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
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

// MARK: - 分屏按钮（Button + popover，直接套用 PillButtonStyle，与文件/日志等按钮完全一致）
//
// 为什么用 Button 而不是 Menu：
//   Menu 使用 macOS 系统级 NSMenuButton 渲染，hover/press 状态由系统控制，
//   无法被 ButtonStyle 接管，视觉上与其他 PillButton 存在明显差异。
//   改为 Button + popover 后，PillButtonStyle 完全控制所有视觉状态。

private struct SplitScreenMenuButton: View {

    @Binding var splitLayout: SplitLayout
    @Binding var showSplitSessionPicker: Bool
    @Binding var splitSessionId: Session.ID?
    @Binding var gridSessionIds: [Session.ID]

    @State private var showPopover = false

    private var isActive: Bool { splitLayout != .none }

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Text("⊡ 分屏")
        }
        .buttonStyle(PillButtonStyle(tone: isActive ? .tinted : .normal))
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            splitPopoverContent
        }
        .help(isActive ? "分屏管理" : "开启分屏")
    }

    @ViewBuilder
    private var splitPopoverContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if splitLayout == .none {
                SplitOptionRow("左右分屏", icon: "rectangle.split.2x1") {
                    splitLayout = .horizontal; showSplitSessionPicker = true; showPopover = false
                }
                SplitOptionRow("上下分屏", icon: "rectangle.split.1x2") {
                    splitLayout = .vertical; showSplitSessionPicker = true; showPopover = false
                }
                SplitOptionRow("四格分屏 (2×2)", icon: "rectangle.split.2x2") {
                    splitLayout = .grid; showSplitSessionPicker = true; showPopover = false
                }
            } else {
                SplitOptionRow("切换为左右分屏", icon: "rectangle.split.2x1") {
                    splitLayout = .horizontal
                    if splitSessionId == nil { showSplitSessionPicker = true }
                    showPopover = false
                }
                SplitOptionRow("切换为上下分屏", icon: "rectangle.split.1x2") {
                    splitLayout = .vertical
                    if splitSessionId == nil { showSplitSessionPicker = true }
                    showPopover = false
                }
                SplitOptionRow("切换为四格分屏", icon: "rectangle.split.2x2") {
                    splitLayout = .grid
                    if gridSessionIds.isEmpty { showSplitSessionPicker = true }
                    showPopover = false
                }
                Divider()
                    .padding(.horizontal, 8)
                SplitOptionRow("关闭分屏", icon: "rectangle", isDestructive: true) {
                    splitLayout = .none; splitSessionId = nil; gridSessionIds = []
                    showPopover = false
                }
            }
        }
        .padding(.vertical, 4)
        .frame(minWidth: 180)
    }
}

// MARK: - 分屏弹出菜单行

private struct SplitOptionRow: View {

    let title: LocalizedStringKey
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    init(_ title: LocalizedStringKey, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(isDestructive
                    ? DesignTokens.Colors.statusError
                    : DesignTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXSmall, style: .continuous)
                .fill(isHovering ? DesignTokens.Colors.surfaceHover : Color.clear)
                .padding(.horizontal, 4)
        )
        .onHover { isHovering = $0 }
    }
}

