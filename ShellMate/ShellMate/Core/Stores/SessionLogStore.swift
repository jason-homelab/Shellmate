import Foundation

// MARK: - 会话日志条目

struct SessionLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sessionName: String
    let type: LogType
    let content: String

    enum LogType: String, CaseIterable {
        case output = "output"
        case input  = "input"
        case error  = "error"
        case system = "system"

        var label: String {
            switch self {
            case .output: return "输出"
            case .input:  return "输入"
            case .error:  return "错误"
            case .system: return "系统"
            }
        }
    }
}

// MARK: - 日志 Store

/// 全局会话日志 Store（内存中保留最近 5000 条）
final class SessionLogStore: ObservableObject {
    static let shared = SessionLogStore()
    private init() {}

    @Published private(set) var entries: [SessionLogEntry] = []
    private let maxEntries = 5000

    func append(_ entry: SessionLogEntry) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }

    func clear() {
        DispatchQueue.main.async { self.entries.removeAll() }
    }

    func clearSession(_ name: String) {
        DispatchQueue.main.async {
            self.entries.removeAll { $0.sessionName == name }
        }
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
