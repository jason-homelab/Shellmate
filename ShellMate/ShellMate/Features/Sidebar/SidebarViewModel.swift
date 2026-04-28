import SwiftUI
import Combine

// MARK: - SidebarViewModel
//
// 侧边栏 UI 状态管理，将 SessionSidebarView 的本地状态与业务逻辑
// 收拢到 ViewModel，View 仅做展示。
//
// 职责：
//   • 搜索栏显示/隐藏及焦点触发
//   • 模态弹窗（密码管理、分组管理）的开/关状态
//   • 数据加载协调（调用 SessionStore / GroupStore 的异步接口）

@MainActor
final class SidebarViewModel: BaseViewModel {

    // MARK: - 搜索栏状态

    @Published var isSearchBarVisible: Bool = false
    @Published var searchFocusTrigger: Bool = false

    // MARK: - 模态弹窗状态

    @Published var showPasswordManager: Bool = false
    @Published var showGroupManager: Bool = false

    // MARK: - 操作

    /// 展示搜索框并聚焦（⌘F / 菜单栏 ⌘L 触发）
    func showSearch() {
        withAnimation(DesignTokens.Animation.fast) { isSearchBarVisible = true }
        searchFocusTrigger = true
    }

    /// 数据初始加载（在 .task 中调用）
    func loadData(sessionStore: SessionStore, groupStore: GroupStore) async {
        await perform {
            await sessionStore.loadSessions()
            await groupStore.loadGroups()
        }
    }
}
