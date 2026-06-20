import SwiftUI
import Combine

// W3 新增：能力注册中心（ADR-004）
// Feature 自注册能力，⌘K Command Palette / 工具栏 / Onboarding 三处共享

@MainActor
final class CapabilityRegistry: ObservableObject {

    static let shared = CapabilityRegistry()

    @Published private(set) var capabilities: [Capability] = []
    private var ids: Set<String> = []

    private init() {}

    func register(_ capability: Capability) {
        guard !ids.contains(capability.id) else {
            assertionFailure("重复注册 Capability: \(capability.id)")
            return
        }
        ids.insert(capability.id)
        capabilities.append(capability)
    }

    func capabilities(in category: Capability.Category) -> [Capability] {
        capabilities.filter { $0.category == category }
    }

    func search(_ query: String) -> [Capability] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return capabilities }
        return capabilities.filter { cap in
            cap.searchTokens.contains { $0.lowercased().contains(q) }
        }
    }
}

// MARK: - Capability

struct Capability: Identifiable, Equatable {

    let id: String
    let title: LocalizedStringKey
    let category: Category
    let icon: AppIcon
    let shortcut: KeyboardShortcutSpec?
    let searchTokens: [String]
    let isAvailable: () -> Bool
    let action: () -> Void

    static func == (lhs: Capability, rhs: Capability) -> Bool {
        lhs.id == rhs.id
    }

    enum Category: String, CaseIterable {
        case connection   = "connection"
        case ai           = "ai"
        case files        = "files"
        case productivity = "productivity"
        case monitoring   = "monitoring"
        case system       = "system"

        var title: LocalizedStringKey {
            switch self {
            case .connection:   return "capability.category.connection"
            case .ai:           return "capability.category.ai"
            case .files:        return "capability.category.files"
            case .productivity: return "capability.category.productivity"
            case .monitoring:   return "capability.category.monitoring"
            case .system:       return "capability.category.system"
            }
        }
    }

    struct KeyboardShortcutSpec: Equatable {
        let key: String       // 形如 "K" / "↩" / "T"
        let modifiers: String // 形如 "⌘" / "⌘⇧"

        var display: String { modifiers + key }
    }
}
