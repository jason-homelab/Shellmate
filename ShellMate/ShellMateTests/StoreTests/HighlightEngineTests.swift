import XCTest
@testable import ShellMate

/// HighlightEngine 单元测试
/// 覆盖规则管理、关键字高亮注入、正则模式、禁用逻辑、边界场景
@MainActor
final class HighlightEngineTests: XCTestCase {

    // MARK: - 属性

    private var engine: HighlightEngine!

    /// 测试前保存 shared 原始状态，测试后完整还原
    private var savedRules:     [HighlightRule]!
    private var savedIsEnabled: Bool!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        engine = HighlightEngine.shared
        savedRules     = engine.rules
        savedIsEnabled = engine.isEnabled
        // 测试开始时清空，使用隔离环境
        engine.rules     = []
        engine.isEnabled = true
    }

    override func tearDown() async throws {
        engine.rules     = savedRules
        engine.isEnabled = savedIsEnabled
        engine = nil
        try await super.tearDown()
    }

    // MARK: - 辅助

    private func utf8(_ string: String) -> Data { string.data(using: .utf8)! }
    private func string(_ data: Data) -> String { String(data: data, encoding: .utf8) ?? "" }

    private func makeRule(
        pattern: String,
        color: HighlightColor = .red,
        enabled: Bool = true,
        useRegex: Bool = false
    ) -> HighlightRule {
        HighlightRule(pattern: pattern, color: color, enabled: enabled, useRegex: useRegex)
    }

    // MARK: - 禁用模式测试

    /// isEnabled = false 时，数据原样返回，不注入 ANSI
    func testDisabledEnginePassthrough() {
        engine.isEnabled = false
        engine.rules = [makeRule(pattern: "ERROR")]

        let input = utf8("ERROR occurred")
        let output = engine.process(input)

        XCTAssertEqual(output, input)
    }

    /// 空规则列表时，数据原样返回
    func testEmptyRulesPassthrough() {
        engine.rules = []
        let input = utf8("ERROR something failed")
        let output = engine.process(input)

        XCTAssertEqual(output, input)
    }

    // MARK: - 字面量匹配测试

    /// 字面量规则命中关键字，输出含 ANSI 序列
    func testLiteralRuleInjectsANSI() {
        engine.rules = [makeRule(pattern: "ERROR", color: .red)]

        let output = string(engine.process(utf8("Some ERROR happened")))

        XCTAssertTrue(output.contains("\u{1B}[31m"), "应注入红色 ANSI（\\e[31m）")
        XCTAssertTrue(output.contains("ERROR"),     "关键字 ERROR 仍应存在于输出")
        XCTAssertTrue(output.contains("\u{1B}[0m"), "应有复位序列（\\e[0m）")
    }

    /// 字面量规则：不含关键字时，数据不变
    func testLiteralRuleNoMatchReturnsUnchanged() {
        engine.rules = [makeRule(pattern: "ERROR")]

        let raw = "Everything is fine\n"
        let output = string(engine.process(utf8(raw)))

        XCTAssertEqual(output, raw)
        XCTAssertFalse(output.contains("\u{1B}["))
    }

    /// 字面量规则区分大小写：ERROR 不匹配 error
    func testLiteralRuleCaseSensitive() {
        engine.rules = [makeRule(pattern: "ERROR")]

        let output = string(engine.process(utf8("error: something")))

        XCTAssertFalse(output.contains("\u{1B}["), "小写 error 不应被 ERROR 规则匹配")
    }

    /// 多条规则各自命中，分别注入对应颜色
    func testMultipleRulesApplied() {
        engine.rules = [
            makeRule(pattern: "ERROR",   color: .red),
            makeRule(pattern: "WARNING", color: .yellow),
        ]

        let output = string(engine.process(utf8("ERROR and WARNING occurred")))

        XCTAssertTrue(output.contains("\u{1B}[31m"), "ERROR 应为红色（31m）")
        XCTAssertTrue(output.contains("\u{1B}[33m"), "WARNING 应为黄色（33m）")
    }

    // MARK: - 禁用规则测试

    /// enabled = false 的规则不产生高亮
    func testDisabledRuleSkipped() {
        engine.rules = [makeRule(pattern: "ERROR", enabled: false)]

        let input = utf8("ERROR found")
        let output = engine.process(input)

        XCTAssertEqual(output, input, "禁用规则不应修改数据")
    }

    /// 混合启用/禁用规则：只有启用的规则生效
    func testMixedEnabledDisabledRules() {
        engine.rules = [
            makeRule(pattern: "ERROR",   color: .red,    enabled: true),
            makeRule(pattern: "WARNING", color: .yellow, enabled: false),
        ]

        let output = string(engine.process(utf8("ERROR and WARNING")))

        XCTAssertTrue(output.contains("\u{1B}[31m"),  "启用的 ERROR 应高亮")
        XCTAssertFalse(output.contains("\u{1B}[33m"), "禁用的 WARNING 不应高亮")
    }

    // MARK: - 正则表达式模式测试

    /// useRegex = true 时，使用正则表达式匹配
    func testRegexRuleMatches() {
        engine.rules = [makeRule(pattern: "\\bERR\\w*\\b", color: .red, useRegex: true)]

        let output = string(engine.process(utf8("ERRNO=2 and ERROR in module")))

        XCTAssertTrue(output.contains("\u{1B}[31m"), "正则规则应命中 ERRNO 和 ERROR")
    }

    /// 无效正则表达式规则被静默忽略（不崩溃）
    func testInvalidRegexRuleSilentlyIgnored() {
        engine.rules = [makeRule(pattern: "[invalid(", useRegex: true)]

        let input = utf8("some text")
        let output = engine.process(input)

        XCTAssertEqual(output, input, "无效正则不应修改数据，也不应崩溃")
    }

    // MARK: - 双重高亮防护测试

    /// 已含 ESC 的片段不被二次高亮（避免破坏已有 ANSI 序列）
    func testAlreadyHighlightedFragmentNotDoubleHighlighted() {
        engine.rules = [makeRule(pattern: "ERROR", color: .red)]

        // 输入中 ERROR 已被 green 高亮
        let preHighlighted = "\u{1B}[32mERROR\u{1B}[0m something"
        let output = string(engine.process(utf8(preHighlighted)))

        // 输出不应出现 red（31m）序列注入
        XCTAssertFalse(output.contains("\u{1B}[31m"), "已有 ANSI 序列的片段不应被二次高亮")
    }

    // MARK: - 规则管理测试

    /// addRule：新规则追加到列表末尾
    func testAddRule() {
        let rule = makeRule(pattern: "CRITICAL", color: .magenta)
        engine.addRule(rule)

        XCTAssertEqual(engine.rules.count, 1)
        XCTAssertEqual(engine.rules.first?.pattern, "CRITICAL")
    }

    /// removeRule：按 id 删除指定规则
    func testRemoveRule() {
        let r1 = makeRule(pattern: "ERROR")
        let r2 = makeRule(pattern: "WARN")
        engine.addRule(r1)
        engine.addRule(r2)

        engine.removeRule(id: r1.id)

        XCTAssertEqual(engine.rules.count, 1)
        XCTAssertEqual(engine.rules.first?.pattern, "WARN")
    }

    /// removeRule：id 不存在时不报错
    func testRemoveNonExistentRuleIsNoOp() {
        engine.addRule(makeRule(pattern: "ERROR"))
        engine.removeRule(id: UUID()) // 不存在

        XCTAssertEqual(engine.rules.count, 1)
    }

    /// updateRule：更新规则的 pattern、color 等字段
    func testUpdateRule() {
        var rule = makeRule(pattern: "ERROR", color: .red)
        engine.addRule(rule)

        rule.pattern = "FATAL"
        rule.color   = .magenta
        engine.updateRule(rule)

        XCTAssertEqual(engine.rules.first?.pattern, "FATAL")
        XCTAssertEqual(engine.rules.first?.color,   .magenta)
    }

    /// updateRule：id 不存在时不报错
    func testUpdateNonExistentRuleIsNoOp() {
        engine.addRule(makeRule(pattern: "ERROR"))
        engine.updateRule(makeRule(pattern: "GHOST")) // 不同 id

        XCTAssertEqual(engine.rules.first?.pattern, "ERROR") // 未被修改
    }

    // MARK: - 非 UTF-8 数据测试

    /// 非 UTF-8 字节序列原样返回（不崩溃）
    func testNonUTF8DataPassthrough() {
        engine.rules = [makeRule(pattern: "ERROR")]

        let binary = Data([0xFF, 0xFE, 0x00, 0x01, 0xAB])
        let output = engine.process(binary)

        XCTAssertEqual(output, binary, "非 UTF-8 数据应原样返回")
    }

    // MARK: - 空数据测试

    /// 空 Data 原样返回
    func testEmptyDataPassthrough() {
        engine.rules = [makeRule(pattern: "ERROR")]

        let empty = Data()
        let output = engine.process(empty)

        XCTAssertEqual(output, empty)
    }

    // MARK: - 颜色代码映射测试

    /// HighlightColor ANSI 前景色代码正确
    func testHighlightColorANSICodes() {
        XCTAssertEqual(HighlightColor.red.ansiFGCode,     "31")
        XCTAssertEqual(HighlightColor.yellow.ansiFGCode,  "33")
        XCTAssertEqual(HighlightColor.green.ansiFGCode,   "32")
        XCTAssertEqual(HighlightColor.cyan.ansiFGCode,    "36")
        XCTAssertEqual(HighlightColor.magenta.ansiFGCode, "35")
        XCTAssertEqual(HighlightColor.blue.ansiFGCode,    "34")
        XCTAssertEqual(HighlightColor.white.ansiFGCode,   "37")
    }

    // MARK: - 默认规则测试

    /// HighlightRule.defaults 覆盖核心关键字
    func testDefaultRulesContainEssentialKeywords() {
        let defaults = HighlightRule.defaults
        let patterns = defaults.map(\.pattern)

        XCTAssertTrue(patterns.contains("ERROR"),   "默认规则应包含 ERROR")
        XCTAssertTrue(patterns.contains("error"),   "默认规则应包含 error")
        XCTAssertTrue(patterns.contains("warning"), "默认规则应包含 warning")
        XCTAssertTrue(patterns.contains("WARN"),    "默认规则应包含 WARN")
        XCTAssertTrue(patterns.contains("success"), "默认规则应包含 success")
        XCTAssertTrue(patterns.contains("failed"),  "默认规则应包含 failed")
    }

    /// 默认规则中 ERROR/error 均使用红色
    func testDefaultErrorRulesAreRed() {
        let defaults = HighlightRule.defaults
        let errorRules = defaults.filter { $0.pattern == "ERROR" || $0.pattern == "error" }

        XCTAssertTrue(errorRules.allSatisfy { $0.color == .red }, "ERROR/error 规则应为红色")
    }

    // MARK: - 性能测试

    /// 1MB 数据处理性能 < 500ms
    func testProcessPerformanceLargeData() {
        engine.rules = HighlightRule.defaults
        // 构造 1MB 数据（包含少量 ERROR 关键字）
        let chunk = String(repeating: "Normal output line with no keywords.\n", count: 100)
        let errorLine = "ERROR: critical failure detected\n"
        let fullText = String(repeating: chunk + errorLine, count: 27) // ~1MB
        let data = fullText.data(using: .utf8)!

        let start = CFAbsoluteTimeGetCurrent()
        _ = engine.process(data)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        print("高亮引擎处理 1MB 数据耗时: \(String(format: "%.1f", elapsed))ms")
        XCTAssertLessThan(elapsed, 500, "高亮引擎处理 1MB 数据应在 500ms 内完成")
    }
}
