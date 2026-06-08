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

        // 自评 P0#3：移除 system.command_palette 自指 capability
        // 用户在 palette 内选择"命令面板"会触发 toggle 关闭，UX 死循环
    }
}

// 自评 P0#3：原 toggleAIAssistant / toggleSFTP / toggleTunnelManager 三个
// 无订阅者的通知已删除。Capability action 全部改用已存在的真实通知。
