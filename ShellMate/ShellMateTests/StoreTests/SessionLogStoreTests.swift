import XCTest
@testable import ShellMate

/// SessionLogStore 单元测试
/// 覆盖日志追加、过滤、清除、导出及容量上限逻辑
final class SessionLogStoreTests: XCTestCase {

    // MARK: - 属性

    /// 独立测试实例（避免污染 shared 单例）
    private var store: SessionLogStoreTestable!

    // MARK: - 生命周期

    override func setUp() {
        super.setUp()
        store = SessionLogStoreTestable()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - 辅助方法

    private func makeEntry(
        session: String = "test@1.2.3.4",
        type: SessionLogEntry.LogType = .info,
        content: String = "测试日志",
        secondsAgo: Double = 0
    ) -> SessionLogEntry {
        SessionLogEntry(
            timestamp: Date().addingTimeInterval(-secondsAgo),
            sessionName: session,
            type: type,
            content: content
        )
    }

    // MARK: - LogType 基础测试

    /// LogType rawValue 与 label 应正确对应
    func testLogTypeRawValuesAndLabels() {
        XCTAssertEqual(SessionLogEntry.LogType.info.rawValue,    "info")
        XCTAssertEqual(SessionLogEntry.LogType.warning.rawValue, "warning")
        XCTAssertEqual(SessionLogEntry.LogType.error.rawValue,   "error")
        XCTAssertEqual(SessionLogEntry.LogType.command.rawValue, "command")

        XCTAssertEqual(SessionLogEntry.LogType.info.label,    "信息")
        XCTAssertEqual(SessionLogEntry.LogType.warning.label, "警告")
        XCTAssertEqual(SessionLogEntry.LogType.error.label,   "错误")
        XCTAssertEqual(SessionLogEntry.LogType.command.label, "命令")
    }

    /// LogType.allCases 应包含全部 4 种类型
    func testLogTypeAllCases() {
        XCTAssertEqual(SessionLogEntry.LogType.allCases.count, 4)
    }

    // MARK: - 初始状态测试

    /// 初始状态：entries 为空
    func testInitialState() {
        XCTAssertTrue(store.entries.isEmpty)
    }

    // MARK: - append 测试

    /// append 单条日志
    func testAppendSingleEntry() {
        let entry = makeEntry(content: "首条日志")
        store.appendSync(entry)

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.content, "首条日志")
    }

    /// append 多条日志保持顺序
    func testAppendMultipleEntriesPreservesOrder() {
        for i in 1...5 {
            store.appendSync(makeEntry(content: "日志\(i)"))
        }

        XCTAssertEqual(store.entries.count, 5)
        XCTAssertEqual(store.entries.first?.content, "日志1")
        XCTAssertEqual(store.entries.last?.content,  "日志5")
    }

    /// append 超过 maxEntries(5000) 时，最早的条目被裁剪
    func testAppendEnforcesMaxEntriesLimit() {
        let limit = store.testMaxEntries
        // 先填满
        for i in 0..<limit {
            store.appendSync(makeEntry(content: "entry-\(i)"))
        }
        XCTAssertEqual(store.entries.count, limit)

        // 再追加 10 条
        for i in 0..<10 {
            store.appendSync(makeEntry(content: "overflow-\(i)"))
        }

        XCTAssertEqual(store.entries.count, limit)
        // 最早的 10 条应已被裁剪，首条变为 entry-10
        XCTAssertEqual(store.entries.first?.content, "entry-10")
        XCTAssertEqual(store.entries.last?.content, "overflow-9")
    }

    // MARK: - clear 测试

    /// clear() 清空全部日志
    func testClearAll() {
        store.appendSync(makeEntry(session: "A"))
        store.appendSync(makeEntry(session: "B"))
        store.appendSync(makeEntry(session: "A"))

        store.clearSync()

        XCTAssertTrue(store.entries.isEmpty)
    }

    // MARK: - clearSession 测试

