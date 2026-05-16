import Foundation

// MARK: - 数据传输 / 发送 / PTY 控制

extension TerminalController {

    func send(_ data: Data) async throws {
        guard state == .connected else {
            throw SSHError.sessionClosed
        }
        if let pm = proxyJumpManager {
            try await pm.write(data)
        } else if let conn = sshConnection {
            try await Task.detached(priority: .userInitiated) {
                try conn.write(data)
            }.value
        } else if let conn = telnetConnection {
            await conn.write(data)
        } else if let conn = serialConnection {
            try await conn.write(data)
        } else {
            throw SSHError.sessionClosed
        }
        SyncInputStore.shared.broadcast(data: data, from: sessionId)
    }

    func send(_ string: String) async throws {
        guard let data = string.data(using: .utf8) else {
            throw SSHError.libssh2Error(code: -1, message: "字符串编码失败")
        }
        try await send(data)
    }

    func sendControl(_ control: UInt8) async throws {
        try await send(Data([control]))
    }

    /// 连接成功后自动执行 Login Script（startupCommand）
    /// 延迟 1.0s 等待 shell 完成 MOTD/初始化输出，然后逐行发送命令
    func executeStartupCommandIfNeeded() {
        guard let cmd = session.startupCommand, !cmd.isEmpty else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, self.state == .connected else { return }
            let lines = cmd.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let toSend = line + "\n"
                guard let data = toSend.data(using: .utf8) else { continue }
                try? await self.send(data)
                if index < lines.count - 1 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            AppLogger.ssh.info("[\(self.session.name)] Login Script 执行完毕（\(lines.count) 行）")
        }
    }

    /// W12.6：接收来自同步组其他终端的广播输入，直接写入 SSH（不再二次广播）
    func broadcastReceive(data: Data) {
        Task { [weak self] in
            guard let self, state == .connected else { return }
            do {
                if let pm = proxyJumpManager {
                    try await pm.write(data)
                } else if let conn = sshConnection {
                    try await Task.detached(priority: .userInitiated) {
                        try conn.write(data)
                    }.value
                }
            } catch {
                AppLogger.general.debug("[SyncInput] 广播接收写入失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Compose Pane

    func sendComposeContent(_ text: String) {
        logInputEntry(text)
        Task { [weak self] in
            guard let self else { return }
            await recorder.appendInput(text)
            try? await send(text)
        }
    }

    func sendQuickCommand(_ command: QuickCommand) {
        logInputEntry(command.content)
        let lines = command.content.components(separatedBy: "\n")
        if command.sendLineByLine && lines.count > 1 {
            Task { [weak self] in
                guard let self else { return }
                for (index, line) in lines.enumerated() {
                    if index > 0 {
                        let delayNs = UInt64(command.lineDelay) * 1_000_000
                        try? await Task.sleep(nanoseconds: delayNs)
                    }
                    let content = command.appendNewline ? line + "\r" : line
                    try? await self.send(content)
                }
            }
        } else {
            let content = command.appendNewline ? command.content + "\r" : command.content
            Task { try? await send(content) }
        }
    }

    // MARK: - 隧道管理器面板

    func openTunnelManager() {
        isTunnelManagerOpen = true
    }

    func closeTunnelManager() {
        isTunnelManagerOpen = false
    }

    // MARK: - 终端操作

    func clearTerminal() {
        let bytes = [UInt8]("\u{1B}c".utf8)
        terminalView?.feed(byteArray: bytes[...])
    }

    // MARK: - PTY 控制

    func resizePTY(columns: Int, rows: Int) {
        guard state == .connected else { return }
        sshConnection?.resizeTerminal(cols: columns, rows: rows)
        if let pm = proxyJumpManager {
            Task { await pm.resizeTerminal(cols: columns, rows: rows) }
        }
        if let conn = telnetConnection {
            Task { await conn.updateWindowSize(columns: columns, rows: rows) }
        }
        terminalSize = TerminalSize(columns: columns, rows: rows)
    }
}
