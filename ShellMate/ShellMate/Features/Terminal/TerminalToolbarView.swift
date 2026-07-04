import SwiftUI

/// 终端工具栏
/// 提供字号调整、清屏、搜索等快捷操作
/// 终端工具栏（从 TerminalView 抽出，Phase 17）
/// 终端标题 + 字号控制 + 清屏/搜索/SFTP/隧道/tmux/命令编辑/快捷命令/同步输入/AI 等工具按钮。
/// 依赖经注入：controller(@ObservedObject) / session / 三个 @EnvironmentObject / 若干 @Binding /
/// SFTP 切换闭包；EnvironmentObject 由 TerminalView 所在环境自动向下传递。
struct TerminalToolbarView: View {

    // MARK: - 依赖

    @ObservedObject var controller: TerminalController
    let session: Session

    @EnvironmentObject var panels: ContentViewModel
    @EnvironmentObject var syncStore: SyncInputStore
    @EnvironmentObject var aiSettings: AISettingsStore

    @Binding var showSearch: Bool
    @Binding var isAIPanelOpen: Bool
    @Binding var aiInitialError: String?
    @Binding var showSummaryPanel: Bool
    @Binding var sessionFontSize: Double

    let minFontSize: Double
    let maxFontSize: Double
    let onToggleSFTP: () -> Void

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 终端标题（已连接时显示，如 "ubuntu@host: ~"）
            if !controller.terminalTitle.isEmpty {
                Text(controller.terminalTitle)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // 右侧工具按钮
            toolButtonsView
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 36)
        .background {
            Rectangle()
                .fill(DesignTokens.Colors.surfacePanel)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignTokens.Colors.glassBorderSide)
                        .frame(height: 0.5)
                }
        }
    }

    private var toolButtonsView: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.xxs) {
            fontSizeControls

            toolbarDivider

            ToolbarButton(icon: .clear, tooltip: "清屏 (⌘K)") {
                controller.clearTerminal()
            }

            ToolbarButton(
                icon: .search,
                tooltip: "搜索 (⌘F)",
                isActive: showSearch
            ) {
                withAnimation { showSearch.toggle() }
            }

            toolbarDivider

            // SFTP 文件管理器按钮
            ToolbarButton(
                icon: .arrowUpArrowDown,
                tooltip: "SFTP 文件管理器",
                isEnabled: controller.state == .connected,
                isActive: controller.isSFTPPanelOpen
            ) {
                onToggleSFTP()
            }

            // 隧道管理器按钮（⌘⇧U）
            ToolbarButton(
                icon: .arrowLeftArrowRight,
                tooltip: "隧道管理器 (⌘⇧U)",
                isActive: panels.showTunnelPanel
            ) {
                withAnimation(DesignTokens.Animation.standard) { panels.showTunnelPanel.toggle() }
            }

            // tmux 会话管理器按钮（⌘⇧T）
            if case .available = controller.tmuxStore.availability {
                ToolbarButton(
                    icon: .tmux,
                    tooltip: "tmux 会话管理器 (⌘⇧T)",
                    isActive: panels.showTmuxPanel,
                    tintColor: panels.showTmuxPanel ? DesignTokens.Colors.accentPrimary : nil
                ) {
                    withAnimation(DesignTokens.Animation.standard) { panels.showTmuxPanel.toggle() }
                }
            }

            // Compose Pane 按钮
            ToolbarButton(
                icon: .log,
                tooltip: "命令编辑区",
                isActive: controller.isComposePaneOpen
            ) {
                withAnimation(DesignTokens.Animation.standard) {
                    controller.isComposePaneOpen.toggle()
                }
            }

            // W11：快捷命令管理器按钮（⌘⇧K）
            ToolbarButton(
                icon: .listBulletRectangle,
                tooltip: "快捷命令 (⌘⇧K)",
                isActive: panels.showQuickCommandPanel
            ) {
                withAnimation(DesignTokens.Animation.standard) { panels.showQuickCommandPanel.toggle() }
            }

            // W12.6：同步输入按钮（O03）
            ToolbarButton(
                icon: syncStore.isSynced(session.id) ? .syncGrid : .squareGrid,
                tooltip: syncStore.isSynced(session.id) ? "关闭同步输入" : "同步输入",
                isEnabled: controller.state == .connected,
                isActive: syncStore.isSynced(session.id),
                tintColor: syncStore.isSynced(session.id) ? DesignTokens.Colors.statusConnecting : nil
            ) {
                if syncStore.isSynced(session.id) {
                    syncStore.deactivate()
                } else {
                    panels.syncInputSessionId = session.id
                    withAnimation(DesignTokens.Animation.standard) { panels.showSyncInputPanel = true }
                }
            }

            toolbarDivider

            // AI 助手按钮（仅在 AI 功能启用时显示）
            if aiSettings.isEnabled {
                ToolbarButton(
                    icon: .ai,
                    tooltip: "AI 助手 (⌘⇧A)",
                    isActive: isAIPanelOpen,
                    tintColor: isAIPanelOpen ? nil : (controller.detectedErrorText != nil ? DesignTokens.Colors.statusConnecting : nil)
                ) {
                    withAnimation(DesignTokens.Animation.standard) {
                        isAIPanelOpen.toggle()
                        if !isAIPanelOpen { aiInitialError = nil }
                    }
                }

                // AI-05：会话摘要按钮（⌘⇧S）
                ToolbarButton(
                    icon: .textViewfinder,
                    tooltip: "会话摘要 (⌘⇧S)",
                    isEnabled: controller.state == .connected
                ) {
                    showSummaryPanel = true
                }
            }
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(DesignTokens.Colors.borderSecondary)
            .frame(width: 1, height: 16)
            .padding(.horizontal, DesignTokens.Spacing.xxs)
    }

    private var fontSizeControls: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.xxs) {
            ToolbarButton(
                icon: .zoomOut,
                tooltip: "减小字号 (⌘-)",
                isEnabled: sessionFontSize > minFontSize
            ) {
                sessionFontSize = max(minFontSize, sessionFontSize - 1)
            }

            Text("\(Int(sessionFontSize))pt")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 34)
                .multilineTextAlignment(.center)

            ToolbarButton(
                icon: .zoomIn,
                tooltip: "增大字号 (⌘+)",
                isEnabled: sessionFontSize < maxFontSize
            ) {
                sessionFontSize = min(maxFontSize, sessionFontSize + 1)
            }
        }
    }
}

