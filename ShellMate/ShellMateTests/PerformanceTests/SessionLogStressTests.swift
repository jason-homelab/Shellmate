import XCTest
@testable import ShellMate

/// TC-30.4：SessionLogStore + LogPanelView 1万条日志推送极限验证
/// 验收标准：
///   - 10,000 条 append 完成时间 < 5 秒（单次追加平均 ≤ 0.5ms）
///   - maxEntries(5000) 上限裁剪逻辑正确：超出时首条为第 5001 条
///   - 高频 append 后 entries.count 不超过 maxEntries
///   - exportText 对 5000 条数据的格式化耗时 < 1 秒
final class SessionLogStressTests: XCTestCase {

    // MARK: - 可测试 Store（同步操作，规避 DispatchQueue.main.async）

    private var store: SessionLogStoreTestable!

    override func setUp() {
        super.setUp()
        store = SessionLogStoreTestable()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - 辅助

    private func makeEntry(index: Int, session: String = "ubuntu@192.168.100.167") -> SessionLogEntry {
        SessionLogEntry(
            timestamp: Date(),
            sessionName: session,
            type: index % 4 == 0 ? .error : (index % 3 == 0 ? .warning : .info),
            content: "第 \(index) 条日志 — ls -la /tmp/shellmate && echo done"
        )
    }

    // MARK: - 30.4a：10,000 条追加完成时间 < 5 秒

    func test_TC30_4a_AppendTenThousandEntries_Under5Seconds() {
        let count = 10_000
        let start = Date()
        for i in 0..<count {
            store.appendSync(makeEntry(index: i))
        }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 5.0,
            "TC-30.4a：10,000 条追加应在 5 秒内完成，实际耗时：\(String(format: "%.3f", elapsed))s")
    }

    // MARK: - 30.4b：超出 maxEntries(5000) 后裁剪逻辑正确

    func test_TC30_4b_MaxEntriesClampCorrect() {
        let maxEntries = store.testMaxEntries  // 5000
        let pushCount  = 10_000

        for i in 0..<pushCount {
            store.appendSync(makeEntry(index: i))
        }

        XCTAssertEqual(store.entries.count, maxEntries,
            "TC-30.4b：追加 \(pushCount) 条后 entries.count 应被裁剪到 \(maxEntries)")

        // 首条应为第 5000 条（index=5000），末条为第 9999 条（index=9999）
        XCTAssertTrue(store.entries.first?.content.contains("第 5000") == true,
            "TC-30.4b：裁剪后首条应为 index=5000，实际：\(store.entries.first?.content ?? "nil")")
        XCTAssertTrue(store.entries.last?.content.contains("第 9999") == true,
            "TC-30.4b：裁剪后末条应为 index=9999，实际：\(store.entries.last?.content ?? "nil")")
    }

    // MARK: - 30.4c：高频混合操作（append + clearSession）无崩溃

    func test_TC30_4c_MixedOperationsNoCrash() {
        let sessions = ["session-A", "session-B", "session-C"]
        for i in 0..<5_000 {
            let s = sessions[i % sessions.count]
            store.appendSync(SessionLogEntry(
                timestamp: Date(),
                sessionName: s,
                type: .info,
                content: "日志 \(i)"
            ))
        }
        // 清除其中一个会话
        store.clearSessionSync("session-B")

        // 验证 B 已清除，A/C 保留
        let hasB = store.entries.contains { $0.sessionName == "session-B" }
        XCTAssertFalse(hasB, "TC-30.4c：clearSession 后 session-B 的条目应全部删除")
        XCTAssertGreaterThan(store.entries.count, 0,
            "TC-30.4c：其他会话条目应仍然存在")
    }

    // MARK: - 30.4d：exportText 对 5000 条数据格式化耗时 < 1 秒

    func test_TC30_4d_ExportTextPerformanceUnder1Second() {
        for i in 0..<store.testMaxEntries {
            store.appendSync(makeEntry(index: i))
        }
        XCTAssertEqual(store.entries.count, store.testMaxEntries)

        let start = Date()
        let text = store.exportText(filtered: store.entries)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertFalse(text.isEmpty, "TC-30.4d：exportText 结果不应为空")
        XCTAssertLessThan(elapsed, 1.0,
            "TC-30.4d：exportText 5000 条应在 1 秒内完成，实际耗时：\(String(format: "%.3f", elapsed))s")
    }

    // MARK: - 30.4e：XCTest measure 基准（官方性能回归保护）

    func test_TC30_4e_AppendPerformanceMeasure() {
        measure {
            let localStore = SessionLogStoreTestable()
            for i in 0..<10_000 {
                localStore.appendSync(makeEntry(index: i))
            }
        }
    }
}