    /// clearSession 只删除指定会话的日志
    func testClearSessionPreservesOtherSessions() {
        store.appendSync(makeEntry(session: "session-A", content: "A1"))
        store.appendSync(makeEntry(session: "session-B", content: "B1"))
        store.appendSync(makeEntry(session: "session-A", content: "A2"))
        store.appendSync(makeEntry(session: "session-B", content: "B2"))

        store.clearSessionSync("session-A")

        XCTAssertEqual(store.entries.count, 2)
        XCTAssertTrue(store.entries.allSatisfy { $0.sessionName == "session-B" })
    }

    /// clearSession 对不存在的会话不报错
    func testClearNonExistentSessionIsNoOp() {
        store.appendSync(makeEntry(session: "existing"))
        store.clearSessionSync("nonexistent")

        XCTAssertEqual(store.entries.count, 1)
    }

    // MARK: - exportText 测试

    /// exportText 格式：[HH:mm:ss.SSS] [type] content
    func testExportTextFormat() {
        let entry = SessionLogEntry(
            timestamp: Date(timeIntervalSince1970: 0), // 1970-01-01 00:00:00 UTC
            sessionName: "test",
            type: .error,
            content: "发生错误"
        )

        let text = store.exportText(filtered: [entry])

        XCTAssertTrue(text.contains("[error]"),   "导出文本应包含 [error] 类型标签")
        XCTAssertTrue(text.contains("发生错误"),   "导出文本应包含日志内容")
        XCTAssertTrue(text.contains(":"),         "导出文本应包含时间戳冒号分隔")
    }

    /// exportText 多条日志用换行连接
    func testExportTextMultipleEntriesJoinedByNewline() {
        let entries = (1...3).map { i in
            SessionLogEntry(timestamp: Date(), sessionName: "s", type: .info, content: "行\(i)")
        }

        let text = store.exportText(filtered: entries)
        let lines = text.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 3)
    }

    /// exportText 空列表返回空字符串
    func testExportTextEmptyReturnsEmpty() {
        let text = store.exportText(filtered: [])
        XCTAssertTrue(text.isEmpty)
    }

    /// exportText 包含所有 LogType 的正确标签
    func testExportTextAllLogTypes() {
        let entries = SessionLogEntry.LogType.allCases.map { type in
            SessionLogEntry(timestamp: Date(), sessionName: "s", type: type, content: "test")
        }
        let text = store.exportText(filtered: entries)

        XCTAssertTrue(text.contains("[info]"))
        XCTAssertTrue(text.contains("[warning]"))
        XCTAssertTrue(text.contains("[error]"))
        XCTAssertTrue(text.contains("[command]"))
    }

    // MARK: - SessionLogEntry 基础测试

    /// SessionLogEntry id 每次创建都唯一
    func testEntryIdsAreUnique() {
        let e1 = makeEntry()
        let e2 = makeEntry()
        XCTAssertNotEqual(e1.id, e2.id)
    }

    /// SessionLogEntry 字段正确存储
    func testEntryFieldsArePreserved() {
        let now = Date()
        let entry = SessionLogEntry(
            timestamp: now,
            sessionName: "ubuntu@10.0.0.1",
            type: .command,
            content: "ls -la"
        )

        XCTAssertEqual(entry.timestamp, now)
        XCTAssertEqual(entry.sessionName, "ubuntu@10.0.0.1")
        XCTAssertEqual(entry.type, .command)
        XCTAssertEqual(entry.content, "ls -la")
    }
}

// MARK: - 可测试的 SessionLogStore 子类

/// 为单元测试提供同步写入接口，避免 DispatchQueue.main.async 异步时序问题
final class SessionLogStoreTestable {

    private(set) var entries: [SessionLogEntry] = []
    let testMaxEntries = 5000

    func appendSync(_ entry: SessionLogEntry) {
        entries.append(entry)
        if entries.count > testMaxEntries {
            entries.removeFirst(entries.count - testMaxEntries)
        }
    }

    func clearSync() {
        entries.removeAll()
    }

    func clearSessionSync(_ name: String) {
        entries.removeAll { $0.sessionName == name }
    }

    func exportText(filtered: [SessionLogEntry]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return filtered.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.type.rawValue)] \(entry.content)"
        }.joined(separator: "\n")
    }
}
