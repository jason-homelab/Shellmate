import XCTest
@testable import ShellMate

/// TerminalConnectionState 状态机单元测试（自评 P1#5）
/// 覆盖 reduce 状态转移 + UI 派生属性，对应 architecture-handbook.md §3.1
/// "每个状态机 ≥ 80% 行覆盖率" 要求
@MainActor
final class TerminalConnectionStateTests: XCTestCase {

    // MARK: - 初始态 & reduce 转移

    func test_initial_state_is_idle() {
        XCTAssertEqual(TerminalConnectionState.initial, .idle)
    }

    func test_idle_connectRequested_transitions_to_connecting_dns() {
        var state: TerminalConnectionState = .idle
        state.reduce(.connectRequested)
        XCTAssertEqual(state, .connecting(stage: .dns))
    }

    func test_disconnected_connectRequested_re_enters_connecting() {
        var state: TerminalConnectionState = .disconnected(reason: .userInitiated)
        state.reduce(.connectRequested)
        XCTAssertEqual(state, .connecting(stage: .dns))
    }

    func test_failed_connectRequested_re_enters_connecting() {
        var state: TerminalConnectionState = .failed(reason: .authentication)
        state.reduce(.connectRequested)
        XCTAssertEqual(state, .connecting(stage: .dns))
    }

    func test_connecting_stageAdvanced_updates_stage() {
        var state: TerminalConnectionState = .connecting(stage: .dns)
        state.reduce(.stageAdvanced(.tcp))
        XCTAssertEqual(state, .connecting(stage: .tcp))

        state.reduce(.stageAdvanced(.handshake))
        XCTAssertEqual(state, .connecting(stage: .handshake))

        state.reduce(.stageAdvanced(.auth))
        XCTAssertEqual(state, .connecting(stage: .auth))
    }

    func test_connecting_authSucceeded_transitions_to_connected() {
        var state: TerminalConnectionState = .connecting(stage: .auth)
        state.reduce(.authSucceeded)
        if case .connected = state {} else {
            XCTFail("expected .connected, got \(state)")
        }
    }

    func test_connected_networkLost_transitions_to_reconnecting() {
        var state: TerminalConnectionState = .connected(since: Date())
        state.reduce(.networkLost)
        XCTAssertEqual(state, .reconnecting(attempt: 1, maxAttempts: 5))
    }

    func test_reconnecting_retry_increments_attempt() {
        var state: TerminalConnectionState = .reconnecting(attempt: 1, maxAttempts: 5)
        state.reduce(.retryRequested)
        XCTAssertEqual(state, .reconnecting(attempt: 2, maxAttempts: 5))

        state.reduce(.retryRequested)
        XCTAssertEqual(state, .reconnecting(attempt: 3, maxAttempts: 5))
    }

    func test_reconnecting_retry_at_max_does_not_advance() {
        var state: TerminalConnectionState = .reconnecting(attempt: 5, maxAttempts: 5)
        state.reduce(.retryRequested)
        // 达到 maxAttempts 后 retryRequested 不再递增
        XCTAssertEqual(state, .reconnecting(attempt: 5, maxAttempts: 5))
    }

    func test_reconnecting_authSucceeded_transitions_to_connected() {
        var state: TerminalConnectionState = .reconnecting(attempt: 2, maxAttempts: 5)
        state.reduce(.authSucceeded)
        if case .connected = state {} else {
            XCTFail("expected .connected, got \(state)")
        }
    }

    func test_reconnecting_at_max_failed_transitions_to_failed_unknown() {
        var state: TerminalConnectionState = .reconnecting(attempt: 5, maxAttempts: 5)
        state.reduce(.failed(.tcpRefused))
        XCTAssertEqual(state, .failed(reason: .tcpRefused))
    }

    func test_any_failed_event_transitions_to_failed_with_reason() {
        var state: TerminalConnectionState = .connecting(stage: .handshake)
        state.reduce(.failed(.hostKeyMismatch))
        XCTAssertEqual(state, .failed(reason: .hostKeyMismatch))

        state = .connected(since: Date())
        state.reduce(.failed(.authentication))
        XCTAssertEqual(state, .failed(reason: .authentication))
    }

    func test_any_disconnected_event_transitions_to_disconnected_with_reason() {
        var state: TerminalConnectionState = .connected(since: Date())
        state.reduce(.disconnected(.userInitiated))
        XCTAssertEqual(state, .disconnected(reason: .userInitiated))

        state = .connecting(stage: .tcp)
        state.reduce(.disconnected(.networkLost))
        XCTAssertEqual(state, .disconnected(reason: .networkLost))
    }

    func test_userCancelled_resets_to_idle() {
        var state: TerminalConnectionState = .connecting(stage: .auth)
        state.reduce(.userCancelled)
        XCTAssertEqual(state, .idle)

        state = .reconnecting(attempt: 3, maxAttempts: 5)
        state.reduce(.userCancelled)
        XCTAssertEqual(state, .idle)
    }

