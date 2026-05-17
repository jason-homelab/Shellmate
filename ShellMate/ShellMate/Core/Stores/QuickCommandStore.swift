import Foundation
import CoreData
import Combine

// MARK: - 快捷命令 Store

/// 快捷命令存储（Core Data 版）
/// 将 [QuickCommandSet] 持久化到 Core Data（支持 CloudKit 同步）
/// 首次启动时自动将旧 UserDefaults JSON 数据迁移至 Core Data
@MainActor
final class QuickCommandStore: ObservableObject {

    // MARK: - 常量

    /// 旧版 UserDefaults 数据迁移标记
    private static let migrationDoneKey = "shellmate.quickcommand.migrated.v1"
    /// 旧版 UserDefaults 存储键（迁移完成后清除）
    private static let legacyStorageKey  = "shellmate.quickcommandsets"

    // MARK: - 属性

    @Published private(set) var commandSets: [QuickCommandSet] = []

    /// 当前选中的命令集 ID
    @Published var selectedSetID: UUID?

    /// 当前选中的命令集
    var selectedSet: QuickCommandSet? {
        commandSets.first { $0.id == selectedSetID }
    }

    // MARK: - 单例

    static let shared = QuickCommandStore()

    // MARK: - 私有属性

    private var context: NSManagedObjectContext {
        PersistenceController.shared.viewContext
    }

    // MARK: - 初始化

    init() {
        migrateIfNeeded()
        fetchAll()
        if commandSets.isEmpty {
            insertDefaultSet()
        }
        selectedSetID = commandSets.first?.id
    }

    // MARK: - 读取

