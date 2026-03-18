import SwiftUI

/// 终端标签栏视图
/// 显示所有终端标签页和新建标签按钮
struct TerminalTabBarView: View {

    // MARK: - 属性

    @ObservedObject var store: TabBarStore

    /// 新建标签页动作
    var onNewTab: (() -> Void)?

    // MARK: - 私有状态

    @State private var draggedTabId: UUID?

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 0) {
            // 标签页列表
            tabList

            // 新建标签按钮
            newTabButton

            Spacer()
        }
        .frame(height: DesignTokens.Sizes.tabBarHeight)
        .background(DesignTokens.Colors.surfaceWindow)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - 子视图

    /// 标签页列表
    private var tabList: some View {
        HStack(spacing: 1) {
            ForEach(store.tabs) { tab in
                TerminalTabView(
                    tab: tab,
                    isSelected: store.selectedTabId == tab.id,
                    onClose: {
                        store.requestCloseTab(tab)
                    },
                    onSelect: {
                        store.selectTab(tab)
                    }
                )
                .onDrag {
                    draggedTabId = tab.id
                    return NSItemProvider(object: tab.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: TabDropDelegate(
                    targetTab: tab,
                    store: store,
                    draggedTabId: $draggedTabId
                ))
            }
        }
    }

    /// 新建标签按钮
    private var newTabButton: some View {
        Button(action: {
            onNewTab?()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("新建标签页")
        .padding(.horizontal, DesignTokens.Spacing.xxs)
    }
}

// MARK: - 拖拽代理

/// 标签页拖拽代理
struct TabDropDelegate: DropDelegate {
    let targetTab: TerminalTab
    let store: TabBarStore
    @Binding var draggedTabId: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggedTabId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedTabId,
              draggedId != targetTab.id,
              let sourceIndex = store.tabs.firstIndex(where: { $0.id == draggedId }),
              let destinationIndex = store.tabs.firstIndex(where: { $0.id == targetTab.id }) else {
            return
        }

        withAnimation(DesignTokens.Animation.fast) {
            store.moveTabs(
                from: IndexSet(integer: sourceIndex),
                to: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - 关闭确认弹窗

/// 关闭标签页确认视图
struct TabCloseConfirmationView: View {

    @ObservedObject var store: TabBarStore

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // 图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(DesignTokens.Colors.statusConnecting)

            // 标题
            Text("关闭连接中的标签页？")
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // 说明
            if let tab = store.tabToClose {
                Text("\"\(tab.title)\" 当前正在连接中，关闭后连接将断开。")
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // 按钮
            HStack(spacing: DesignTokens.Spacing.md) {
                Button("取消") {
                    store.cancelCloseTab()
                }
                .keyboardShortcut(.cancelAction)

                Button("关闭") {
                    store.confirmCloseTab()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignTokens.Spacing.xxl)
        .frame(width: 320)
        .background(DesignTokens.Colors.surfacePanel)
        .cornerRadius(DesignTokens.Sizes.cornerRadiusLarge)
    }
}

// MARK: - 预览

#Preview("终端标签栏 - 多标签") {
    let store = TabBarStore()

    // 添加预览标签页
    for tab in TerminalTab.previewTabs {
        store.addTab(tab)
    }

    return TerminalTabBarView(store: store)
        .frame(width: 800)
}

#Preview("终端标签栏 - 空状态") {
    let store = TabBarStore()

    return TerminalTabBarView(store: store)
        .frame(width: 800)
}

#Preview("关闭确认弹窗") {
    let store = TabBarStore()
    store.tabToClose = TerminalTab.preview
    store.isShowingCloseConfirmation = true

    return TabCloseConfirmationView(store: store)
        .background(DesignTokens.Colors.surfaceWindow)
}
