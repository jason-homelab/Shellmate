import SwiftUI

/// 终端视图
/// 完整的 SSH 终端界面，整合工具栏、终端渲染和搜索功能
struct TerminalView: View {

    // MARK: - 属性

    /// 会话
    let session: Session

    /// 终端控制器
    @StateObject private var controller: TerminalController

    /// 终端视图引用
    @State private var terminalView: ShellMateTerminalView?

    /// 是否显示搜索栏
    @State private var showSearch: Bool = false

    /// 搜索文本
    @State private var searchText: String = ""

    /// 当前匹配索引
    @State private var currentMatch: Int = 0

    /// 总匹配数
    @State private var totalMatches: Int = 0

    /// 大小写敏感
    @State private var caseSensitive: Bool = false

    /// 状态文本
    @State private var statusText: String = ""

    /// 终端标题
    @State private var terminalTitle: String = ""

    /// 是否显示连接错误
    @State private var showConnectionError: Bool = false

    /// 连接错误信息
    @State private var connectionErrorMessage: String = ""

    // MARK: - 初始化

    init(session: Session) {
        self.session = session
        _controller = StateObject(wrappedValue: TerminalController(session: session))
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbarView

            // 搜索栏（条件显示）
            if showSearch {
                searchBarView
            }

            // 终端内容区域
            terminalContentView
        }
        .background(DesignTokens.Colors.surfaceWindow)
        .onAppear {
            setupController()
            connectIfNeeded()
        }
        .onDisappear {
            // 可选：断开连接
            // Task { await controller.disconnect() }
        }
        .alert("连接错误", isPresented: $showConnectionError) {
            Button("重试") {
                connect()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(connectionErrorMessage)
        }
    }

    // MARK: - 子视图

    /// 工具栏
    private var toolbarView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // 左侧：连接状态
            HStack(spacing: DesignTokens.Spacing.sm) {
                StatusDotView(state: controller.state.stateColor)

                Text(controller.state.displayName)
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            // 中间：终端标题
            if !terminalTitle.isEmpty {
                Text(terminalTitle)
                    .font(DesignTokens.Typography.labelSmall)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // 右侧：工具按钮
            toolButtonsView
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfacePanel)
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }

    /// 工具按钮
    private var toolButtonsView: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // 字号控制
            fontSizeControls

            Divider()
                .frame(height: 16)
                .padding(.horizontal, DesignTokens.Spacing.xs)

            // 清屏
            ToolbarButton(
                icon: "clear",
                tooltip: "清屏 (⌘K)"
            ) {
                terminalView?.clear()
            }

            // 搜索
            ToolbarButton(
                icon: "magnifyingglass",
                tooltip: "搜索 (⌘F)",
                isActive: showSearch
            ) {
                withAnimation {
                    showSearch.toggle()
                }
            }

            Divider()
                .frame(height: 16)
                .padding(.horizontal, DesignTokens.Spacing.xs)

