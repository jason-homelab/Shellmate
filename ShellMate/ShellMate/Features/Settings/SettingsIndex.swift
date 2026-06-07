import SwiftUI
import Combine

// W4 新增：设置项搜索索引（解 UE-P1#13 设置搜索）
// 与 CapabilityRegistry 同构 — 自注册 + 集中检索 + Tab/Section 跳转

@MainActor
final class SettingsIndex: ObservableObject {

    static let shared = SettingsIndex()

    @Published private(set) var items: [SettingItem] = []
    @Published var pendingHighlightId: String?     // 用户在搜索中选中后，目标 Tab 用此 ID 高亮

    private var ids: Set<String> = []

    private init() {
        registerBuiltinItems()
    }

    // MARK: - 注册

    func register(_ item: SettingItem) {
        guard !ids.contains(item.id) else { return }
        ids.insert(item.id)
        items.append(item)
    }

    // MARK: - 搜索

    func search(_ query: String) -> [SettingItem] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return items.filter { item in
            item.searchTokens.contains { $0.lowercased().contains(q) }
        }
    }

    // MARK: - 触发跳转

    func jump(to item: SettingItem) {
        pendingHighlightId = item.id
        NotificationCenter.default.post(
            name: .settingsTabRequested,
            object: nil,
            userInfo: ["tab": item.tab.rawValue, "section": item.section]
        )
    }

    // MARK: - 内置设置项注册（按 Tab 分组）

    private func registerBuiltinItems() {
        // 通用 Tab
        register(.init(id: "general.protocol",
            title: "settings.general.default_protocol",
            tab: .general, section: "protocol",
            searchTokens: ["protocol", "default", "ssh", "telnet", "默认协议"]))

        register(.init(id: "general.notifications",
            title: "settings.general.notifications",
            tab: .general, section: "notifications",
            searchTokens: ["notification", "通知", "推送"]))

        // 外观
        register(.init(id: "appearance.theme",
            title: "settings.appearance.theme",
            tab: .appearance, section: "theme",
            searchTokens: ["theme", "color", "scheme", "主题", "颜色", "配色"]))

        register(.init(id: "appearance.font",
            title: "settings.appearance.font",
            tab: .appearance, section: "font",
            searchTokens: ["font", "family", "字体", "字号"]))

        register(.init(id: "appearance.cursor.blink",
            title: "settings.appearance.cursor_blink",
            tab: .appearance, section: "cursor",
            searchTokens: ["cursor", "blink", "光标", "闪烁"]))

        register(.init(id: "appearance.ligatures",
            title: "settings.appearance.ligatures",
            tab: .appearance, section: "font",
            searchTokens: ["ligatures", "连字"]))

        register(.init(id: "appearance.transparency",
            title: "settings.appearance.transparency",
            tab: .appearance, section: "background",
            searchTokens: ["transparency", "opacity", "透明度", "背景"]))

        // 终端
        register(.init(id: "terminal.font_size",
            title: "settings.terminal.default_font_size",
            tab: .terminal, section: "font",
            searchTokens: ["font size", "字号"]))

        register(.init(id: "terminal.scrollback",
            title: "settings.terminal.scrollback",
            tab: .terminal, section: "scrollback",
            searchTokens: ["scrollback", "history", "回滚", "历史"]))

        register(.init(id: "terminal.meta",
            title: "settings.terminal.meta_key",
            tab: .terminal, section: "keyboard",
            searchTokens: ["meta", "option", "alt", "键盘"]))

        register(.init(id: "terminal.keepalive",
            title: "settings.terminal.keepalive",
            tab: .terminal, section: "session",
            searchTokens: ["keepalive", "heartbeat", "心跳", "保活"]))

        // AI
        register(.init(id: "ai.model",
            title: "settings.ai.model",
            tab: .ai, section: "model",
            searchTokens: ["ai", "claude", "model", "模型"]))

        register(.init(id: "ai.api_key",
            title: "settings.ai.api_key",
            tab: .ai, section: "credentials",
            searchTokens: ["api", "key", "token", "密钥"]))

        // 安全
        register(.init(id: "security.hostkeys",
            title: "settings.security.host_keys",
            tab: .security, section: "hostkeys",
            searchTokens: ["host key", "fingerprint", "主机密钥", "指纹"]))

        register(.init(id: "security.passwords",
            title: "settings.security.passwords",
            tab: .security, section: "passwords",
            searchTokens: ["password", "keychain", "密码", "钥匙串"]))

        // iCloud
        register(.init(id: "icloud.sync",
            title: "settings.icloud.sync_status",
            tab: .icloud, section: "status",
            searchTokens: ["icloud", "sync", "同步", "云"]))
    }
}

// MARK: - SettingItem

struct SettingItem: Identifiable, Equatable {
    let id: String
    let title: LocalizedStringKey
    let tab: SettingsTab
    let section: String
    let searchTokens: [String]

    static func == (lhs: SettingItem, rhs: SettingItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - SettingsTab（与现有 SettingsView 内部 enum 平行；若已存在请合并）

enum SettingsTab: String, CaseIterable {
    case general    = "general"
    case appearance = "appearance"
    case terminal   = "terminal"
    case ai         = "ai"
    case automation = "automation"
    case highlight  = "highlight"
    case security   = "security"
    case icloud     = "icloud"

    var displayName: LocalizedStringKey {
        switch self {
        case .general:    return "settings.tab.general"
        case .appearance: return "settings.tab.appearance"
        case .terminal:   return "settings.tab.terminal"
        case .ai:         return "settings.tab.ai"
        case .automation: return "settings.tab.automation"
        case .highlight:  return "settings.tab.highlight"
        case .security:   return "settings.tab.security"
        case .icloud:     return "settings.tab.icloud"
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let settingsTabRequested = Notification.Name("shellmate.settingsTabRequested")
}
