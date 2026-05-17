import Foundation
import SwiftTerm

// MARK: - 终端尺寸

struct TerminalSize: Equatable {
    let columns: Int
    let rows: Int
    static let `default` = TerminalSize(columns: 80, rows: 24)
}

// MARK: - 终端数据合并器（W15.2 60fps 优化）

/// 将高频 SSH 数据包合并到 16ms 窗口后批量喂给 SwiftTerm，防止主线程微任务积压
actor TerminalDataCoalescer {

    private var buffer: [UInt8] = []
    private var hasPendingFlush = false

    func append(_ bytes: [UInt8]) -> Bool {
        buffer.append(contentsOf: bytes)
        if hasPendingFlush { return false }
        hasPendingFlush = true
        return true
    }

    func drain() -> [UInt8] {
        hasPendingFlush = false
        let result = buffer
        buffer = []
        return result
    }
}

// MARK: - 终端控制器委托

protocol TerminalControllerDelegate: AnyObject {
    func terminalController(_ controller: TerminalController, didChangeState state: TerminalController.State)
    func terminalController(_ controller: TerminalController, didReceiveData data: Data)
    func terminalController(_ controller: TerminalController, didReceiveErrorData data: Data)
    func terminalController(_ controller: TerminalController, didChangeTitle title: String)
    func terminalController(_ controller: TerminalController, didFailWithError error: SSHError)
    func terminalController(_ controller: TerminalController, willReconnect attempt: Int, of maxAttempts: Int)
}