            // 连接/断开按钮
            connectionButton
        }
    }

    /// 字号控制
    private var fontSizeControls: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ToolbarButton(
                icon: "minus.magnifyingglass",
                tooltip: "减小字号 (⌘-)",
                isEnabled: (terminalView?.fontSize ?? 13) > 9
            ) {
                let current = terminalView?.fontSize ?? 13
                terminalView?.setFontSize(max(9, current - 1))
            }

            Text("\(Int(terminalView?.fontSize ?? 13))pt")
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 40)

            ToolbarButton(
                icon: "plus.magnifyingglass",
                tooltip: "增大字号 (⌘+)",
                isEnabled: (terminalView?.fontSize ?? 13) < 24
            ) {
                let current = terminalView?.fontSize ?? 13
                terminalView?.setFontSize(min(24, current + 1))
            }
        }
    }

    /// 连接按钮
    @ViewBuilder
    private var connectionButton: some View {
        switch controller.state {
        case .connected:
            ToolbarButton(
                icon: "xmark.circle",
                tooltip: "断开连接",
                tintColor: DesignTokens.Colors.statusError
            ) {
                Task { await controller.disconnect() }
            }

        case .disconnected, .failed:
            ToolbarButton(
                icon: "bolt.fill",
                tooltip: "连接",
                tintColor: DesignTokens.Colors.statusConnected
            ) {
                connect()
            }

        case .connecting, .reconnecting:
            ToolbarButton(
                icon: "xmark.circle",
                tooltip: "取消"
            ) {
                controller.cancelReconnect()
                Task { await controller.disconnect() }
            }
        }
    }

    /// 搜索栏
    private var searchBarView: some View {
        TerminalSearchBar(
            searchText: $searchText,
            currentMatch: $currentMatch,
            totalMatches: totalMatches,
            caseSensitive: $caseSensitive,
            onClose: {
                withAnimation {
                    showSearch = false
                    searchText = ""
                }
            },
            onNext: findNext,
            onPrevious: findPrevious
        )
        .padding(DesignTokens.Spacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// 终端内容区域
    private var terminalContentView: some View {
        ZStack {
            // 终端视图
            ShellMateTerminalViewRepresentable(
                terminalView: $terminalView,
                theme: .darkDefault,
                delegate: controller
            )

            // 状态覆层
            stateOverlay
        }
    }

    /// 状态覆层
    @ViewBuilder
    private var stateOverlay: some View {
        switch controller.state {
        case .disconnected:
            disconnectedOverlay

        case .connecting:
            connectingOverlay

        case .reconnecting(let attempt):
            reconnectingOverlay(attempt: attempt)

        case .failed(let reason):
            failedOverlay(reason: reason)

        case .connected:
            EmptyView()
        }
    }

    /// 断开连接覆层
    private var disconnectedOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "terminal")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text("未连接")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("\(session.username)@\(session.host):\(session.port)")
                .font(DesignTokens.Typography.codeMedium)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Button(action: connect) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "bolt.fill")
                    Text("连接")
                }
                .font(DesignTokens.Typography.labelLarge)
                .foregroundColor(.white)
                .padding(.horizontal, DesignTokens.Spacing.xxl)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.accentPrimary)
                .cornerRadius(DesignTokens.Sizes.cornerRadiusMedium)
            }
            .buttonStyle(.plain)
            .padding(.top, DesignTokens.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.95))
    }

    /// 连接中覆层
    private var connectingOverlay: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .controlSize(.large)

            Text("正在连接...")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("\(session.username)@\(session.host)")
                .font(DesignTokens.Typography.codeSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.9))
    }

    /// 重连中覆层
    private func reconnectingOverlay(attempt: Int) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .controlSize(.large)

            Text("正在重连...")
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("第 \(attempt) 次尝试，共 \(controller.reconnectConfig.maxAttempts) 次")
                .font(DesignTokens.Typography.labelSmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Button("取消") {
                controller.cancelReconnect()
            }
            .buttonStyle(.bordered)
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.9))
    }

    /// 连接失败覆层
    private func failedOverlay(reason: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.statusError)

            Text("连接失败")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text(reason)
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xxxl)

            HStack(spacing: DesignTokens.Spacing.md) {
                Button("重试") {
                    connect()
                }
                .buttonStyle(.borderedProminent)

                Button("关闭") {
                    // 可以发送关闭通知
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.95))
    }

    // MARK: - 方法

    /// 设置控制器
    private func setupController() {
        controller.terminalView = terminalView
        controller.delegate = self
    }

    /// 如果需要则连接
    private func connectIfNeeded() {
        // 可以在这里添加自动连接逻辑
    }

    /// 连接
    private func connect() {
        Task {
            do {
                try await controller.connect()
            } catch let error as SSHError {
                connectionErrorMessage = error.localizedDescription
                showConnectionError = true
            }
        }
    }

    /// 查找下一个
    private func findNext() {
        guard totalMatches > 0 else { return }
        currentMatch = currentMatch < totalMatches ? currentMatch + 1 : 1
        // 实际实现需要调用终端视图的搜索方法
    }

    /// 查找上一个
    private func findPrevious() {
        guard totalMatches > 0 else { return }
        currentMatch = currentMatch > 1 ? currentMatch - 1 : totalMatches
        // 实际实现需要调用终端视图的搜索方法
    }
}

// MARK: - TerminalControllerDelegate

extension TerminalView: TerminalControllerDelegate {

    func terminalController(_ controller: TerminalController, didChangeState state: TerminalController.State) {
        // 状态变化已通过 @Published 自动更新
    }

    func terminalController(_ controller: TerminalController, didReceiveData data: Data) {
        // 数据已通过 controller 直接传递给 terminalView
    }

    func terminalController(_ controller: TerminalController, didReceiveErrorData data: Data) {
        // 可以选择特殊处理 stderr
    }

    func terminalController(_ controller: TerminalController, didChangeTitle title: String) {
        terminalTitle = title
    }

    func terminalController(_ controller: TerminalController, didFailWithError error: SSHError) {
        connectionErrorMessage = error.localizedDescription
        // 不自动显示弹窗，让覆层显示错误
    }

    func terminalController(_ controller: TerminalController, willReconnect attempt: Int, of maxAttempts: Int) {
        statusText = "重连中 (\(attempt)/\(maxAttempts))"
    }
}

// MARK: - 多终端标签视图

/// 多终端标签视图
/// 支持多个终端标签页的容器视图
struct MultiTerminalView: View {

    // MARK: - 属性

    /// 终端会话管理器
    @ObservedObject var sessionManager: TerminalSessionManager

    /// 会话列表
    let sessions: [Session]

    // MARK: - 视图

    var body: some View {
        if let selectedId = sessionManager.selectedControllerId,
           let session = sessions.first(where: { $0.id == selectedId }) {
            TerminalView(session: session)
        } else {
            emptyStateView
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "terminal")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            Text("选择一个会话开始")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text("从左侧边栏选择一个会话，或双击会话以连接")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.surfaceWindow)
    }
}

// MARK: - 预览

#Preview("终端视图 - 未连接") {
    TerminalView(session: Session.preview)
        .frame(width: 800, height: 600)
}

#Preview("终端视图 - 空状态") {
    MultiTerminalView(
        sessionManager: TerminalSessionManager.shared,
        sessions: []
    )
    .frame(width: 800, height: 600)
}
