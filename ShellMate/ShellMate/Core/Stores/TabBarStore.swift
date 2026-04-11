import Foundation
import Combine

/// 标签栏状态管理器
/// 负责管理终端标签页的状态和业务逻辑
@MainActor
final class TabBarStore: ObservableObject {

    // MARK: - 发布属性

    /// 所有标签页
    @Published private(set) var tabs: [TerminalTab] = []

    /// 当前选中的标签页 ID
    @Published var selectedTabId: UUID?

    /// 是否显示关闭确认
    @Published var isShowingCloseConfirmation: Bool = false

    /// 待关闭的标签页
    @Published var tabToClose: TerminalTab?

    // MARK: - 计算属性

    /// 当前选中的标签页
    var selectedTab: TerminalTab? {
        guard let id = selectedTabId else { return nil }
        return tabs.first { $0.id == id }
    }

    /// 标签页数量
    var tabCount: Int {
        tabs.count
    }

    /// 是否只有一个标签页
    var hasOnlyOneTab: Bool {
        tabs.count == 1
    }

    /// 当前选中的标签页索引
    var selectedIndex: Int? {
        guard let id = selectedTabId else { return nil }
        return tabs.firstIndex { $0.id == id }
    }

    // MARK: - 初始化

    init() {
        // 冷启动：自动打开本地 Shell（任务 13.7-B，对标 MobaXterm）
        let localTab = TerminalTab.localTerminal()
        tabs = [localTab]
        selectedTabId = localTab.id
    }

    // MARK: - 标签页管理

    /// 添加新标签页
    /// - Parameter session: 关联的会话
    /// - Returns: 新创建的标签页
    @discardableResult
    func addTab(for session: Session) -> TerminalTab {
        let tab = TerminalTab(session: session)
        tabs.append(tab)
        selectedTabId = tab.id
        return tab
    }

    /// 添加新标签页
    /// - Parameter tab: 标签页
    func addTab(_ tab: TerminalTab) {
        tabs.append(tab)
        selectedTabId = tab.id
    }

    /// 添加本地终端标签页（任务 13.7）
    /// - Returns: 新创建的本地终端标签页
    @discardableResult
    func addLocalTerminalTab() -> TerminalTab {
        let tab = TerminalTab.localTerminal()
        tabs.append(tab)
        selectedTabId = tab.id
        return tab
    }

    /// 关闭标签页
    /// - Parameter tab: 要关闭的标签页
    func closeTab(_ tab: TerminalTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }

        // 如果关闭的是当前选中的标签页，需要选择其他标签页
        if selectedTabId == tab.id {
            // 优先选择右边的标签页，如果没有则选择左边的
            if index < tabs.count - 1 {
                selectedTabId = tabs[index + 1].id
            } else if index > 0 {
                selectedTabId = tabs[index - 1].id
            } else {
                selectedTabId = nil
            }
        }

        tabs.remove(at: index)

