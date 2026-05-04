import SwiftUI

/// 会话侧边栏视图
/// 包含搜索框、会话列表和底部操作栏的完整侧边栏
struct SessionSidebarView: View {

    // MARK: - 属性

    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var groupStore: GroupStore

    /// 连接会话回调
    var onConnect: ((Session) -> Void)?

    /// 侧边栏 UI 状态 ViewModel
    @StateObject private var vm = SidebarViewModel()

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作头部：标题 + 操作图标按钮
            sidebarHeader

            // 搜索框（默认隐藏，⌘F 触发后显示）
            if vm.isSearchBarVisible || !sessionStore.searchQuery.isEmpty {
                SidebarSearchView(searchText: $sessionStore.searchQuery, focusTrigger: $vm.searchFocusTrigger)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.top, DesignTokens.Spacing.sm)
                    .padding(.bottom, DesignTokens.Spacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 会话列表（flex:1）
            if sessionStore.isLoading {
                loadingView
            } else if sessionStore.filteredSessions.isEmpty {
                emptyStateView
            } else {
                SessionListView(
                    sessionStore: sessionStore,
                    groupStore: groupStore,
                    onConnect: onConnect
                )
            }

            // 底部统计条（Figma 8:32：高度 36px，"N connected" + "N total"）
            SidebarFooterView(
                connectedCount: connectedSessionCount,
                totalCount: sessionStore.sessions.count
            )
        }
        .frame(minWidth: DesignTokens.Sizes.sidebarMinWidth)
        .frame(maxWidth: DesignTokens.Sizes.sidebarMaxWidth)
        .frame(idealWidth: DesignTokens.Sizes.sidebarWidth)
        // Figma §02: 亮色 bg-[#f5f5f7] = surfaceWindow，与主窗口背景同色
        .background(DesignTokens.Colors.surfaceWindow)
        .task {
            await vm.loadData(sessionStore: sessionStore, groupStore: groupStore)
        }
        // PRD 8.1：⌘F 唤出并聚焦搜索框
        .background(
            Button("") { vm.showSearch() }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        )
        // 菜单栏 ⌘L 聚焦侧边栏搜索框
        .onReceive(NotificationCenter.default.publisher(for: .focusSidebarSearchRequested)) { _ in
            vm.showSearch()
        }
    }

    // MARK: - 侧边栏头部

    /// 顶部操作头部：显示标题 + 新建会话、分组、设置快捷按钮
    private var sidebarHeader: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            // Figma: text-sm font-medium text-[#1d1d1f] t('sidebar.sessions') = "会话"
            Text("会话")
                .font(DesignTokens.Typography.bodyLargeMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // 新建会话
            sidebarIconButton(systemImage: "plus", tooltip: "新建会话 (⌘N)") {
                sessionStore.showNewSessionForm()
            }
            .keyboardShortcut("n", modifiers: .command)

            // 分组管理（FolderCog，对齐 Figma-Spec-v2 §02）
            sidebarIconButton(systemImage: "folder.badge.gearshape", tooltip: "分组管理 (⌘⇧N)") {
                vm.showGroupManager = true
            }
            .sheet(isPresented: $vm.showGroupManager) {
                GroupManagerView(
                    groupStore: groupStore,
                    onClose: { vm.showGroupManager = false }
                )
            }

            // 密码管理（KeyRound，对齐 Figma-Spec-v2 §02）
            sidebarIconButton(systemImage: "key.fill", tooltip: "密码管理") {
                vm.showPasswordManager = true
            }
            .sheet(isPresented: $vm.showPasswordManager) {
                PasswordManagerView(
                    sessions: sessionStore.sessions,
                    onClose: { vm.showPasswordManager = false }
                )
            }

            // 打开设置（macOS 14+ 使用 SettingsLink，13 回退到 sendAction）
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Label("偏好设置", systemImage: "gear")
                        .labelStyle(.iconOnly)
                        .font(DesignTokens.Typography.iconLarge)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .frame(width: DesignTokens.Sizes.iconButtonSize, height: DesignTokens.Sizes.iconButtonSize)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Sizes.cornerRadiusSmall, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("偏好设置")
            } else {
                sidebarIconButton(systemImage: "gear", tooltip: "偏好设置") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
        }
        // Figma: p-3 = 12px 均匀 padding
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(height: 44)
        .background {
            // Figma: backdrop-blur-xl bg-white/40 border-b border-[#d2d2d7]/50
            Rectangle()
                .fill(.ultraThinMaterial)
            Rectangle()
                .fill(Color.white.opacity(0.40))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(hex: "#d2d2d7").opacity(0.50))
                        .frame(height: 0.5)
                }
        }
    }

    private func sidebarIconButton(
        systemImage: String,
        tooltip: String,
        accessibilityText: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        HoverIconButton(
            systemImage: systemImage,
            accessibilityText: accessibilityText ?? tooltip,
            size: DesignTokens.Sizes.iconButtonSize,
            action: action
        )
        .help(tooltip)
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(.circular)
            Text("加载中...")
                .font(DesignTokens.Typography.bodySmall)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .padding(.top, DesignTokens.Spacing.sm)
            Spacer()
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        Group {
            if sessionStore.searchQuery.isEmpty {
                EmptyStateView.noSessions {
                    sessionStore.showNewSessionForm()
                }
            } else {
                EmptyStateView.noSearchResults(query: sessionStore.searchQuery)
            }
        }
    }

    // MARK: - 统计辅助

    private var connectedSessionCount: Int {
        sessionStore.sessions.filter { $0.connectionState == .connected }.count
    }

}

// MARK: - 侧边栏工具栏视图

struct SidebarToolbarView: View {

    // MARK: - 属性

    @ObservedObject var groupStore: GroupStore

    // MARK: - 视图

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 全部展开/折叠
            Menu {
                Button("全部展开") {
                    Task {
                        await groupStore.expandAll()
                    }
                }

                Button("全部折叠") {
                    Task {
                        await groupStore.collapseAll()
                    }
                }
            } label: {
                Image(systemName: "sidebar.squares.leading")
                    .font(DesignTokens.Typography.bodyLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24, height: 24)

            Spacer()

            // 排序选项（预留）
            Menu {
                Button("按名称排序") { }
                Button("按最近连接排序") { }
                Button("按创建时间排序") { }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(DesignTokens.Typography.bodyLarge)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - 悬停图标按钮（薄壳，内部委托 PillButtonStyle）
// 保留 HoverIconButton 名称用于现有调用点；新代码请直接用：
//   Button { ... } label: { Label(...).labelStyle(.iconOnly) }
//      .buttonStyle(PillButtonStyle(tone: .ghost, variant: .iconOnly))

struct HoverIconButton: View {
    let systemImage: String
    /// VoiceOver 朗读文本（必填，缺省 fallback 到 systemImage 名）
    var accessibilityText: String? = nil
    var size: CGFloat = 28
    var iconSize: CGFloat = 16
    var iconColor: Color = DesignTokens.Colors.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(accessibilityText ?? systemImage, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundColor(iconColor)
        }
        .buttonStyle(PillButtonStyle(tone: .ghost, variant: .iconOnly))
    }
}

// MARK: - 预览

#Preview("侧边栏") {
    let sessionStore = SessionStore()
    let groupStore = GroupStore()

    return SessionSidebarView(
        sessionStore: sessionStore,
        groupStore: groupStore
    )
    .frame(width: 220, height: 600)
}
