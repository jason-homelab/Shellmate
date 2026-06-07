import SwiftUI
import Combine

// W8：⌘K Command Palette 状态管理
// 持有搜索 query / 当前选中 index / 显示开关，由 Host 创建并注入 View

@MainActor
final class CommandPaletteStore: ObservableObject {

    @Published var isVisible: Bool = false
    @Published var query: String = ""
    @Published var selectedIndex: Int = 0
    @Published var recentlyUsedIds: [String] = []

    private static let maxRecent = 5

    var filteredCapabilities: [Capability] {
        let registry = CapabilityRegistry.shared
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return defaultSnapshot(registry: registry)
        }
        return registry.search(query)
    }

    /// 按 category 分组，保留每组内顺序
    var groupedCapabilities: [(category: Capability.Category, items: [Capability])] {
        let items = filteredCapabilities
        var bucket: [Capability.Category: [Capability]] = [:]
        var orderedCategories: [Capability.Category] = []
        for cap in items {
            if bucket[cap.category] == nil {
                bucket[cap.category] = []
                orderedCategories.append(cap.category)
            }
            bucket[cap.category]?.append(cap)
        }
        return orderedCategories.map { ($0, bucket[$0] ?? []) }
    }

    /// 扁平化用于键盘导航
    var flatItems: [Capability] { filteredCapabilities }

    var hasResults: Bool { !flatItems.isEmpty }

    // MARK: - 可见性

    func open() {
        query = ""
        selectedIndex = 0
        isVisible = true
    }

    func close() {
        isVisible = false
        query = ""
        selectedIndex = 0
    }

    func toggle() {
        if isVisible { close() } else { open() }
    }

    // MARK: - 键盘导航

    func selectNext() {
        let count = flatItems.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
    }

    func selectPrevious() {
        let count = flatItems.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
    }

    func executeSelected() {
        guard flatItems.indices.contains(selectedIndex) else {
            handleNoResults()
            return
        }
        let cap = flatItems[selectedIndex]
        markRecentlyUsed(cap.id)
        close()
        cap.action()
    }

    func execute(_ capability: Capability) {
        markRecentlyUsed(capability.id)
        close()
        capability.action()
    }

    // MARK: - 无结果引导至 AI

    func handleNoResults() {
        // 触发 AI 助手，预填用户输入作为 prompt 起点
        let prompt = query
        close()
        NotificationCenter.default.post(
            name: .askAIWithPrompt,
            object: nil,
            userInfo: ["prompt": prompt]
        )
    }

    // MARK: - 最近使用

    private func markRecentlyUsed(_ id: String) {
        recentlyUsedIds.removeAll { $0 == id }
        recentlyUsedIds.insert(id, at: 0)
        if recentlyUsedIds.count > Self.maxRecent {
            recentlyUsedIds.removeLast(recentlyUsedIds.count - Self.maxRecent)
        }
    }

    private func defaultSnapshot(registry: CapabilityRegistry) -> [Capability] {
        // 优先展示最近使用，其后展示推荐（按 category 顺序）
        var seen = Set<String>()
        var ordered: [Capability] = []

        for id in recentlyUsedIds {
            if let cap = registry.capabilities.first(where: { $0.id == id }), !seen.contains(id) {
                ordered.append(cap)
                seen.insert(id)
            }
        }
        for cap in registry.capabilities where !seen.contains(cap.id) {
            ordered.append(cap)
            seen.insert(cap.id)
        }
        return ordered
    }
}

// MARK: - Notification

extension Notification.Name {
    /// ⌘K 切换命令面板（由 AppCommands 菜单触发）
    static let toggleCommandPaletteRequested = Notification.Name("toggleCommandPaletteRequested")
    /// 命令面板无结果时引导至 AI，prompt 在 userInfo
    static let askAIWithPrompt = Notification.Name("askAIWithPrompt")
}
