import XCTest
@testable import ShellMate

/// TabBarStore 单元测试
/// 覆盖标签页状态管理器的完整业务逻辑
@MainActor
final class TabBarStoreTests: XCTestCase {

    // MARK: - 属性

    var store: TabBarStore!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        store = TabBarStore()
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    private func makeSession(name: String = "测试会话", host: String = "host.com") -> Session {
        Session(name: name, host: host, username: "user")
    }

    private func makeTab(title: String = "测试标签") -> TerminalTab {
        TerminalTab(sessionId: UUID(), title: title)
    }

    // MARK: - 初始状态测试

    /// 初始状态：无标签页，无选中
    func testInitialState() {
        XCTAssertTrue(store.tabs.isEmpty)
        XCTAssertNil(store.selectedTabId)
        XCTAssertNil(store.selectedTab)
        XCTAssertEqual(store.tabCount, 0)
        XCTAssertFalse(store.isShowingCloseConfirmation)
        XCTAssertNil(store.tabToClose)
    }

    // MARK: - 添加标签页测试

    /// addTab(for:) 创建并自动选中新标签页
    func testAddTabForSession() {
        let session = makeSession()
        let tab = store.addTab(for: session)

        XCTAssertEqual(store.tabCount, 1)
        XCTAssertEqual(store.selectedTabId, tab.id)
        XCTAssertEqual(store.selectedTab?.sessionId, session.id)
    }

    /// addTab(_ tab:) 直接追加并自动选中
    func testAddTabDirectly() {
        let tab = makeTab(title: "直接追加")
        store.addTab(tab)

        XCTAssertEqual(store.tabCount, 1)
        XCTAssertEqual(store.selectedTabId, tab.id)
    }

