import XCTest
@testable import ShellMate

/// TerminalViewModel 单元测试
/// 覆盖 AI 错误侦探、输出缓冲区、指标面板状态及 ANSI 剥离
@MainActor
final class TerminalViewModelTests: XCTestCase {

    // MARK: - 属性

    var vm: TerminalViewModel!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        vm = TerminalViewModel()
    }

    override func tearDown() async throws {
        vm = nil
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialState_noPanelOpen() {
        XCTAssertFalse(vm.isComposePaneOpen)
        XCTAssertFalse(vm.isRecordingDialogOpen)
    }

    func testInitialState_noMetrics() {
        XCTAssertNil(vm.serverMetrics)
    }

    func testInitialState_noDetectedError() {
        XCTAssertNil(vm.detectedErrorText)
    }

    func testInitialState_outputBufferEmpty() {
        XCTAssertTrue(vm.recentTerminalOutput().isEmpty)
    }

    // MARK: - 面板状态

    func testIsComposePaneOpen_canBeToggled() {
        vm.isComposePaneOpen = true
        XCTAssertTrue(vm.isComposePaneOpen)
        vm.isComposePaneOpen = false
        XCTAssertFalse(vm.isComposePaneOpen)
    }

    func testIsRecordingDialogOpen_canBeToggled() {
        vm.isRecordingDialogOpen = true
        XCTAssertTrue(vm.isRecordingDialogOpen)
        vm.isRecordingDialogOpen = false
        XCTAssertFalse(vm.isRecordingDialogOpen)
    }

    func testPanelStates_areIndependent() {
        vm.isComposePaneOpen = true
        XCTAssertFalse(vm.isRecordingDialogOpen)
        vm.isRecordingDialogOpen = true
        XCTAssertTrue(vm.isComposePaneOpen)
    }

    // MARK: - 输出缓冲区

    func testUpdateOutputBuffer_appendsText() {
        vm.updateOutputBuffer("hello ")
        vm.updateOutputBuffer("world")
        XCTAssertEqual(vm.recentTerminalOutput(), "hello world")
    }

    func testUpdateOutputBuffer_emptyString_noOp() {
        vm.updateOutputBuffer("existing")
        vm.updateOutputBuffer("")
        XCTAssertEqual(vm.recentTerminalOutput(), "existing")
    }

    func testUpdateOutputBuffer_truncatesAtMaxLength() {
        // 写入超过 32_000 字符的内容，应截断
        let bigText = String(repeating: "x", count: 40_000)
        vm.updateOutputBuffer(bigText)
        XCTAssertLessThanOrEqual(vm.recentTerminalOutput().count, 32_000)
    }

    // MARK: - AI 错误侦探

    func testDetectErrors_commandNotFound_setsDetectedText() {
        vm.detectErrors(in: "bash: foo: command not found")
        XCTAssertNotNil(vm.detectedErrorText)
    }

    func testDetectErrors_permissionDenied_setsDetectedText() {
        vm.detectErrors(in: "Permission denied (publickey)")
        XCTAssertNotNil(vm.detectedErrorText)
    }

    func testDetectErrors_normalOutput_doesNotSetError() {
        vm.detectErrors(in: "total 48\ndrwxr-xr-x  5 ubuntu ubuntu 4096 Jan 1 00:00 .\n")
        XCTAssertNil(vm.detectedErrorText)
    }

    func testDetectErrors_truncatesLongLine() {
        let longError = "command not found: " + String(repeating: "a", count: 200)
        vm.detectErrors(in: longError)
        XCTAssertNotNil(vm.detectedErrorText)
        XCTAssertLessThanOrEqual(vm.detectedErrorText!.count, 120)
    }

    func testClearDetectedError_nilsDetectedText() {
        vm.detectErrors(in: "command not found")
        XCTAssertNotNil(vm.detectedErrorText)
        vm.clearDetectedError()
        XCTAssertNil(vm.detectedErrorText)
    }

    func testClearDetectedError_whenNone_doesNotCrash() {
        XCTAssertNil(vm.detectedErrorText)
        vm.clearDetectedError() // 无 crash 即通过
    }

    // MARK: - ANSI 剥离

    func testStripANSI_removesColorCodes() {
        let colored = "\u{1B}[32mhello\u{1B}[0m world"
        let result = vm.stripANSI(colored)
        XCTAssertEqual(result, "hello world")
    }

    func testStripANSI_plainText_unchanged() {
        let plain = "hello world"
        XCTAssertEqual(vm.stripANSI(plain), plain)
    }

    func testStripANSI_emptyString_unchanged() {
        XCTAssertEqual(vm.stripANSI(""), "")
    }

    func testStripANSI_multipleCodes_allRemoved() {
        let text = "\u{1B}[1m\u{1B}[31mERROR\u{1B}[0m: something went wrong"
        let result = vm.stripANSI(text)
        XCTAssertEqual(result, "ERROR: something went wrong")
    }

    // MARK: - stopMetricsMonitor（无 monitor 时 no-op）

    func testStopMetricsMonitor_whenNone_doesNotCrash() {
        vm.stopMetricsMonitor()
        XCTAssertNil(vm.serverMetrics)
    }
}
