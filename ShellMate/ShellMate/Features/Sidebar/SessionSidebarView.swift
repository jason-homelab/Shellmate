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

    /// 搜索栏是否可见（默认隐藏，⌘F 触发，对齐 Figma 无搜索栏设计）
    @State private var isSearchBarVisible: Bool = false

    /// 密码管理弹窗（任务 13.16）
    @State private var showPasswordManager: Bool = false

    /// 分组管理弹窗（任务 13.17）
    @State private var showGroupManager: Bool = false

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作头部：标题 + 操作图标按钮
            sidebarHeader

            // 搜索框（默认隐藏，⌘F 触发后显示，对齐 Figma 无持久搜索栏设计）
            if isSearchBarVisible || !sessionStore.searchQuery.isEmpty {
                SidebarSearchView(searchText: $sessionStore.searchQuery, focusTrigger: $searchFocusTrigger)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.top, DesignTokens.Spacing.sm)
                    .padding(.bottom, DesignTokens.Spacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

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
        }
        .frame(minWidth: DesignTokens.Sizes.sidebarMinWidth)
        .frame(maxWidth: DesignTokens.Sizes.sidebarMaxWidth)
        .frame(idealWidth: DesignTokens.Sizes.sidebarWidth)
        // Figma: bg-[#f5f5f7]/95 backdrop-blur-xl border-r border-[#d2d2d7]/50
        .background(.ultraThinMaterial)
        .background(DesignTokens.Colors.surfaceWindow.opacity(0.95))
        .task {
            await loadData()
        }
        // PRD 8.1：⌘F 唤出并聚焦搜索框
        .background(
            Button("") {
                withAnimation(DesignTokens.Animation.fast) { isSearchBarVisible = true }
                searchFocusTrigger = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .hidden()
        )
        // 菜单栏 ⌘L 聚焦侧边栏搜索框
        .onReceive(NotificationCenter.default.publisher(for: .focusSidebarSearchRequested)) { _ in
            withAnimation(DesignTokens.Animation.fast) { isSearchBarVisible = true }
            searchFocusTrigger = true
        }
    }

    // MARK: - 侧边栏头部

    /// 顶部操作头部：显示标题 + 新建会话、分组、设置快捷按钮
    private var sidebarHeader: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            // Figma: text-sm font-medium text-[#1d1d1f]
            Text("会话")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()

            // 新建会话
            sidebarIconButton(systemImage: "plus", tooltip: "新建会话 (⌘N)") {
                sessionStore.showNewSessionForm()
            }
            .keyboardShortcut("n", modifiers: .command)

            // 分组管理（FolderCog，对齐 Figma-Spec-v2 §02）
            sidebarIconButton(systemImage: "folder.badge.gearshape", tooltip: "分组管理 (⌘⇧N)") {
                showGroupManager = true
            }
            .sheet(isPresented: $showGroupManager) {
                GroupManagerView(
                    groupStore: groupStore,
                    onClose: { showGroupManager = false }
                )
            }

            // 密码管理（KeyRound，对齐 Figma-Spec-v2 §02）
            sidebarIconButton(systemImage: "key.fill", tooltip: "密码管理") {
                showPasswordManager = true
            }
            .sheet(isPresented: $showPasswordManager) {
                PasswordManagerView(
                    sessions: sessionStore.sessions,
                    onClose: { showPasswordManager = false }
                )
            }

            // 打开设置（macOS 14+ 使用 SettingsLink，13 回退到 sendAction）
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Image(systemName: "gear")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .frame(width: DesignTokens.Sizes.iconButtonSize, height: DesignTokens.Sizes.iconButtonSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background {
            // Figma: border-b border-[#d2d2d7]/50 bg-white/40
            Rectangle()
                .fill(Color.white.opacity(0.40))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DesignTokens.Colors.borderPrimary)
                        .frame(height: 0.5)
                }
        }
    }

    private func sidebarIconButton(systemImage: String, tooltip: String, action: @escaping () -> Void) -> some View {
        HoverIconButton(systemImage: systemImage, size: DesignTokens.Sizes.iconButtonSize, action: action)
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

// MARK: - 悬停图标按钮（对齐 Figma h-7 w-7 rounded-lg hover:bg-black/5）

/// 带悬停背景的小图标按钮，用于侧边栏/工具栏
struct HoverIconButton: View {
    let systemImage: String
    var size: CGFloat = 28
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: size, height: size)
                .background(isHovering ? Color.black.opacity(0.05) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.hover) { isHovering = hovering }
        }
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