    // MARK: - UI 派生属性

    func test_displayBadge_for_all_states() {
        XCTAssertEqual(TerminalConnectionState.idle.displayBadge, .disconnected)
        XCTAssertEqual(TerminalConnectionState.connecting(stage: .dns).displayBadge, .connecting)
        XCTAssertEqual(TerminalConnectionState.connected(since: Date()).displayBadge, .connected)
        XCTAssertEqual(TerminalConnectionState.reconnecting(attempt: 1, maxAttempts: 5).displayBadge, .connecting)
        XCTAssertEqual(TerminalConnectionState.disconnected(reason: .userInitiated).displayBadge, .disconnected)
        XCTAssertEqual(TerminalConnectionState.failed(reason: .authentication).displayBadge, .error)
    }

    func test_allowsTabClose_blocks_connected_and_reconnecting() {
        XCTAssertFalse(TerminalConnectionState.connected(since: Date()).allowsTabClose)
        XCTAssertFalse(TerminalConnectionState.reconnecting(attempt: 1, maxAttempts: 5).allowsTabClose)
        XCTAssertTrue(TerminalConnectionState.idle.allowsTabClose)
        XCTAssertTrue(TerminalConnectionState.disconnected(reason: .userInitiated).allowsTabClose)
        XCTAssertTrue(TerminalConnectionState.failed(reason: .authentication).allowsTabClose)
        XCTAssertTrue(TerminalConnectionState.connecting(stage: .tcp).allowsTabClose)
    }

    func test_showsReconnectOverlay_only_for_disconnect_or_failed() {
        XCTAssertTrue(TerminalConnectionState.disconnected(reason: .networkLost).showsReconnectOverlay)
        XCTAssertTrue(TerminalConnectionState.disconnected(reason: .serverClosed).showsReconnectOverlay)
        XCTAssertTrue(TerminalConnectionState.failed(reason: .authentication).showsReconnectOverlay)
        XCTAssertFalse(TerminalConnectionState.idle.showsReconnectOverlay)
        XCTAssertFalse(TerminalConnectionState.connecting(stage: .dns).showsReconnectOverlay)
        XCTAssertFalse(TerminalConnectionState.connected(since: Date()).showsReconnectOverlay)
        XCTAssertFalse(TerminalConnectionState.reconnecting(attempt: 1, maxAttempts: 5).showsReconnectOverlay)
    }

    /// P1#9：用户主动断开不应弹 overlay 引导重连（语义上是用户预期断开）
    func test_userInitiated_disconnect_does_not_show_reconnect_overlay() {
        XCTAssertFalse(TerminalConnectionState.disconnected(reason: .userInitiated).showsReconnectOverlay)
        XCTAssertFalse(TerminalConnectionState.disconnected(reason: .idleTimeout).showsReconnectOverlay)
    }

    func test_pulseFrequency_traffic_lights() {
        // 常规 connecting 慢脉冲 1.0s
        XCTAssertEqual(TerminalConnectionState.connecting(stage: .dns).pulseFrequency, 1.0)
        // reconnecting 急促 0.6s
        XCTAssertEqual(TerminalConnectionState.reconnecting(attempt: 2, maxAttempts: 5).pulseFrequency, 0.6)
        // 其他状态无脉冲
        XCTAssertEqual(TerminalConnectionState.idle.pulseFrequency, 0)
        XCTAssertEqual(TerminalConnectionState.connected(since: Date()).pulseFrequency, 0)
        XCTAssertEqual(TerminalConnectionState.failed(reason: .authentication).pulseFrequency, 0)
    }

    // MARK: - StateMachine wrapper

    func test_state_machine_wrapper_publishes_changes() {
        let machine = StateMachine<TerminalConnectionState>(initial: .idle)
        XCTAssertEqual(machine.state, .idle)

        machine.send(.connectRequested)
        XCTAssertEqual(machine.state, .connecting(stage: .dns))

        machine.send(.stageAdvanced(.auth))
        machine.send(.authSucceeded)
        if case .connected = machine.state {} else {
            XCTFail("expected .connected, got \(machine.state)")
        }
    }

    // MARK: - ConnectStage rawValue 与 i18n key

    func test_connect_stage_raw_values() {
        XCTAssertEqual(TerminalConnectionState.ConnectStage.dns.rawValue, 1)
        XCTAssertEqual(TerminalConnectionState.ConnectStage.tcp.rawValue, 2)
        XCTAssertEqual(TerminalConnectionState.ConnectStage.handshake.rawValue, 3)
        XCTAssertEqual(TerminalConnectionState.ConnectStage.auth.rawValue, 4)
    }
}
