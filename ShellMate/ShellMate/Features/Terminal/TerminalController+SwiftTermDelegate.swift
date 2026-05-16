import Foundation
import SwiftTerm
import AppKit

// MARK: - SwiftTerm TerminalViewDelegate

extension TerminalController: SwiftTerm.TerminalViewDelegate {

    nonisolated func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        let d = Data(data)
        Task { @MainActor [weak self] in
            try? await self?.send(d)
        }
    }

    nonisolated func scrolled(source: SwiftTerm.TerminalView, position: Double) {}

    nonisolated func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.terminalTitle = title
            delegate?.terminalController(self, didChangeTitle: title)
        }
    }

    nonisolated func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
        Task { @MainActor [weak self] in
            self?.terminalSize = TerminalSize(columns: newCols, rows: newRows)
        }
    }

    nonisolated func bell(source: SwiftTerm.TerminalView) {
        let enabled = UserDefaults.standard.object(forKey: "terminal.bellEnabled") as? Bool ?? true
        guard enabled else { return }
        let visual = UserDefaults.standard.bool(forKey: "terminal.visualBell")
        if visual {
            Task { @MainActor in
                source.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
                try? await Task.sleep(nanoseconds: 120_000_000)
                source.layer?.backgroundColor = .clear
            }
        } else {
            NSSound.beep()
        }
    }

    nonisolated func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
        // OSC 7 序列：shells 在 cd 后发出 \e]7;file://host/path\a
        guard let raw = directory, !raw.isEmpty else { return }
        let path: String
        if raw.hasPrefix("file://") {
            if let url = URL(string: raw), !url.path.isEmpty {
                path = url.path
            } else {
                path = raw
            }
        } else {
            path = raw
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.currentRemoteDirectory != path {
                self.currentRemoteDirectory = path
                AppLogger.ssh.debug("[PWD] OSC-7 目录更新: \(path)")
            }
        }
    }

    nonisolated func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {}

    nonisolated func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}

    nonisolated func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {}

    nonisolated func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {}

    nonisolated func mouseModeChanged(source: SwiftTerm.TerminalView) {}
}

// MARK: - TmuxSendTarget

extension TerminalController: TmuxSendTarget {
    /// 发送 tmux 内部命令：直接写入 SSH 连接，不经过 SyncInputStore 广播
    func sendTmuxCommand(_ command: String) {
        guard let data = command.data(using: .utf8) else { return }
        Task { [weak self] in
            guard let self, state == .connected else { return }
            if let pm = proxyJumpManager {
                try? await pm.write(data)
            } else if let conn = sshConnection {
                try? await Task.detached(priority: .userInitiated) {
                    try conn.write(data)
                }.value
            }
        }
    }
}

// MARK: - State 扩展

extension TerminalController.State {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }

    var displayName: String {
        switch self {
        case .disconnected:  return "未连接"
        case .connecting:    return "正在连接..."
        case .connected:     return "已连接"
        case .reconnecting(let attempt): return "正在重连 (\(attempt))..."
        case .failed(let reason): return "连接失败: \(reason)"
        }
    }

    var toConnectionState: ConnectionState {
        switch self {
        case .disconnected:        return .offline
        case .connecting, .reconnecting: return .connecting
        case .connected:           return .connected
        case .failed:              return .error
        }
    }
}
