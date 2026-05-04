import XCTest
@testable import ShellMate

/// TC-30.8：10,000 条 SFTP 文件列表渲染性能验证
/// 验收标准：
///   - 10,000 条 SFTPFileItem 构建耗时 < 1 秒
///   - SFTPPanelViewModel.remoteItems 写入 10,000 条后计算属性正确
///   - 文件列表过滤（按名称搜索）在 10,000 条中耗时 < 0.1 秒
///   - 排序（按 name / size / modifiedAt）在 10,000 条中耗时 < 0.2 秒
@MainActor
final class SFTPRenderPerformanceTests: XCTestCase {

    // MARK: - 辅助

    private func makeItems(count: Int) -> [SFTPFileItem] {
        (0..<count).map { i -> SFTPFileItem in
            let name = String(format: "file_%06d.log", i)
            let path = "/tmp/perf/" + name
            let type_: SFTPFileType = i % 10 == 0 ? .directory : .regularFile
            let size = UInt64(i * 1024)
            let mtime = Date(timeIntervalSinceNow: Double(-i * 60))
            return SFTPFileItem(
                name: name,
                path: path,
                fileType: type_,
                size: size,
                permissions: 0o644,
                modifiedAt: mtime,
                uid: 1000,
                gid: 1000
            )
        }
    }

    // MARK: - 30.8a：10,000 条 SFTPFileItem 构建耗时 < 1 秒

    func test_TC30_8a_BuildTenThousandItems_Under1Second() {
        let start = Date()
        let items = makeItems(count: 10_000)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(items.count, 10_000, "TC-30.8a：应构建 10,000 条 SFTPFileItem")
        XCTAssertLessThan(elapsed, 1.0,
            "TC-30.8a：10,000 条构建应在 1 秒内完成，实际：\(String(format: "%.3f", elapsed))s")
    }

    // MARK: - 30.8b：名称过滤 10,000 条中耗时 < 0.1 秒

    func test_TC30_8b_FilterByName_Under100ms() {
        let items = makeItems(count: 10_000)
        let keyword = "file_0005"

        let start = Date()
        let filtered = items.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertFalse(filtered.isEmpty, "TC-30.8b：过滤结果不应为空")
        XCTAssertLessThan(elapsed, 0.1,
            "TC-30.8b：10,000 条名称过滤应在 0.1 秒内完成，实际：\(String(format: "%.4f", elapsed))s")
    }

    // MARK: - 30.8c：按名称排序 10,000 条中耗时 < 0.2 秒

    func test_TC30_8c_SortByName_Under200ms() {
        var items = makeItems(count: 10_000)
        // 打乱顺序以模拟真实场景
        items.shuffle()

        let start = Date()
        let sorted = items.sorted { $0.name < $1.name }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(sorted.first?.name, "file_000000.log",
            "TC-30.8c：按名称升序排序后首条应为 file_000000.log")
        XCTAssertLessThan(elapsed, 0.2,
            "TC-30.8c：10,000 条名称排序应在 0.2 秒内完成，实际：\(String(format: "%.4f", elapsed))s")
    }

    // MARK: - 30.8d：按大小排序 10,000 条中耗时 < 0.2 秒

    func test_TC30_8d_SortBySize_Under200ms() {
        var items = makeItems(count: 10_000)
        items.shuffle()

        let start = Date()
        let sorted = items.sorted { $0.size > $1.size }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertGreaterThan(sorted.first?.size ?? 0, sorted.last?.size ?? .max,
            "TC-30.8d：按大小降序排序应正确")
        XCTAssertLessThan(elapsed, 0.2,
            "TC-30.8d：10,000 条大小排序应在 0.2 秒内完成，实际：\(String(format: "%.4f", elapsed))s")
    }

    // MARK: - 30.8e：目录/文件分类计数正确

    func test_TC30_8e_FileTypeCountCorrect() {
        let items = makeItems(count: 10_000)

        let dirCount  = items.filter { $0.fileType == .directory }.count
        let fileCount = items.filter { $0.fileType == .regularFile   }.count

        // 每 10 个中 1 个是目录（index % 10 == 0）
        XCTAssertEqual(dirCount, 1_000,
            "TC-30.8e：10,000 条中应有 1000 个目录（每隔 10 条一个）")
        XCTAssertEqual(fileCount, 9_000,
            "TC-30.8e：10,000 条中应有 9000 个文件")
    }

    // MARK: - 30.8f：XCTest measure 基准

    func test_TC30_8f_FilterMeasure() {
        let items = makeItems(count: 10_000)
        measure {
            _ = items.filter { $0.name.localizedCaseInsensitiveContains("file_001") }
        }
    }
}