// MARK: - 工具栏按钮

/// 工具栏按钮组件
struct ToolbarButton: View {

    // MARK: - 属性

    /// 图标名称
    let icon: AppIcon

    /// 提示文本
    let tooltip: String

    /// 是否启用
    var isEnabled: Bool = true

    /// 是否激活状态
    var isActive: Bool = false

    /// 着色
    var tintColor: Color? = nil

    /// 点击动作
    let action: () -> Void

    // MARK: - 状态

    @State private var isHovered: Bool = false

    // MARK: - 视图

    var body: some View {
        Button(action: action) {
            icon.image
                .font(DesignTokens.Typography.bodyMedium)
                .imageScale(.medium)
                .foregroundColor(buttonColor)
                .frame(width: 28, height: 28, alignment: .center)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(!isEnabled)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel(tooltip)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 计算属性

    /// 按钮颜色
    private var buttonColor: Color {
        if !isEnabled {
            return DesignTokens.Colors.textTertiary.opacity(0.5)
        }
        if let tint = tintColor {
            return tint
        }
        if isActive {
            return DesignTokens.Colors.accentPrimary
        }
        return DesignTokens.Colors.textSecondary
    }

    /// 背景颜色（Figma: hover:bg-black/5 = surfaceHover）
    private var backgroundColor: Color {
        if isActive {
            return DesignTokens.Colors.accentPrimary.opacity(0.15)
        }
        if isHovered && isEnabled {
            return DesignTokens.Colors.surfaceHover
        }
        return .clear
    }
}

// MARK: - 终端搜索栏

/// 终端搜索栏
struct TerminalSearchBar: View {

    // MARK: - 属性

    /// 搜索文本
    @Binding var searchText: String

    /// 当前匹配索引
    @Binding var currentMatch: Int

    /// 总匹配数（0 = 未找到）
    let totalMatches: Int

    /// 是否区分大小写
    @Binding var caseSensitive: Bool

    /// 是否使用正则表达式（O01 新增）
    @Binding var useRegex: Bool

    /// 关闭回调
    var onClose: (() -> Void)?

    /// 搜索下一个
    var onNext: (() -> Void)?

    /// 搜索上一个
    var onPrevious: (() -> Void)?

    // MARK: - 焦点

    @FocusState private var isFocused: Bool

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 搜索图标
            AppIcon.search.image
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            // 搜索输入框
            TextField("搜索...", text: $searchText)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.bodySmall)
                .focused($isFocused)
                .onSubmit {
                    onNext?()
                }

            // 搜索状态提示
            if !searchText.isEmpty {
                Text(totalMatches > 0 ? "已找到" : "未找到")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(totalMatches > 0
                        ? DesignTokens.Colors.statusConnected
                        : DesignTokens.Colors.statusError)
                    .frame(width: 46)
            }

            // 大小写敏感切换
            Button(action: { caseSensitive.toggle() }) {
                Text("Aa")
                    .font(DesignTokens.Typography.captionLarge)
                    .fontWeight(caseSensitive ? .bold : .regular)
                    .foregroundColor(caseSensitive ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(caseSensitive ? DesignTokens.Colors.accentPrimary.opacity(0.15) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXXSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("区分大小写")

            // 正则表达式切换（O01 新增）
            Button(action: { useRegex.toggle() }) {
                Text(".*")
                    .font(DesignTokens.Typography.codeTiny)
                    .fontWeight(useRegex ? .bold : .regular)
                    .foregroundColor(useRegex ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(useRegex ? DesignTokens.Colors.accentPrimary.opacity(0.15) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusXXSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("正则表达式")

            Divider()
                .frame(height: 16)

            // 上一个
            Button(action: { onPrevious?() }) {
                AppIcon.chevronUp.image
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(totalMatches == 0)
            .help("上一个 (⇧Enter)")

            // 下一个
            Button(action: { onNext?() }) {
                AppIcon.chevronDown.image
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(totalMatches == 0)
            .help("下一个 (Enter)")

            Divider()
                .frame(height: 16)

            // 关闭按钮
            Button(action: { onClose?() }) {
                AppIcon.close.image
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("关闭 (Esc)")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .glassPanel(radius: DesignTokens.Sizes.cornerRadiusSmall)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium, style: .continuous)
                .stroke(DesignTokens.Colors.borderPrimary, lineWidth: 1)
        )
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - 预览

#Preview("终端搜索栏") {
    TerminalSearchBar(
        searchText: .constant("error"),
        currentMatch: .constant(1),
        totalMatches: 1,
        caseSensitive: .constant(false),
        useRegex: .constant(false)
    )
    .padding()
    .frame(width: 450)
    .background(DesignTokens.Colors.surfaceWindow)
}
