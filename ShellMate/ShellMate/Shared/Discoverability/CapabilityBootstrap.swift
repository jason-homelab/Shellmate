import SwiftUI

// W3 新增：示范性能力注册（首批 4 项）
// 完整方案要求各 Feature 在自身模块自注册，本文件作为过渡期集中注册示例
// W4-W6 期间各 Feature 应迁出至自身的 Bootstrap

enum CapabilityBootstrap {

    @MainActor
    static func registerInitialCapabilities() {
        let r = CapabilityRegistry.shared

        // AI 助手（卖点高亮）
        r.register(Capability(
            id: "ai.assistant",
            title: "capability.ai.title",
            category: .ai,
            icon: .ai,
            shortcut: .init(key: "I", modifiers: "⌘"),
            searchTokens: ["ai", "assistant", "AI助手", "智能", "claude"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .toggleAIAssistant, object: nil)
            }
        ))

        // 命令面板自指（meta）
        r.register(Capability(
            id: "system.command_palette",
            title: "capability.command_palette.title",
            category: .system,
            icon: .commandPalette,
            shortcut: .init(key: "K", modifiers: "⌘"),
            searchTokens: ["command", "palette", "命令", "搜索"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .toggleCommandPalette, object: nil)
            }
        ))

        // SFTP 文件浏览
        r.register(Capability(
            id: "files.sftp",
            title: "capability.sftp.title",
            category: .files,
            icon: .sftp,
            shortcut: .init(key: "S", modifiers: "⌘⇧"),
            searchTokens: ["sftp", "files", "文件传输", "上传", "下载"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .toggleSFTP, object: nil)
            }
        ))

        // 端口转发
        r.register(Capability(
            id: "network.tunnel",
            title: "capability.tunnel.title",
            category: .connection,
            icon: .tunnel,
            shortcut: nil,
            searchTokens: ["tunnel", "forward", "端口转发", "socks"],
            isAvailable: { true },
            action: {
                NotificationCenter.default.post(name: .toggleTunnelManager, object: nil)
            }
        ))
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let toggleAIAssistant     = Notification.Name("shellmate.toggleAIAssistant")
    static let toggleCommandPalette  = Notification.Name("shellmate.toggleCommandPalette")
    static let toggleSFTP            = Notification.Name("shellmate.toggleSFTP")
    static let toggleTunnelManager   = Notification.Name("shellmate.toggleTunnelManager")
}
