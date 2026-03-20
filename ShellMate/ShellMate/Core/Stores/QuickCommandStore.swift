import Foundation
import Combine

// MARK: - 快捷命令 Store

/// 快捷命令本地存储
/// 将 [QuickCommandSet] 持久化到 UserDefaults（JSON 编码），无需 Core Data
@MainActor
final class QuickCommandStore: ObservableObject {

    // MARK: - 常量

    private static let storageKey = "shellmate.quickcommandsets"

    // MARK: - 属性

    @Published private(set) var commandSets: [QuickCommandSet] = []

    /// 当前选中的命令集 ID
    @Published var selectedSetID: UUID?

    /// 当前选中的命令集
    var selectedSet: QuickCommandSet? {
        commandSets.first { $0.id == selectedSetID }
    }

    // MARK: - 单例（供全局访问）

    static let shared = QuickCommandStore()

    // MARK: - 初始化

    init() {
        load()
        if commandSets.isEmpty {
            commandSets = [.defaultSet]
            save()
        }
        selectedSetID = commandSets.first?.id
    }

    // MARK: - 命令集操作

    func addCommandSet(name: String) {
        let newSet = QuickCommandSet(
            name: name,
            sortOrder: commandSets.count
        )
        commandSets.append(newSet)
        selectedSetID = newSet.id
        save()
    }

    func deleteCommandSet(id: UUID) {
        commandSets.removeAll { $0.id == id }
        if selectedSetID == id {
            selectedSetID = commandSets.first?.id
        }
        save()
    }

    func renameCommandSet(id: UUID, newName: String) {
        guard let idx = commandSets.firstIndex(where: { $0.id == id }) else { return }
        commandSets[idx].name = newName
        save()
    }

    // MARK: - 命令操作

    func addCommand(to setID: UUID, name: String = "新命令", content: String = "") {
        guard let idx = commandSets.firstIndex(where: { $0.id == setID }) else { return }
        let sortOrder = commandSets[idx].commands.count
        let cmd = QuickCommand(name: name, content: content, sortOrder: sortOrder)
        commandSets[idx].commands.append(cmd)
        save()
    }

    func updateCommand(_ command: QuickCommand, in setID: UUID) {
        guard let setIdx = commandSets.firstIndex(where: { $0.id == setID }),
              let cmdIdx = commandSets[setIdx].commands.firstIndex(where: { $0.id == command.id })
        else { return }
        commandSets[setIdx].commands[cmdIdx] = command
        save()
    }

    func deleteCommand(id: UUID, from setID: UUID) {
        guard let setIdx = commandSets.firstIndex(where: { $0.id == setID }) else { return }
        commandSets[setIdx].commands.removeAll { $0.id == id }
        save()
    }

    func moveCommand(in setID: UUID, from source: IndexSet, to destination: Int) {
        guard let setIdx = commandSets.firstIndex(where: { $0.id == setID }) else { return }
        var cmds = commandSets[setIdx].sortedCommands
        cmds.move(fromOffsets: source, toOffset: destination)
        // 重写 sortOrder
        for (i, var cmd) in cmds.enumerated() {
            cmd.sortOrder = i
            cmds[i] = cmd
        }
        commandSets[setIdx].commands = cmds
        save()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let sets = try? JSONDecoder().decode([QuickCommandSet].self, from: data)
        else { return }
        commandSets = sets.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(commandSets) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
