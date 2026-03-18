import XCTest
import CoreData
@testable import ShellMate

/// GroupStore 单元测试
/// 覆盖分组状态管理器的状态流转和业务逻辑
@MainActor
final class GroupStoreTests: XCTestCase {

    // MARK: - 测试属性

    var persistenceController: PersistenceController!
    var repository: GroupRepository!
    var store: GroupStore!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        repository = GroupRepository(persistenceController: persistenceController)
        store = GroupStore(repository: repository)
    }

    override func tearDown() async throws {
        store = nil
        repository = nil
        persistenceController = nil
        try await super.tearDown()
    }

    // MARK: - 初始状态测试

    /// 测试初始状态
    func testInitialState() async throws {
        // Then
        XCTAssertTrue(store.groups.isEmpty)
        XCTAssertTrue(store.topLevelGroups.isEmpty)
        XCTAssertNil(store.editingGroup)
        XCTAssertFalse(store.isShowingGroupForm)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
    }

    // MARK: - 加载测试

    /// 测试加载分组
    func testLoadGroups() async throws {
        // Given
        let group = SessionGroup(name: "测试分组", colorHex: "#4A90D9")
        try await repository.save(group)

        // When
        await store.loadGroups()

        // Then
        XCTAssertEqual(store.groups.count, 1)
        XCTAssertEqual(store.topLevelGroups.count, 1)
        XCTAssertFalse(store.isLoading)
    }

    /// 测试加载空分组列表
    func testLoadEmptyGroups() async throws {
        // When
        await store.loadGroups()

        // Then
        XCTAssertTrue(store.groups.isEmpty)
        XCTAssertTrue(store.topLevelGroups.isEmpty)
    }

    // MARK: - CRUD 测试

    /// 测试保存分组
    func testSaveGroup() async throws {
        // Given
        let group = SessionGroup(name: "新分组", colorHex: "#2DCE7A")

        // When
        await store.saveGroup(group)

        // Then
        XCTAssertEqual(store.groups.count, 1)
        XCTAssertEqual(store.groups.first?.name, "新分组")
    }

    /// 测试删除分组
    func testDeleteGroup() async throws {
        // Given
        let group = SessionGroup(name: "待删除", colorHex: "#F04060")
        await store.saveGroup(group)

        // When
        await store.deleteGroup(group)

        // Then
        XCTAssertTrue(store.groups.isEmpty)
    }

    // MARK: - 展开/折叠测试

    /// 测试切换展开状态
    func testToggleExpanded() async throws {
        // Given
        let group = SessionGroup(name: "测试分组", colorHex: "#4A90D9")
        await store.saveGroup(group)
        let initialExpanded = store.groups.first?.isExpanded ?? true

        // When
        await store.toggleExpanded(group)

        // Then
        XCTAssertEqual(store.groups.first?.isExpanded, !initialExpanded)
    }

    /// 测试设置展开状态
    func testSetExpanded() async throws {
        // Given
        let group = SessionGroup(name: "测试分组", colorHex: "#4A90D9")
        await store.saveGroup(group)

        // When - 设为折叠
        await store.setExpanded(group, isExpanded: false)
        XCTAssertEqual(store.groups.first?.isExpanded, false)

        // When - 设为展开
        await store.setExpanded(group, isExpanded: true)
        XCTAssertEqual(store.groups.first?.isExpanded, true)
    }

    /// 测试全部展开
    func testExpandAll() async throws {
        // Given
        var group1 = SessionGroup(name: "分组1", colorHex: "#4A90D9")
        var group2 = SessionGroup(name: "分组2", colorHex: "#2DCE7A")
        await store.saveGroup(group1)
        await store.saveGroup(group2)

        // 先折叠所有分组
        await store.collapseAll()

        // When
        await store.expandAll()

        // Then
        XCTAssertTrue(store.groups.allSatisfy { $0.isExpanded })
    }

    /// 测试全部折叠
    func testCollapseAll() async throws {
        // Given
        let group1 = SessionGroup(name: "分组1", colorHex: "#4A90D9")
        let group2 = SessionGroup(name: "分组2", colorHex: "#2DCE7A")
        await store.saveGroup(group1)
        await store.saveGroup(group2)

        // When
        await store.collapseAll()

        // Then
        XCTAssertTrue(store.groups.allSatisfy { !$0.isExpanded })
    }

    // MARK: - 弹窗状态测试

    /// 测试显示新建分组弹窗
    func testShowNewGroupForm() async throws {
        // When
        store.showNewGroupForm()

        // Then
        XCTAssertTrue(store.isShowingGroupForm)
        XCTAssertNil(store.editingGroup)
    }

    /// 测试显示编辑分组弹窗
    func testShowEditGroupForm() async throws {
        // Given
        let group = SessionGroup(name: "待编辑", colorHex: "#4A90D9")
        await store.saveGroup(group)

        // When
        store.showEditGroupForm(for: group)

        // Then
        XCTAssertTrue(store.isShowingGroupForm)
        XCTAssertEqual(store.editingGroup?.id, group.id)
    }

    /// 测试关闭弹窗
    func testDismissGroupForm() async throws {
        // Given
        let group = SessionGroup(name: "测试", colorHex: "#4A90D9")
        store.showEditGroupForm(for: group)

        // When
        store.dismissGroupForm()

        // Then
        XCTAssertFalse(store.isShowingGroupForm)
        XCTAssertNil(store.editingGroup)
    }

    // MARK: - 按 ID 查询测试

    /// 测试按 ID 获取分组
    func testGroupById() async throws {
        // Given
        let group = SessionGroup(name: "测试分组", colorHex: "#4A90D9")
        await store.saveGroup(group)

        // When
        let fetchedGroup = store.group(by: group.id)

        // Then
        XCTAssertNotNil(fetchedGroup)
        XCTAssertEqual(fetchedGroup?.id, group.id)
    }

    /// 测试按 ID 获取不存在的分组
    func testGroupByIdNotFound() async throws {
        // When
        let fetchedGroup = store.group(by: UUID())

        // Then
        XCTAssertNil(fetchedGroup)
    }

    // MARK: - 嵌套分组测试

    /// 测试顶级分组过滤
    func testTopLevelGroupsFilter() async throws {
        // Given
        var parentGroup = SessionGroup(name: "父分组", colorHex: "#4A90D9")
        await store.saveGroup(parentGroup)

        var childGroup = SessionGroup(
            name: "子分组",
            colorHex: "#2DCE7A",
            parentId: parentGroup.id
        )
        await store.saveGroup(childGroup)

        // Then
        XCTAssertEqual(store.groups.count, 2)
        XCTAssertEqual(store.topLevelGroups.count, 1)
        XCTAssertEqual(store.topLevelGroups.first?.name, "父分组")
    }

    // MARK: - 错误处理测试

    /// 测试错误消息可以被清除
    func testErrorMessageCanBeCleared() async throws {
        // Given
        store.errorMessage = "测试错误"

        // When
        store.errorMessage = nil

        // Then
        XCTAssertNil(store.errorMessage)
    }
}
