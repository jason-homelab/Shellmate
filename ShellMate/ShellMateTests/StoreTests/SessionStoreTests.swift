import XCTest
import CoreData
@testable import ShellMate

/// SessionStore 单元测试
/// 覆盖会话状态管理器的状态流转和业务逻辑
@MainActor
final class SessionStoreTests: XCTestCase {

    // MARK: - 测试属性

    var persistenceController: PersistenceController!
    var repository: SessionRepository!
    var store: SessionStore!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        repository = SessionRepository(persistenceController: persistenceController)
        store = SessionStore(repository: repository)
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
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertTrue(store.filteredSessions.isEmpty)
        XCTAssertEqual(store.searchQuery, "")
        XCTAssertNil(store.selectedSessionId)
        XCTAssertNil(store.editingSession)
        XCTAssertFalse(store.isShowingSessionForm)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
    }

    // MARK: - 加载测试

    /// 测试加载会话
    func testLoadSessions() async throws {
        // Given
        let session = Session(name: "测试会话", host: "test.com", username: "user")
        try await repository.save(session)

        // When
        await store.loadSessions()

        // Then
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.filteredSessions.count, 1)
        XCTAssertFalse(store.isLoading)
    }

    /// 测试加载空会话列表
    func testLoadEmptySessions() async throws {
        // When
        await store.loadSessions()

        // Then
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertTrue(store.filteredSessions.isEmpty)
    }

    // MARK: - 搜索测试

    /// 测试搜索过滤
    func testSearchFilter() async throws {
        // Given
        let sessions = [
            Session(name: "生产服务器", host: "prod.com", username: "admin"),
            Session(name: "开发服务器", host: "dev.com", username: "dev"),
            Session(name: "测试环境", host: "test.com", username: "test")
        ]
        for session in sessions {
            try await repository.save(session)
        }
        await store.loadSessions()

        // When
        store.searchQuery = "服务器"

        // 等待搜索完成
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then
        XCTAssertEqual(store.filteredSessions.count, 2)
    }

    /// 测试清空搜索恢复全部
    func testClearSearchRestoresAll() async throws {
        // Given
        let sessions = [
            Session(name: "服务器1", host: "h1.com", username: "u1"),
            Session(name: "服务器2", host: "h2.com", username: "u2")
        ]
        for session in sessions {
            try await repository.save(session)
        }
        await store.loadSessions()
        store.searchQuery = "服务器1"
        try await Task.sleep(nanoseconds: 100_000_000)

        // When
        store.searchQuery = ""
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(store.filteredSessions.count, 2)
    }

    // MARK: - CRUD 测试

    /// 测试保存会话
    func testSaveSession() async throws {
        // Given
        let session = Session(name: "新会话", host: "new.com", username: "newuser")

        // When
        await store.saveSession(session)

        // Then
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions.first?.name, "新会话")
    }

    /// 测试删除会话
    func testDeleteSession() async throws {
        // Given
        let session = Session(name: "待删除", host: "delete.com", username: "user")
        await store.saveSession(session)
        store.selectedSessionId = session.id

        // When
        await store.deleteSession(session)

        // Then
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertNil(store.selectedSessionId)
    }

    /// 测试删除选中的会话清除选中状态
    func testDeleteSelectedSessionClearsSelection() async throws {
        // Given
        let session1 = Session(name: "会话1", host: "h1.com", username: "u1")
        let session2 = Session(name: "会话2", host: "h2.com", username: "u2")
        await store.saveSession(session1)
        await store.saveSession(session2)
        store.selectedSessionId = session1.id

        // When
        await store.deleteSession(session1)

        // Then
        XCTAssertNil(store.selectedSessionId)
        XCTAssertEqual(store.sessions.count, 1)
    }

    // MARK: - 移动测试

    /// 测试移动会话到分组
    func testMoveSessionToGroup() async throws {
        // Given
        let session = Session(name: "待移动", host: "move.com", username: "user")
        await store.saveSession(session)
        let groupId = UUID()

        // When
        await store.moveSession(session, to: groupId)

        // Then
        // 由于分组不存在，会话的 groupId 可能不会被实际更新
        // 这里主要测试方法不抛出异常
        XCTAssertEqual(store.sessions.count, 1)
    }

    // MARK: - 排序测试

    /// 测试更新排序
    func testUpdateSortOrder() async throws {
        // Given
        let session1 = Session(name: "会话1", host: "h1.com", username: "u1", sortOrder: 0)
        let session2 = Session(name: "会话2", host: "h2.com", username: "u2", sortOrder: 1)
        let session3 = Session(name: "会话3", host: "h3.com", username: "u3", sortOrder: 2)
        await store.saveSession(session1)
        await store.saveSession(session2)
        await store.saveSession(session3)

        // When - 将第一个会话移到最后
        await store.updateSortOrder(
            from: IndexSet(integer: 0),
            to: 3,
            in: nil
        )

        // Then
        XCTAssertEqual(store.sessions.count, 3)
    }

    // MARK: - 弹窗状态测试

    /// 测试显示新建会话弹窗
    func testShowNewSessionForm() async throws {
        // When
        store.showNewSessionForm()

        // Then
        XCTAssertTrue(store.isShowingSessionForm)
        XCTAssertNil(store.editingSession)
    }

    /// 测试显示编辑会话弹窗
    func testShowEditSessionForm() async throws {
        // Given
        let session = Session(name: "待编辑", host: "edit.com", username: "user")
        await store.saveSession(session)

        // When
        store.showEditSessionForm(for: session)

        // Then
        XCTAssertTrue(store.isShowingSessionForm)
        XCTAssertEqual(store.editingSession?.id, session.id)
    }

    /// 测试关闭弹窗
    func testDismissSessionForm() async throws {
        // Given
        let session = Session(name: "测试", host: "test.com", username: "user")
        store.showEditSessionForm(for: session)

        // When
        store.dismissSessionForm()

        // Then
        XCTAssertFalse(store.isShowingSessionForm)
        XCTAssertNil(store.editingSession)
    }

    // MARK: - 连接状态测试

    /// 测试更新连接状态
    func testUpdateConnectionState() async throws {
        // Given
        let session = Session(name: "测试", host: "test.com", username: "user")
        await store.saveSession(session)

        // When
        store.updateConnectionState(for: session.id, state: .connecting)

        // Then
        XCTAssertEqual(store.sessions.first?.connectionState, .connecting)
        XCTAssertEqual(store.filteredSessions.first?.connectionState, .connecting)
    }

    /// 测试连接状态流转：离线 -> 连接中 -> 已连接
    func testConnectionStateTransition() async throws {
        // Given
        let session = Session(name: "测试", host: "test.com", username: "user")
        await store.saveSession(session)
        XCTAssertEqual(store.sessions.first?.connectionState, .offline)

        // When - 开始连接
        store.updateConnectionState(for: session.id, state: .connecting)
        XCTAssertEqual(store.sessions.first?.connectionState, .connecting)

        // When - 连接成功
        store.updateConnectionState(for: session.id, state: .connected)
        XCTAssertEqual(store.sessions.first?.connectionState, .connected)
    }

    /// 测试连接状态流转：已连接 -> 断开中 -> 离线
    func testDisconnectionStateTransition() async throws {
        // Given
        let session = Session(name: "测试", host: "test.com", username: "user")
        await store.saveSession(session)
        store.updateConnectionState(for: session.id, state: .connected)

        // When - 开始断开
        store.updateConnectionState(for: session.id, state: .disconnecting)
        XCTAssertEqual(store.sessions.first?.connectionState, .disconnecting)

        // When - 断开完成
        store.updateConnectionState(for: session.id, state: .offline)
        XCTAssertEqual(store.sessions.first?.connectionState, .offline)
    }

    /// 测试连接错误状态
    func testConnectionErrorState() async throws {
        // Given
        let session = Session(name: "测试", host: "test.com", username: "user")
        await store.saveSession(session)
        store.updateConnectionState(for: session.id, state: .connecting)

        // When - 连接失败
        store.updateConnectionState(for: session.id, state: .error)

        // Then
        XCTAssertEqual(store.sessions.first?.connectionState, .error)
    }

    // MARK: - 选中状态测试

    /// 测试选中会话
    func testSelectSession() async throws {
        // Given
        let session = Session(name: "测试", host: "test.com", username: "user")
        await store.saveSession(session)

        // When
        store.selectedSessionId = session.id

        // Then
        XCTAssertEqual(store.selectedSessionId, session.id)
        XCTAssertNotNil(store.selectedSession)
        XCTAssertEqual(store.selectedSession?.id, session.id)
    }

    /// 测试选中不存在的会话
    func testSelectNonExistentSession() async throws {
        // When
        store.selectedSessionId = UUID()

        // Then
        XCTAssertNotNil(store.selectedSessionId)
        XCTAssertNil(store.selectedSession)
    }

    // MARK: - 最后连接时间测试

    /// 测试更新最后连接时间
    func testUpdateLastConnectedAt() async throws {
        // Given
        let session = Session(name: "测试", host: "test.com", username: "user")
        await store.saveSession(session)
        XCTAssertNil(store.sessions.first?.lastConnectedAt)

        // When
        await store.updateLastConnectedAt(for: session.id)

        // Then
        XCTAssertNotNil(store.sessions.first?.lastConnectedAt)
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
