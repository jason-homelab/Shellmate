import Foundation
import Combine

// MARK: - 自动化触发器存储（技术方案 §3.19.4）

/// 自动化触发器持久化层（UserDefaults + JSON）
/// 与 TmuxConfigStore 保持一致的存储策略，避免 Core Data 迁移风险
@MainActor
final class AutomationTriggerStore: ObservableObject {

    static let shared = AutomationTriggerStore()

    @Published private(set) var triggers: [AutomationTrigger] = []

    private let defaultsKey = "automation.triggers"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        load()
    }

    // MARK: - 查询

    /// 返回对指定会话生效的已启用触发器（全局 + 会话级）
    func activeTriggers(for sessionId: UUID) -> [AutomationTrigger] {
        triggers.filter { trigger in
            guard trigger.isEnabled else { return false }
            switch trigger.scope {
            case .global:           return true
            case .session(let id):  return id == sessionId
            }
        }
    }

    // MARK: - CRUD

    func add(_ trigger: AutomationTrigger) {
        triggers.append(trigger)
        save()
    }

    func update(_ trigger: AutomationTrigger) {
        guard let idx = triggers.firstIndex(where: { $0.id == trigger.id }) else { return }
        triggers[idx] = trigger
        save()
    }

    func delete(_ trigger: AutomationTrigger) {
        triggers.removeAll { $0.id == trigger.id }
        save()
    }

    func toggle(_ trigger: AutomationTrigger) {
        var updated = trigger
        updated.isEnabled.toggle()
        update(updated)
    }

    // MARK: - 持久化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? decoder.decode([AutomationTrigger].self, from: data) else {
            return
        }
        triggers = decoded
    }

    private func save() {
        guard let data = try? encoder.encode(triggers) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