        // 最后一个标签关闭后自动补开本地 Shell（任务 13.7-B）
        if tabs.isEmpty {
            let localTab = TerminalTab.localTerminal()
            tabs.append(localTab)
            selectedTabId = localTab.id
        }
    }

    /// 请求关闭标签页（带确认）
    /// - Parameter tab: 要关闭的标签页
    func requestCloseTab(_ tab: TerminalTab) {
        // 如果标签页正在连接中，显示确认弹窗
        if tab.connectionState == .connected || tab.connectionState == .connecting {
            tabToClose = tab
            isShowingCloseConfirmation = true
        } else {
            closeTab(tab)
        }
    }

    /// 确认关闭标签页
    func confirmCloseTab() {
        if let tab = tabToClose {
            closeTab(tab)
        }
        tabToClose = nil
        isShowingCloseConfirmation = false
    }

    /// 取消关闭标签页
    func cancelCloseTab() {
        tabToClose = nil
        isShowingCloseConfirmation = false
    }

    /// 关闭所有标签页（随后自动补开本地 Shell）
    func closeAllTabs() {
        tabs.removeAll()
        selectedTabId = nil
        // 自动补开本地 Shell（任务 13.7-B）
        let localTab = TerminalTab.localTerminal()
        tabs.append(localTab)
        selectedTabId = localTab.id
    }

    /// 关闭其他标签页
    /// - Parameter tab: 保留的标签页
    func closeOtherTabs(except tab: TerminalTab) {
        tabs = tabs.filter { $0.id == tab.id }
        selectedTabId = tab.id
    }

    /// 关闭右侧标签页
    /// - Parameter tab: 参考标签页
    func closeTabsToRight(of tab: TerminalTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs = Array(tabs.prefix(through: index))

        // 如果选中的标签页被关闭，选择参考标签页
        if let selectedId = selectedTabId,
           !tabs.contains(where: { $0.id == selectedId }) {
            selectedTabId = tab.id
        }
    }

    /// 关闭左侧标签页
    /// - Parameter tab: 参考标签页
    func closeTabsToLeft(of tab: TerminalTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs = Array(tabs.suffix(from: index))

        // 如果选中的标签页被关闭，选择参考标签页
        if let selectedId = selectedTabId,
           !tabs.contains(where: { $0.id == selectedId }) {
            selectedTabId = tab.id
        }
    }

    // MARK: - 标签页选择

    /// 选择标签页
    /// - Parameter tab: 要选择的标签页
    func selectTab(_ tab: TerminalTab) {
        selectedTabId = tab.id
    }

    /// 选择标签页（通过索引）
    /// - Parameter index: 索引
    func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        selectedTabId = tabs[index].id
    }

    /// 选择下一个标签页
    func selectNextTab() {
        guard let currentIndex = selectedIndex else {
            if !tabs.isEmpty {
                selectedTabId = tabs[0].id
            }
            return
        }

        let nextIndex = (currentIndex + 1) % tabs.count
        selectedTabId = tabs[nextIndex].id
    }

    /// 选择上一个标签页
    func selectPreviousTab() {
        guard let currentIndex = selectedIndex else {
            if !tabs.isEmpty {
                selectedTabId = tabs[tabs.count - 1].id
            }
            return
        }

        let previousIndex = (currentIndex - 1 + tabs.count) % tabs.count
        selectedTabId = tabs[previousIndex].id
    }

    // MARK: - 标签页排序

    /// 移动标签页
    /// - Parameters:
    ///   - source: 源索引集
    ///   - destination: 目标索引
    func moveTabs(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }

    /// 交换标签页位置
    /// - Parameters:
    ///   - sourceIndex: 源索引
    ///   - destinationIndex: 目标索引
    func swapTabs(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0 && sourceIndex < tabs.count,
              destinationIndex >= 0 && destinationIndex < tabs.count else { return }

        tabs.swapAt(sourceIndex, destinationIndex)
    }

    // MARK: - 标签页状态更新

    /// 更新标签页连接状态
    /// - Parameters:
    ///   - tabId: 标签页 ID
    ///   - state: 新的连接状态
    func updateConnectionState(for tabId: UUID, state: ConnectionState) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].connectionState = state
        }
    }

    /// 更新标签页标题
    /// - Parameters:
    ///   - tabId: 标签页 ID
    ///   - title: 新标题
    func updateTitle(for tabId: UUID, title: String) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].title = title
        }
    }

    /// 更新标签页加载状态
    /// - Parameters:
    ///   - tabId: 标签页 ID
    ///   - isLoading: 是否正在加载
    func updateLoading(for tabId: UUID, isLoading: Bool) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].isLoading = isLoading
        }
    }

    // MARK: - 查找

    /// 根据会话 ID 查找标签页
    /// - Parameter sessionId: 会话 ID
    /// - Returns: 标签页（如果存在）
    func tab(for sessionId: UUID) -> TerminalTab? {
        tabs.first { $0.sessionId == sessionId }
    }

    /// 检查会话是否已有打开的标签页
    /// - Parameter sessionId: 会话 ID
    /// - Returns: 是否已打开
    func hasTab(for sessionId: UUID) -> Bool {
        tabs.contains { $0.sessionId == sessionId }
    }
}