    /// 连续添加多个标签页：最后添加的被选中
    func testAddMultipleTabsLastSelectedIsActive() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")
        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)

        XCTAssertEqual(store.tabCount, 3)
        XCTAssertEqual(store.selectedTabId, t3.id)
    }

    // MARK: - 关闭标签页测试

    /// closeTab：关闭选中标签页，自动切换到右侧相邻标签
    func testCloseTabSelectsRightNeighbor() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")
        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)
        store.selectTab(t1) // 选中第一个

        store.closeTab(t1)

        XCTAssertEqual(store.tabCount, 2)
        XCTAssertEqual(store.selectedTabId, t2.id) // 应切换到 T2（原右侧）
    }

    /// closeTab：关闭最右侧标签页，自动切换到左侧相邻标签
    func testCloseLastTabSelectsLeftNeighbor() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        store.addTab(t1)
        store.addTab(t2)
        store.selectTab(t2)

        store.closeTab(t2)

        XCTAssertEqual(store.tabCount, 1)
        XCTAssertEqual(store.selectedTabId, t1.id)
    }

    /// closeTab：关闭唯一标签页后，selectedTabId 为 nil
    func testCloseOnlyTabClearsSelection() {
        let tab = makeTab()
        store.addTab(tab)

        store.closeTab(tab)

        XCTAssertEqual(store.tabCount, 0)
        XCTAssertNil(store.selectedTabId)
    }

    /// closeAllTabs：清空所有标签页和选中状态
    func testCloseAllTabs() {
        store.addTab(makeTab(title: "T1"))
        store.addTab(makeTab(title: "T2"))
        store.addTab(makeTab(title: "T3"))

        store.closeAllTabs()

        XCTAssertTrue(store.tabs.isEmpty)
        XCTAssertNil(store.selectedTabId)
    }

    /// closeOtherTabs：保留指定标签页，关闭其余全部
    func testCloseOtherTabs() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")
        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)

        store.closeOtherTabs(except: t2)

        XCTAssertEqual(store.tabCount, 1)
        XCTAssertEqual(store.tabs.first?.id, t2.id)
        XCTAssertEqual(store.selectedTabId, t2.id)
    }

    /// closeTabsToRight：关闭目标标签页右侧所有标签页
    func testCloseTabsToRight() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")
        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)

        store.closeTabsToRight(of: t1)

        XCTAssertEqual(store.tabCount, 1)
        XCTAssertEqual(store.tabs.first?.id, t1.id)
    }

    /// closeTabsToLeft：关闭目标标签页左侧所有标签页
    func testCloseTabsToLeft() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")
        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)
        store.selectTab(t3)

        store.closeTabsToLeft(of: t3)

        XCTAssertEqual(store.tabCount, 1)
        XCTAssertEqual(store.tabs.first?.id, t3.id)
    }

    // MARK: - 关闭确认流程测试

    /// requestCloseTab：已连接的标签页需要确认弹窗
    func testRequestCloseConnectedTabShowsConfirmation() {
        var tab = makeTab()
        tab.connectionState = .connected
        store.addTab(tab)

        store.requestCloseTab(tab)

        XCTAssertTrue(store.isShowingCloseConfirmation)
        XCTAssertEqual(store.tabToClose?.id, tab.id)
        XCTAssertEqual(store.tabCount, 1) // 未真正关闭
    }

    /// requestCloseTab：已断开的标签页直接关闭，不弹确认
    func testRequestCloseOfflineTabClosesDirectly() {
        var tab = makeTab()
        tab.connectionState = .offline
        store.addTab(tab)

        store.requestCloseTab(tab)

        XCTAssertFalse(store.isShowingCloseConfirmation)
        XCTAssertEqual(store.tabCount, 0)
    }

    /// confirmCloseTab：确认后真正关闭标签页并重置确认状态
    func testConfirmCloseTab() {
        var tab = makeTab()
        tab.connectionState = .connected
        store.addTab(tab)
        store.requestCloseTab(tab)

        store.confirmCloseTab()

        XCTAssertEqual(store.tabCount, 0)
        XCTAssertFalse(store.isShowingCloseConfirmation)
        XCTAssertNil(store.tabToClose)
    }

    /// cancelCloseTab：取消后标签页保留，确认状态重置
    func testCancelCloseTab() {
        var tab = makeTab()
        tab.connectionState = .connected
        store.addTab(tab)
        store.requestCloseTab(tab)

        store.cancelCloseTab()

        XCTAssertEqual(store.tabCount, 1)
        XCTAssertFalse(store.isShowingCloseConfirmation)
        XCTAssertNil(store.tabToClose)
    }

    // MARK: - 标签页选择测试

    /// selectTab：切换选中标签页
    func testSelectTab() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        store.addTab(t1)
        store.addTab(t2)
        store.selectTab(t1)

        XCTAssertEqual(store.selectedTabId, t1.id)
    }

    /// selectTab(at:)：按索引切换
    func testSelectTabAtIndex() {
        store.addTab(makeTab(title: "T1"))
        store.addTab(makeTab(title: "T2"))
        store.addTab(makeTab(title: "T3"))
        store.selectTab(at: 0)

        XCTAssertEqual(store.selectedTab?.title, "T1")

        store.selectTab(at: 2)
        XCTAssertEqual(store.selectedTab?.title, "T3")
    }

    /// selectTab(at:)：越界索引不崩溃，不改变选中
    func testSelectTabAtOutOfBoundsIndex() {
        let tab = makeTab()
        store.addTab(tab)
        let originalId = store.selectedTabId

        store.selectTab(at: 99)

        XCTAssertEqual(store.selectedTabId, originalId)
    }

    /// selectNextTab：循环切换到下一个标签页
    func testSelectNextTab() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")
        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)
        store.selectTab(t1)

        store.selectNextTab()
        XCTAssertEqual(store.selectedTabId, t2.id)

        store.selectNextTab()
        XCTAssertEqual(store.selectedTabId, t3.id)

        // 循环：最后一个的下一个是第一个
        store.selectNextTab()
        XCTAssertEqual(store.selectedTabId, t1.id)
    }

    /// selectPreviousTab：循环切换到上一个标签页
    func testSelectPreviousTab() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")
        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)
        store.selectTab(t1)

        store.selectPreviousTab()

        // 循环：第一个的前一个是最后一个
        XCTAssertEqual(store.selectedTabId, t3.id)
    }

    // MARK: - 标签页排序测试

    /// moveTabs：正确移动标签页顺序
    func testMoveTabs() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")
        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)

        // 将 T1（index 0）移到末尾（index 3 → 等效 index 2）
        store.moveTabs(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(store.tabs[0].title, "T2")
        XCTAssertEqual(store.tabs[1].title, "T3")
        XCTAssertEqual(store.tabs[2].title, "T1")
    }

    /// swapTabs：交换两个标签页位置
    func testSwapTabs() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        let t3 = makeTab(title: "T3")
        store.addTab(t1)
        store.addTab(t2)
        store.addTab(t3)

        store.swapTabs(from: 0, to: 2)

        XCTAssertEqual(store.tabs[0].title, "T3")
        XCTAssertEqual(store.tabs[1].title, "T2")
        XCTAssertEqual(store.tabs[2].title, "T1")
    }

    /// swapTabs：相同索引不发生交换
    func testSwapTabsSameIndex() {
        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        store.addTab(t1)
        store.addTab(t2)

        store.swapTabs(from: 0, to: 0)

        XCTAssertEqual(store.tabs[0].title, "T1")
    }

    // MARK: - 状态更新测试

    /// updateConnectionState：更新指定标签页的连接状态
    func testUpdateConnectionState() {
        let tab = makeTab()
        store.addTab(tab)

        store.updateConnectionState(for: tab.id, state: .connected)

        XCTAssertEqual(store.tabs.first?.connectionState, .connected)
    }

    /// updateTitle：更新指定标签页的标题
    func testUpdateTitle() {
        let tab = makeTab(title: "原始标题")
        store.addTab(tab)

        store.updateTitle(for: tab.id, title: "更新后标题")

        XCTAssertEqual(store.tabs.first?.title, "更新后标题")
    }

    /// updateLoading：更新指定标签页的加载状态
    func testUpdateLoading() {
        let tab = makeTab()
        store.addTab(tab)
        XCTAssertFalse(store.tabs.first?.isLoading ?? true)

        store.updateLoading(for: tab.id, isLoading: true)

        XCTAssertTrue(store.tabs.first?.isLoading ?? false)
    }

    // MARK: - 查找测试

    /// tab(for:)：按会话 ID 找到对应标签页
    func testTabForSessionId() {
        let session = makeSession()
        let tab = store.addTab(for: session)

        let found = store.tab(for: session.id)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, tab.id)
    }

    /// tab(for:)：会话 ID 不存在时返回 nil
    func testTabForNonExistentSessionId() {
        let found = store.tab(for: UUID())

        XCTAssertNil(found)
    }

    /// hasTab(for:)：存在时返回 true，不存在时返回 false
    func testHasTab() {
        let session = makeSession()
        store.addTab(for: session)

        XCTAssertTrue(store.hasTab(for: session.id))
        XCTAssertFalse(store.hasTab(for: UUID()))
    }

    // MARK: - 计算属性测试

    /// hasOnlyOneTab：只有一个标签页时为 true
    func testHasOnlyOneTab() {
        XCTAssertFalse(store.hasOnlyOneTab)

        store.addTab(makeTab())
        XCTAssertTrue(store.hasOnlyOneTab)

        store.addTab(makeTab())
        XCTAssertFalse(store.hasOnlyOneTab)
    }

    /// selectedIndex：返回当前选中标签页的索引
    func testSelectedIndex() {
        XCTAssertNil(store.selectedIndex)

        let t1 = makeTab(title: "T1")
        let t2 = makeTab(title: "T2")
        store.addTab(t1)
        store.addTab(t2)
        store.selectTab(t1)

        XCTAssertEqual(store.selectedIndex, 0)

        store.selectTab(t2)
        XCTAssertEqual(store.selectedIndex, 1)
    }
}