    /// 从 Core Data 重新载入所有命令集
    func fetchAll() {
        let request: NSFetchRequest<CDQuickCommandSet> = CDQuickCommandSet.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDQuickCommandSet.sortOrder, ascending: true)]
        do {
            let entities = try context.fetch(request)
            commandSets = entities.map { QuickCommandSet(from: $0) }
        } catch {
            AppLogger.db.debug("[QuickCommandStore] fetchAll 失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 命令集操作

    func addCommandSet(name: String) {
        let entity = CDQuickCommandSet(context: context)
        entity.id          = UUID()
        entity.name        = name
        entity.sortOrder   = Int32(commandSets.count)
        entity.modifiedAt  = Date()
        saveContext()
        fetchAll()
        selectedSetID = entity.id
    }

    func deleteCommandSet(id: UUID) {
        let request: NSFetchRequest<CDQuickCommandSet> = CDQuickCommandSet.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                saveContext()
            }
        } catch {
            AppLogger.db.error("[QuickCommandStore] 删除命令集失败: \(error.localizedDescription)")
        }
        if selectedSetID == id { selectedSetID = nil }
        fetchAll()
        if selectedSetID == nil { selectedSetID = commandSets.first?.id }
    }

    func renameCommandSet(id: UUID, newName: String) {
        guard let entity = fetchCDSet(id: id) else { return }
        entity.name       = newName
        entity.modifiedAt = Date()
        saveContext()
        fetchAll()
    }

    // MARK: - 命令操作

    func addCommand(to setID: UUID, name: String = "新命令", content: String = "") {
        guard let setEntity = fetchCDSet(id: setID) else { return }
        let existing = (setEntity.commands as? Set<CDQuickCommand>)?.count ?? 0
        let cmd = CDQuickCommand(context: context)
        cmd.id            = UUID()
        cmd.name          = name
        cmd.commandText   = content
        cmd.appendNewline = true
        cmd.lineByLine    = false
        cmd.lineDelay     = 50
        cmd.sortOrder     = Int32(existing)
        cmd.modifiedAt    = Date()
        cmd.commandSet    = setEntity
        saveContext()
        fetchAll()
    }

    func updateCommand(_ command: QuickCommand, in setID: UUID) {
        guard let cmdEntity = fetchCDCommand(id: command.id) else { return }
        cmdEntity.name          = command.name
        cmdEntity.commandText   = command.content
        cmdEntity.appendNewline = command.appendNewline
        cmdEntity.lineByLine    = command.sendLineByLine
        cmdEntity.lineDelay     = Int32(command.lineDelay)
        cmdEntity.shortcut      = command.shortcut
        cmdEntity.sortOrder     = Int32(command.sortOrder)
        cmdEntity.modifiedAt    = Date()
        saveContext()
        fetchAll()
    }

    func deleteCommand(id: UUID, from setID: UUID) {
        guard let cmdEntity = fetchCDCommand(id: id) else { return }
        context.delete(cmdEntity)
        saveContext()
        fetchAll()
    }

    func moveCommand(in setID: UUID, from source: IndexSet, to destination: Int) {
        guard let setIdx = commandSets.firstIndex(where: { $0.id == setID }) else { return }
        var cmds = commandSets[setIdx].sortedCommands
        cmds.move(fromOffsets: source, toOffset: destination)
        for (i, cmd) in cmds.enumerated() {
            if let entity = fetchCDCommand(id: cmd.id) {
                entity.sortOrder  = Int32(i)
                entity.modifiedAt = Date()
            }
        }
        saveContext()
        fetchAll()
    }

    // MARK: - 私有辅助

    private func fetchCDSet(id: UUID) -> CDQuickCommandSet? {
        let request: NSFetchRequest<CDQuickCommandSet> = CDQuickCommandSet.fetchRequest()
        request.predicate  = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        do {
            return try context.fetch(request).first
        } catch {
            AppLogger.db.error("[QuickCommandStore] 查询命令集失败: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchCDCommand(id: UUID) -> CDQuickCommand? {
        let request: NSFetchRequest<CDQuickCommand> = CDQuickCommand.fetchRequest()
        request.predicate  = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        do {
            return try context.fetch(request).first
        } catch {
            AppLogger.db.error("[QuickCommandStore] 查询命令失败: \(error.localizedDescription)")
            return nil
        }
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            AppLogger.db.debug("[QuickCommandStore] 保存失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 默认数据

    private func insertDefaultSet() {
        let setEntity = CDQuickCommandSet(context: context)
        setEntity.id         = UUID()
        setEntity.name       = "默认命令集"
        setEntity.sortOrder  = 0
        setEntity.modifiedAt = Date()

        let defaults: [(String, String)] = [
            ("查看进程", "ps aux"),
            ("磁盘用量", "df -h"),
            ("内存信息", "free -h"),
            ("系统日志", "tail -n 50 /var/log/syslog"),
            ("网络连接", "ss -tunlp"),
            ("当前用户", "whoami && id"),
        ]
        for (i, (name, text)) in defaults.enumerated() {
            let cmd = CDQuickCommand(context: context)
            cmd.id            = UUID()
            cmd.name          = name
            cmd.commandText   = text
            cmd.appendNewline = true
            cmd.lineByLine    = false
            cmd.lineDelay     = 50
            cmd.sortOrder     = Int32(i)
            cmd.modifiedAt    = Date()
            cmd.commandSet    = setEntity
        }
        saveContext()
        fetchAll()
    }

    // MARK: - 一次性数据迁移（UserDefaults → Core Data）

    private func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.migrationDoneKey) else { return }
        defer {
            UserDefaults.standard.set(true, forKey: Self.migrationDoneKey)
            UserDefaults.standard.removeObject(forKey: Self.legacyStorageKey)
        }

        guard let data = UserDefaults.standard.data(forKey: Self.legacyStorageKey),
              let sets = try? JSONDecoder().decode([QuickCommandSet].self, from: data),
              !sets.isEmpty
        else { return }

        for set in sets.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let setEntity = CDQuickCommandSet(context: context)
            setEntity.id         = set.id
            setEntity.name       = set.name
            setEntity.sortOrder  = Int32(set.sortOrder)
            setEntity.modifiedAt = Date()

            for cmd in set.commands {
                let cmdEntity = CDQuickCommand(context: context)
                cmdEntity.id            = cmd.id
                cmdEntity.name          = cmd.name
                cmdEntity.commandText   = cmd.content
                cmdEntity.appendNewline = cmd.appendNewline
                cmdEntity.lineByLine    = cmd.sendLineByLine
                cmdEntity.lineDelay     = Int32(cmd.lineDelay)
                cmdEntity.shortcut      = cmd.shortcut
                cmdEntity.sortOrder     = Int32(cmd.sortOrder)
                cmdEntity.modifiedAt    = Date()
                cmdEntity.commandSet    = setEntity
            }
        }
        saveContext()
        AppLogger.db.debug("[QuickCommandStore] 已从 UserDefaults 迁移 \(sets.count) 个命令集至 Core Data")
    }
}
