import SwiftUI

// W3 新增：示范性能力注册（首批 4 项）
// 完整方案要求各 Feature 在自身模块自注册，本文件作为过渡期集中注册示例
// W4-W6 期间各 Feature 应迁出至自身的 Bootstrap

enum CapabilityBootstrap {

    @MainActor
    static func registerInitialCapabilities() {
        let r = CapabilityRegistry.shared

        // AI 助手（卖点高亮）
        // 自评 P0#3：复用已存在的 .aiPanelRequested（TerminalView 已订阅）
        r.register(Capability(
            id: "ai.assistant",
            title: "capability.ai.title",
            category: .ai,
            icon: .ai,
            shortcut: .init(key: "I", modifiers: "⌘"),
            searchTokens: ["ai", "assistant", "AI助手", "智能", "claude"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .aiPanelRequested, object: nil)
            }
        ))

        // SFTP 文件浏览（复用已存在的 .sftpPanelRequested，已有 ContentViewLifecycleModifier 订阅）
        r.register(Capability(
            id: "files.sftp",
            title: "capability.sftp.title",
            category: .files,
            icon: .sftp,
            shortcut: .init(key: "S", modifiers: "⌘⇧"),
            searchTokens: ["sftp", "files", "文件传输", "上传", "下载"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .sftpPanelRequested, object: nil)
            }
        ))

        // 端口转发（复用已存在的 .tunnelManagerRequested）
        r.register(Capability(
            id: "network.tunnel",
            title: "capability.tunnel.title",
            category: .connection,
            icon: .tunnel,
            shortcut: nil,
            searchTokens: ["tunnel", "forward", "端口转发", "socks"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .tunnelManagerRequested, object: nil)
            }
        ))

        // ── W9 扩展：5 项新能力 ─────────────────────────────

        // Tmux 管理（复用 .tmuxManagerRequested）
        r.register(Capability(
            id: "productivity.tmux",
            title: "capability.tmux.title",
            category: .productivity,
            icon: .tmux,
            shortcut: .init(key: "M", modifiers: "⌘⇧"),
            searchTokens: ["tmux", "session", "window", "复用", "终端会话"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .tmuxManagerRequested, object: nil)
            }
        ))

        // 快捷命令
        r.register(Capability(
            id: "productivity.quick_command",
            title: "capability.quick_command.title",
            category: .productivity,
            icon: .quickCommand,
            shortcut: .init(key: "K", modifiers: "⌘⇧"),
            searchTokens: ["quick", "command", "snippet", "快捷", "片段", "模板"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .quickCommandsRequested, object: nil)
            }
        ))

        // 脚本自动化
        r.register(Capability(
            id: "productivity.script_library",
            title: "capability.script.title",
            category: .productivity,
            icon: .script,
            shortcut: nil,
            searchTokens: ["script", "automation", "脚本", "自动化"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .scriptLibraryRequested, object: nil)
            }
        ))

        // 录制对话
        r.register(Capability(
            id: "productivity.recording",
            title: "capability.recording.title",
            category: .productivity,
            icon: .recording,
            shortcut: nil,
            searchTokens: ["recording", "录制", "回放", "session record"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .recordingDialogRequested, object: nil)
            }
        ))

        // 日志面板
        r.register(Capability(
            id: "monitoring.logs",
            title: "capability.logs.title",
            category: .monitoring,
            icon: .log,
            shortcut: .init(key: "L", modifiers: "⌘⌥"),
            searchTokens: ["log", "logs", "日志", "panel", "面板"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .logPanelRequested, object: nil)
            }
        ))

        // 自评 P0#3：移除 system.command_palette 自指 capability
        // 用户在 palette 内选择"命令面板"会触发 toggle 关闭，UX 死循环
    }
}

// 自评 P0#3：原 toggleAIAssistant / toggleSFTP / toggleTunnelManager 三个
// 无订阅者的通知已删除。Capability action 全部改用已存在的真实通知。
