import XCTest
@testable import ShellMate

/// SidebarViewModel 单元测试
/// 覆盖 UI 状态（搜索栏、模态弹窗）的开/关流转
@MainActor
final class SidebarViewModelTests: XCTestCase {

    // MARK: - 测试属性

    var vm: SidebarViewModel!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        vm = SidebarViewModel()
    }

    override func tearDown() async throws {
        vm = nil
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialState_searchBarHidden() {
        XCTAssertFalse(vm.isSearchBarVisible)
    }

    func testInitialState_searchFocusTriggerFalse() {
        XCTAssertFalse(vm.searchFocusTrigger)
    }

    func testInitialState_passwordManagerHidden() {
        XCTAssertFalse(vm.showPasswordManager)
    }

    func testInitialState_groupManagerHidden() {
        XCTAssertFalse(vm.showGroupManager)
    }

    // MARK: - showSearch

    func testShowSearch_setsSearchBarVisible() {
        vm.showSearch()
        XCTAssertTrue(vm.isSearchBarVisible)
    }

    func testShowSearch_setsSearchFocusTrigger() {
        vm.showSearch()
        XCTAssertTrue(vm.searchFocusTrigger)
    }

    func testShowSearch_calledTwice_remainsVisible() {
        vm.showSearch()
        vm.showSearch()
        XCTAssertTrue(vm.isSearchBarVisible)
        XCTAssertTrue(vm.searchFocusTrigger)
    }

    // MARK: - 模态弹窗状态切换

    func testShowPasswordManager_canBeSetToTrue() {
        vm.showPasswordManager = true
        XCTAssertTrue(vm.showPasswordManager)
    }

    func testShowPasswordManager_canBeReset() {
        vm.showPasswordManager = true
        vm.showPasswordManager = false
        XCTAssertFalse(vm.showPasswordManager)
    }

    func testShowGroupManager_canBeSetToTrue() {
        vm.showGroupManager = true
        XCTAssertTrue(vm.showGroupManager)
    }

    func testShowGroupManager_canBeReset() {
        vm.showGroupManager = true
        vm.showGroupManager = false
        XCTAssertFalse(vm.showGroupManager)
    }

    // MARK: - 状态独立性

    func testPasswordManager_andGroupManager_areIndependent() {
        vm.showPasswordManager = true
        XCTAssertFalse(vm.showGroupManager)

        vm.showGroupManager = true
        XCTAssertTrue(vm.showPasswordManager)
        XCTAssertTrue(vm.showGroupManager)
    }
}
