import Foundation
import CoreData

/// 分组仓库协议
/// 定义分组数据的 CRUD 操作接口
protocol GroupRepositoryProtocol {
    func fetchAll() async throws -> [SessionGroup]
    func fetch(by id: UUID) async throws -> SessionGroup?
    func save(_ group: SessionGroup) async throws
    func delete(_ group: SessionGroup) async throws
    func toggleExpanded(_ group: SessionGroup) async throws
    func updateSortOrder(groups: [SessionGroup]) async throws
}

/// 分组仓库实现
/// 负责分组数据的持久化操作
@MainActor
final class GroupRepository: GroupRepositoryProtocol {

    // MARK: - 属性

    private let persistenceController: PersistenceController

    // MARK: - 初始化

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - 获取方法

    /// 获取所有分组
    func fetchAll() async throws -> [SessionGroup] {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDSessionGroup.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \CDSessionGroup.name, ascending: true)
        ]

        let entities = try context.fetch(request)
        return entities.map { SessionGroup(from: $0) }
    }

    /// 获取顶级分组（无父分组）
    func fetchTopLevel() async throws -> [SessionGroup] {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
        request.predicate = NSPredicate(format: "parent == nil")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDSessionGroup.sortOrder, ascending: true)
        ]

        let entities = try context.fetch(request)
        return entities.map { SessionGroup(from: $0) }
    }

    /// 根据 ID 获取分组
    func fetch(by id: UUID) async throws -> SessionGroup? {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        let entities = try context.fetch(request)
        return entities.first.map { SessionGroup(from: $0) }
    }

    /// 获取子分组
    func fetchChildren(of groupId: UUID) async throws -> [SessionGroup] {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
        request.predicate = NSPredicate(format: "parent.id == %@", groupId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDSessionGroup.sortOrder, ascending: true)
        ]

        let entities = try context.fetch(request)
        return entities.map { SessionGroup(from: $0) }
    }

    // MARK: - 保存方法

    /// 保存分组（新建或更新）
    func save(_ group: SessionGroup) async throws {
        let context = persistenceController.viewContext

        // 查找是否存在
        let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", group.id as CVarArg)
        request.fetchLimit = 1

        let entity: CDSessionGroup
        if let existing = try context.fetch(request).first {
            entity = existing
        } else {
            entity = CDSessionGroup(context: context)
        }

        // 更新实体
        group.update(entity: entity)

        // 处理父分组关系
        if let parentId = group.parentId {
            let parentRequest: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
            parentRequest.predicate = NSPredicate(format: "id == %@", parentId as CVarArg)
            parentRequest.fetchLimit = 1

            if let parent = try context.fetch(parentRequest).first {
                entity.parent = parent
            }
        } else {
            entity.parent = nil
        }

        persistenceController.save()
    }

    // MARK: - 删除方法

    /// 删除分组
    /// 注意：删除分组时，其下的会话会变成未分组状态
    func delete(_ group: SessionGroup) async throws {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", group.id as CVarArg)
        request.fetchLimit = 1

        if let entity = try context.fetch(request).first {
            // 将该分组下的会话设为未分组
            if let sessions = entity.sessions as? Set<CDSession> {
                for session in sessions {
                    session.group = nil
                    session.modifiedAt = Date()
                }
            }

            // 将子分组提升到当前分组的父级
            if let children = entity.children as? Set<CDSessionGroup> {
                for child in children {
                    child.parent = entity.parent
                    child.modifiedAt = Date()
                }
            }

            context.delete(entity)
            persistenceController.save()
        }
    }

    // MARK: - 展开/折叠

    /// 切换分组展开状态
    func toggleExpanded(_ group: SessionGroup) async throws {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", group.id as CVarArg)
        request.fetchLimit = 1

        if let entity = try context.fetch(request).first {
            entity.isExpanded.toggle()
            entity.modifiedAt = Date()
            persistenceController.save()
        }
    }

    /// 设置分组展开状态
    func setExpanded(_ group: SessionGroup, isExpanded: Bool) async throws {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", group.id as CVarArg)
        request.fetchLimit = 1

        if let entity = try context.fetch(request).first {
            entity.isExpanded = isExpanded
            entity.modifiedAt = Date()
            persistenceController.save()
        }
    }

    // MARK: - 批量展开/折叠

    /// 展开所有分组
    func expandAll() async throws {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()

        let entities = try context.fetch(request)
        for entity in entities {
            entity.isExpanded = true
            entity.modifiedAt = Date()
        }

        persistenceController.save()
    }

    /// 折叠所有分组
    func collapseAll() async throws {
        let context = persistenceController.viewContext
        let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()

        let entities = try context.fetch(request)
        for entity in entities {
            entity.isExpanded = false
            entity.modifiedAt = Date()
        }

        persistenceController.save()
    }

    // MARK: - 排序方法

    /// 批量更新排序顺序
    func updateSortOrder(groups: [SessionGroup]) async throws {
        let context = persistenceController.viewContext

        for group in groups {
            let request: NSFetchRequest<CDSessionGroup> = CDSessionGroup.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", group.id as CVarArg)
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                entity.sortOrder = group.sortOrder
                entity.modifiedAt = Date()
            }
        }

        persistenceController.save()
    }
}
