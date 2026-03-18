import XCTest
import CoreData
@testable import ShellMate

/// GroupRepository 单元测试
/// 覆盖分组数据的增删改查全部操作
@MainActor
final class GroupRepositoryTests: XCTestCase {

    // MARK: - 测试属性

    var persistenceController: PersistenceController!
    var repository: GroupRepository!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        repository = GroupRepository(persistenceController: persistenceController)
    }

    override func tearDown() async throws {
        repository = nil
        persistenceController = nil
        try await super.tearDown()
    }

    // MARK: - 创建测试

    /// 测试创建新分组
    func testCreateGroup() async throws {
        // Given
        let group = SessionGroup(
            name: "生产环境",
            colorHex: "#2DCE7A"
        )

        // When
        try await repository.save(group)
        let groups = try await repository.fetchAll()

        // Then
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.name, "生产环境")
        XCTAssertEqual(groups.first?.colorHex, "#2DCE7A")
        XCTAssertTrue(groups.first?.isExpanded ?? false)
    }

    /// 测试创建多个分组
    func testCreateMultipleGroups() async throws {
        // Given
        let groups = [
            SessionGroup(name: "生产", colorHex: "#2DCE7A"),
            SessionGroup(name: "开发", colorHex: "#4A90D9"),
            SessionGroup(name: "测试", colorHex: "#F0A500")
        ]

        // When
        for group in groups {
            try await repository.save(group)
        }
        let fetchedGroups = try await repository.fetchAll()

        // Then
        XCTAssertEqual(fetchedGroups.count, 3)
    }

    // MARK: - 读取测试

    /// 测试按 ID 获取分组
    func testFetchGroupById() async throws {
        // Given
        let group = SessionGroup(name: "测试分组", colorHex: "#4A90D9")
        try await repository.save(group)

        // When
        let fetchedGroup = try await repository.fetch(by: group.id)

        // Then
        XCTAssertNotNil(fetchedGroup)
        XCTAssertEqual(fetchedGroup?.id, group.id)
        XCTAssertEqual(fetchedGroup?.name, "测试分组")
    }

    /// 测试获取不存在的分组返回 nil
    func testFetchNonExistentGroup() async throws {
        // Given
        let nonExistentId = UUID()

        // When
        let fetchedGroup = try await repository.fetch(by: nonExistentId)

        // Then
        XCTAssertNil(fetchedGroup)
    }

    // MARK: - 更新测试

    /// 测试更新分组
    func testUpdateGroup() async throws {
        // Given
        var group = SessionGroup(name: "原始名称", colorHex: "#4A90D9")
        try await repository.save(group)

        // When
        group.name = "更新后名称"
        group.colorHex = "#F04060"
        try await repository.save(group)
        let fetchedGroup = try await repository.fetch(by: group.id)

        // Then
        XCTAssertEqual(fetchedGroup?.name, "更新后名称")
        XCTAssertEqual(fetchedGroup?.colorHex, "#F04060")
    }

    /// 测试切换展开状态
    func testToggleExpanded() async throws {
        // Given
        var group = SessionGroup(name: "测试分组", colorHex: "#4A90D9")
        try await repository.save(group)
        let initialExpanded = group.isExpanded

        // When
        try await repository.toggleExpanded(group)
        let fetchedGroup = try await repository.fetch(by: group.id)

        // Then
        XCTAssertEqual(fetchedGroup?.isExpanded, !initialExpanded)
    }

    /// 测试设置展开状态
    func testSetExpanded() async throws {
        // Given
        var group = SessionGroup(name: "测试分组", colorHex: "#4A90D9")
        try await repository.save(group)

        // When - 设为折叠
        try await repository.setExpanded(group, isExpanded: false)
        var fetchedGroup = try await repository.fetch(by: group.id)
        XCTAssertEqual(fetchedGroup?.isExpanded, false)

        // When - 设为展开
        try await repository.setExpanded(group, isExpanded: true)
        fetchedGroup = try await repository.fetch(by: group.id)
        XCTAssertEqual(fetchedGroup?.isExpanded, true)
    }

    // MARK: - 删除测试

    /// 测试删除分组
    func testDeleteGroup() async throws {
        // Given
        let group = SessionGroup(name: "待删除分组", colorHex: "#F04060")
        try await repository.save(group)

        // When
        try await repository.delete(group)
        let groups = try await repository.fetchAll()

        // Then
        XCTAssertEqual(groups.count, 0)
    }

    /// 测试删除不存在的分组不抛出异常
    func testDeleteNonExistentGroup() async throws {
        // Given
        let nonExistentGroup = SessionGroup(name: "不存在", colorHex: "#000000")

        // When & Then - 不应抛出异常
        try await repository.delete(nonExistentGroup)
    }

    // MARK: - 嵌套分组测试

    /// 测试创建子分组
    func testCreateChildGroup() async throws {
        // Given
        var parentGroup = SessionGroup(name: "父分组", colorHex: "#4A90D9")
        try await repository.save(parentGroup)

        var childGroup = SessionGroup(
            name: "子分组",
            colorHex: "#2DCE7A",
            parentId: parentGroup.id
        )

        // When
        try await repository.save(childGroup)
        let fetchedChild = try await repository.fetch(by: childGroup.id)

        // Then
        XCTAssertEqual(fetchedChild?.parentId, parentGroup.id)
    }

    /// 测试获取顶级分组
    func testFetchTopLevelGroups() async throws {
        // Given
        var parentGroup = SessionGroup(name: "顶级分组", colorHex: "#4A90D9")
        try await repository.save(parentGroup)

        var childGroup = SessionGroup(
            name: "子分组",
            colorHex: "#2DCE7A",
            parentId: parentGroup.id
        )
        try await repository.save(childGroup)

        // When
        let topLevelGroups = try await repository.fetchTopLevel()

        // Then
        XCTAssertEqual(topLevelGroups.count, 1)
        XCTAssertEqual(topLevelGroups.first?.name, "顶级分组")
    }

    // MARK: - 排序测试

    /// 测试分组排序顺序
    func testGroupSortOrder() async throws {
        // Given
        var group1 = SessionGroup(name: "分组C", colorHex: "#4A90D9", sortOrder: 2)
        var group2 = SessionGroup(name: "分组A", colorHex: "#2DCE7A", sortOrder: 0)
        var group3 = SessionGroup(name: "分组B", colorHex: "#F0A500", sortOrder: 1)

        try await repository.save(group1)
        try await repository.save(group2)
        try await repository.save(group3)

        // When
        let groups = try await repository.fetchAll()

        // Then - 应按 sortOrder 排序
        XCTAssertEqual(groups[0].name, "分组A")
        XCTAssertEqual(groups[1].name, "分组B")
        XCTAssertEqual(groups[2].name, "分组C")
    }

    // MARK: - 批量操作测试

    /// 测试全部展开
    func testExpandAll() async throws {
        // Given
        var group1 = SessionGroup(name: "分组1", colorHex: "#4A90D9")
        group1 = SessionGroup(
            id: group1.id,
            name: group1.name,
            colorHex: group1.colorHex,
            sortOrder: group1.sortOrder,
            isExpanded: false,
            modifiedAt: group1.modifiedAt,
            parentId: group1.parentId,
            childrenIds: group1.childrenIds
        )
        var group2 = SessionGroup(name: "分组2", colorHex: "#2DCE7A")
        group2 = SessionGroup(
            id: group2.id,
            name: group2.name,
            colorHex: group2.colorHex,
            sortOrder: group2.sortOrder,
            isExpanded: false,
            modifiedAt: group2.modifiedAt,
            parentId: group2.parentId,
            childrenIds: group2.childrenIds
        )

        try await repository.save(group1)
        try await repository.save(group2)

        // When
        try await repository.expandAll()
        let groups = try await repository.fetchAll()

        // Then
        XCTAssertTrue(groups.allSatisfy { $0.isExpanded })
    }

    /// 测试全部折叠
    func testCollapseAll() async throws {
        // Given
        var group1 = SessionGroup(name: "分组1", colorHex: "#4A90D9")
        var group2 = SessionGroup(name: "分组2", colorHex: "#2DCE7A")

        try await repository.save(group1)
        try await repository.save(group2)

        // When
        try await repository.collapseAll()
        let groups = try await repository.fetchAll()

        // Then
        XCTAssertTrue(groups.allSatisfy { !$0.isExpanded })
    }
}
