import SwiftUI

// W1 新增：a11y 文案集中目录
// 所有 VoiceOver label / hint 必须经此枚举，便于 i18n 与 review 集中维护
// 详见 ARCH §1.1 / UI §3.3 / ADR-005

enum AccessibilityCatalog {

    // ── 连接状态点 ─────────────────────────────────────────
    enum ConnectionStatus {
        static let connected    = LocalizedStringKey("a11y.status.connected")
        static let connecting   = LocalizedStringKey("a11y.status.connecting")
        static let disconnected = LocalizedStringKey("a11y.status.disconnected")
        static let error        = LocalizedStringKey("a11y.status.error")

        static func hint(for state: ConnectionUIState) -> LocalizedStringKey {
            switch state {
            case .connected:    return "a11y.status.connected.hint"
            case .connecting:   return "a11y.status.connecting.hint"
            case .disconnected: return "a11y.status.disconnected.hint"
            case .error:        return "a11y.status.error.hint"
            }
        }
    }

    // ── 标签页 ────────────────────────────────────────────
    enum Tab {
        static let selected   = LocalizedStringKey("a11y.tab.selected")
        static let unselected = LocalizedStringKey("a11y.tab.unselected")
        static let close      = LocalizedStringKey("a11y.tab.close")
        static let activity   = LocalizedStringKey("a11y.tab.activity")
    }

    // ── AI 对话气泡 ───────────────────────────────────────
    enum ChatMessage {
        static let userRole      = LocalizedStringKey("a11y.chat.user")
        static let assistantRole = LocalizedStringKey("a11y.chat.assistant")
        static let systemRole    = LocalizedStringKey("a11y.chat.system")
        static let codeBlock     = LocalizedStringKey("a11y.chat.codeblock")
    }

    // ── 反馈 ──────────────────────────────────────────────
    enum Feedback {
        static let toast  = LocalizedStringKey("a11y.feedback.toast")
        static let banner = LocalizedStringKey("a11y.feedback.banner")
        static let close  = LocalizedStringKey("a11y.feedback.close")
    }

    // ── 工具栏 ────────────────────────────────────────────
    enum Toolbar {
        static let connect       = LocalizedStringKey("a11y.toolbar.connect")
        static let disconnect    = LocalizedStringKey("a11y.toolbar.disconnect")
        static let ai            = LocalizedStringKey("a11y.toolbar.ai")
        static let tools         = LocalizedStringKey("a11y.toolbar.tools")
        static let commandPalette = LocalizedStringKey("a11y.toolbar.command_palette")
    }

    // ── SFTP / 文件 ───────────────────────────────────────
    enum File {
        static func row(name: String, sizeBytes: Int64, isDirectory: Bool) -> String {
            let kind = isDirectory ? "文件夹" : "文件"
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "\(kind) \(name)，大小 \(formatter.string(fromByteCount: sizeBytes))"
        }
    }

    // ── CPU / 指标 ────────────────────────────────────────
    enum Metrics {
        static func cpuUsage(percent: Double, historySeconds: Int) -> String {
            "CPU 使用率 \(Int(percent))%，过去 \(historySeconds) 秒"
        }

        static func memoryUsage(usedMB: Int, totalMB: Int) -> String {
            "内存 \(usedMB)MB 已用，总 \(totalMB)MB"
        }
    }
}

// 连接状态的 UI 表达枚举（与 W2 TerminalConnectionState 共享语义层）
enum ConnectionUIState: Equatable {
    case connected
    case connecting
    case disconnected
    case error
}
