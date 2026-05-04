import XCTest
@testable import ShellMate

/// AIPanelViewModel 单元测试
/// 覆盖初始状态、消息追加、取消/清空、模式切换及回调安全
@MainActor
final class AIPanelViewModelTests: XCTestCase {

    // MARK: - 属性

    var vm: AIPanelViewModel!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        vm = AIPanelViewModel(session: Session.preview)
    }

    override func tearDown() async throws {
        vm = nil
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialState_hasWelcomeMessage() {
        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages.first?.role, .assistant)
    }

    func testInitialState_notStreaming() {
        XCTAssertFalse(vm.isStreaming)
    }

    func testInitialState_streamingContentEmpty() {
        XCTAssertTrue(vm.streamingContent.isEmpty)
    }

    func testInitialState_inputTextEmpty() {
        XCTAssertTrue(vm.inputText.isEmpty)
    }

    func testInitialState_defaultModeIsChat() {
        XCTAssertEqual(vm.inputMode, .chat)
    }

    func testInitialState_canRetryFalse() {
        XCTAssertFalse(vm.canRetry)
    }

    func testInitialState_noErrorMessage() {
        XCTAssertNil(vm.errorMessage)
    }

    func testInitialState_sessionStored() {
        XCTAssertEqual(vm.session.id, Session.preview.id)
    }

    // MARK: - 输入模式

    func testInputMode_canSwitchToNlCommand() {
        vm.inputMode = .nlCommand
        XCTAssertEqual(vm.inputMode, .nlCommand)
    }

    func testInputMode_rawValues_notEmpty() {
        for mode in AIInputMode.allCases {
            XCTAssertFalse(mode.rawValue.isEmpty)
        }
    }

    func testInputMode_allCasesCount() {
        XCTAssertEqual(AIInputMode.allCases.count, 2)
    }

    // MARK: - 离线发送（NetworkMonitor mock 未注入时 skip）

    func testSend_emptyText_doesNotAppendMessage() {
        let before = vm.messages.count
        vm.send(text: "")
        XCTAssertEqual(vm.messages.count, before)
    }

    func testSend_whitespaceOnly_doesNotAppendMessage() {
        let before = vm.messages.count
        vm.send(text: "   \n  ")
        XCTAssertEqual(vm.messages.count, before)
    }

    // MARK: - clear

    func testClear_resetsMessages() {
        vm.clear()
        XCTAssertTrue(vm.messages.isEmpty)
    }

    func testClear_resetsStreamingContent() {
        vm.streamingContent = "partial"
        vm.clear()
        XCTAssertTrue(vm.streamingContent.isEmpty)
    }

    func testClear_resetsStreamingFlag() {
        vm.isStreaming = true
        vm.clear()
        XCTAssertFalse(vm.isStreaming)
    }

    func testClear_resetsErrorMessage() {
        vm.errorMessage = "some error"
        vm.clear()
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - cancel

    func testCancel_whenNotStreaming_doesNotCrash() {
        XCTAssertFalse(vm.isStreaming)
        vm.cancel()   // 应无 crash
        XCTAssertFalse(vm.isStreaming)
    }

    func testCancel_appendsStreamingContentIfNonEmpty() {
        vm.streamingContent = "partial response"
        vm.isStreaming = true
        vm.cancel()
        XCTAssertTrue(vm.messages.last?.content == "partial response")
    }

    func testCancel_clearsStreamingContent() {
        vm.streamingContent = "partial"
        vm.isStreaming = true
        vm.cancel()
        XCTAssertTrue(vm.streamingContent.isEmpty)
    }

    // MARK: - retry（无上次发送文本时 no-op）

    func testRetry_withoutPreviousText_doesNotCrash() {
        vm.canRetry = true
        vm.retry()   // lastSentText 为空，不执行
        // 无 crash 即通过
    }

    func testRetry_canRetryFalse_doesNothing() {
        vm.canRetry = false
        let before = vm.messages.count
        vm.retry()
        XCTAssertEqual(vm.messages.count, before)
    }

    // MARK: - prefillError（流式中 skip）

    func testPrefillError_whenStreaming_doesNotAppend() {
        vm.isStreaming = true
        let before = vm.messages.count
        vm.prefillError("some error")
        XCTAssertEqual(vm.messages.count, before)
    }

    // MARK: - BaseViewModel 继承

    func testClearError_clearsErrorMessage() {
        vm.errorMessage = "error"
        vm.clearError()
        XCTAssertNil(vm.errorMessage)
    }
}
