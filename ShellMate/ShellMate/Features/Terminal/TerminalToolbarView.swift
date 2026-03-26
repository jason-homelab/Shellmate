import SwiftUI

/// 终端工具栏
/// 提供字号调整、清屏、搜索等快捷操作
struct TerminalToolbarView: View {

    // MARK: - 属性

    /// 终端控制器
    @ObservedObject var controller: TerminalController

    /// 当前字体大小
    @State private var fontSize: CGFloat = 13

    /// 是否显示搜索栏
    @Binding var showSearch: Bool

    /// 连接状态描述
    @Binding var statusText: String

    // MARK: - 常量

    /// 最小字号
    private let minFontSize: CGFloat = 9

    /// 最大字号
    private let maxFontSize: CGFloat = 24

    /// 字号调整步长
    private let fontSizeStep: CGFloat = 1

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 左侧：连接状态
            connectionStatusView

            Spacer()

            // 中间：状态文本
            if !statusText.isEmpty {
                Text(statusText)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            Spacer()

            // 右侧：工具按钮
            toolButtonsView
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Rectangle().fill(DesignTokens.Colors.glassUltraLight))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignTokens.Colors.glassBorderSide)
                        .frame(height: 0.5)
                }
        }
    }

    // MARK: - 子视图

    /// 连接状态视图
    private var connectionStatusView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 状态点
            StatusDotView(state: controller.state.stateColor)

            // 状态文本
            Text(controller.state.displayName)
                .font(DesignTokens.Typography.labelMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            // 重连中显示进度
            if case .reconnecting(let attempt) = controller.state {
                Text("(\(attempt)/\(controller.reconnectConfig.maxAttempts))")
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
    }

    /// 工具按钮视图
    private var toolButtonsView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // 字号减小
            ToolbarButton(
                icon: "minus.magnifyingglass",
                tooltip: "减小字号 (⌘-)",
                isEnabled: fontSize > minFontSize
            ) {
                decreaseFontSize()
            }

            // 字号显示
            Text("\(Int(fontSize))pt")
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 40)

            // 字号增大
            ToolbarButton(
                icon: "plus.magnifyingglass",
                tooltip: "增大字号 (⌘+)",
                isEnabled: fontSize < maxFontSize
            ) {
                increaseFontSize()
            }

            Divider()
                .frame(height: 16)
                .padding(.horizontal, DesignTokens.Spacing.xs)

            // 清屏
            ToolbarButton(
                icon: "clear",
                tooltip: "清屏 (⌘K)"
            ) {
                clearScreen()
            }

            // 搜索
            ToolbarButton(
                icon: "magnifyingglass",
                tooltip: "搜索 (⌘F)",
                isActive: showSearch
            ) {
                toggleSearch()
            }

            Divider()
                .frame(height: 16)
                .padding(.horizontal, DesignTokens.Spacing.xs)

            // 连接/断开
            if controller.state == .connected {
                ToolbarButton(
                    icon: "xmark.circle",
                    tooltip: "断开连接",
                    tintColor: DesignTokens.Colors.statusError
                ) {
                    disconnect()
                }
            } else if controller.state == .disconnected || controller.state.isFailed {
                ToolbarButton(
                    icon: "bolt.fill",
                    tooltip: "连接",
                    tintColor: DesignTokens.Colors.statusConnected
                ) {
                    connect()
                }
            } else if controller.state.isReconnecting {
                ToolbarButton(
                    icon: "xmark.circle",
                    tooltip: "取消重连"
                ) {
                    cancelReconnect()
                }
            }
        }
    }

    // MARK: - 操作

    /// 增大字号
    private func increaseFontSize() {
        fontSize = min(maxFontSize, fontSize + fontSizeStep)
    }

    /// 减小字号
    private func decreaseFontSize() {
        fontSize = max(minFontSize, fontSize - fontSizeStep)
    }

    /// 清屏
    private func clearScreen() {
        controller.clearTerminal()
    }

    /// 切换搜索
    private func toggleSearch() {
        withAnimation {
            showSearch.toggle()
        }
    }

    /// 连接
    private func connect() {
        Task {
            try? await controller.connect()
        }
    }

    /// 断开连接
    private func disconnect() {
        Task {
            await controller.disconnect()
        }
    }

    /// 取消重连
    private func cancelReconnect() {
        controller.cancelReconnect()
    }
}

// MARK: - 工具栏按钮

/// 工具栏按钮组件
struct ToolbarButton: View {

    // MARK: - 属性

    /// 图标名称
    let icon: String

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
            Image(systemName: icon)
                .font(.system(size: 13, weight: .regular))
                .imageScale(.medium)
                .foregroundColor(buttonColor)
                .frame(width: 26, height: 26, alignment: .center)
                .background(backgroundColor)
                .cornerRadius(5)
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

    /// 背景颜色
    private var backgroundColor: Color {
        if isActive {
            return DesignTokens.Colors.accentPrimary.opacity(0.15)
        }
        if isHovered && isEnabled {
            return DesignTokens.Colors.glassHoverColor
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
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
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
                    .font(.system(size: 11, weight: caseSensitive ? .bold : .regular))
                    .foregroundColor(caseSensitive ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(caseSensitive ? DesignTokens.Colors.accentPrimary.opacity(0.15) : .clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("区分大小写")

            // 正则表达式切换（O01 新增）
            Button(action: { useRegex.toggle() }) {
                Text(".*")
                    .font(.system(size: 11, weight: useRegex ? .bold : .regular, design: .monospaced))
                    .foregroundColor(useRegex ? DesignTokens.Colors.accentPrimary : DesignTokens.Colors.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(useRegex ? DesignTokens.Colors.accentPrimary.opacity(0.15) : .clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("正则表达式")

            Divider()
                .frame(height: 16)

            // 上一个
            Button(action: { onPrevious?() }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(totalMatches == 0)
            .help("上一个 (⇧Enter)")

            // 下一个
            Button(action: { onNext?() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(totalMatches == 0)
            .help("下一个 (Enter)")

            Divider()
                .frame(height: 16)

            // 关闭按钮
            Button(action: { onClose?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("关闭 (Esc)")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .glassPanel(radius: DesignTokens.Sizes.cornerRadiusSmall)
        .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusMedium)
                .stroke(DesignTokens.Colors.borderPrimary, lineWidth: 1)
        )
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - 预览

#Preview("终端工具栏") {
    let controller = TerminalController(
        session: Session.preview
    )

    return VStack {
        TerminalToolbarView(
            controller: controller,
            showSearch: .constant(false),
            statusText: .constant("ubuntu@server:~$")
        )

        Spacer()
    }
    .frame(width: 800, height: 100)
    .background(DesignTokens.Colors.surfaceWindow)
}

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
