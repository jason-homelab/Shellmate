import Foundation
import AppKit

// MARK: - 录制条目（asciinema v2 事件）

/// asciinema v2 格式的单个时间线事件
struct AsciicastEvent: Codable {
    let time: Double   // 从录制开始的秒数
    let type: String   // "o"=输出, "i"=输入
    let data: String   // 终端数据
}

// MARK: - 录制文件元数据

struct RecordingFile: Identifiable, Codable {
    let id: UUID
    var sessionName: String
    var filename: String          // 相对 ~/Documents/ShellMate/Recordings/
    var duration: TimeInterval    // 总时长（秒）
    var createdAt: Date
    var fileSize: Int64           // 字节数，-1 表示未知
}

// MARK: - SessionRecorder

/// asciinema v2 格式的终端录制 Actor
/// 线程安全：所有状态由 Actor 保护
actor SessionRecorder {

    // MARK: - 状态

    enum State {
        case idle
        case recording(startedAt: Date)
        case stopped
    }

    private(set) var state: State = .idle
    private(set) var sessionName: String = ""

    private var startTime: Date?
    private var events: [AsciicastEvent] = []
    private var terminalWidth: Int = 220
    private var terminalHeight: Int = 50

    // MARK: - 录制控制

    func startRecording(sessionName: String, width: Int = 220, height: Int = 50) {
        guard case .idle = state else { return }
        self.sessionName = sessionName
        self.terminalWidth = width
        self.terminalHeight = height
        self.startTime = Date()
        self.events = []
        self.state = .recording(startedAt: Date())
    }

    func appendOutput(_ data: String) {
        guard case .recording = state, let start = startTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        events.append(AsciicastEvent(time: elapsed, type: "o", data: data))
    }

    func appendInput(_ data: String) {
        guard case .recording = state, let start = startTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        events.append(AsciicastEvent(time: elapsed, type: "i", data: data))
    }

    /// 停止录制并返回 asciinema v2 格式的文件内容
    func stopRecording() -> (content: Data, duration: TimeInterval)? {
        guard case .recording = state, let start = startTime else { return nil }
        let duration = Date().timeIntervalSince(start)
        state = .idle

        let content = buildAsciinemaV2(duration: duration)
        startTime = nil
        return content.flatMap { ($0, duration) }
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var elapsedSeconds: TimeInterval {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - 序列化

    /// 构建 asciinema v2 格式（NDJSON：每行一个 JSON）
    private func buildAsciinemaV2(duration: TimeInterval) -> Data? {
        var lines: [String] = []

        // 头部 JSON 对象
        let header: [String: Any] = [
            "version": 2,
            "width": terminalWidth,
            "height": terminalHeight,
            "timestamp": Int(startTime?.timeIntervalSince1970 ?? Date().timeIntervalSince1970),
            "duration": duration,
            "title": sessionName,
            "env": ["TERM": "xterm-256color"]
        ]
        guard let headerData = try? JSONSerialization.data(withJSONObject: header, options: .sortedKeys),
              let headerLine = String(data: headerData, encoding: .utf8)
        else { return nil }
        lines.append(headerLine)

        // 事件行：[time, type, data]
        for event in events {
            let arr: [Any] = [event.time, event.type, event.data]
            if let d = try? JSONSerialization.data(withJSONObject: arr),
               let s = String(data: d, encoding: .utf8) {
                lines.append(s)
            }
        }

        return (lines.joined(separator: "\n") + "\n").data(using: .utf8)
    }
}

// MARK: - 录制文件存储

enum RecordingStorage {

    /// ~/Documents/ShellMate/Recordings/ 目录
    static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("ShellMate/Recordings", isDirectory: true)
    }

    static func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true
        )
    }

    /// 保存录制数据到磁盘，返回保存结果
    static func save(
        data: Data,
        sessionName: String,
        duration: TimeInterval
    ) throws -> RecordingFile {
        try ensureDirectoryExists()

        let sanitized = sessionName
            .components(separatedBy: .init(charactersIn: "/:*?\"<>|\\"))
            .joined(separator: "_")
        let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(19).replacingOccurrences(of: ":", with: "-")
        let filename = "\(sanitized.isEmpty ? "session" : sanitized)_\(dateStr).cast"
        let fileURL = recordingsDirectory.appendingPathComponent(filename)

        try data.write(to: fileURL, options: .atomic)

        return RecordingFile(
            id: UUID(),
            sessionName: sessionName,
            filename: filename,
            duration: duration,
            createdAt: Date(),
            fileSize: Int64(data.count)
        )
    }

    /// 列出所有已保存的录制文件
    static func listRecordings() -> [RecordingFile] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return urls
            .filter { $0.pathExtension == "cast" }
            .compactMap { url -> RecordingFile? in
                let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let size = Int64(attrs?.fileSize ?? 0)
                let created = attrs?.creationDate ?? Date()
                return RecordingFile(
                    id: UUID(),
                    sessionName: url.deletingPathExtension().lastPathComponent,
                    filename: url.lastPathComponent,
                    duration: 0,     // 不解析文件内容获取 duration
                    createdAt: created,
                    fileSize: size
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 删除录制文件
    static func delete(filename: String) throws {
        let url = recordingsDirectory.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: url)
    }

    /// 在 Finder 中展示
    static func revealInFinder(filename: String) {
        let url = recordingsDirectory.appendingPathComponent(filename)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
