import Foundation

// MARK: - 数据传输 / 发送 / PTY 控制

extension TerminalController {

    func send(_ data: Data) async throws {
        guard state == .connected else {
            throw SSHError.sessionClosed
        }
        detectExitCommand(in: data)
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

    /// 逐字节解析用户输入，检测 exit/logout/quit 命令以区分主动退出和意外断线
    private func detectExitCommand(in data: Data) {
        for byte in data {
            switch byte {
            case 0x1B:
                // ESC：转义序列开始（方向键等），重置缓冲以避免误识别
                inputLineBuffer = ""
            case 0x7F, 0x08:
                // Backspace / DEL
                if !inputLineBuffer.isEmpty { inputLineBuffer.removeLast() }
            case 0x0D, 0x0A:
                // CR / LF：命令确认，检查是否为退出命令
                let cmd = inputLineBuffer.trimmingCharacters(in: .whitespaces)
                if cmd == "exit" || cmd == "logout" || cmd == "quit" {
                    userExiting = true
                }
                inputLineBuffer = ""
            case 0x20...0x7E:
                // 可打印 ASCII：新行第一个字符时重置退出标志（说明用户在子 shell 退出后继续使用）
                if inputLineBuffer.isEmpty { userExiting = false }
                inputLineBuffer.append(Character(UnicodeScalar(byte)))
            default:
                break
            }
        }
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
