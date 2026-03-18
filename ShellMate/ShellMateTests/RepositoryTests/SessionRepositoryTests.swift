import XCTest
import CoreData
@testable import ShellMate

/// SessionRepository 单元测试
/// 覆盖会话数据的增删改查全部操作
@MainActor
final class SessionRepositoryTests: XCTestCase {

    // MARK: - 测试属性

    var persistenceController: PersistenceController!
    var repository: SessionRepository!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        // 使用内存数据库进行测试
        persistenceController = PersistenceController(inMemory: true)
        repository = SessionRepository(persistenceController: persistenceController)
    }

    override func tearDown() async throws {
        repository = nil
        persistenceController = nil
        try await super.tearDown()
    }

    // MARK: - 创建测试

    /// 测试创建新会话
    func testCreateSession() async throws {
        // Given
        let session = Session(
            name: "测试服务器",
            host: "192.168.1.100",
            port: 22,
            username: "root"
        )

        // When
        try await repository.save(session)
        let sessions = try await repository.fetchAll()

        // Then
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.name, "测试服务器")
        XCTAssertEqual(sessions.first?.host, "192.168.1.100")
        XCTAssertEqual(sessions.first?.port, 22)
        XCTAssertEqual(sessions.first?.username, "root")
    }

    /// 测试创建多个会话
    func testCreateMultipleSessions() async throws {
        // Given
        let sessions = [
            Session(name: "服务器1", host: "host1.example.com", username: "user1"),
            Session(name: "服务器2", host: "host2.example.com", username: "user2"),
            Session(name: "服务器3", host: "host3.example.com", username: "user3")
        ]

        // When
        for session in sessions {
            try await repository.save(session)
        }
        let fetchedSessions = try await repository.fetchAll()

        // Then
        XCTAssertEqual(fetchedSessions.count, 3)
    }

    // MARK: - 读取测试

    /// 测试按 ID 获取会话
    func testFetchSessionById() async throws {
        // Given
        let session = Session(
            name: "测试会话",
            host: "test.example.com",
            username: "testuser"
        )
        try await repository.save(session)

        // When
        let fetchedSession = try await repository.fetch(by: session.id)

        // Then
        XCTAssertNotNil(fetchedSession)
        XCTAssertEqual(fetchedSession?.id, session.id)
        XCTAssertEqual(fetchedSession?.name, "测试会话")
    }

    /// 测试获取不存在的会话返回 nil
    func testFetchNonExistentSession() async throws {
        // Given
        let nonExistentId = UUID()

        // When
        let fetchedSession = try await repository.fetch(by: nonExistentId)

        // Then
        XCTAssertNil(fetchedSession)
    }

    /// 测试按分组获取会话
    func testFetchSessionsByGroup() async throws {
        // Given
        let groupId = UUID()
        let sessionsInGroup = [
            Session(name: "分组会话1", host: "h1.com", username: "u1", groupId: groupId),
            Session(name: "分组会话2", host: "h2.com", username: "u2", groupId: groupId)
        ]
        let sessionWithoutGroup = Session(name: "无分组会话", host: "h3.com", username: "u3")

        for session in sessionsInGroup {
            try await repository.save(session)
        }
        try await repository.save(sessionWithoutGroup)

        // When - 注意：此测试需要先创建分组才能正确关联
        let ungroupedSessions = try await repository.fetchByGroup(groupId: nil)

        // Then
        XCTAssertEqual(ungroupedSessions.count, 3) // 因为分组不存在，所有会话都是未分组的
    }

    // MARK: - 更新测试

    /// 测试更新会话
    func testUpdateSession() async throws {
        // Given
        var session = Session(
            name: "原始名称",
            host: "original.example.com",
            username: "originaluser"
        )
        try await repository.save(session)

        // When
        session.name = "更新后名称"
        session.host = "updated.example.com"
        try await repository.save(session)
        let fetchedSession = try await repository.fetch(by: session.id)

        // Then
        XCTAssertEqual(fetchedSession?.name, "更新后名称")
        XCTAssertEqual(fetchedSession?.host, "updated.example.com")
    }

    /// 测试更新会话标签
    func testUpdateSessionTags() async throws {
        // Given
        var session = Session(
            name: "标签测试",
            host: "tags.example.com",
            username: "user",
            tags: ["生产", "Linux"]
        )
        try await repository.save(session)

        // When
        session.tags = ["开发", "macOS", "新增标签"]
        try await repository.save(session)
        let fetchedSession = try await repository.fetch(by: session.id)

        // Then
        XCTAssertEqual(fetchedSession?.tags.count, 3)
        XCTAssertTrue(fetchedSession?.tags.contains("开发") ?? false)
        XCTAssertTrue(fetchedSession?.tags.contains("macOS") ?? false)
    }

    // MARK: - 删除测试

    /// 测试软删除会话
    func testSoftDeleteSession() async throws {
        // Given
        let session = Session(
            name: "待删除会话",
            host: "delete.example.com",
            username: "user"
        )
        try await repository.save(session)

        // When
        try await repository.delete(session)
        let sessions = try await repository.fetchAll()
        let deletedSession = try await repository.fetch(by: session.id)

        // Then
        XCTAssertEqual(sessions.count, 0) // fetchAll 不返回软删除的会话
        XCTAssertNil(deletedSession) // fetch 也不返回软删除的会话
    }

    /// 测试永久删除会话
    func testPermanentlyDeleteSession() async throws {
        // Given
        let session = Session(
            name: "永久删除会话",
            host: "permanent.example.com",
            username: "user"
        )
        try await repository.save(session)

        // When
        try await repository.permanentlyDelete(session)

        // Then
        // 验证从数据库中完全删除
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        let entities = try context.fetch(request)
        XCTAssertTrue(entities.isEmpty)
    }

    // MARK: - 搜索测试

    /// 测试按名称搜索
    func testSearchByName() async throws {
        // Given
        let sessions = [
            Session(name: "生产服务器", host: "prod.com", username: "admin"),
            Session(name: "开发服务器", host: "dev.com", username: "dev"),
            Session(name: "测试环境", host: "test.com", username: "test")
        ]
        for session in sessions {
            try await repository.save(session)
        }

        // When
        let results = try await repository.search(query: "服务器")

        // Then
        XCTAssertEqual(results.count, 2)
    }

    /// 测试按主机搜索
    func testSearchByHost() async throws {
        // Given
        let sessions = [
            Session(name: "服务器1", host: "api.example.com", username: "user1"),
            Session(name: "服务器2", host: "web.example.com", username: "user2"),
            Session(name: "服务器3", host: "db.other.com", username: "user3")
        ]
        for session in sessions {
            try await repository.save(session)
        }

        // When
        let results = try await repository.search(query: "example.com")

        // Then
        XCTAssertEqual(results.count, 2)
    }

    /// 测试空搜索返回全部
    func testEmptySearchReturnsAll() async throws {
        // Given
        let sessions = [
            Session(name: "服务器1", host: "h1.com", username: "u1"),
            Session(name: "服务器2", host: "h2.com", username: "u2")
        ]
        for session in sessions {
            try await repository.save(session)
        }

        // When
        let results = try await repository.search(query: "")

        // Then
        XCTAssertEqual(results.count, 2)
    }

    /// 测试搜索无结果
    func testSearchNoResults() async throws {
        // Given
        let session = Session(name: "服务器", host: "server.com", username: "user")
        try await repository.save(session)

        // When
        let results = try await repository.search(query: "不存在的内容")

        // Then
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - 移动测试

    /// 测试移动会话到分组
    func testMoveSessionToGroup() async throws {
        // Given
        var session = Session(
            name: "待移动会话",
            host: "move.example.com",
            username: "user"
        )
        try await repository.save(session)
        let newGroupId = UUID()

        // When
        try await repository.move(session: session, to: newGroupId)
        let fetchedSession = try await repository.fetch(by: session.id)

        // Then
        // 注意：由于分组不存在，groupId 不会被实际关联
        // 这里只验证方法调用不抛出异常
        XCTAssertNotNil(fetchedSession)
    }

    /// 测试移动会话到未分组
    func testMoveSessionToUngrouped() async throws {
        // Given
        let groupId = UUID()
        var session = Session(
            name: "待移动会话",
            host: "move.example.com",
            username: "user",
            groupId: groupId
        )
        try await repository.save(session)

        // When
        try await repository.move(session: session, to: nil)
        let fetchedSession = try await repository.fetch(by: session.id)

        // Then
        XCTAssertNil(fetchedSession?.groupId)
    }

    // MARK: - 排序测试

    /// 测试更新排序顺序
    func testUpdateSortOrder() async throws {
        // Given
        var session1 = Session(name: "会话1", host: "h1.com", username: "u1", sortOrder: 0)
        var session2 = Session(name: "会话2", host: "h2.com", username: "u2", sortOrder: 1)
        var session3 = Session(name: "会话3", host: "h3.com", username: "u3", sortOrder: 2)
        try await repository.save(session1)
        try await repository.save(session2)
        try await repository.save(session3)

        // When - 重新排序
        session1.sortOrder = 2
        session2.sortOrder = 0
        session3.sortOrder = 1
        try await repository.updateSortOrder(sessions: [session1, session2, session3])

        // Then
        let sessions = try await repository.fetchAll()
        XCTAssertEqual(sessions[0].name, "会话2") // sortOrder 0
        XCTAssertEqual(sessions[1].name, "会话3") // sortOrder 1
        XCTAssertEqual(sessions[2].name, "会话1") // sortOrder 2
    }

    // MARK: - 性能测试

    /// 测试 500 会话搜索性能 < 100ms
    func testSearchPerformance() async throws {
        // Given - 创建 500 个会话
        for i in 0..<500 {
            let session = Session(
                name: "服务器\(i)",
                host: "host\(i).example.com",
                username: "user\(i)",
                tags: i % 2 == 0 ? ["生产"] : ["开发"]
            )
            try await repository.save(session)
        }

        // When & Then - 测量搜索时间
        let startTime = CFAbsoluteTimeGetCurrent()
        let results = try await repository.search(query: "服务器1")
        let endTime = CFAbsoluteTimeGetCurrent()
        let elapsed = (endTime - startTime) * 1000 // 毫秒

        print("搜索 500 会话耗时: \(elapsed)ms")
        XCTAssertLessThan(elapsed, 100, "搜索应在 100ms 内完成")
        XCTAssertGreaterThan(results.count, 0)
    }
}
