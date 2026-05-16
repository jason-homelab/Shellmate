import Foundation
import Combine

// MARK: - Script Library Store

@MainActor
class ScriptStore: ObservableObject {

    // MARK: - 发布状态

    @Published var scripts: [Script] = []

    // MARK: - 持久化

    private let storageKey = "scriptLibrary.scripts"

    // MARK: - 初始化

    init() {
        load()
        if scripts.isEmpty {
            scripts = Script.samples
            save()
        }
    }

    // MARK: - 分组访问

    /// 返回按分类分组的脚本字典，分类名按首字母排序
    var groupedScripts: [(category: String, scripts: [Script])] {
        let dict = Dictionary(grouping: scripts, by: \.category)
        return dict.keys.sorted().map { cat in
            (category: cat, scripts: dict[cat, default: []].sorted { $0.name < $1.name })
        }
    }

    // MARK: - CRUD

    func addScript(_ script: Script) {
        scripts.append(script)
        save()
    }

    func updateScript(_ script: Script) {
        guard let idx = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        var updated = script
        updated.modifiedAt = Date()
        scripts[idx] = updated
        save()
    }

    func deleteScript(_ id: UUID) {
        scripts.removeAll { $0.id == id }
        save()
    }

    func duplicateScript(_ script: Script) {
        var copy = script
        copy.id = UUID()
        copy.name = script.name + " (副本)"
        copy.createdAt = Date()
        copy.modifiedAt = Date()
        scripts.append(copy)
        save()
    }

    // MARK: - 持久化

    private func save() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Script].self, from: data)
        else { return }
        scripts = decoded
    }
}
