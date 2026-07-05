import XCTest
@testable import ShellMate

/// 大数据性能基准（长期 backlog：大数据性能基准）
///
/// 覆盖实时/批量热路径，用 `measure` 建立性能基线，并配正确性断言防止功能回归：
/// - HighlightEngine.process：每批终端输出都会经过的实时高亮
/// - SSHConfigParser.parseContent：批量导入 SSH config
///
/// 说明：`measure` 记录基线用于本地 profiling 与回归对比；CI 中不因墙钟时间失败，
/// 功能回归由随附的正确性/规模断言拦截。
final class LargeDataPerformanceTests: XCTestCase {

    // MARK: - 高亮引擎（实时热路径）

    /// 构造约 lineCount 行合成终端输出，约 1/5 行含高亮关键字。
    private func makeTerminalOutput(lineCount: Int) -> Data {
        let keywords = ["error", "warning", "success", "failed", "info", "debug"]
        var lines: [String] = []
        lines.reserveCapacity(lineCount)
        for i in 0..<lineCount {
            if i % 5 == 0 {
                lines.append("[\(i)] \(keywords[i % keywords.count]): op on /var/log/app-\(i).log")
            } else {
                lines.append("[\(i)] processing item \(i) at 12:00:\(i % 60) OK")
            }
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    @MainActor
    func test_HighlightEngine_process_10kLines_Baseline() {
        let engine = HighlightEngine.shared
        engine.isEnabled = true
        engine.rules = HighlightRule.defaults
        let data = makeTerminalOutput(lineCount: 10_000)

        measure {
            _ = engine.process(data)
        }
    }

    @MainActor
    func test_HighlightEngine_process_InjectsANSI() {
        let engine = HighlightEngine.shared
        engine.isEnabled = true
        engine.rules = HighlightRule.defaults

        let out = engine.process(Data("build failed with error".utf8))
        let str = String(decoding: out, as: UTF8.self)
        XCTAssertTrue(str.contains("\u{1B}["), "匹配关键字应注入 ANSI 高亮序列")
        XCTAssertGreaterThan(out.count, "build failed with error".utf8.count, "高亮后字节数应增加")
    }

    @MainActor
    func test_HighlightEngine_process_DisabledReturnsOriginal() {
        let engine = HighlightEngine.shared
        engine.rules = HighlightRule.defaults
        engine.isEnabled = false

        let input = Data("line with error".utf8)
        XCTAssertEqual(engine.process(input), input, "禁用时应原样返回")
        engine.isEnabled = true  // 复位，避免影响其它测试
    }

    // MARK: - SSH Config 解析（批量导入热路径）

    /// 构造含 hostCount 个 Host 块的合成 SSH config。
    private func makeSSHConfig(hostCount: Int) -> String {
        var out = ""
        out.reserveCapacity(hostCount * 90)
        for i in 0..<hostCount {
            out += """
            Host server-\(i)
                HostName 10.\(i / 256).\(i % 256).10
                User ubuntu
                Port \(2000 + (i % 1000))
                IdentityFile ~/.ssh/id_ed25519_\(i)

            """
        }
        return out
    }

    func test_SSHConfigParser_parse_2000Hosts_Baseline() {
        let config = makeSSHConfig(hostCount: 2000)
        measure {
            _ = SSHConfigParser.parseContent(config)
        }
    }

    func test_SSHConfigParser_parse_2000Hosts_Correctness() {
        let config = makeSSHConfig(hostCount: 2000)
        let entries = SSHConfigParser.parseContent(config)
        XCTAssertEqual(entries.count, 2000, "应解析出全部 Host 块")
        XCTAssertEqual(entries.first?.username, "ubuntu")
        XCTAssertEqual(entries.first?.port, 2000)
    }
}
