import Foundation

// MARK: - 会话日志扩展（terminal.loggingEnabled）

extension TerminalController {

    /// 将原始终端字节追加到日志文件（仅 terminal.loggingEnabled=true 时生效）
    func appendToSessionLog(_ bytes: [UInt8]) {
        let enabled = UserDefaults.standard.object(forKey: "terminal.loggingEnabled") as? Bool ?? false
        guard enabled else { return }

        if !sessionLogOpened {
            sessionLogOpened = true
            sessionLogHandle = openSessionLogFile()
        }
        guard let handle = sessionLogHandle else { return }
        let data = Data(bytes)
        try? handle.write(contentsOf: data)
    }

    /// 创建并打开会话日志文件，返回 FileHandle
    func openSessionLogFile() -> FileHandle? {
        var logDir = UserDefaults.standard.string(forKey: "terminal.logDirectory") ?? "~/Documents/ShellMate/Logs/"
        logDir = (logDir as NSString).expandingTildeInPath

        var fmt = UserDefaults.standard.string(forKey: "terminal.logFilenameFormat") ?? "{session}_{date}.log"
        let dateStr = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd_HHmmss"
            return f.string(from: Date())
        }()
        fmt = fmt
            .replacingOccurrences(of: "{session}", with: session.name.replacingOccurrences(of: "/", with: "-"))
            .replacingOccurrences(of: "{date}", with: dateStr)
            .replacingOccurrences(of: "{host}", with: session.host)

        let url = URL(fileURLWithPath: logDir).appendingPathComponent(fmt)
        do {
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: logDir),
                                                    withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            return try FileHandle(forWritingTo: url)
        } catch {
            AppLogger.general.debug("[SessionLog] 无法创建日志文件 \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    /// 将终端输出按行写入 SessionLogStore（去除 ANSI 转义码）
    func logOutputLines(_ raw: String) {
        let clean = terminalVM.stripANSI(raw)
        let lines = clean.components(separatedBy: "\n")
        let now = Date()
        let name = session.name
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .controlCharacters)
            guard !trimmed.isEmpty else { continue }
            SessionLogStore.shared.append(SessionLogEntry(
                timestamp: now,
                sessionName: name,
                type: .info,
                content: trimmed
            ))
        }
    }

    /// 写入用户输入日志（来自 Compose Pane 或快捷命令）
    func logInputEntry(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        SessionLogStore.shared.append(SessionLogEntry(
            timestamp: Date(),
            sessionName: session.name,
            type: .command,
            content: trimmed
        ))
    }

    /// 写入系统事件日志
    func logSystemEvent(_ message: String) {
        SessionLogStore.shared.append(SessionLogEntry(
            timestamp: Date(),
            sessionName: session.name,
            type: .warning,
            content: message
        ))
    }
}
