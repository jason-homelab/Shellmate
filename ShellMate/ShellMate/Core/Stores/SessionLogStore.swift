import Foundation

// MARK: - 会话日志条目

struct SessionLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sessionName: String
    let type: LogType
    let content: String

    enum LogType: String, CaseIterable {
        case info    = "info"
        case warning = "warning"
        case error   = "error"
        case command = "command"

        var label: String {
            switch self {
            case .info:    return "信息"
            case .warning: return "警告"
            case .error:   return "错误"
            case .command: return "命令"
            }
        }
    }
}

// MARK: - 日志 Store

/// 全局会话日志 Store（内存中保留最近 5000 条）
@MainActor
final class SessionLogStore: ObservableObject {
    static let shared = SessionLogStore()
    private init() {}

    @Published private(set) var entries: [SessionLogEntry] = []
    private let maxEntries = 5000

    func append(_ entry: SessionLogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }

    func clearSession(_ name: String) {
        entries.removeAll { $0.sessionName == name }
    }

    /// 将日志导出为 txt 文本
    func exportText(filtered: [SessionLogEntry]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return filtered.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.type.rawValue)] \(entry.content)"
        }.joined(separator: "\n")
    }
}
