import SwiftUI

/// 会话侧边栏视图
/// 包含搜索框、会话列表和底部操作栏的完整侧边栏
struct SessionSidebarView: View {

    // MARK: - 属性

    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var groupStore: GroupStore

    /// 连接会话回调
    var onConnect: ((Session) -> Void)?

    /// 搜索框焦点触发器（⌘F 快捷键驱动）
    @State private var searchFocusTrigger: Bool = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            SidebarSearchView(searchText: $sessionStore.searchQuery, focusTrigger: $searchFocusTrigger)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.top, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.xs)

            // 会话列表
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

            // 底部操作栏
            SidebarFooterView(
                onNewSession: {
                    sessionStore.showNewSessionForm()
                },
                onNewGroup: {
                    groupStore.showNewGroupForm()
                }
            )
        }
        .frame(minWidth: DesignTokens.Sizes.sidebarMinWidth)
        .frame(maxWidth: DesignTokens.Sizes.sidebarMaxWidth)
        .frame(idealWidth: DesignTokens.Sizes.sidebarWidth)
        .background(DesignTokens.Colors.surfaceWindow)
        .task {
            await loadData()
        }
        // PRD 8.1：⌘F 聚焦搜索框
        .background(
            Button("") { searchFocusTrigger = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        )
        // 菜单栏 ⌘L 聚焦侧边栏搜索框
        .onReceive(NotificationCenter.default.publisher(for: .focusSidebarSearchRequested)) { _ in
            searchFocusTrigger = true
        }
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

    // MARK: - 数据加载

    private func loadData() async {
        await sessionStore.loadSessions()
        await groupStore.loadGroups()
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
                    .font(.system(size: 14))
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
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
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
